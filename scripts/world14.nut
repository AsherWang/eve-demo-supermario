// World 1-4. Terrain comes from the ROM's L_CastleArea1 parser output; the
// verified ROM and Mesen remain offline extraction tools only.
if(!("ROM_WORLD_1_4_AREA" in getroottable())) dofile("scripts/generated/world14_data.nut");
if(!("ROM_WORLD_1_4_METATILES" in getroottable())) dofile("scripts/generated/world14_map.nut");
world14Assets <- null;
world14AudioAssets <- {
    theme = "assets/audio/castle_theme.wav",
    fast = "assets/audio/castle_fast.wav",
    clear = "assets/audio/castle_clear.wav",
    bowserFire = "assets/audio/bowser_fire.wav",
    bowserFall = "assets/audio/bowser_fall.wav"
};

// SMBDIS FirebarPosLookupTbl, FirebarTblOffsets and FirebarMirrorData.
// The ROM rotates a 16.8 spin state and indexes this quarter-circle table;
// it does not use a floating-point sine.
WORLD14_FIREBAR_POS <- [
    0,1,3,4,5,6,7,7,8,
    0,3,6,9,11,13,14,15,16,
    0,4,9,13,16,19,22,23,24,
    0,6,12,18,22,26,29,31,32,
    0,7,15,22,28,33,37,39,40,
    0,9,18,27,33,39,44,47,48,
    0,11,21,31,39,46,51,55,56,
    0,12,24,36,45,53,59,62,64,
    0,14,27,40,50,59,66,70,72,
    0,15,31,45,56,66,74,78,80,
    0,17,34,49,62,73,81,86,88
];
WORLD14_FIREBAR_OFFSETS <- [0,9,18,27,36,45,54,63,72,81,90,99];
WORLD14_FIREBAR_MIRROR <- [1,3,2,0];
WORLD14_FIREBAR_SPEED <- [0x28,0x38,0x28,0x38,0x28];
WORLD14_FIREBAR_DIRECTION <- [0,0,0x10,0x10,0];
WORLD14_FLAME_TIMERS <- [0xbf,0x40,0xbf,0xbf,0xbf,0x40,0x40,0xbf];
WORLD14_FLAME_Y <- [0x90,0x80,0x70,0x90];

function loadWorld14Assets() {
    local metatiles = {};
    foreach(column in ROM_WORLD_1_4_METATILES)
        foreach(meta in column)
            if(meta != 0 && !(meta in metatiles))
                metatiles[meta] <- loadTexture("assets/world14/metatile-" + meta + ".png");
    world14Assets = {
        hudCoins = [loadTexture("assets/world14/hud-coin-0.png"),
            loadTexture("assets/world14/hud-coin-1.png"),
            loadTexture("assets/world14/hud-coin-2.png"),
            loadTexture("assets/world14/hud-coin-3.png"),
            loadTexture("assets/world14/hud-coin-4.png"),
            loadTexture("assets/world14/hud-coin-5.png")],
        metatiles = metatiles,
        bowser = [loadTexture("assets/world14/bowser-0.png"),
                  loadTexture("assets/world14/bowser-1.png")],
        retainer = loadTexture("assets/world14/toad.png"),
        firebar = [loadTexture("assets/world14/firebar-0.png"),
                   loadTexture("assets/world14/firebar-1.png")],
        bowserFlame = loadTexture("assets/world14/bowser-flame.png"),
        audio = world14AudioAssets,
        manifest = "assets/world14/manifest.json"
    };
    if("assets" in getroottable() && assets != null) assets.world14 <- world14Assets;
    return world14Assets;
}

function world14TileForMeta(meta) {
    if(meta == 0x62 || meta == 0x61) return TILE_SOLID;
    if(meta == 0x5f) return TILE_HIDDEN_COIN;
    if(meta == 0xc0) return TILE_QUESTION;
    if(meta == 0xc1) return TILE_POWERUP_BLOCK;
    if(meta == 0xc4) return TILE_USED;
    if(meta == 0x89) return TILE_SOLID;
    // Lava, chain, axe and the castle's decorative metatiles are non-solid.
    return TILE_EMPTY;
}

function world14BuildCollision(g) {
    g.tiles = array(LEVEL_WIDTH * LEVEL_HEIGHT, TILE_EMPTY);
    for(local x = 0; x < ROM_WORLD_1_4_METATILES.len(); x += 1)
        for(local row = 0; row < 13; row += 1) {
            local meta = ROM_WORLD_1_4_METATILES[x][row];
            setTile(g, x, row + 2, world14TileForMeta(meta));
        }
}

