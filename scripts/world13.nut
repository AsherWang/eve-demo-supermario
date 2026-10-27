// World 1-3: tree ledges from L_GroundArea7 and objects from E_GroundArea7.
// The emulator is only used to produce checked-in offline evidence.

function world13UsedMetatiles() {
    return [0x16,0x17,0x18,0x24,0x25,0x45,0x46,0x47,0x48,0x49,0x4a,
            0x4b,0x4c,0x4d,0x52,0x54,0x61,0x80,0x81,0x82,0x83,0x84,
            0x85,0xc1,0xc2];
}

function loadWorld13Assets() {
    if (assets == null) loadAssets();
    if ("world13" in assets) return;
    local metatiles = {};
    foreach(meta in world13UsedMetatiles())
        metatiles[meta] <- loadTexture("assets/world13/metatile-" + meta + ".png");
    assets.world13 <- {
        metatiles = metatiles,
        questions = [loadTexture("assets/world13/question-0.png"),
            loadTexture("assets/world13/question-1.png"),
            loadTexture("assets/world13/question-2.png"),
            loadTexture("assets/world13/question-3.png"),
            loadTexture("assets/world13/question-4.png"),
            loadTexture("assets/world13/question-5.png")],
        platform = loadTexture("assets/world13/platform.png"),
        coins = [loadTexture("assets/world13/coin-0.png"),
            loadTexture("assets/world13/coin-1.png"),
            loadTexture("assets/world13/coin-2.png"),
            loadTexture("assets/world13/coin-3.png"),
            loadTexture("assets/world13/coin-4.png"),
            loadTexture("assets/world13/coin-5.png")],
        bulletBill = loadTexture("assets/world13/bullet-bill.png"),
        redKoopaRight = [loadTexture("assets/world13/red-koopa-0-right.png"),
            loadTexture("assets/world13/red-koopa-1-right.png")],
        redKoopaLeft = [loadTexture("assets/world13/red-koopa-0-left.png"),
            loadTexture("assets/world13/red-koopa-1-left.png")],
        redParatroopaRight = [loadTexture("assets/world13/red-paratroopa-0-right.png"),
            loadTexture("assets/world13/red-paratroopa-1-right.png")],
        redParatroopaLeft = [loadTexture("assets/world13/red-paratroopa-0-left.png"),
            loadTexture("assets/world13/red-paratroopa-1-left.png")],
        redShell = [loadTexture("assets/world13/red-shell-0.png"),
            loadTexture("assets/world13/red-shell-1.png")]
    };
}

function drawWorld13Background(g) {
    // World 1-3 uses the ROM's ordinary outdoor backdrop. Clouds and scenery
    // are decoded into the map and drawn by the owned tile hook.
    screenRect(0.0,0.0,LOGICAL_WIDTH,LOGICAL_HEIGHT,
               146.0/255.0,144.0/255.0,1.0);
}

// Return the ROM-palette sprite for red Koopas and Paratroopas. The shared
// renderer owns positioning, clipping, and flipped/shell coordinate fixes; it
// substitutes this texture while retaining those branches. Normal enemies
// return null so their existing path remains unchanged.
function world13EnemyTexture(g,e,visualState) {
    if(g.level!=3 || e.kind!="koopa" || !("red" in e) || !e.red)
        return null;
    if(visualState=="flipped" || visualState=="shell" ||
       visualState=="shellMoving") {
        local frame=visualState=="shellMoving" ? 0 : e.displayShellFrame;
        if(frame<0 || frame>=assets.world13.redShell.len()) frame=0;
        return assets.world13.redShell[frame];
    }
    local facing=e.displayFacing;
    // EnemyGfxHandler checks FrameCounter bit 3 before selecting the second
    // six-tile frame. Render-side RAM is two gameplay counts ahead, matching
    // the shared Goomba animation hook.
    local frame=(((g.nesFrameCounter+254)&0xff)&0x08)==0 ? 1 : 0;
    if(e.displayParatroopa)
        return facing<0 ? assets.world13.redParatroopaLeft[frame] :
                          assets.world13.redParatroopaRight[frame];
    return facing<0 ? assets.world13.redKoopaLeft[frame] :
                      assets.world13.redKoopaRight[frame];
}

