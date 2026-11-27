// World 2-4. Terrain comes from the ROM's L_CastleArea3 parser output; the
// verified ROM and Mesen remain offline extraction tools only.
if(!("ROM_WORLD_2_4_AREA" in getroottable())) dofile("scripts/generated/world24_data.nut");
if(!("ROM_WORLD_2_4_METATILES" in getroottable())) dofile("scripts/generated/world24_map.nut");
world24Assets <- null;
world24AudioAssets <- {
    theme = "assets/audio/castle_theme.wav",
    fast = "assets/audio/castle_fast.wav",
    clear = "assets/audio/castle_clear.wav",
    bowserFire = "assets/audio/bowser_fire.wav",
    bowserFall = "assets/audio/bowser_fall.wav"
};

// SMBDIS FirebarPosLookupTbl, FirebarTblOffsets and FirebarMirrorData.
// The ROM rotates a 16.8 spin state and indexes this quarter-circle table;
// it does not use a floating-point sine.
WORLD24_FIREBAR_POS <- [
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
WORLD24_FIREBAR_OFFSETS <- [0,9,18,27,36,45,54,63,72,81,90,99];
WORLD24_FIREBAR_MIRROR <- [1,3,2,0];
WORLD24_FIREBAR_SPEED <- [0x28,0x38,0x28,0x38,0x28];
WORLD24_FIREBAR_DIRECTION <- [0,0,0x10,0x10,0];
WORLD24_FLAME_TIMERS <- [0xbf,0x40,0xbf,0xbf,0xbf,0x40,0x40,0xbf];
WORLD24_FLAME_Y <- [0x90,0x80,0x70,0x90];

function loadWorld24Assets() {
    local metatiles = {};
    foreach(column in ROM_WORLD_2_4_METATILES)
        foreach(meta in column)
            if(meta != 0 && !(meta in metatiles))
                metatiles[meta] <- loadTexture("assets/world24/metatile-" + meta + ".png");
    world24Assets = {
        hudCoins = [loadTexture("assets/world24/hud-coin-0.png"),
            loadTexture("assets/world24/hud-coin-1.png"),
            loadTexture("assets/world24/hud-coin-2.png"),
            loadTexture("assets/world24/hud-coin-3.png"),
            loadTexture("assets/world24/hud-coin-4.png"),
            loadTexture("assets/world24/hud-coin-5.png")],
        metatiles = metatiles,
        bowserLeft = [loadTexture("assets/world24/bowser-left-0.png"),
            loadTexture("assets/world24/bowser-left-1.png"),
            loadTexture("assets/world24/bowser-left-2.png"),
            loadTexture("assets/world24/bowser-left-3.png")],
        bowserRight = [loadTexture("assets/world24/bowser-right-0.png"),
            loadTexture("assets/world24/bowser-right-1.png"),
            loadTexture("assets/world24/bowser-right-2.png"),
            loadTexture("assets/world24/bowser-right-3.png")],
        platform = loadTexture("assets/world24/platform.png"),
        podoboo = loadTexture("assets/world24/podoboo.png"),
        retainer = loadTexture("assets/world24/toad.png"),
        firebar = [loadTexture("assets/world24/firebar-0.png"),
                   loadTexture("assets/world24/firebar-1.png")],
        bowserFlame = loadTexture("assets/world24/bowser-flame.png"),
        audio = world24AudioAssets,
        manifest = "assets/world24/manifest.json"
    };
    if("assets" in getroottable() && assets != null) assets.world24 <- world24Assets;
    return world24Assets;
}

function world24TileForMeta(meta) {
    if(meta == 0x62 || meta == 0x61) return TILE_SOLID;
    if(meta == 0x52) return TILE_BRICK;
    if(meta == 0x5f) return TILE_HIDDEN_COIN;
    if(meta == 0xc0) return TILE_QUESTION;
    if(meta == 0xc1) return TILE_POWERUP_BLOCK;
    if(meta == 0xc4) return TILE_USED;
    if(meta == 0x89) return TILE_SOLID;
    // Lava, chain, axe and the castle's decorative metatiles are non-solid.
    return TILE_EMPTY;
}

function world24BuildCollision(g) {
    g.tiles = array(TILE_STRIDE * LEVEL_HEIGHT, TILE_EMPTY);
    g.levelCoins=[];
    for(local x = 0; x < ROM_WORLD_2_4_METATILES.len(); x += 1)
        for(local row = 0; row < 13; row += 1) {
            local meta = ROM_WORLD_2_4_METATILES[x][row];
            setTile(g, x, row + 2, world24TileForMeta(meta));
            if(meta==0xC2) g.levelCoins.append({x=x*16.0,y=(row+2)*16.0,
                width=16.0,height=16.0,active=true});
        }
}

function world24ParseCastleObjects(g) {
    local data = ROM_WORLD_2_4_ENEMY;
    local page = 0, cursor = 0, pageSelected = false;
    local firebars = [], bowser = null, retainer = null, podoboos = [];
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
                spinSpeed = WORLD24_FIREBAR_SPEED[id - 0x1B],
                spinDirection = WORLD24_FIREBAR_DIRECTION[id - 0x1B]
            });
        } else if(id == 0x2D) {
            bowser = {
                x = unit * 16.0, y = row * 16.0, width = 32.0, height = 32.0,
                originX = unit * 16.0, direction = -1, hp = 5, defeated = false,
                awake=false,slot=-1,rearSlot=-1,
                falling = false, hidden = false, vy = 0.0, ySpeed = 0.0,
                fireTimer = 0xDF, feetTimer = 32, feetFrame = 0,
                bodyControls = 0, movementSpeed = 2, movingDir = 2,
                maxRange = 0x21, flameTimerCtrl = 0, flameYOffset = 0,
                jumpTimer=32, verticalY=row*16, verticalSpeed=0, verticalForce=0, verticalDummy=0
            };
        } else if(id == 0x35) {
            retainer = {x = unit * 16.0, y = 184.0, width = 16.0, height = 24.0};
        } else if(id == 0x0C) {
            // E_CastleArea3 has two normal-mode Podoboos; preserve both.
            podoboos.append({x = unit * 16.0, y = 258.0, awake=false, retired=false,slot=-1,
                timer=1, verticalY=258, verticalSpeed=0,verticalForce=0,verticalDummy=0,
                width=16.0,height=16.0});
        } else if(id == 0x2B || id == 0x2C || id == 0x28) {
            g.platforms.append({id=id, spawnX=unit*16.0, x=unit*16.0+(id==0x28?0.0:12.0), y=row*16.0,
                previousX=unit*16.0, previousY=row*16.0,
                width=id==0x28?32.0:24.0, awake=false, retired=false,slot=-1,
                fraction=0.0, secondaryCounter=0, primaryCounter=0,
                speed=id==0x2B?-240.0/256.0:240.0/256.0});
        } else if(id == 0x15) {
            g.world24.flameSourceX = unit * 16.0;

        }
        cursor += 2;
        pageSelected = false;
    }
    g.world24.firebars = firebars;
    g.world24.bowser = bowser;
    g.world24.retainer = retainer;
    g.world24.podoboos = podoboos;
}