function world14ParseCastleObjects(g) {
    local data = ROM_WORLD_1_4_ENEMY;
    local page = 0, cursor = 0, pageSelected = false;
    local firebars = [], bowser = null, retainer = null, podoboo = null;
    while(cursor + 1 < data.len() && data[cursor] != 0xFF) {
        local a = data[cursor], b = data[cursor + 1], row = a & 15;
        if((b & 0x80) != 0 && !pageSelected) {
            page += 1;
            pageSelected = true;
        }
        if(row == 15 && !pageSelected) {
            page = b & 0x3F;
            pageSelected = true;
            cursor += 2;
            continue;
        }
        local unit = page * 16 + (a >> 4);
        local id = b & 0x3F;
        if((b&0x40)!=0) {cursor+=2;pageSelected=false;continue;}
        if(id >= 0x1B && id <= 0x1F) {
            local longBar = id == 0x1F;
            firebars.append({
                unit = unit, row = row, id = id,
                x = unit * 16.0 + 4.0, y = row * 16.0 + 4.0,
                length = longBar ? 12 : 6,
                spinLow = 0, spinHigh = 0,
                awake = false, retired = false, slot = -1,
                spinSpeed = WORLD14_FIREBAR_SPEED[id - 0x1B],
                spinDirection = WORLD14_FIREBAR_DIRECTION[id - 0x1B]
            });
        } else if(id == 0x2D) {
            bowser = {
                x = unit * 16.0, y = row * 16.0, width = 32.0, height = 32.0,
                originX = unit * 16.0, direction = -1, hp = 5, defeated = false,
                falling = false, hidden = false, vy = 0.0, ySpeed = 0.0,
                fireTimer = 0xDF, feetTimer = 32, faceTimer = 32, feetFrame = 0,
                bodyControls = 0, movementSpeed = 2, movingDir = 2,
                maxRange = 0x21, flameTimerCtrl = 0, flameYOffset = 0
            };
        } else if(id == 0x35) {
            retainer = {x = unit * 16.0, y = 184.0, width = 16.0, height = 24.0};
        } else if(id == 0x0C) {
            // E_CastleArea1 also contains one Podoboo slot immediately before
            // Bowser. It uses the lava column as its cycle origin.
            podoboo = {x = unit * 16.0, baseY = 224.0, y = 224.0,
                       vy = -4.0, timer = 90, width = 8.0, height = 12.0};
        }
        cursor += 2;
        pageSelected = false;
    }
    g.world14.firebars = firebars;
    g.world14.bowser = bowser;
    g.world14.retainer = retainer;
    g.world14.podoboo = podoboo;
}

function startWorld14(g) {
    g.level = 4;
    g.stage = "world14";
    g.area = "castle";
    g.romBackgroundCollision = true;
    g.areaWidth = ROM_WORLD_1_4_METATILES.len();
    clearAreaObjects(g);
    g.plants = []; g.platforms = []; g.enterablePipes = []; g.sidePipeX = -1;
    g.flagX = 100000.0; g.castleX = 100000.0; g.castleFlagVisible = false;
    g.endLevelScrollLocked = false; g.fireworks = []; g.floatingScores = [];
    local resetWorld = {
        metatiles = ROM_WORLD_1_4_METATILES,
        baseMetatiles = ROM_WORLD_1_4_METATILES,
        firebars = [], bowser = null, retainer = null, podoboo = null,
        firebarSlots = array(5,null), firebarSlotHigh = array(5,0),
        projectiles = [], flames = [], bridgeRight = 140,
        axeX = 141.0 * 16.0, stateFrames = 0, clearStarted = false,
        rescued = false, completeFrames = 0, axeSparkle = 0,
        bridgeOffset = 0, axeGone = false, chainGone = false,
        primaryMsgCounter = 0, secondaryMsgCounter = 0, worldEndFrames = 0
    };
    if("world14" in g) g.world14 = resetWorld; else g.world14 <- resetWorld;
    world14BuildCollision(g);
    world14ParseCastleObjects(g);
    // InitializeArea entry control $02 places small Mario's body at Y $60
    // (canonical OAM Y $50) on the raised castle entrance.
    resetPlayerForArea(g, 40, 80);
    g.player.grounded = true;
    g.player.entranceFalling = false;
    g.player.fallForce = 0x28;
    g.cameraX = 0.0; g.displayCameraX = 0.0; g.previousScrollAmount = 0.0;
    g.checkpointPage = 0;
    g.time = 300; g.displayTime = 300; g.gameTimerControl = 23; g.hurryActive = false;
    g.state = "playing"; g.stateTimer = 0.0;
    g.soundEvents.append("resume_music");
    return g;
}