// ChkForDemoteKoopa: the first stomp removes a red Paratroopa's wings and
// returns it to ordinary walking state. It remains a 24px-tall enemy, clears
// its vertical 8.8 accumulators, and uses EnemyFacePlayer's table index with
// DemotedKoopaXSpdData
// ($08/$f8, the same half-pixel walking speed as a normal Koopa).
function demoteWorld13Paratroopa(g,e) {
    if(g.level!=3 || e.kind!="koopa" || !e.alive || e.state!="walking" ||
       !("red" in e) || !e.red || !("paratroopa" in e) || !e.paratroopa)
        return false;
    e.paratroopa=false;
    // InitVStf clears speed/force but retains this object's YMF dummy byte.
    e.nesYDummy=e.verticalDummy;
    e.nesYSpeed=0;e.nesYMoveForce=0;
    e.verticalSpeed=0;e.verticalForce=0;e.verticalDummy=0;
    e.vy=0.0;e.grounded=false;
    // EnemyFacePlayer returns index 0 when EnemyX-PlayerX is nonnegative;
    // DemotedKoopaXSpdData maps that index to +8, and index 1 to -8.
    local direction=g.player.x<e.x ? 1 : -1;
    e.world13Facing=direction;
    e.vx=direction*KOOPA_WALK_SPEED;
    e.shellDirection=direction;
    // RedPTroopaOrigXPos aliases Enemy_X_MoveForce ($0401). The flight
    // initializer stores the original Y there; demotion reuses that byte
    // as the fractional horizontal position, including this movement pass.
    e.x=floor(e.x)+(e.originalY&0xff)/256.0+e.vx*FIXED_DT;
    return true;
}

function world13TileTexture(g,tx,ty,tile) {
    if (g.world13Metatiles.len()==0) return tileTexture(g,tile);
    local index=tileIndex(tx,ty);
    local meta=g.world13Metatiles[index];
    local baseTile=g.world13BaseTiles[index];
    // Flagpole and the goal castle are drawn by the shared course-clear
    // renderer. Coins use the shared animated level-coin objects.
    if (meta==0x24 || meta==0x25 || meta==0xc2) return null;
    if ((meta==0xc0 || meta==0xc1) && tile==baseTile &&
        (tile==TILE_QUESTION || tile==TILE_POWERUP_BLOCK)) {
        local phase=g.displayColorPhase;
        if (phase<0 || phase>=assets.world13.questions.len()) phase=0;
        return assets.world13.questions[phase];
    }
    if (tile==baseTile && meta in assets.world13.metatiles)
        return assets.world13.metatiles[meta];
    if (tile==TILE_EMPTY && baseTile==TILE_EMPTY && meta in assets.world13.metatiles)
        return assets.world13.metatiles[meta];
    return tileTexture(g,tile);
}

function world13TileFor(meta,block) {
    if (meta==0xc2 || meta==0x24 || meta==0x25) return TILE_EMPTY;
    if (meta==0xc1) return TILE_POWERUP_BLOCK;
    if (meta==0xc0) return TILE_QUESTION;
    if (block==0) return TILE_EMPTY;
    if (block==0x54) return TILE_GROUND;
    if (block==0x52) return TILE_BRICK;
    return TILE_SOLID;
}

function applyWorld13Map(g) {
    g.world13Metatiles=array(LEVEL_WIDTH*LEVEL_HEIGHT,0);
    g.world13Blocks=array(LEVEL_WIDTH*LEVEL_HEIGHT,0);
    g.levelCoins=[];
    // The camera can expose four continuation columns beyond the nominal
    // 160-column course. Capture them from the ROM parser as well: the ground
    // and castle artwork continue into that final screen.
    local mapWidth=ROM_WORLD_1_3_METATILES.len();
    for(local x=0;x<mapWidth;x+=1) for(local row=0;row<13;row+=1) {
        local y=row+2, index=tileIndex(x,y);
        local meta=ROM_WORLD_1_3_METATILES[x][row];
        local block=ROM_WORLD_1_3_BLOCKS[x][row];
        g.world13Metatiles[index]=meta;g.world13Blocks[index]=block;
        setTile(g,x,y,world13TileFor(meta,block));
        if(meta==0xc2 || meta==0xc3)
            g.levelCoins.append({x=x*16.0,y=y*16.0,width=16.0,height=16.0,active=true});
    }
    g.world13BaseTiles=clone g.tiles;
    g.flagX=152.0*TILE_SIZE;g.flagY=48.0;g.preparedFlagY=48.0;
    g.displayFlagY=48.0;g.castleX=155.0*TILE_SIZE;
}