function startWorld24(g) {
    g.world=2;
    g.level = 4;
    g.stage = "world24";
    g.area = "castle";
    g.romBackgroundCollision = true;
    g.areaWidth = ROM_WORLD_2_4_METATILES.len();
    clearAreaObjects(g);
    g.plants = []; g.platforms = []; g.enterablePipes = []; g.sidePipeX = -1;
    g.flagX = 100000.0; g.castleX = 100000.0; g.castleFlagVisible = false;
    g.endLevelScrollLocked = false; g.fireworks = []; g.floatingScores = [];
    local resetWorld = {
        metatiles = ROM_WORLD_2_4_METATILES,
        baseMetatiles = ROM_WORLD_2_4_METATILES,
        firebars = [], bowser = null, retainer = null, podoboos = [],
        flameSourceX=-1.0, ambientFlameTimer=0, random=[65,97,227,32,230,167,106], interval=0,
        firebarSlots = array(5,null), firebarSlotHigh = array(5,0),
        projectiles = [], flames = [], bridgeRight = 140,
        axeX = 141.0 * 16.0, stateFrames = 0, clearStarted = false,
        rescued = false, completeFrames = 0, axeSparkle = 0,
        bridgeOffset = 0, axeGone = false, chainGone = false,
        primaryMsgCounter = 0, secondaryMsgCounter = 0, worldEndFrames = 0
    };
    if("world24" in g) g.world24 = resetWorld; else g.world24 <- resetWorld;
    world24BuildCollision(g);
    world24ParseCastleObjects(g);
    foreach(pod in g.world24.podoboos) if(pod.x<=303.0) {
        for(local slot=0;slot<5;slot+=1) if(g.world24.firebarSlots[slot]==null) {
            pod.slot=slot;pod.awake=true;g.world24.firebarSlots[slot]=pod;break;
        }
    }
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

function world24BridgePresent(g) {
    if(!("world24" in g)) return false;
    return g.world24.bridgeRight >= 128;
}

function world24TileTexture(g, tx, ty, tile) {
    if(world24Assets == null) loadWorld24Assets();
    if(!("world24" in g) || tx < 0 || tx >= g.areaWidth || ty < 2 || ty >= LEVEL_HEIGHT)
        return null;
    local row = ty - 2, meta = g.world24.metatiles[tx][row];
    if(meta == 0 || meta==0xC2) return null;
    if(meta==0x52 && tile==TILE_EMPTY) return null;
    if(g.world24.axeGone && meta == 0xC5) return null;
    if(g.world24.chainGone && meta == 0x0C) return null;
    if(meta == 0x89 && tx > g.world24.bridgeRight) {
        return null;
    }
    if((meta == 0xC1 || meta==0xC0) && tile == TILE_USED) return world24Assets.metatiles[0xC4];
    return meta in world24Assets.metatiles ? world24Assets.metatiles[meta] : null;
}

function drawWorld24Background(g) {
    // CastlePaletteData makes ROM metatiles $86/$87 the animated lava surface
    // and body. The shared black backdrop is supplied by the parent renderer.
    return null;
}

function world24OverlapPlayer(g, x, y, width, height) {
    local p = g.player;
    return !p.dead && overlaps(p.x + 3.0, p.y + 3.0, 10.0, p.height - 4.0,
                               x, y, width, height);
}

function world24FirebarPoint(bar, index) {
    // ProcFirebar draws the fixed origin first, then five radius-table
    // entries for a short bar. The origin is not lookup-table radius eight.
    if(index==0) return {x=bar.x,y=bar.y};
    local horizontalNibble = bar.spinHigh & 0x0F;
    if(horizontalNibble >= 9)
        horizontalNibble = 16 - horizontalNibble;
    local verticalNibble = (bar.spinHigh + 8) & 0x0F;
    if(verticalNibble >= 9)
        verticalNibble = 16 - verticalNibble;
    local offset = WORLD24_FIREBAR_OFFSETS[index-1];
    local horizontal = WORLD24_FIREBAR_POS[offset + horizontalNibble];
    local vertical = WORLD24_FIREBAR_POS[offset + verticalNibble];
    local mirror = WORLD24_FIREBAR_MIRROR[(bar.spinHigh >> 3) & 0x03];
    if((mirror & 0x01) == 0) horizontal = -horizontal;
    if((mirror & 0x02) == 0) vertical = -vertical;
    return {
        x = bar.x + horizontal,
        y = bar.y + vertical
    };
}

function world24ToggleBit(value, mask) {
    return (value & mask) != 0 ? value - mask : value + mask;
}

function world24TickFirebar(bar) {
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

function world24NextFlameTimer(b) {
    local timer = WORLD24_FLAME_TIMERS[b.flameTimerCtrl & 0x07];
    b.flameTimerCtrl = (b.flameTimerCtrl + 1) & 0x07;
    return timer;
}

function world24SpawnBowserFlame(g, ambient=false) {
    local w=g.world24,b=w.bowser;
    if(b==null || b.defeated) return false;
    local slot=-1;
    for(local i=0;i<5;i+=1) if(w.firebarSlots[i]==null) {slot=i;break;}
    if(slot<0) return false;
    local lane=w.random[slot]&3,target=WORLD24_FLAME_Y[lane].tofloat();
    local shot={x=ambient?g.cameraX+287.0:b.x-14.0,y=ambient?target:b.y+8.0,
        width=24.0,height=8.0,vx=-1.25,vy=0.0,targetY=target,active=true,slot=slot,fresh=true};
    w.projectiles.append(shot);w.firebarSlots[slot]=shot;
    emitSound(g,"bowser_fire");return true;
}

function world24HurtBowser(g) {
    local b = g.world24.bowser;
    if(b == null || b.defeated) return;
    b.hp -= 1;
    if(b.hp <= 0) {
        b.defeated = true; b.falling = true; b.vy = -2.0;
        emitSound(g, "bowser_fall");
        parityRecordEvent(g, "gameplay", "bowser_defeated");
    }
}

function updateWorld24Actors(g) {
    if(!("world24" in g) || g.state != "playing" || g.player.dead) return;
    local w = g.world24, p = g.player;
    local frame = g.nesFrameCounter;
    // Same seven-byte LFSR as the ROM. Exact bootstrap/slot phase remains a parity gate.
    local feedback=((w.random[0]&2)^(w.random[1]&2))!=0?128:0;
    for(local i=0;i<7;i+=1) {
        local next=(w.random[i]&1)*128;
        w.random[i]=(w.random[i]>>1)|feedback;feedback=next;
    }
    w.interval-=1;
    local intervalTick=w.interval<0;
    if(intervalTick) w.interval=20;
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
        world24TickFirebar(bar);
        w.firebarSlotHigh[bar.slot]=bar.spinHigh;
        for(local index = 0; index < bar.length; index += 1) {
            local point = world24FirebarPoint(bar, index);
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

    if(w.flameSourceX>=0.0 && w.flameSourceX<=parserBoundary &&
       !w.bowser.awake) {
        if(w.ambientFlameTimer>0) w.ambientFlameTimer-=1;
        if(w.ambientFlameTimer<=0 && world24SpawnBowserFlame(g,true)) {
            w.ambientFlameTimer=world24NextFlameTimer(w.bowser)+32;
            w.projectiles[w.projectiles.len()-1].x=actorCamera+287.0;
        }
    }
    local b = w.bowser;
    if(b != null) {
        if(b.defeated && !b.hidden) {
            b.y+=b.vy; b.vy+=0.125;
            if(b.y>=240.0) {b.hidden=true;b.falling=false;}
        }
        local justSpawned=false;
        if(!b.awake && b.originX<=parserBoundary) {
            local free=[];
            for(local i=0;i<5;i+=1) if(w.firebarSlots[i]==null) free.append(i);
            if(free.len()>=2) {
                b.slot=free[0];b.rearSlot=free[1];b.awake=true;justSpawned=true;
                w.firebarSlots[b.slot]=b;w.firebarSlots[b.rearSlot]=b;
            }
        }
        if(!b.defeated && b.awake && !justSpawned) {
            if(b.jumpTimer>0) b.jumpTimer-=1;
            // BowserControl skips feet and horizontal movement while the
            // mouth bit is set. MovingDir controls facing; the signed speed
            // byte controls travel independently, including left-facing
            // travel to the right of the original position.
            if((b.bodyControls & 0x80)==0) {
            b.feetTimer -= 1;
            if(b.feetTimer <= 0) {
                b.feetTimer = 32;
                b.feetFrame = 1 - b.feetFrame;
                b.bodyControls = world24ToggleBit(b.bodyControls, 0x01);
            }
            if((frame & 0x0F) == 0) b.movingDir = 2;
            if(b.jumpTimer > 0) {
                if(p.x > b.x) {
                    b.movingDir = 1;
                    b.movementSpeed = 2;
                    b.jumpTimer = 32;
                    b.fireTimer = 32;
                }

            }
            if((frame & 0x03) == 0) {
                if(b.x==b.originX) b.maxRange=[33,65,17,49][w.random[b.slot]&3];
                local delta = b.x - b.originX;
                b.x += b.movementSpeed;
                delta = b.x - b.originX;
                if(delta < 0) delta = -delta;
                if(b.movingDir!=1 && delta >= b.maxRange)
                    b.movementSpeed = b.x > b.originX ? -1 : 1;
            }
            }
            if(b.jumpTimer>0) {
                if(b.jumpTimer==1) {
                    b.verticalY=b.y.tointeger()-1;
                    b.verticalSpeed=254;b.verticalForce=0;b.verticalDummy=0;
                    b.y=b.verticalY.tofloat();
                }
            } else {
                world13ImposeGravity(b,15,0,2,false);b.y=b.verticalY.tofloat();
                if(b.y>=128.0) {b.y=128.0;b.verticalY=128;
                    b.jumpTimer=[33,65,17,49][w.random[b.slot]&3];}
            }
            b.fireTimer -= 1;
            if(b.fireTimer <= 0) {
                b.fireTimer = 32;
                b.bodyControls = world24ToggleBit(b.bodyControls, 0x80);
                if((b.bodyControls & 0x80) == 0) {
                    b.fireTimer = world24NextFlameTimer(b);
                    world24SpawnBowserFlame(g);
                }
            }
            if(world24BowserHitsPlayer(g,b)) {
                hurtPlayer(g, {kind="bowser", x=b.x});
                if(p.dead) return;
            }
        }
        foreach(ball in g.fireballs) {
            if(!ball.active || ball.exploding) continue;
            if(overlaps(ball.x, ball.y, ball.width, ball.height,
                        b.x + 2.0, b.y + 2.0, 28.0, 30.0)) {
                explodeFireball(ball);
                world24HurtBowser(g);
            }
        }
    }

    for(local index = w.projectiles.len() - 1; index >= 0; index -= 1) {
        local shot = w.projectiles[index];
        if(shot.fresh) {shot.fresh=false;continue;}
        shot.x += shot.vx;
        if(shot.y < shot.targetY) shot.y += 1.0;
        else if(shot.y > shot.targetY) shot.y -= 1.0;
        if(world24FlameHitsPlayer(g,shot)) {
            shot.active = false;
            hurtPlayer(g, {kind="bowser_flame", x=shot.x});
            if(p.dead) return;
        }
        if(shot.x + shot.width < g.cameraX - 32.0) shot.active = false;
        if(!shot.active) {w.firebarSlots[shot.slot]=null;w.projectiles.remove(index);}
    }

    foreach(index,pod in w.podoboos) {
        if(pod.retired || pod.x>parserBoundary) continue;
        if(pod.x<actorCamera-73.0) {
            pod.retired=true;
            if(pod.slot>=0) {w.firebarSlots[pod.slot]=null;
                w.firebarSlotHigh[pod.slot]=pod.verticalSpeed;}
            continue;
        }
        if(!pod.awake) {
            for(local slot=0;slot<5;slot+=1) if(w.firebarSlots[slot]==null) {
                pod.slot=slot;pod.awake=true;w.firebarSlots[slot]=pod;break;
            }
            continue;
        }
        if(intervalTick && pod.timer>0) pod.timer-=1;
        if(pod.timer==0) {
            local random=w.random[(pod.slot+1)%7];
            pod.verticalY=258;pod.verticalSpeed=249;pod.verticalForce=random|128;
            pod.timer=(random&15)|6;
        }
        world13ImposeGravity(pod,28,0,3,false);pod.y=pod.verticalY.tofloat();
        if(pod.y<240.0 && world24OverlapPlayer(g,pod.x,pod.y,pod.width,pod.height)) {
            hurtPlayer(g,{kind="podoboo",x=pod.x});if(p.dead) return;
        }
    }
    updateWorld24Platforms(g);

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
        g.state = "world24Axe";
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

function world24RemoveBridgeSection(g) {
    local w = g.world24;
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

function updateWorld24Transition(g) {
    if(!("world24" in g)) return false;
    if(g.input.resetQueued && ["world24Axe","world24VictoryWalk","world24Rescue",
            "world24EndWorld","worldComplete"].find(g.state)!=null) {
        resetRound(g);
        return true;
    }
    local w = g.world24, p = g.player;
    if(g.state == "world24Axe") {
        w.stateFrames += 1;
        local b = w.bowser;
        if(b == null || b.defeated) {
            if((w.stateFrames & 3)==1) world24RemoveBridgeSection(g);
        }
        if(b != null && !b.defeated) {
            b.feetTimer -= 1;
            if(b.feetTimer <= 0) {
                b.feetTimer = 4;
                b.bodyControls = world24ToggleBit(b.bodyControls, 0x01);
                world24RemoveBridgeSection(g);
            }
        }
        if(b != null && b.defeated && !b.hidden) {
            // BridgeCollapse -> MoveEnemySlowVert: force $0f, maximum speed $02.
            b.vy += 15.0 / 256.0;
            if(b.vy > 2.0) b.vy = 2.0;
            b.y += b.vy;
            if(b.y >= 224.0 && w.bridgeOffset>=15) {
                b.hidden = true;
                b.falling = false;
                if(!w.clearStarted) {
                    w.clearStarted = true;
                    // VictoryMode task 1 (SetupVictoryMode) is reached only
                    // after defeated Bowser falls below the $e0 threshold.
                    emitSound(g, "castle_clear");
                    parityRecordEvent(g, "music", "end_castle");
                }
                g.state = "world24VictoryWalk";
                w.stateFrames = 0;
            }
        }
        if((b == null || b.hidden) && w.bridgeOffset >= 15) {
            if(!w.clearStarted) {
                w.clearStarted = true;
                emitSound(g, "castle_clear");
                parityRecordEvent(g, "music", "end_castle");
            }
            if(w.stateFrames >= 64) {
                g.state = "world24VictoryWalk";
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
    if(g.state == "world24VictoryWalk") {
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
            g.state = "world24Rescue";
            w.stateFrames = 0;
            parityRecordEvent(g, "gameplay", "mushroom_retainer_saved");
        }
        return true;
    }
    if(g.state == "world24Rescue") {
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
            g.state = "world24EndWorld";
            w.stateFrames = 0;
        }
        return true;
    }
    if(g.state == "world24EndWorld") {
        w.stateFrames += 1;
        p.nesXSpeed = 0; p.vx = 0.0; p.grounded = true;
        if(w.worldEndFrames > 0) w.worldEndFrames -= 1;
        if(w.worldEndFrames <= 0) {
            parityRecordEvent(g, "gameplay", "world24_complete");
            g.state="worldComplete";
            w.completeFrames=0; // 3-1 is unavailable; retain World 2-4 identity.
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

function world24DrawText(g, text, x, y) {
    local glyphs=[];
    foreach(character in text) {
        local glyph=0x24;
        if(character>=65 && character<=90) glyph=character-65+0x0A;
        else if(character>=48 && character<=57) glyph=character-48;
        else if(character==33) glyph=0x2B;
        else if(character==45) glyph=0x28;
        glyphs.append(glyph);
    }
    local roomPage=floor(g.world24.retainer.x/256.0)*256.0;
    drawHudGlyphs(glyphs,roomPage+x-visualCameraX(g),y);
}

function drawWorld24Actors(g, behind) {
    if(world24Assets == null) loadWorld24Assets();
    if(!("world24" in g) || world24Assets == null) return;
    local w = g.world24, frame = (g.nesFrameCounter + w.stateFrames) & 0xFF;
    if(behind) return;
    // Retainer OAM attribute $02 has no background-priority bit. Drawing
    // behind metatiles clips the last sprite scanline into the floor.
    if(w.retainer != null)
        worldTexture(g, world24Assets.retainer, w.retainer.x, w.retainer.y + 1.0, 16.0, 24.0);
    local fireTexture = world24Assets.firebar[(frame >> 2) & 1];
    foreach(bar in w.firebars) {
        if(!bar.awake || bar.retired) continue;
        for(local index = 0; index < bar.length; index += 1) {
            local point = world24FirebarPoint(bar, index);
            worldTexture(g, fireTexture, point.x, point.y, 8.0, 8.0);
        }
    }
    local b = w.bowser;
    if(b != null && !b.hidden) {
        local right=b.movingDir==1;
        local pose=((b.bodyControls & 0x80)!=0?2:0)+(b.bodyControls & 1);
        // b.x is the front object. The rear is +16 when facing left,
        // -16 when facing right, and always eight pixels below the front.
        local texture=right?world24Assets.bowserRight[pose]:world24Assets.bowserLeft[pose];
        worldTexture(g,texture,b.x-(right?16.0:0.0),b.y,32.0,32.0);
    }
    foreach(shot in w.projectiles)
        worldTexture(g, world24Assets.bowserFlame, shot.x, shot.y, 24.0, 8.0);
    foreach(pod in w.podoboos) if(pod.awake && pod.y<240.0)
        worldTexture(g, world24Assets.podoboo, pod.x, pod.y, 16.0, 16.0);
    foreach(platform in g.platforms) {
        if(!platform.awake || platform.retired) continue;
        local ys=platform.id==0x28?[platform.previousY]:
            [platform.previousY,(platform.previousY+128.0)%256.0];
        foreach(y in ys) if(y>=32.0) for(local x=0.0;x<platform.width;x+=8.0)
            worldTexture(g,world24Assets.platform,platform.previousX+x,y+1.0,8.0,8.0);
    }
    if(g.state == "world24Rescue" || g.state == "world24EndWorld" ||
       g.state == "worldComplete") {
        // Nametable addresses $2548, $25c5 and $2605 in the original ROM.
        // The first message remains visible when the second message arrives.
        world24DrawText(g,"THANK YOU MARIO!",64.0,80.0);
        if(w.primaryMsgCounter>=2) {
            world24DrawText(g,"BUT OUR PRINCESS IS IN",40.0,112.0);
            world24DrawText(g,"ANOTHER CASTLE!",40.0,128.0);
        }
    }
}


function isWorld24(g) {return g.world==2 && g.level==4;}

function updateWorld24DeathReload(g) {
    g.deathReloadFrames+=1;
    if(g.deathReloadFrames==1) {
        // World2 HalfwayPageNybbles=$65,$70: stage 4 low nibble is zero.
        g.checkpointPage=0;g.lives-=1;
        if(g.lives<=0) {g.lives=0;g.state="gameOver";g.player.dead=false;
            emitSound(g,"game_over");return;}
    }
    if(g.deathReloadFrames>=166) startLevel(g,2,4,true);
}

function updateWorld24Platforms(g) {
    foreach(platform in g.platforms) {
        if(platform.retired) continue;
        if(platform.x<g.cameraX-73.0) {
            platform.retired=true;
            if(platform.slot>=0) {
                g.world24.firebarSlots[platform.slot]=null;
                g.world24.firebarSlotHigh[platform.slot]=platform.id==0x2B?255:0;
            }
            continue;
        }
        if(!platform.awake) {
            local projected=g.cameraX+(g.player.nesXScroll>0?g.player.nesXScroll:0);
            if(platform.spawnX>floor((projected+303.0)/16.0)*16.0) continue;
            for(local slot=0;slot<5;slot+=1) if(g.world24.firebarSlots[slot]==null) {
                platform.slot=slot;g.world24.firebarSlots[slot]=platform;break;
            }
            if(platform.slot<0) continue;
            platform.awake=true;continue;
        }
        local oldX=platform.x,oldY=platform.y;
        platform.previousX=oldX;platform.previousY=oldY;
        if(platform.id==0x28) {
            if((g.nesFrameCounter&3)==0) {
                if((platform.primaryCounter&1)==0) {
                    if(platform.secondaryCounter==14) platform.primaryCounter+=1;
                    else platform.secondaryCounter+=1;
                } else {
                    if(platform.secondaryCounter==0) platform.primaryCounter+=1;
                    else platform.secondaryCounter-=1;
                }
            }
            local speed=platform.secondaryCounter;
            if((platform.primaryCounter&2)==0) speed=-speed;
            platform.fraction+=speed/16.0;
            local dx=floor(platform.fraction);
            platform.fraction-=dx;platform.x+=dx;
            world24PlatformCollision(g,platform,oldX,oldY,platform.x,platform.y);
        } else {
            platform.fraction+=platform.speed;
            local dy=floor(platform.fraction);platform.fraction-=dy;
            platform.y=(oldY+dy+256.0)%256.0;
            // Small lift objects draw two 24px platforms separated by 128px.
            // Do not carry a rider across the vertical wrapping seam.
            foreach(offset in [0.0,128.0]) {
                local before=(oldY+offset)%256.0,after=(platform.y+offset)%256.0;
                if(abs(after-before)<2.0)
                    world24PlatformCollision(g,platform,oldX,before,platform.x,after);
            }
        }
    }
}

// Focused mechanics tests use explicit setup; these are not route evidence.
function runWorld24SelfTest() {
    local g=createGame();startWorld24(g);
    requireSelfTest(isWorld24(g) && g.stage=="world24" && g.areaWidth==160 && g.time==300,
        "2-4 identity, map width and castle timer");
    requireSelfTest(ROM_WORLD_2_4_AREA.len()==115 && ROM_WORLD_2_4_ENEMY.len()==47,
        "2-4 must load CastleArea3 streams");
    requireSelfTest(g.world24.firebars.len()==6 && g.world24.podoboos.len()==2 && g.platforms.len()==3,
        "2-4 must retain both Podoboos, both lifts and horizontal platform");
    requireSelfTest(g.world24.metatiles[141][6]==0xC5 && g.world24.bowser.x==2160.0 &&
        g.world24.retainer.x==2448.0,"2-4 ROM axe, Bowser and retainer positions");
    foreach(page in [0,6,8]) {
        local dead=createGame();startLevel(dead,2,4);dead.cameraX=page*256.0;
        dead.score=12300;dead.coins=7;dead.player.big=true;dead.player.fire=true;
        finishPlayerDeath(dead);
        for(local f=0;f<166;f+=1) updateWorld24DeathReload(dead);
        requireSelfTest(isWorld24(dead) && dead.checkpointPage==0 && dead.cameraX==0.0 &&
            dead.player.x==40.0 && dead.player.y==96.0 && dead.lives==2 && !dead.player.dead &&
            !dead.player.big && !dead.player.fire && dead.score==12300 && dead.coins==7,
            "2-4 death always restarts raised entrance, preserving progress and consuming one life");
    }
    foreach(fireDefeat in [false,true]) {
        local clear=createGame();startWorld24(clear);
        if(fireDefeat) for(local i=0;i<5;i+=1) world24HurtBowser(clear);
        clear.player.x=2256.0;clear.player.y=114.0;clear.player.nesYSpeed=1;
        updateWorld24Actors(clear);
        requireSelfTest(clear.state=="world24Axe","downward axe foot probe must begin clear");
        for(local f=0;f<2200 && clear.state!="worldComplete";f+=1)
            simulateFixed(clear,FIXED_DT);
        requireSelfTest(clear.world==2 && clear.level==4 && clear.state=="worldComplete" &&
            clear.world24.bridgeOffset==15 && clear.world24.rescued &&
            clear.world24.primaryMsgCounter==4 && clear.world24.bowser.hidden,
            "2-4 axe clear and prior fire defeat must finish in truthful bounded endpoint");
    }
    local lava=createGame();startWorld24(lava);
    lava.player.x=129.0*16.0;lava.player.y=202.0;lava.player.grounded=false;
    updateWorld24Actors(lava);
    requireSelfTest(lava.player.dead,"castle lava must be fatal");
    local side=createGame();startWorld24(side);
    side.player.x=1359.0;side.player.y=78.0;side.player.nesXSpeed=40;
    side.player.nesYSpeed=-2;
    world24PlatformCollision(side,side.platforms[0],1372.0,89.0,1372.0,88.0);
    requireSelfTest(side.player.x==1358.0 && side.player.nesXSpeed==0,
        "small lift side must impede movement using the ROM small-player box");
    local flame={x=2015.0,y=144.0};
    side.player.x=2002.0;side.player.y=137.0;
    requireSelfTest(!world24FlameHitsPlayer(side,flame),
        "flame artwork outside its central ROM hitbox must not hurt Mario");
    side.player.x=2010.0;
    requireSelfTest(world24FlameHitsPlayer(side,flame),"central flame hitbox must remain harmful");
    print("World 2-4 mechanics self-test passed.\n");
}

function world24PlatformCollision(g,platform,oldX,oldY,newX,newY) {
    local p=g.player;
    local canonicalY=p.big&&!p.crouching?p.y:p.y-16.0;
    if(canonicalY<0.0 || canonicalY>=208.0 || p.dead || oldY<32.0) return;
    local left=p.x+(p.big&&!p.crouching?2.0:3.0),right=p.x+(p.big&&!p.crouching?14.0:13.0);
    local top=canonicalY+(p.big&&!p.crouching?8.0:20.0),bottom=canonicalY+32.0;
    local height=platform.id==0x28?13.0:6.0;
    if(right<oldX || left>oldX+platform.width || bottom<oldY || top>oldY+height) return;
    local headDifference=oldY+height-top;
    if(headDifference>=0 && headDifference<4.0 && p.nesYSpeed<0) p.nesYSpeed=1;
    local feetDifference=bottom-oldY;
    if(feetDifference>=0.0 && feetDifference<6.0 && p.nesYSpeed>=0) {
        p.x+=newX-oldX;p.pendingPlatformXScroll+=(newX-oldX).tointeger();
        p.y=newY-p.height;p.grounded=true;p.entranceFalling=false;
        p.vy=0.0;p.nesYSpeed=0;p.nesYMoveForce=0;
        return;
    }
    if(right-oldX>=0.0 && right-oldX<8.0) impedePlayerMove(g,p,1);
    else if(oldX+platform.width-left-1.0>=0.0 && oldX+platform.width-left-1.0<9.0) impedePlayerMove(g,p,2);
}

function world24FlameHitsPlayer(g,shot) {
    local p=g.player;
    if(p.dead) return false;
    local big=p.big&&!p.crouching,canonicalY=big?p.y:p.y-16.0;
    local left=p.x+(big?2.0:3.0),right=p.x+(big?14.0:13.0);
    local top=canonicalY+(big?8.0:20.0),bottom=canonicalY+32.0;
    // ROM bounding box control $08 is the flame's central four pixels.
    return right>=shot.x+6.0 && left<=shot.x+10.0 &&
        bottom>=shot.y+4.0 && top<=shot.y+8.0;
}

function world24BowserHitsPlayer(g,b) {
    local p=g.player,big=p.big&&!p.crouching,canonicalY=big?p.y:p.y-16.0;
    local left=p.x+(big?2.0:3.0),right=p.x+(big?14.0:13.0);
    local top=canonicalY+(big?8.0:20.0),bottom=canonicalY+32.0;
    foreach(rear in [false,true]) {
        local x=b.x+(rear?(b.movingDir==1?-16.0:16.0):0.0);
        local y=b.y+(rear?8.0:0.0);
        if(right>=x && left<=x+16.0 && bottom>=y+2.0 && top<=y+21.0) return true;
    }
    return false;
}