function world14BridgePresent(g) {
    if(!("world14" in g)) return false;
    return g.world14.bridgeRight >= 128;
}

function world14TileTexture(g, tx, ty, tile) {
    if(world14Assets == null) loadWorld14Assets();
    if(!("world14" in g) || tx < 0 || tx >= g.areaWidth || ty < 2 || ty >= LEVEL_HEIGHT)
        return null;
    local row = ty - 2, meta = g.world14.metatiles[tx][row];
    if(meta == 0) return null;
    if(g.world14.axeGone && meta == 0xC5) return null;
    if(g.world14.chainGone && meta == 0x0C) return null;
    if(meta == 0x89 && tx > g.world14.bridgeRight) {
        return null;
    }
    if(meta == 0xC1 && tile == TILE_USED) return world14Assets.metatiles[0xC4];
    return meta in world14Assets.metatiles ? world14Assets.metatiles[meta] : null;
}

function drawWorld14Background(g) {
    // CastlePaletteData makes ROM metatiles $86/$87 the animated lava surface
    // and body. The shared black backdrop is supplied by the parent renderer.
    return null;
}

function world14OverlapPlayer(g, x, y, width, height) {
    local p = g.player;
    return !p.dead && overlaps(p.x + 3.0, p.y + 3.0, 10.0, p.height - 4.0,
                               x, y, width, height);
}

function world14FirebarPoint(bar, index) {
    // ProcFirebar draws the fixed origin first, then five radius-table
    // entries for a short bar. The origin is not lookup-table radius eight.
    if(index==0) return {x=bar.x,y=bar.y};
    local horizontalNibble = bar.spinHigh & 0x0F;
    if(horizontalNibble >= 9)
        horizontalNibble = 16 - horizontalNibble;
    local verticalNibble = (bar.spinHigh + 8) & 0x0F;
    if(verticalNibble >= 9)
        verticalNibble = 16 - verticalNibble;
    local offset = WORLD14_FIREBAR_OFFSETS[index-1];
    local horizontal = WORLD14_FIREBAR_POS[offset + horizontalNibble];
    local vertical = WORLD14_FIREBAR_POS[offset + verticalNibble];
    local mirror = WORLD14_FIREBAR_MIRROR[(bar.spinHigh >> 3) & 0x03];
    if((mirror & 0x01) == 0) horizontal = -horizontal;
    if((mirror & 0x02) == 0) vertical = -vertical;
    return {
        x = bar.x + horizontal,
        y = bar.y + vertical
    };
}

function world14ToggleBit(value, mask) {
    return (value & mask) != 0 ? value - mask : value + mask;
}

function world14TickFirebar(bar) {
    local low = bar.spinLow;
    local high = bar.spinHigh;
    if(bar.spinDirection == 0) {
        low += bar.spinSpeed;
        if(low > 0xFF) {
            low = low & 0xFF;
            high += 1;
        }
    } else {
        low -= bar.spinSpeed;
        if(low < 0) {
            low = low & 0xFF;
            high -= 1;
        }
    }
    high = high & 0x1F;
    if(bar.id == 0x1F && high == 0x08) high += 1;
    if(bar.id == 0x1F && high == 0x18) high += 1;
    bar.spinLow = low;
    bar.spinHigh = high;
}

function world14NextFlameTimer(b) {
    local timer = WORLD14_FLAME_TIMERS[b.flameTimerCtrl & 0x07];
    b.flameTimerCtrl = (b.flameTimerCtrl + 1) & 0x07;
    return timer;
}

function world14SpawnBowserFlame(g) {
    local b = g.world14.bowser;
    if(b == null || b.defeated) return;
    local lane = b.flameYOffset & 0x03;
    b.flameYOffset = (b.flameYOffset + 1) & 0x03;
    g.world14.projectiles.append({
        x = b.x, y = WORLD14_FLAME_Y[lane] - 16.0,
        width = 24.0, height = 8.0, vx = -0.25, vy = 0.0,
        targetY = WORLD14_FLAME_Y[lane] - 16.0, active = true
    });
    emitSound(g, "bowser_fire");
}

function world14HurtBowser(g) {
    local b = g.world14.bowser;
    if(b == null || b.defeated) return;
    b.hp -= 1;
    if(b.hp <= 0) {
        b.defeated = true; b.falling = true; b.vy = -2.0;
        emitSound(g, "bowser_fall");
        parityRecordEvent(g, "gameplay", "bowser_defeated");
    }
}