function decodeWorld13Enemies(g) {
    local data=ROM_WORLD_1_3_ENEMIES,page=0,cursor=0;
    local horizontalPlatformCount=0;
    local horizontalMoveFractions=[0x80,0x00,0x60];
    g.world13BulletSources=[];
    g.world13Bullets=[];
    while(cursor+1<data.len() && data[cursor]!=255) {
        local a=data[cursor],b=data[cursor+1],row=a&15;
        if((b&128)!=0) page+=1;
        if(row==14) {cursor+=3;continue;}
        // Secondary-hard-mode objects remain in the stream but are not
        // instantiated during a normal game. Both World 1-3 Bullet Bill
        // frenzy sources carry this bit.
        if((b&64)!=0) {cursor+=2;continue;}
        local id=b&63;
        local x=(page*16+(a>>4))*16.0;
        if(id==0x0f) {
            local e=makeEnemyAt(x,row+1,"koopa");
            e.red <- true;e.paratroopa <- true;e.world13Facing <- -1;
            e.previousParatroopa=true;e.preparedParatroopa=true;e.displayParatroopa=true;
            local enemyY=e.y.tointeger();
            e.anchorX <- x;e.verticalY <- enemyY;
            e.originalY <- enemyY;
            e.centerY <- (e.originalY < 0x80 ? e.originalY+0x30 : e.originalY-0x20);
            e.verticalSpeed <- 0;e.verticalForce <- 0;e.verticalDummy <- 0;
            g.goombas.append(e);
        } else if(id==0x00 || id==0x03 || id==0x06) {
            local e=makeEnemyAt(x,row+1,id==0x06?"goomba":"koopa");
            e.red <- id==0x03;
            if(e.red) e.world13Facing <- -1;
            g.goombas.append(e);
        } else if(id==0x25) {
            local platformY=row*16;
            g.platforms.append({x=x,y=platformY.tofloat(),initialY=platformY.tofloat(),
                previousX=x,previousY=platformY.tofloat(),id=id,motion="vertical",
                width=48.0,awake=false,retired=false,slot=-1,lastSlot=-1,
                verticalY=platformY,
                verticalSpeed=0,verticalForce=0,verticalDummy=0});
        } else if(id==0x26 || id==0x27) {
            local up=id==0x26;
            g.platforms.append({x=x+12.0,y=row*16.0,initialY=row*16.0,
                previousX=x+12.0,previousY=row*16.0,id=id,motion="lift",
                width=48.0,awake=false,retired=false,slot=-1,lastSlot=-1,
                speed=up?-240.0/256.0:240.0/256.0});
        } else if(id==0x28) {
            // InitHoriPlatform clears the secondary counter but intentionally
            // preserves Enemy_X_MoveForce. These three platforms inherit $80,
            // $00 and $60 from their verified ROM object-slot history. The
            // force is at $0401+slot because MoveEnemyHorizontally increments
            // X before calling MoveObjectHorizontally.
            local moveFraction=horizontalPlatformCount<horizontalMoveFractions.len() ?
                horizontalMoveFractions[horizontalPlatformCount] : 0;
            g.platforms.append({x=x,y=row*16.0,initialY=row*16.0,
                previousX=x,previousY=row*16.0,id=id,motion="horizontal",
                width=48.0,awake=false,retired=false,slot=-1,lastSlot=-1,
                fraction=moveFraction.tofloat(),
                secondaryCounter=0,primaryCounter=0});
            horizontalPlatformCount+=1;
        } else if(id==0x17) {
            g.world13BulletSources.append({x=x,y=row*16.0,awake=false,timer=0});
        }
        cursor+=2;
    }
}

function world13ResetObjects(g) {
    clearAreaObjects(g);
    g.platforms=[];g.world13BulletSources=[];g.world13Bullets=[];
    g.world13BaseTiles=[];g.world13Metatiles=[];g.world13Blocks=[];
    g.plants=[];g.enterablePipes=[];g.sidePipeX=-1;
    g.flagScoreAge=-1;g.castleFlagVisible=false;g.fireworks=[];
    g.endLevelScrollLocked=false;
}

