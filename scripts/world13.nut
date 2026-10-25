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
        bulletBill = loadTexture("assets/world13/bullet-bill.png")
    };
}

function drawWorld13Background(g) {
    // World 1-3 uses the ROM's ordinary outdoor backdrop. Clouds and scenery
    // are decoded into the map and drawn by the owned tile hook.
    screenRect(0.0,0.0,LOGICAL_WIDTH,LOGICAL_HEIGHT,
               146.0/255.0,144.0/255.0,1.0);
}

function world13TileTexture(g,tx,ty,tile) {
    if (g.world13Metatiles.len()==0) return tileTexture(g,tile);
    local index=tileIndex(tx,ty);
    local meta=g.world13Metatiles[index];
    local baseTile=g.world13BaseTiles[index];
    // Flagpole and the goal castle are drawn by the shared course-clear
    // renderer. Coins use the shared animated level-coin objects.
    if (meta==0x24 || meta==0x25 || meta==0xc2) return null;
    if (tx >= floor(g.castleX/TILE_SIZE).tointeger()) return null;
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
    for(local x=0;x<g.areaWidth;x+=1) for(local row=0;row<13;row+=1) {
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
            e.red <- true;e.paratroopa <- true;
            local enemyY=e.y.tointeger();
            e.anchorX <- x;e.verticalY <- enemyY;
            e.originalY <- enemyY;
            e.centerY <- (e.originalY < 0x80 ? e.originalY+0x30 : e.originalY-0x20);
            e.verticalSpeed <- 0;e.verticalForce <- 0;e.verticalDummy <- 0;
            g.goombas.append(e);
        } else if(id==0x00 || id==0x03 || id==0x06) {
            local e=makeEnemyAt(x,row+1,id==0x06?"goomba":"koopa");
            e.red <- id==0x03;g.goombas.append(e);
        } else if(id==0x25) {
            local platformY=row*16;
            g.platforms.append({x=x,y=platformY.tofloat(),initialY=platformY.tofloat(),
                previousX=x,previousY=platformY.tofloat(),id=id,motion="vertical",
                width=48.0,awake=false,verticalY=platformY,
                verticalSpeed=0,verticalForce=0,verticalDummy=0});
        } else if(id==0x26 || id==0x27) {
            local up=id==0x26;
            g.platforms.append({x=x+12.0,y=row*16.0,initialY=row*16.0,
                previousX=x+12.0,previousY=row*16.0,id=id,motion="lift",
                width=48.0,awake=false,speed=up?-240.0/256.0:240.0/256.0});
        } else if(id==0x28) {
            g.platforms.append({x=x,y=row*16.0,initialY=row*16.0,
                previousX=x,previousY=row*16.0,id=id,motion="horizontal",
                width=48.0,awake=false,fraction=0.0,
                secondaryCounter=0,primaryCounter=0});
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
    g.level=3;g.stage="main";g.area="main";g.areaWidth=160;
    g.cameraX=0.0;g.displayCameraX=0.0;
    world13ResetObjects(g);
    applyWorld13Map(g);
    decodeWorld13Enemies(g);
    resetPlayerForArea(g,40,176);
    g.player.big=big;g.player.fire=fire;
    g.player.height=big?32.0:16.0;
    g.player.grounded=true;g.player.entranceFalling=false;
    g.player.vy=0.0;g.player.nesYSpeed=0;g.player.nesYMoveForce=0;
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
    if(p.x+p.width<=left || p.x>=right+platform.width) return;
    p.x+=newX-oldX;p.y=newY-p.height;p.grounded=true;p.entranceFalling=false;
    p.vy=0.0;p.nesYSpeed=0;p.nesYMoveForce=0;
}

function world13SignedByte(value) {
    return value>=0x80?value-0x100:value;
}

// ImposeGravity in SMBDIS.ASM. The actor stores the same byte-sized vertical
// speed, movement force and dummy accumulator as the original object slot.
function world13ImposeGravity(actor,downAmount,upAmount,maxSpeed,upward) {
    local forceBefore=actor.verticalForce;
    local forceSum=forceBefore+downAmount;
    local carry=forceSum>>8;
    actor.verticalDummy=(actor.verticalDummy+forceBefore)&0xff;
    actor.verticalY+=world13SignedByte(actor.verticalSpeed)+carry;
    actor.verticalForce=forceSum&0xff;
    actor.verticalSpeed=(actor.verticalSpeed+carry)&0xff;
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
    foreach(platform in g.platforms) {
        if(!platform.awake) {
            local boundary=floor((g.cameraX+LOGICAL_WIDTH-1.0+48.0)/16.0)*16.0;
            if(platform.x-platform.width/2.0>boundary) continue;
            platform.awake=true;
        }
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
            local direction=(platform.primaryCounter&2)!=0?1:-1;
            platform.fraction+=direction*platform.secondaryCounter;
            while(platform.fraction<0.0) {platform.fraction+=16.0;newX-=1.0;}
            while(platform.fraction>=16.0) {platform.fraction-=16.0;newX+=1.0;}
        } else {
            platform.fraction+=platform.speed;
            while(platform.fraction<0.0) {platform.fraction+=1.0;newY-=1.0;}
            while(platform.fraction>=1.0) {platform.fraction-=1.0;newY+=1.0;}
            if(newY<0.0) newY+=256.0;
            if(newY>=256.0) newY-=256.0;
        }
        platform.x=newX;platform.y=newY;
        world13PlatformRider(g,platform,oldX,oldY,newX,newY);
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
            g.world13Bullets.append({source=source,x=g.cameraX+LOGICAL_WIDTH+8.0,
                y=80.0,width=16.0,height=16.0,vx=-1.5*NES_FRAME_RATE,active=true});
            emitSound(g,"blast");source.timer=64;
        }
    }
    foreach(bullet in g.world13Bullets) {
        if(!bullet.active) continue;
        bullet.x+=bullet.vx*FIXED_DT;
        if(bullet.x<g.cameraX-32.0) {bullet.active=false;continue;}
        if(!p.dead && overlaps(p.x+3.0,p.y+(p.big?8.0:4.0),10.0,
            p.big&&!p.crouching?24.0:12.0,bullet.x+2.0,bullet.y+2.0,12.0,12.0))
            hurtPlayer(g);
    }
}