function updateWorld14Actors(g) {
    if(!("world14" in g) || g.state != "playing" || g.player.dead) return;
    local w = g.world14, p = g.player;
    local frame = g.nesFrameCounter;
    local actorCamera=g.cameraX;
    if(p.nesXScroll>0 && !p.scrollSideCollisionTimer) {
        local position=p.previousX-g.cameraX;
        if(position>=80.0) {
            local scroll=p.nesXScroll;
            if(position<112.0 && scroll>=2) scroll-=1;
            actorCamera+=scroll;
        }
    }
    local parserBoundary=floor((actorCamera+303.0)/16.0)*16.0;

    foreach(bar in w.firebars) {
        if(bar.retired) continue;
        if(bar.awake && bar.x<actorCamera-73.0) {
            w.firebarSlots[bar.slot]=null;bar.retired=true;continue;
        }
        if(!bar.awake) {
            if(bar.x-4.0>parserBoundary) continue;
            local slot=-1;
            for(local index=0;index<5;index+=1)
                if(w.firebarSlots[index]==null) {slot=index;break;}
            if(slot<0) continue;
            bar.slot=slot;bar.awake=true;
            // InitShortFirebar clears the low spin byte only. Reused enemy
            // slots retain their previous high byte, including offscreen phase.
            bar.spinHigh=w.firebarSlotHigh[slot];
            w.firebarSlots[slot]=bar;
            continue;
        }
        if(bar.x<actorCamera || bar.x>actorCamera+255.0) continue;
        world14TickFirebar(bar);
        w.firebarSlotHigh[bar.slot]=bar.spinHigh;
        for(local index = 0; index < bar.length; index += 1) {
            local point = world14FirebarPoint(bar, index);
            local canonicalY=p.big&&!p.crouching?p.y:p.y-16.0;
            local sampleX=p.x+4.0;
            local relativeX=point.x-actorCamera;
            local hit=false;
            if(canonicalY>=0 && canonicalY<256 && relativeX>=0 && relativeX<240 &&
               abs(sampleX-point.x)<8.0) {
                foreach(offset in (p.big&&!p.crouching?[0.0,12.0,24.0]:[24.0]))
                    if(abs(canonicalY+offset-point.y)<8.0) hit=true;
            }
            if(hit && p.starTimer<=0.0) {
                hurtPlayer(g, {kind="firebar", x=point.x});
                if(p.dead) return;
            }
        }
    }

    local b = w.bowser;
    if(b != null) {
        if(!b.defeated && b.x < g.cameraX + 320.0) {
            // BowserControl skips feet and horizontal movement while the
            // mouth bit is set. MovingDir controls facing; the signed speed
            // byte controls travel independently, including left-facing
            // travel to the right of the original position.
            if((b.bodyControls & 0x80)==0) {
            b.feetTimer -= 1;
            if(b.feetTimer <= 0) {
                b.feetTimer = 32;
                b.feetFrame = 1 - b.feetFrame;
                b.bodyControls = world14ToggleBit(b.bodyControls, 0x01);
            }
            if((frame & 0x0F) == 0) b.movingDir = 2;
            if(b.faceTimer > 0) {
                if(p.x > b.x) {
                    b.movingDir = 1;
                    b.movementSpeed = 2;
                    b.faceTimer = 32;
                    b.fireTimer = 32;
                }
                b.faceTimer -= 1;
            }
            if((frame & 0x03) == 0) {
                local delta = b.x - b.originX;
                b.x += b.movementSpeed;
                delta = b.x - b.originX;
                if(delta < 0) delta = -delta;
                if(b.movingDir!=1 && delta >= b.maxRange)
                    b.movementSpeed = b.x > b.originX ? -1 : 1;
            }
            }
            b.fireTimer -= 1;
            if(b.fireTimer <= 0) {
                b.fireTimer = 32;
                b.bodyControls = world14ToggleBit(b.bodyControls, 0x80);
                if((b.bodyControls & 0x80) == 0) {
                    b.fireTimer = world14NextFlameTimer(b);
                    world14SpawnBowserFlame(g);
                }
            }
            if(world14OverlapPlayer(g, b.x + 3.0, b.y + 3.0, 26.0, 29.0)) {
                hurtPlayer(g, {kind="bowser", x=b.x});
                if(p.dead) return;
            }
        }
        foreach(ball in g.fireballs) {
            if(!ball.active || ball.exploding) continue;
            if(overlaps(ball.x, ball.y, ball.width, ball.height,
                        b.x + 2.0, b.y + 2.0, 28.0, 30.0)) {
                explodeFireball(ball);
                world14HurtBowser(g);
            }
        }
    }

    for(local index = w.projectiles.len() - 1; index >= 0; index -= 1) {
        local shot = w.projectiles[index];
        shot.x += shot.vx;
        if(shot.y < shot.targetY) shot.y += 0.25;
        else if(shot.y > shot.targetY) shot.y -= 0.25;
        if(world14OverlapPlayer(g, shot.x, shot.y, shot.width, shot.height)) {
            shot.active = false;
            hurtPlayer(g, {kind="bowser_flame", x=shot.x});
            if(p.dead) return;
        }
        if(shot.x + shot.width < g.cameraX - 32.0) shot.active = false;
        if(!shot.active) w.projectiles.remove(index);
    }

    local pod = w.podoboo;
    if(pod != null && pod.x > g.cameraX - 32.0 && pod.x < g.cameraX + 288.0) {
        if(pod.timer > 0) pod.timer -= 1;
        else {
            pod.y += pod.vy; pod.vy += 0.08;
            if(world14OverlapPlayer(g, pod.x, pod.y, pod.width, pod.height)) {
                hurtPlayer(g, {kind="podoboo", x=pod.x});
                if(p.dead) return;
            }
            if(pod.y > pod.baseY) { pod.y = pod.baseY; pod.vy = -4.0; pod.timer = 90; }
        }
    }

    // ChkFootMTile handles $c5 only on a downward foot probe. A body AABB
    // also catches Mario passing beside the axe, prematurely starting the
    // bridge collapse while he is still above the bridge.
    local axeFootRow=floor((p.y+p.height)/16.0).tointeger()-2;
    local touchedAxe=false;
    if(p.nesYSpeed>=0 && axeFootRow>=0 && axeFootRow<13)
        foreach(offset in [3.0,12.0]) {
            local column=floor((p.x+offset)/16.0).tointeger();
            if(column>=0 && column<g.areaWidth &&
               w.metatiles[column][axeFootRow]==0xC5) touchedAxe=true;
        }
    if(touchedAxe) {
        g.state = "world14Axe";
        g.stateTimer = 0.0;
        w.stateFrames = 0;
        p.nesXSpeed = 0x18; p.vx=p.nesXSpeed/16.0*NES_FRAME_RATE;
        parityRecordEvent(g, "gameplay", "axe_touched");
        return;
    }

    // ROM metatiles $86/$87 are lava. Falling through their body is fatal.
    local column = floor((p.x + p.width * 0.5) / TILE_SIZE).tointeger();
    local row = floor((p.y + p.height - 1.0) / TILE_SIZE).tointeger() - 2;
    if(column >= 0 && column < g.areaWidth && row >= 0 && row < 13) {
        local meta = w.metatiles[column][row];
        if((meta == 0x86 || meta == 0x87) && p.y + p.height >= (row + 2) * 16.0) {
            killPlayer(g, ",\"cause\":\"lava\"");
        }
    }
}