function startWorld13(g) {
    local big=g.player.big,fire=g.player.fire;
    if (!("world13Metatiles" in g)) g.world13Metatiles <- [];
    if (!("world13Blocks" in g)) g.world13Blocks <- [];
    if (!("world13BaseTiles" in g)) g.world13BaseTiles <- [];
    if (!("world13BulletSources" in g)) g.world13BulletSources <- [];
    if (!("world13Bullets" in g)) g.world13Bullets <- [];
    // The ROM's scroll boundary extends four metatiles beyond the captured
    // 160-column course map. Course clear advances the camera through those
    // empty columns and clamps at X=$0940 / 2368 before the next area loads.
    g.level=3;g.stage="main";g.area="main";g.areaWidth=164;
    g.romBackgroundCollision=true;
    g.cameraX=0.0;g.displayCameraX=0.0;
    world13ResetObjects(g);
    applyWorld13Map(g);
    decodeWorld13Enemies(g);
    resetPlayerForArea(g,40,176);
    g.player.big=big;g.player.fire=fire;
    g.player.height=big?32.0:16.0;
    g.player.grounded=true;g.player.entranceFalling=false;
    g.player.vy=0.0;g.player.nesYSpeed=0;g.player.nesYMoveForce=0;
    g.player.fallForce=0x28;
    g.time=300;g.displayTime=300;g.gameTimerControl=23;
    g.hurryActive=false;g.nesFrameCounter=0x1a;
    g.intervalTimerControl=0;g.colorRotateOffset=1;
    g.displayColorPhase=0;g.pendingColorPhase=0;g.colorPhasePending=false;
    g.vramAreaParserTask=0;g.vramBufferAddrCtrl=0;
    g.state="playing";g.stateTimer=0.0;g.checkpointPage=0;
    g.soundEvents.append("resume_music");
}

function initializeWorld13Parity(g) {
    g.nesFrameCounter=0x1a;g.intervalTimerControl=0;
    g.gameTimerControl=23;g.colorRotateOffset=1;
    g.displayColorPhase=0;g.vramAreaParserTask=0;g.vramBufferAddrCtrl=0;
    g.cameraX=0.0;g.displayCameraX=0.0;
    g.player.big=false;g.player.fire=false;
    resetPlayerForArea(g,40,176);g.player.grounded=true;
}

function world13PlatformRider(g,platform,oldX,oldY,newX,newY) {
    local p=g.player;
    if(p.dead || p.nesYSpeed<0.0) return;
    local previousFeet=p.previousY+p.height;
    local currentFeet=p.y+p.height;
    local wasRiding=p.grounded && abs(previousFeet-oldY)<=2.5;
    local crossed=previousFeet<=oldY+2.5 && currentFeet>=newY-0.01;
    if(!wasRiding && !crossed) return;
    local left=oldX<newX?oldX:newX;
    local right=oldX>newX?oldX:newX;
    // Platform and player bounds are inclusive in the ROM collision pass.
    // Treating an exact edge contact as a miss drops the first landing frame.
    if(p.x+p.width<left || p.x>right+platform.width) return;
    p.x+=newX-oldX;
    p.pendingPlatformXScroll+=(newX-oldX).tointeger();
    p.y=newY-p.height;p.grounded=true;p.entranceFalling=false;
    p.vy=0.0;p.nesYSpeed=0;p.nesYMoveForce=0;
}

function world13SignedByte(value) {
    return value>=0x80?value-0x100:value;
}

// ImposeGravity in SMBDIS.ASM. The actor stores the same byte-sized vertical
// speed, movement force and dummy accumulator as the original object slot.
function world13ImposeGravity(actor,downAmount,upAmount,maxSpeed,upward) {
    local forceBefore=actor.verticalForce;
    // The ROM retains the carry from the dummy accumulator's addition while
    // it loads and optionally decrements the vertical speed. That carry is
    // what advances Platform_Y_Position in Shigeru's $25 vertical platform
    // schedule; using the newly accumulated acceleration carry shifts the
    // platform down dozens of frames late.
    local dummySum=actor.verticalDummy+forceBefore;
    local yCarry=dummySum>>8;
    actor.verticalDummy=dummySum&0xff;
    local forceSum=forceBefore+downAmount;
    local speedCarry=forceSum>>8;
    actor.verticalY+=world13SignedByte(actor.verticalSpeed)+yCarry;
    actor.verticalForce=forceSum&0xff;
    actor.verticalSpeed=(actor.verticalSpeed+speedCarry)&0xff;
    if(world13SignedByte(actor.verticalSpeed)>=maxSpeed &&
       actor.verticalForce<0x80) {
        actor.verticalSpeed=maxSpeed;
        actor.verticalForce=0;
    }
    if(!upward) return;
    local subtract=actor.verticalForce-upAmount;
    local borrow=subtract<0?1:0;
    actor.verticalForce=subtract&0xff;
    actor.verticalSpeed=(actor.verticalSpeed-borrow)&0xff;
    if(world13SignedByte(actor.verticalSpeed) < -maxSpeed) {
        if(actor.verticalForce<0x80) {
            actor.verticalSpeed=(-maxSpeed)&0xff;
            actor.verticalForce=0xff;
        }
    }
}