function updateWorld13Actors(g) {
    foreach(e in g.goombas) {
        if(!e.alive || !("paratroopa" in e)) continue;
        if(!e.awake || e.state!="walking") {
            e.anchorX=e.x;e.verticalY=e.y.tointeger();
            e.verticalSpeed=0;e.verticalForce=0;e.verticalDummy=0;
            continue;
        }
        // ProcMoveRedPTroopa has no horizontal movement routine. updateGoombas
        // runs first for shared collisions, so undo its generic walk step.
        e.x=e.anchorX;e.vx=0.0;
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
        worldTexture(g,assets.world13.platform,platform.x,platform.y,
                     platform.width,8.0);
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
        g.areaWidth==160,"1-3 stage geometry");
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
    redParatroopa.awake=true;
    local paratroopaX=redParatroopa.anchorX,paratroopaY=redParatroopa.originalY;
    for(local i=0;i<86;i+=1) {
        g.nesFrameCounter=(g.nesFrameCounter+1)&0xff;
        updateWorld13Actors(g);
    }
    requireSelfTest(redParatroopa.x==paratroopaX && redParatroopa.vx==0.0 &&
        redParatroopa.y==paratroopaY+1,
        "red Paratroopa must use the ROM vertical 8.8 motion without walking");
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
    requireSelfTest(world13TileTexture(g,154,7,TILE_EMPTY)!=null,
        "tile hook must draw decorative ROM metatiles");
    requireSelfTest(world13TileTexture(g,152,3,TILE_EMPTY)==null,
        "flag artwork must defer to shared renderer");
}