function world14RemoveBridgeSection(g) {
    local w = g.world14;
    if(w.bridgeOffset >= 15) return false;
    local offset = w.bridgeOffset;
    if(offset == 0) {
        w.axeGone = true;
    } else if(offset == 1) {
        w.chainGone = true;
    } else {
        // SMBDIS BridgeCollapseData: bridge columns $98..$80, one ROM
        // metatile (16 pixels) every four frames.
        local column = 140 - (offset - 2);
        for(local row = 0; row < 13; row += 1)
            if(w.metatiles[column][row] == 0x89)
                setTile(g, column, row + 2, TILE_EMPTY);
        w.bridgeRight = column - 1;
    }
    emitSound(g, "blast");
    w.bridgeOffset += 1;
    return true;
}

function updateWorld14Transition(g) {
    if(!("world14" in g)) return false;
    if(g.input.resetQueued && ["world14Axe","world14VictoryWalk","world14Rescue",
            "world14EndWorld","worldComplete"].find(g.state)!=null) {
        resetRound(g);
        return true;
    }
    local w = g.world14, p = g.player;
    if(g.state == "world14Axe") {
        w.stateFrames += 1;
        local b = w.bowser;
        if(b != null && !b.defeated) {
            b.feetTimer -= 1;
            if(b.feetTimer <= 0) {
                b.feetTimer = 4;
                b.bodyControls = world14ToggleBit(b.bodyControls, 0x01);
                world14RemoveBridgeSection(g);
            }
        }
        if(b != null && b.defeated && !b.hidden) {
            // BridgeCollapse -> MoveEnemySlowVert: force $0f, maximum speed $02.
            b.vy += 15.0 / 256.0;
            if(b.vy > 2.0) b.vy = 2.0;
            b.y += b.vy;
            if(b.y >= 224.0) {
                b.hidden = true;
                b.falling = false;
                if(!w.clearStarted) {
                    w.clearStarted = true;
                    // VictoryMode task 1 (SetupVictoryMode) is reached only
                    // after defeated Bowser falls below the $e0 threshold.
                    emitSound(g, "castle_clear");
                    parityRecordEvent(g, "music", "end_castle");
                }
                g.state = "world14VictoryWalk";
                w.stateFrames = 0;
            }
        }
        if(b == null && w.bridgeOffset >= 15) {
            if(!w.clearStarted) {
                w.clearStarted = true;
                emitSound(g, "castle_clear");
                parityRecordEvent(g, "music", "end_castle");
            }
            if(w.stateFrames >= 64) {
                g.state = "world14VictoryWalk";
                w.stateFrames = 0;
            }
        }
        if(w.bridgeOffset == 15 && b != null && !b.defeated) {
            // The final BridgeCollapseData entry changes Bowser to state $40
            // and queues Sfx_BowserFall in the same frame.
            b.defeated = true;
            b.falling = true;
            b.vy = 0.0;
            b.ySpeed = 0.0;
            emitSound(g, "bowser_fall");
            parityRecordEvent(g, "sound", "bowser_fall");
        }
        return true;
    }
    if(g.state == "world14VictoryWalk") {
        w.stateFrames += 1;
        local b = w.bowser;
        p.facing = 1;
        autoControlPlayerEndLevel(g, FIXED_DT);
        // VictoryMode scrolls to the retainer's page, then stops scrolling.
        local maximum = floor(w.retainer.x / 256.0) * 256.0 + 1.0;
        g.cameraX = clampValue(p.x - 120.0, 0.0, maximum);
        g.displayCameraX = g.cameraX;
        local stopX = w.retainer.x - 17.0;
        if(p.x >= stopX && p.grounded) {
            p.x = stopX; p.nesXSpeed = 0; p.vx = 0.0;
            p.previousX = p.x; p.previousY = p.y;
            w.rescued = true;
            g.state = "world14Rescue";
            w.stateFrames = 0;
            parityRecordEvent(g, "gameplay", "mushroom_retainer_saved");
        }
        return true;
    }
    if(g.state == "world14Rescue") {
        w.stateFrames += 1;
        p.nesXSpeed = 0; p.vx = 0.0; p.grounded = true;
        // AwardGameTimerPoints removes one timer unit and adds 50 points per
        // pass. Keep the original timer-tick cadence while the retainer text
        // is displayed; no fixed rescue award is invented.
        if(g.time > 0) {
            if((g.nesFrameCounter & 0x04) != 0) emitSound(g, "timer_tick");
            g.time -= 1;
            g.score += 50;
            g.queuedScore = g.score;
        }
        // PrintVictoryMessages accumulates four in SecondaryMsgCounter each
        // frame. Its carry advances PrimaryMsgCounter once per 64 frames. For
        // World 1-7, primary value four sets WorldEndTimer and advances to
        // PlayerEndWorld.
        w.secondaryMsgCounter += 4;
        if(w.secondaryMsgCounter > 0xFF) {
            w.secondaryMsgCounter = w.secondaryMsgCounter & 0xFF;
            w.primaryMsgCounter += 1;
        }
        if(w.primaryMsgCounter >= 4) {
            w.primaryMsgCounter = 4;
            // WorldEndTimer is in the interval-timer bank, which advances
            // once per 21 rendered frames in the shared timer implementation.
            w.worldEndFrames = 6 * 21;
            g.state = "world14EndWorld";
            w.stateFrames = 0;
        }
        return true;
    }
    if(g.state == "world14EndWorld") {
        w.stateFrames += 1;
        p.nesXSpeed = 0; p.vx = 0.0; p.grounded = true;
        if(w.worldEndFrames > 0) w.worldEndFrames -= 1;
        if(w.worldEndFrames <= 0) {
            g.state = "worldComplete";
            w.completeFrames = 0;
            parityRecordEvent(g, "gameplay", "world14_complete");
        }
        return true;
    }
    if(g.state == "worldComplete") {
        w.completeFrames += 1;
        p.nesXSpeed = 0; p.vx = 0.0; p.grounded = true;
        return true;
    }
    return false;
}