function updateWorld13Platforms(g) {
    local p=g.player;
    local projectedCameraX=g.cameraX+(p.nesXScroll>0?p.nesXScroll:0);
    foreach(platform in g.platforms) {
        if(platform.retired) continue;
        local retireAfterMove=platform.awake && platform.x<projectedCameraX-73.0;
        local newlyAwake=false;
        if(!platform.awake) {
            local boundary=floor((g.cameraX+LOGICAL_WIDTH-1.0+48.0)/16.0)*16.0;
            if(platform.x>boundary) continue;
            platform.awake=true;
            newlyAwake=true;
        }
        if(platform.slot<0) for(local slot=0;slot<5;slot+=1) {
            local occupied=false;
            foreach(e in g.goombas)
                if(e.alive && e.awake && e.slot==slot) {occupied=true;break;}
            foreach(other in g.platforms)
                if(other!=platform && other.awake && !other.retired &&
                   other.slot==slot) {occupied=true;break;}
            foreach(bullet in g.world13Bullets)
                if(bullet.active && bullet.slot==slot) {occupied=true;break;}
            if(!occupied) {platform.slot=slot;break;}
        }
        // The parser's allocation pass only initializes the vertical actor;
        // EnemyMovementSubs begins on its following pass.
        if(newlyAwake && platform.motion=="vertical") continue;
        platform.previousX=platform.x;platform.previousY=platform.y;
        local oldX=platform.x,oldY=platform.y,newX=oldX,newY=oldY;
        if(platform.motion=="vertical") {
            local center=platform.initialY+64.0;
            if((platform.verticalSpeed|platform.verticalForce)==0) {
                platform.verticalDummy=0;
                if(platform.verticalY<platform.initialY.tointeger()) {
                    if((g.nesFrameCounter&7)==0) platform.verticalY+=1;
                } else {
                    world13ImposeGravity(platform,5,10,3,
                        platform.verticalY>=center);
                }
            } else {
                world13ImposeGravity(platform,5,10,3,
                    platform.verticalY>=center);
            }
            newY=platform.verticalY.tofloat();
        } else if(platform.motion=="horizontal") {
            if((g.nesFrameCounter&3)==0) {
                if((platform.primaryCounter&1)==0) {
                    if(platform.secondaryCounter==14)
                        platform.primaryCounter=(platform.primaryCounter+1)&0xff;
                    else platform.secondaryCounter+=1;
                } else {
                    if(platform.secondaryCounter==0)
                        platform.primaryCounter=(platform.primaryCounter+1)&0xff;
                    else platform.secondaryCounter-=1;
                }
            }
            // MoveWithXMCntrs stores the two's complement of the secondary
            // counter while moving unless primary-counter bit 1 is set.
            // MoveObjectHorizontally then treats that byte as 8.8 movement:
            // the low nibble contributes low-nibble*16 to the force, while
            // the signed high nibble contributes whole pixels. The force
            // carry is added to the pixel movement in the same step.
            local moveCounter=platform.secondaryCounter;
            if((platform.primaryCounter&2)==0)
                moveCounter=(-moveCounter)&0xff;
            local lowNibble=(moveCounter&0x0f)*16;
            local highNibble=moveCounter>>4;
            if(highNibble>=8) highNibble-=16;
            platform.fraction+=lowNibble;
            local movementCarry=0;
            while(platform.fraction>=256.0) {
                platform.fraction-=256.0;
                movementCarry+=1;
            }
            newX+=highNibble+movementCarry;
        } else {
            platform.fraction+=platform.speed;
            while(platform.fraction<0.0) {platform.fraction+=1.0;newY-=1.0;}
            while(platform.fraction>=1.0) {platform.fraction-=1.0;newY+=1.0;}
            if(newY<0.0) newY+=256.0;
            if(newY>=256.0) newY-=256.0;
        }
        platform.x=newX;platform.y=newY;
        world13PlatformRider(g,platform,oldX,oldY,newX,newY);
        // Erase only after the final movement pass so both horizontal and
        // vertical fractional bytes survive for the next object in this slot.
        if(retireAfterMove) {
            platform.retired=true;platform.lastSlot=platform.slot;platform.slot=-1;
        }
    }
}