function world14DrawText(g, text, x, y) {
    local glyphs=[];
    foreach(character in text) {
        local glyph=0x24;
        if(character>=65 && character<=90) glyph=character-65+0x0A;
        else if(character>=48 && character<=57) glyph=character-48;
        else if(character==33) glyph=0x2B;
        else if(character==45) glyph=0x28;
        glyphs.append(glyph);
    }
    local roomPage=floor(g.world14.retainer.x/256.0)*256.0;
    drawHudGlyphs(glyphs,roomPage+x-visualCameraX(g),y);
}

function drawWorld14Actors(g, behind) {
    if(world14Assets == null) loadWorld14Assets();
    if(!("world14" in g) || world14Assets == null) return;
    local w = g.world14, frame = (g.nesFrameCounter + w.stateFrames) & 0xFF;
    if(behind) return;
    // Retainer OAM attribute $02 has no background-priority bit. Drawing
    // behind metatiles clips the last sprite scanline into the floor.
    if(w.retainer != null)
        worldTexture(g, world14Assets.retainer, w.retainer.x, w.retainer.y + 1.0, 16.0, 24.0);
    local fireTexture = world14Assets.firebar[(frame >> 2) & 1];
    foreach(bar in w.firebars) {
        if(!bar.awake || bar.retired) continue;
        for(local index = 0; index < bar.length; index += 1) {
            local point = world14FirebarPoint(bar, index);
            worldTexture(g, fireTexture, point.x, point.y, 8.0, 8.0);
        }
    }
    local b = w.bowser;
    if(b != null && !b.hidden && !b.falling) {
        local texture = world14Assets.bowser[(frame >> 4) & 1];
        worldTexture(g, texture, b.x, b.y, 32.0, 32.0);
    } else if(b != null && !b.hidden && b.falling) {
        worldTexture(g, world14Assets.bowser[1], b.x, b.y, 32.0, 32.0);
    }
    foreach(shot in w.projectiles)
        worldTexture(g, world14Assets.bowserFlame, shot.x, shot.y, 24.0, 8.0);
    if(w.podoboo != null && w.podoboo.timer <= 0)
        worldTexture(g, world14Assets.firebar[(frame >> 1) & 1],
                     w.podoboo.x, w.podoboo.y, 8.0, 12.0);
    if(g.state == "world14Rescue" || g.state == "world14EndWorld" ||
       g.state == "worldComplete") {
        // Nametable addresses $2548, $25c5 and $2605 in the original ROM.
        // The first message remains visible when the second message arrives.
        world14DrawText(g,"THANK YOU MARIO!",64.0,80.0);
        if(w.primaryMsgCounter>=2) {
            world14DrawText(g,"BUT OUR PRINCESS IS IN",40.0,112.0);
            world14DrawText(g,"ANOTHER CASTLE!",40.0,128.0);
        }
    }
}

function runWorld14SelfTest() {
    local g = createGame();
    startWorld14(g);
    requireSelfTest(g.level == 4 && g.area == "castle" && g.areaWidth == 160,
        "1-4 must load the 160-column castle area");
    requireSelfTest(ROM_WORLD_1_4_AREA.len() == 97 && ROM_WORLD_1_4_ENEMY.len() == 39,
        "1-4 must use the verified L_CastleArea1 and E_CastleArea1 streams");
    requireSelfTest(g.world14.metatiles[128][8] == 0x89 &&
        g.world14.metatiles[140][8] == 0x89,
        "1-4 bridge must occupy ROM columns 128..140");
    requireSelfTest(g.world14.metatiles[141][6] == 0xC5 &&
        g.world14.metatiles[128][11] == 0x86 &&
        g.world14.metatiles[128][12] == 0x87,
        "1-4 axe and lava must use the captured ROM metatiles");
    requireSelfTest(g.world14.firebars.len() >= 6,
        "1-4 enemy stream must create the castle firebars");
    requireSelfTest(g.world14.bowser != null && g.world14.bowser.x == 135.0 * 16.0 &&
        g.world14.bowser.hp == 5,
        "1-4 Bowser must spawn from E_CastleArea1 with five hits");
    requireSelfTest(g.world14.retainer != null && g.world14.retainer.x == 153.0 * 16.0,
        "1-4 mushroom retainer object must come from the enemy stream");

    local hazard = createGame(); startWorld14(hazard);
    local first = hazard.world14.firebars[0];
    local point = world14FirebarPoint(first, 1);
    hazard.cameraX = first.x - 128.0;
    hazard.player.x = point.x - 4.0; hazard.player.previousX=hazard.player.x;
    hazard.player.y = point.y - 8.0;
    updateWorld14Actors(hazard);
    updateWorld14Actors(hazard);
    requireSelfTest(hazard.player.dead,
        "1-4 firebar collision must hurt the player");

    local lava = createGame(); startWorld14(lava);
    lava.player.x = 129.0 * 16.0; lava.player.y = 202.0;
    lava.player.grounded = false;
    updateWorld14Actors(lava);
    requireSelfTest(lava.player.dead,
        "1-4 lava metatiles must be fatal");

    local boss = createGame(); startWorld14(boss);
    boss.cameraX = boss.world14.bowser.x - 128.0;
    boss.player.x = boss.world14.bowser.x + 64.0;
    boss.world14.bowser.faceTimer = 0;
    boss.world14.bowser.fireTimer = 1;
    updateWorld14Actors(boss);
    requireSelfTest(boss.world14.projectiles.len() == 0 &&
        (boss.world14.bowser.bodyControls & 0x80) != 0,
        "Bowser must open his mouth before firing");
    boss.world14.bowser.fireTimer = 1;
    updateWorld14Actors(boss);
    requireSelfTest(boss.world14.projectiles.len() == 1 &&
        boss.world14.projectiles[0].vx < 0.0,
        "Bowser must fire a left-moving projectile when his mouth closes");
    boss.fireballs = [{x=boss.world14.bowser.x + 4.0, y=boss.world14.bowser.y + 8.0,
        width=8.0,height=8.0,vx=0.0,vy=0.0,active=true,exploding=false,
        explosionFrames=0,nesYSpeed=0,nesYMoveForce=0,nesYDummy=0,bouncing=false}];
    updateWorld14Actors(boss);
    requireSelfTest(boss.world14.bowser.hp == 4 && boss.fireballs[0].exploding,
        "Mario fireballs must damage Bowser and explode");

    local clear = createGame(); startWorld14(clear);
    clear.player.x = clear.world14.axeX - 8.0; clear.player.y = 146.0;
    clear.player.grounded = false;
    updateWorld14Actors(clear);
    requireSelfTest(clear.state == "playing",
        "passing beside the axe must not trigger a body-overlap clear");
    clear.player.y = 114.0;
    updateWorld14Actors(clear);
    requireSelfTest(clear.state == "world14Axe",
        "touching the ROM axe must enter automatic castle clear");
    for(local frame = 0; frame < 2500 && clear.state != "worldComplete"; frame += 1)
        updateWorld14Transition(clear);
    requireSelfTest(clear.world14.bridgeRight < 128 && clear.world14.rescued &&
        clear.state == "worldComplete" && clear.time == 44 && clear.score == 12800 &&
        clear.world14.primaryMsgCounter == 4 && clear.world14.worldEndFrames == 0,
        "1-4 clear must collapse the bridge, save the mushroom retainer and stop at worldComplete");
    requireSelfTest(clear.player.x < clear.areaWidth * 16.0,
        "1-4 clear must remain bounded to the castle map");
    for(local form=0;form<3;form+=1) {
        local ending=createGame(); startWorld14(ending);
        ending.player.big=form>0; ending.player.fire=form==2;
        resetPlayerForArea(ending,2260,96);
        ending.player.grounded=false; ending.player.nesYSpeed=4;
        ending.player.nesXSpeed=24;
        ending.state="world14VictoryWalk";
        local sawAnimationChange=false,firstAnimation=-100;
        for(local frame=0;frame<1200;frame+=1) {
            simulateFixed(ending,FIXED_DT);
            if(ending.state=="world14VictoryWalk" && ending.player.grounded) {
                if(firstAnimation==-100) firstAnimation=ending.player.displayAnimationFrame;
                else if(firstAnimation!=ending.player.displayAnimationFrame) sawAnimationChange=true;
            }
        }
        requireSelfTest(ending.state=="worldComplete" && ending.world14.rescued &&
            ending.player.x==2431.0 && ending.player.y+ending.player.height==208.0 &&
            ending.player.displayRelX==126.0 && ending.player.displayRelY==176.0 &&
            ending.player.big==(form>0) && ending.player.fire==(form==2) &&
            ending.world14.retainer.y==184.0 && sawAnimationChange,
            "castle ending must animate, land and refresh OAM for small, big and fire Mario");
    }
    print("World 1-4 simulation self-test passed.\n");
}