function updateWorld13Bullets(g) {
    local p=g.player;
    foreach(source in g.world13BulletSources) {
        if(!source.awake) {
            local boundary=floor((g.cameraX+LOGICAL_WIDTH-1.0+48.0)/16.0)*16.0;
            if(source.x>boundary) continue;
            source.awake=true;source.timer=0;
        }
        if(source.timer>0) source.timer-=1;
        local active=false;
        foreach(bullet in g.world13Bullets) if(bullet.source==source) active=true;
        if(source.timer==0 && !active) {
            local bullet={source=source,x=g.cameraX+LOGICAL_WIDTH+8.0,
                y=80.0,width=16.0,height=16.0,vx=-1.5*NES_FRAME_RATE,
                active=true,slot=-1};
            // Bullet Bills are ordinary enemy objects in the ROM and retain
            // their NES slot until OffscreenBoundsCheck erases them. Later
            // stream allocations observe that occupancy.
            for(local slot=0;slot<5;slot+=1) {
                local occupied=false;
                foreach(e in g.goombas) if(e.alive && e.awake && e.slot==slot) {
                    occupied=true;break;
                }
                foreach(other in g.world13Bullets)
                    if(other.active && other.slot==slot) {occupied=true;break;}
                if(!occupied) {bullet.slot=slot;break;}
            }
            g.world13Bullets.append(bullet);
            emitSound(g,"blast");source.timer=64;
        }
    }
    foreach(bullet in g.world13Bullets) {
        if(!bullet.active) continue;
        bullet.x+=bullet.vx*FIXED_DT;
        if(bullet.x<g.cameraX-32.0) {bullet.active=false;bullet.slot=-1;continue;}
        if(!p.dead && overlaps(p.x+3.0,p.y+(p.big?8.0:4.0),10.0,
            p.big&&!p.crouching?24.0:12.0,bullet.x+2.0,bullet.y+2.0,12.0,12.0))
            hurtPlayer(g);
    }
}

function updateWorld13Actors(g) {
    foreach(e in g.goombas) {
        if(!e.alive || !("paratroopa" in e) || !e.paratroopa) continue;
        if(("world13Facing" in e) && e.vx<0.0) e.world13Facing=-1;
        if(("world13Facing" in e) && e.vx>0.0) e.world13Facing=1;
        if(!e.awake || e.state!="walking") {
            e.anchorX=e.x;e.verticalY=e.y.tointeger();
            e.verticalSpeed=0;e.verticalForce=0;e.verticalDummy=0;
            continue;
        }
        // ProcMoveRedPTroopa has no horizontal movement routine. updateGoombas
        // runs first for shared collisions, so undo its generic walk step.
        local newlyAwake=e.vx!=0.0;
        e.x=e.anchorX;e.vx=0.0;
        if(newlyAwake) continue;
        if((e.verticalSpeed|e.verticalForce)==0) {
            e.verticalDummy=0;
            if(e.verticalY<e.originalY && (g.nesFrameCounter&7)==0)
                e.verticalY+=1;
            else if(e.verticalY>=e.originalY)
                world13ImposeGravity(e,3,6,2,e.verticalY>=e.centerY);
        } else {
            world13ImposeGravity(e,3,6,2,e.verticalY>=e.centerY);
        }
        e.y=e.verticalY.tofloat();e.vy=0.0;e.grounded=false;
    }
    updateWorld13Platforms(g);
    updateWorld13Bullets(g);
}

function drawWorld13Actors(g,behind) {
    if(behind) return;
    foreach(platform in g.platforms) {
        if(!platform.awake || platform.x+platform.width<g.cameraX ||
           platform.x>g.cameraX+LOGICAL_WIDTH) continue;
        // The sprite buffer contains the coordinates prepared before this
        // pass's movement; use those rather than a fixed sprite offset.
        screenOamTexture(assets.world13.platform,
            platform.previousX-visualCameraX(g),platform.previousY+1.0,platform.width,8.0,
            platform.previousX-visualCameraX(g));
    }
    foreach(bullet in g.world13Bullets)
        if(bullet.active) worldTexture(g,assets.world13.bulletBill,
            bullet.x,bullet.y-4.0,16.0,24.0);
}

function runWorld13SelfTest() {
    local g=createGame();g.score=12000;g.coins=17;g.lives=3;
    g.player.big=true;g.player.fire=true;startWorld13(g);
    loadWorld13Assets();
    requireSelfTest(g.level==3 && g.stage=="main" && g.area=="main" &&
        g.areaWidth==164,"1-3 stage geometry");
    requireSelfTest(g.player.big && g.player.fire && g.score==12000 &&
        g.coins==17 && g.lives==3,"1-3 entry preserves persistent progress");
    requireSelfTest(g.player.x==40.0 && g.player.grounded &&
        g.nesFrameCounter==0x1a && g.gameTimerControl==23 &&
        g.time==300 && g.displayTime==300,
        "1-3 canonical entrance state");
    initializeWorld13Parity(g);
    requireSelfTest(!g.player.big && !g.player.fire &&
        g.player.height==16.0 && g.player.grounded,
        "1-3 parity fixup must start small despite a prior power-up");
    requireSelfTest(getTile(g,0,13)==TILE_GROUND &&
        isSolidAt(g,0,13),"1-3 ROM ground collision");
    requireSelfTest(g.world13Blocks[tileIndex(154,7)]==0,
        "1-3 decorative cloud/field must not become collision");
    requireSelfTest(g.world13Metatiles[tileIndex(24,9)]==0x16 &&
        getTile(g,24,9)==TILE_SOLID,"1-3 first tree ledge");
    requireSelfTest(g.flagX==152.0*TILE_SIZE && g.castleX==155.0*TILE_SIZE,
        "1-3 ROM flag and castle endpoint");
    local edgeKoopa=g.goombas[0];
    edgeKoopa.x=407.5;edgeKoopa.y=56.0;edgeKoopa.vx=-KOOPA_WALK_SPEED;
    moveEnemyBody(g,edgeKoopa,FIXED_DT);
    requireSelfTest(edgeKoopa.state=="walking" && edgeKoopa.vx>0 &&
        edgeKoopa.y==56.0,"ordinary red Koopa must turn at a ledge without falling");
    startWorld13(g);
    local goombaCount=0,redCount=0,paratroopaCount=0;
    foreach(enemy in g.goombas) {
        if(enemy.kind=="goomba") goombaCount+=1;
        if(enemy.red) redCount+=1;
        if("paratroopa" in enemy && enemy.paratroopa) paratroopaCount+=1;
    }
    requireSelfTest(g.platforms.len()==4 && g.goombas.len()==8 &&
        goombaCount==3 && redCount==5 && paratroopaCount==2 &&
        g.world13BulletSources.len()==0,
        "1-3 E_GroundArea7 actor decode");
    local vertical=g.platforms[0],horizontal=g.platforms[1];
    vertical.awake=true;horizontal.awake=true;
    local oldY=vertical.y,oldX=horizontal.x;
    local verticalMoved=false,horizontalMoved=false;
    for(local i=0;i<80;i+=1) {
        g.nesFrameCounter=(g.nesFrameCounter+1)&0xff;
        updateWorld13Platforms(g);
        if(vertical.y!=oldY) verticalMoved=true;
        if(horizontal.x!=oldX) horizontalMoved=true;
    }
    requireSelfTest(verticalMoved,"vertical platform must move");
    requireSelfTest(horizontalMoved,"horizontal platform must move");
    startWorld13(g);
    local redParatroopa=null;
    foreach(enemy in g.goombas)
        if("paratroopa" in enemy && enemy.paratroopa) {
            redParatroopa=enemy;break;
        }
    requireSelfTest(redParatroopa!=null,"1-3 must load red Paratroopas");
    local walkingTexture=world13EnemyTexture(g,redParatroopa,"walking");
    requireSelfTest(walkingTexture==assets.world13.redParatroopaLeft[0] ||
        walkingTexture==assets.world13.redParatroopaLeft[1],
        "red Paratroopa hook must select a red sprite");
    local redKoopa=null;
    foreach(enemy in g.goombas)
        if(enemy.red && enemy.kind=="koopa" &&
           !("paratroopa" in enemy && enemy.paratroopa)) {
            redKoopa=enemy;break;
        }
    requireSelfTest(redKoopa!=null,"1-3 must load a red Koopa");
    walkingTexture=world13EnemyTexture(g,redKoopa,"walking");
    requireSelfTest(walkingTexture==assets.world13.redKoopaLeft[0] ||
        walkingTexture==assets.world13.redKoopaLeft[1],
        "red Koopa hook must select a red walking sprite");
    local normalEnemy=null;
    foreach(enemy in g.goombas)
        if(enemy.kind=="goomba") {normalEnemy=enemy;break;}
    requireSelfTest(normalEnemy!=null &&
        world13EnemyTexture(g,normalEnemy,"walking")==null,
        "normal enemy hook must defer to the shared renderer");
    redKoopa.displayShellFrame=1;
    requireSelfTest(world13EnemyTexture(g,redKoopa,"shell")==
        assets.world13.redShell[1] &&
        world13EnemyTexture(g,redKoopa,"shellMoving")==
        assets.world13.redShell[0],
        "red shell hook must select exact shell frames");
    redParatroopa.awake=true;
    local paratroopaX=redParatroopa.anchorX,paratroopaY=redParatroopa.originalY;
    for(local i=0;i<86;i+=1) {
        g.nesFrameCounter=(g.nesFrameCounter+1)&0xff;
        updateWorld13Actors(g);
    }
    requireSelfTest(redParatroopa.x==paratroopaX && redParatroopa.vx==0.0 &&
        redParatroopa.y>paratroopaY && redParatroopa.verticalForce!=0,
        "red Paratroopa must use the ROM vertical 8.8 motion without walking");
    g.player.x=redParatroopa.x+64.0;
    local beforeDemoteY=redParatroopa.y;
    requireSelfTest(demoteWorld13Paratroopa(g,redParatroopa) &&
        !redParatroopa.paratroopa && redParatroopa.state=="walking" &&
        redParatroopa.y==beforeDemoteY &&
        redParatroopa.vx==-KOOPA_WALK_SPEED &&
        redParatroopa.verticalSpeed==0 && redParatroopa.verticalForce==0,
        "first Paratroopa stomp must demote it to a walking red Koopa");
    local demotedX=redParatroopa.x,demotedY=redParatroopa.y;
    for(local i=0;i<8;i+=1) {
        g.nesFrameCounter=(g.nesFrameCounter+1)&0xff;
        updateWorld13Actors(g);
    }
    requireSelfTest(redParatroopa.x==demotedX && redParatroopa.y==demotedY,
        "owned Paratroopa flight must not resume after demotion");
    requireSelfTest(!demoteWorld13Paratroopa(g,redParatroopa),
        "Paratroopa demotion must occur only once");
    updateGoombas(g,FIXED_DT);
    requireSelfTest(redParatroopa.x<demotedX,
        "demoted Paratroopa must resume shared red Koopa walking");
    startWorld13(g);vertical=g.platforms[0];vertical.awake=true;
    g.player.x=vertical.x+12.0;g.player.y=vertical.y-g.player.height;
    g.player.previousY=g.player.y;
    g.player.grounded=true;g.player.nesYSpeed=0;
    oldY=vertical.y;
    for(local i=0;i<64;i+=1) {
        g.nesFrameCounter=(g.nesFrameCounter+1)&0xff;
        g.player.previousY=g.player.y;
        updateWorld13Platforms(g);
    }
    requireSelfTest(g.player.grounded && abs(g.player.y+g.player.height-vertical.y)<0.1,
        "vertical platform must carry a rider");
    startWorld13(g);horizontal=g.platforms[1];horizontal.awake=true;
    g.player.x=horizontal.x+12.0;g.player.y=horizontal.y-g.player.height;
    g.player.previousY=g.player.y;g.player.grounded=true;g.player.nesYSpeed=0;
    local riderX=g.player.x;
    for(local i=0;i<80;i+=1) {
        g.nesFrameCounter=(g.nesFrameCounter+1)&0xff;
        g.player.previousY=g.player.y;
        updateWorld13Platforms(g);
    }
    requireSelfTest(abs(g.player.x-horizontal.x-12.0)<0.1 &&
        abs(g.player.y+g.player.height-horizontal.y)<0.1,
        "horizontal platform must carry a rider");
    requireSelfTest(world13TileTexture(g,154,7,TILE_EMPTY)!=null,
        "tile hook must draw decorative ROM metatiles");
    requireSelfTest(world13TileTexture(g,152,3,TILE_EMPTY)==null,
        "flag artwork must defer to shared renderer");
    foreach(enemy in g.goombas)
        if(enemy.red && enemy.kind=="koopa" &&
           !("paratroopa" in enemy && enemy.paratroopa)) {
            redKoopa=enemy;break;
        }
    enterKoopaShell(redKoopa);
    requireSelfTest(redKoopa.state=="shell" && redKoopa.height==14.0,
        "ordinary red Koopa must retain shared shell stomp behavior");
    startWorld13(g);beginFlagSequence(g);
    requireSelfTest(g.state=="endLevel" && g.player.x==g.flagX-7.0,
        "1-3 flag contact must enter the shared course-clear routine");
}
