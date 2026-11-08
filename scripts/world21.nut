// World 2-1 main route and connected underground/sky bonus branches.
dofile("scripts/generated/world21_data.nut");
dofile("scripts/generated/world21_map.nut");
dofile("scripts/generated/world21_branch_maps.nut");

// Area-link commands update the selected destination; their X column is
// parser position, not proof that a pipe or vine exists at that column.
function decodeWorld21AreaLinks(data,world) {
    local links=[],page=0,cursor=0;
    while(cursor<data.len() && data[cursor]!=0xff) {
        if(cursor+1>=data.len()) throw "truncated enemy stream";
        local first=data[cursor],second=data[cursor+1],row=first&15;
        if(second&0x80) page+=1;
        if(row==15 && !(second&0x80)) {page=second&63;cursor+=2;continue;}
        if(row==14) {
            if(cursor+2>=data.len()) throw "truncated area link";
            local third=data[cursor+2];
            if((third>>5)==world-1)
                links.append({streamOffset=cursor,column=page*16+(first>>4),
                    destination=second,entrancePage=third&31});
            cursor+=3;
        } else cursor+=2;
    }
    return links;
}

// A fresh descriptor keeps static source data separate from mutable actors,
// collision tiles, parser state, timers and per-slot movement accumulators.
function world21LevelDescriptor() {
    return {world=2,level=1,stage="world21",areaPointer=0x28,
        metatiles=ROM_WORLD_2_1_METATILES,blocks=ROM_WORLD_2_1_BLOCKS,
        enemies=ROM_WORLD_2_1_ENEMIES,entry={x=40,y=176},
        goal={flagColumn=200,castleColumn=204},
        checkpoint={cameraThreshold=1536,page=6},
        music="overworld",palette="ground",time=400,
        areaLinks=decodeWorld21AreaLinks(ROM_WORLD_2_1_ENEMIES,2),
        branchesPlayable=true};
}

function isWorld21(g) {return g.world==2 && g.level==1;}

function initializeWorld21Parity(g) {
    // First controllable frame of the offline World 2-1 fixture, read from
    // the ROM RAM trace. This initializes a test origin, not gameplay frames.
    // RAM $077f is $01 at this origin; $00 shifts the divider one frame
    // early and must not be compensated by rewinding timers on a later death.
    g.nesFrameCounter=0x1a;g.intervalTimerControl=1;
    g.gameTimerControl=23;g.colorRotateOffset=1;g.displayColorPhase=0;
    g.pendingColorPhase=0;g.colorPhasePending=false;
    g.player.movingDir=0;
}

function initializeWorld21Checkpoint(g,page,entryCounter=null) {
    g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
    resetPlayerForArea(g,page*256+40,176);g.player.grounded=true;
    g.player.movingDir=0;g.checkpointPage=page;
    foreach(e in g.goombas) {
        local trigger=e.groupIndex>=0?e.groupCommandX:e.x;
        // The enemy stream skips commands left of ScreenRight, not just
        // those left of the camera, when loading a checkpoint.
        if(trigger<g.cameraX+LOGICAL_WIDTH-1) e.alive=false;
    }
    // The initial twelve half-column tasks parse 24 metatile columns before
    // control starts. Pipe objects reserve slots during those loading passes.
    foreach(plant in g.plants) {
        if(plant.x<g.cameraX) plant.retired=true;
        else if(plant.x<g.cameraX+24*16 && allocateEnemySlot(g,plant)) {
            plant.awake=true;plant.active=true;
        }
    }
    // The entry-control pass immediately preceding the observable origin
    // also runs enemy motion. Reproduce it rather than supplying Y offsets.
    local counter=g.nesFrameCounter;
    if(entryCounter!=null) g.nesFrameCounter=entryCounter;
    updateWorld12Actors(g);g.nesFrameCounter=counter;
}

function loadWorld21Assets() {
    if(assets==null) loadAssets();
    if("world21" in assets) return;
    local metatiles={};
    foreach(column in ROM_WORLD_2_1_METATILES) foreach(meta in column)
        if(meta!=0 && !(meta in metatiles))
            metatiles[meta] <- loadTexture("assets/world13/metatile-"+meta+".png");
    foreach(column in ROM_WORLD_2_1_SKY_METATILES) foreach(meta in column)
        if(meta!=0 && !(meta in metatiles)) metatiles[meta] <- loadTexture("assets/world13/metatile-"+meta+".png");
    assets.world21 <- {metatiles=metatiles,
        cloud=loadTexture("assets/world21/cloud-platform.png"),
        spriteZeroMasks=[loadTexture("assets/world21/hud-sprite0-0.png"),
            loadTexture("assets/world21/hud-sprite0-1.png"),loadTexture("assets/world21/hud-sprite0-2.png"),
            loadTexture("assets/world21/hud-sprite0-3.png"),loadTexture("assets/world21/hud-sprite0-4.png"),
            loadTexture("assets/world21/hud-sprite0-5.png")],
        wingsRight=[loadTexture("assets/world21/paratroopa-0.png"),loadTexture("assets/world21/paratroopa-1.png")],
        wingsLeft=[loadTexture("assets/world21/paratroopa-0-left.png"),loadTexture("assets/world21/paratroopa-1-left.png")],
        plants=[loadTexture("assets/world21/plant-0.png"),loadTexture("assets/world21/plant-1.png")],
        springs=[loadTexture("assets/world21/spring-0.png"),loadTexture("assets/world21/spring-1.png"),loadTexture("assets/world21/spring-2.png")],
        vineTop=loadTexture("assets/world21/vine-top.png"),vineBody=loadTexture("assets/world21/vine-body.png"),
        vineBodyFlipped=loadTexture("assets/world21/vine-body-flipped.png")};
}

function startWorld21(g) {
    if("world21Main" in g) delete g.world21Main;
    local descriptor=world21LevelDescriptor();
    g.world=descriptor.world;g.level=descriptor.level;g.stage=descriptor.stage;g.area="main";
    g.areaWidth=descriptor.metatiles.len();g.romBackgroundCollision=true;
    clearAreaObjects(g);g.plants=[];g.platforms=[];g.enterablePipes=[];
    g.sidePipeX=-1;g.cameraX=0.0;g.displayCameraX=0.0;
    local state={descriptor=descriptor,baseTiles=[],vines=[],springs=[],
        slotXFractions=[0.0,0.0,0.0,0.0,0.0]};
    if("world21" in g) g.world21=state; else g.world21 <- state;
    local mapping={};
    foreach(pair in [[0x24,TILE_EMPTY],[0x25,TILE_EMPTY],
        [0x51,TILE_BRICK],[0x52,TILE_BRICK],[0x54,TILE_GROUND],
        [0x55,TILE_BRICK_POWERUP],[0x56,TILE_BRICK_VINE],[0x57,TILE_BRICK_STAR],
        [0x58,TILE_BRICK_COIN],[0x59,TILE_BRICK_ONEUP],[0x5f,TILE_HIDDEN_COIN],
        [0x60,TILE_HIDDEN_ONEUP],[0xc0,TILE_QUESTION],[0xc1,TILE_POWERUP_BLOCK],
        [0xc4,TILE_USED],[0x10,TILE_PIPE_TOP_LEFT],[0x11,TILE_PIPE_TOP_RIGHT],
        [0x12,TILE_PIPE_TOP_LEFT],[0x13,TILE_PIPE_TOP_RIGHT],
        [0x14,TILE_PIPE_SHAFT_LEFT],[0x15,TILE_PIPE_SHAFT_RIGHT]]) mapping[pair[0]]<-pair[1];
    for(local x=0;x<g.areaWidth;x+=1) for(local row=0;row<13;row+=1) {
        local meta=ROM_WORLD_2_1_METATILES[x][row],block=ROM_WORLD_2_1_BLOCKS[x][row];
        local tile=meta in mapping?mapping[meta]:(block!=0?TILE_SOLID:TILE_EMPTY);
        setTile(g,x,row+2,tile);
        if(meta==0x10 || meta==0x12)
            g.plants.append({x=x*16.0+8.0,y=(row+2)*16.0,baseY=(row+2)*16.0,
                direction=1,moving=false,timer=0,active=false,awake=false,
                retired=false,slot=-1,enemyCollisionMask=0});
        if(meta==0x67) state.springs.append({x=x*16.0,y=(row+2)*16.0,control=0,timer=0,force=-7});
    }
    state.baseTiles=clone g.tiles;
    decodeWorld11Enemies(g,descriptor.enemies);
    g.flagX=descriptor.goal.flagColumn*16.0;g.castleX=descriptor.goal.castleColumn*16.0;g.flagY=48.0;
    g.preparedFlagY=48.0;g.displayFlagY=48.0;g.castleFlagVisible=false;
    resetPlayerForArea(g,descriptor.entry.x,descriptor.entry.y);g.player.grounded=true;g.player.entranceFalling=false;
    g.state="playing";g.stateTimer=0.0;g.checkpointPage=0;
    g.time=descriptor.time;g.displayTime=descriptor.time;g.gameTimerControl=23;g.hurryActive=false;
    g.soundEvents.append("resume_music");
}

function world21TileTexture(g,tx,ty,tile) {
    if(g.area=="sky") {
        if(ty<2 || tx<0 || tx>=ROM_WORLD_2_1_SKY_METATILES.len()) return null;
        local meta=ROM_WORLD_2_1_SKY_METATILES[tx][ty-2];
        if(meta==0 || meta==0xc2) return null;
        return meta in assets.world21.metatiles?assets.world21.metatiles[meta]:null;
    }
    if(g.area=="underground") {
        if(ty<2 || tx<0 || tx>=ROM_WORLD_2_1_UNDERGROUND_METATILES.len()) return null;
        local meta=ROM_WORLD_2_1_UNDERGROUND_METATILES[tx][ty-2];
        if(meta==0 || meta==0xc2) return null;
        return meta in assets.world12.metatiles?assets.world12.metatiles[meta]:tileTexture(g,tile);
    }
    if(ty<2) return null;
    local meta=ROM_WORLD_2_1_METATILES[tx][ty-2];
    if(meta==0 || meta==0x24 || meta==0x25 || meta==0x5f || meta==0x60) {
        return tile==TILE_USED?assets.tiles.used:null;
    }
    if((meta==0x67 || meta==0x68) && g.world21.springs.len()>0 &&
        g.world21.springs[0].control>0) return null;
    if(tile!=g.world21.baseTiles[tileIndex(tx,ty)]) return tileTexture(g,tile);
    if(meta==0xc0 || meta==0xc1) return assets.tiles.questions[g.displayColorPhase];
    return meta in assets.world21.metatiles?assets.world21.metatiles[meta]:null;
}

function tryWorld21BonusPipe(g) {
    local p=g.player;
    local entering=g.area=="main" && g.input.down && p.grounded &&
        floor((p.x+3)/16)==103 && floor((p.x+12)/16)==104 &&
        abs(p.y+p.height-9*16)<1;
    local leaving=g.area=="underground" && p.grounded && g.input.right &&
        // ROM block probes use integer X and the inclusive X+13 edge.
        p.facing>0 && floor(p.x)+13>=13*16;
    if(!entering && !leaving) return false;
    g.transitionTimer=0;g.areaTransitionFrames=0;
    g.areaReloadTarget=entering?"underground":"main";
    g.state=entering?"pipeDown":"pipeSide";
    emitSound(g,"pipe");return true;
}

function loadWorld21Underground(g) {
    saveMainArea(g);
    g.world21.savedActors <- {plants=g.plants,checkpoint=g.checkpointPage};
    // Snapshot mutable objects without sharing the new branch's actor arrays.
    g.world21Main <- g.world21;
    clearAreaObjects(g);g.plants=[];g.platforms=[];
    g.area="underground";g.areaWidth=16;g.sidePipeX=13;
    g.world12SidePipeBottomRow <- 12;
    local main=g.world21;
    g.world21={descriptor=main.descriptor,baseTiles=[],vines=[],springs=[],
        slotXFractions=[0.0,0.0,0.0,0.0,0.0]};
    local roles={};
    foreach(pair in [[0x52,TILE_BRICK],[0x54,TILE_GROUND],[0x14,TILE_PIPE_SHAFT_LEFT],
        [0x1c,TILE_SIDE_PIPE_TOP_END],[0x1d,TILE_SIDE_PIPE_TOP_SHAFT],
        [0x1e,TILE_SIDE_PIPE_TOP_JOINT],[0x1f,TILE_SIDE_PIPE_BOTTOM_END],
        [0x20,TILE_SIDE_PIPE_BOTTOM_SHAFT],[0x21,TILE_SIDE_PIPE_BOTTOM_JOINT]]) roles[pair[0]]<-pair[1];
    for(local x=0;x<16;x+=1) for(local r=0;r<13;r+=1) {
        local meta=ROM_WORLD_2_1_UNDERGROUND_METATILES[x][r];
        if(meta==0xc2) g.levelCoins.append({x=x*16.0,y=(r+2)*16.0,
            width=16.0,height=16.0,active=true});
        else setTile(g,x,r+2,meta in roles?roles[meta]:
            (ROM_WORLD_2_1_UNDERGROUND_BLOCKS[x][r]!=0?TILE_SOLID:TILE_EMPTY));
    }
    g.world21.baseTiles=clone g.tiles;
    g.cameraX=0;g.displayCameraX=0;
}

function restoreWorld21Main(g,page=7) {
    local main=g.world21Main,actors=main.savedActors;
    loadSavedMainArea(g);g.areaWidth=ROM_WORLD_2_1_METATILES.len();
    g.world21=main;g.plants=actors.plants;g.checkpointPage=actors.checkpoint;
    delete main.savedActors;delete g.world21Main;
    g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
    // Area initialization reparses enemy slots, even when retaining changed
    // main terrain. A plant frozen at its old raised Y must not greet Mario
    // inside the return pipe.
    g.goombas=[];decodeWorld11Enemies(g,g.world21.descriptor.enemies);
    foreach(plant in g.plants) {
        plant.y=plant.baseY;plant.direction=1;plant.moving=false;plant.timer=0;
        plant.active=false;plant.awake=false;plant.retired=false;plant.slot=-1;
        if("previousY" in plant) delete plant.previousY;
        if("displayY" in plant) delete plant.displayY;
        if("preparedGfxFrame" in plant) delete plant.preparedGfxFrame;
        if("displayGfxFrame" in plant) delete plant.displayGfxFrame;
    }
    g.world21.slotXFractions=[0.0,0.0,0.0,0.0,0.0];
    local checkpoint=g.checkpointPage;initializeWorld21Checkpoint(g,page,0);
    g.checkpointPage=checkpoint;
}

function resetWorld21SpriteShuffle(g) {
    g.world21.oamPhase <- 0;
    g.world21.preparedOamPhase <- 0;
    g.world21.displayOamPhase <- 0;
}

function updateWorld21BonusReload(g) {
    g.areaReloadFrames+=1;local frame=g.areaReloadFrames;
    if(frame==1) {
        resetWorld21SpriteShuffle(g);
        g.cameraX=0;g.displayCameraX=0;
        g.player.nesXForce=0;g.player.nesXMoveForce=0;g.player.nesXScroll=0;
        g.player.nesYMoveForce=0;g.player.nesYDummy=0;
        g.colorRotateOffset=0;g.displayColorPhase=0;g.pendingColorPhase=0;
        g.colorPhasePending=false;g.vramScrollThirtyTwo=0;
        g.vramAreaParserTask=0;g.vramBufferAddrCtrl=0;
    } else if(frame==2) {
        if(g.areaReloadTarget=="underground") loadWorld21Underground(g);
        else if(g.areaReloadTarget=="sky") loadWorld21Sky(g);
        else {
            local page=g.area=="sky"?10:7;
            restoreWorld21Main(g,page);
            g.world21.returnPage <- page;
        }
        g.world21.hudTimeHidden <- true;
        resetWorld21SpriteShuffle(g);
        resetPlayerForArea(g,0,0);g.nesFrameCounter=0;
        parityRecordEvent(g,"music","silence");g.soundEvents.append("silence_music");
    } else if(frame==25) {
        parityRecordEvent(g,"music",g.area=="underground"?"underground":(g.area=="sky"?"cloud":"overworld"));
        g.soundEvents.append("resume_music");
    } else if(frame==26) {
        local returnPage="returnPage" in g.world21?g.world21.returnPage:7;
        resetPlayerForArea(g,g.area=="underground"?24:(g.area=="sky"?56:returnPage*256+56),
            g.area=="underground"?32:240);
        g.player.parityOriginFriction=true;g.player.fallForce=0x28;
        g.areaEntranceFrames=0;
        if(g.area=="sky") {
            g.player.vineClimbing <- true;g.player.vineAuto <- false;
            g.player.vineX <- 64.0;g.player.grounded=false;g.state="skyEntrance";
            emitWorld21VineSound(g);
        } else if("returnPage" in g.world21 && g.world21.returnPage==10) {
            resetPlayerForArea(g,10*256+40,0);g.player.entranceFalling=true;
            g.player.fallForce=0x28;g.player.parityOriginFriction=true;
            g.state="areaEntrance";
        } else g.state=g.area=="underground"?"areaEntrance":"areaExitEntrance";
    }
    if(frame==3 || (frame==21 && g.areaReloadTarget=="underground")) g.vramBufferAddrCtrl=3;
    else if(frame==21) g.vramBufferAddrCtrl=2;
    else if(frame>=9 && frame<=20) g.vramBufferAddrCtrl=6;
}

function beginWorld21Block(g) {
    if(!isWorld21(g)) return;
    local slot="nextBlockSlot" in g.world21?g.world21.nextBlockSlot:0;
    g.bump.slot <- slot;
    g.world21.nextBlockSlot <- slot^1;
}

function growWorld21Vine(g,tx,ty) {
    beginWorld21Block(g);
    retainOldTileForPpu(g,tx,ty,TILE_BRICK_VINE);
    bumpEnemiesAbove(g,tx,ty);
    g.bump.active=true;g.bump.tx=tx;g.bump.ty=ty;g.bump.tile=TILE_BRICK_VINE;
    g.bump.time=0.0;g.bump.frame=0;g.bump.powerupPending=false;
    setTile(g,tx,ty,TILE_USED);
    foreach(item in g.powerups) item.active=false; // Vine setup reuses power-up slot 5.
    g.world21.vines.append({x=tx*16.0,y=ty*16.0,height=0.0,maximum=96});
    emitSound(g,"bump");parityRecordEvent(g,"gameplay","block_hit");
    emitWorld21VineSound(g);
}

function world21SpringControl(g) {
    if(!isWorld21(g)) return 0;
    foreach(spring in g.world21.springs) if(spring.control>0) return spring.control;
    return 0;
}

function world21SpringAnimating(g) {return world21SpringControl(g)>0;}

function world21AnimatedSpringTile(g,tx,ty) {
    if(!isWorld21(g)) return false;
    foreach(spring in g.world21.springs)
        if(spring.control>0 && tx==floor(spring.x/16).tointeger() &&
           (ty==floor(spring.y/16).tointeger() || ty==floor(spring.y/16).tointeger()+1)) return true;
    return false;
}

function updateWorld21Actors(g) {
    foreach(plant in g.plants) if(plant.awake &&
        (!plant.active || plant.x<g.cameraX-73.0)) {
        plant.active=false;plant.slot=-1;plant.retired=true;
    }
    // Shared piranha behavior; this course has no World 1-2 lift objects.
    updateWorld12Actors(g);
    foreach(plant in g.plants) if(plant.active) {
        local stopped=g.player.dead && (!("gfxDeathSlot" in g.world21) ||
            plant.slot>g.world21.gfxDeathSlot);
        plant.displayGfxFrame <- "preparedGfxFrame" in plant?plant.preparedGfxFrame:
            ((((g.nesFrameCounter+255)&8)==0)?1:0);
        plant.preparedGfxFrame <- stopped?0:(((g.nesFrameCounter&8)==0)?1:0);
    }
    foreach(vine in g.world21.vines) {
        vine.displayHeight <- vine.height;
        local maximum="maximum" in vine?vine.maximum:96;
        if(vine.height<maximum && (g.nesFrameCounter&2)!=0) vine.height+=1;
    }
    if(g.state=="playing") attachWorld21Vine(g);
    updateWorld21CloudPlatform(g);
    local p=g.player;
    foreach(spring in g.world21.springs) {
        if(p.dead) continue; // TimerControl freezes spring mechanics during death.
        local started=false;
        if(spring.control==0 && p.grounded && p.nesYSpeed>=0 &&
           abs(p.y+p.height-spring.y)<1.0 &&
           p.x+12>spring.x && p.x<spring.x+16) {
            spring.control=1;spring.timer=3;spring.force=-7;started=true;
            p.jumpForce=0x70;
        }
        if(spring.control==0) continue;
        if(!started && spring.timer>0) spring.timer-=1;
        // The ROM moves Mario two pixels on every animation pass, including
        // the landing pass, before advancing the four-frame phase timer.
        p.y+=spring.control<=2?2.0:-2.0;
        if(spring.control>=2 && g.input.jumpQueued) spring.force=-12;
        if(spring.control==4) {
            spring.control=0;p.nesYSpeed=spring.force;
            p.springReleasePending <- true;
            p.jumpGravityActive=false;p.vy=p.nesYSpeed*NES_FRAME_RATE;
        } else if(spring.timer==0) {spring.control+=1;spring.timer=4;}
    }
}

function parseWorld21PlantColumn(g,task) {
    if(g.area!="main") return;
    // AreaParser tasks 7 and 3 process the next two columns, 22 metatiles
    // ahead of the camera's 32-pixel boundary. Pipe objects allocate from
    // the same five enemy slots as walkers; a full buffer skips the plant.
    if(task==7) g.world21.parserColumn <- floor(g.cameraX/32).tointeger()*2+22;
    if(task!=7 && task!=3) return;
    if(!("parserColumn" in g.world21)) return;
    local column=g.world21.parserColumn+(task==3?1:0);
    foreach(plant in g.plants) if(!plant.awake && !plant.retired &&
        floor((plant.x-8)/16).tointeger()==column) {
        plant.retired=true;
        if(allocateEnemySlot(g,plant)) {
            plant.awake=true;plant.active=true;plant.retired=false;
        }
    }
}

function drawWorld21Actors(g,behind) {
    if(behind) {
        // A bouncing block is OAM over a blank nametable cell. Vine sprites
        // win its sprite priority until the replacement metatile is written.
        if(g.bump.active && g.bump.tile==TILE_BRICK_VINE && g.bump.frame>1) {
            local offsets=[-1,-3,-5,-6,-6,-7,-7,-7,-6,-5,-4,-3,-1,1];
            local offset=offsets[clampValue(g.bump.frame-2,0,offsets.len()-1).tointeger()];
            worldTexture(g,assets.tiles.used,g.bump.tx*16.0,g.bump.ty*16.0+offset,16,16);
        }
        foreach(plant in g.plants) if(plant.active) {
            oamBase=world21OamOffset(g,plant.slot);
            local counter=(g.nesFrameCounter+254)&255;
            local frame="displayGfxFrame" in plant?plant.displayGfxFrame:
                (g.player.dead?0:((counter&8)==0?1:0));
            local y="displayY" in plant?plant.displayY:plant.y;
            screenOamTexture(assets.world21.plants[frame],plant.x-visualCameraX(g),y+1,16,24);
        }
        foreach(vine in g.world21.vines) if(("displayHeight" in vine?vine.displayHeight:vine.height)>=8 && vine.x-visualCameraX(g)>=0)
            for(local i=0;i<12;i+=1) {
                local height="displayHeight" in vine?vine.displayHeight:vine.height;
                local y=vine.y-height+i*8;
                if(y>vine.y || y<0 || y>=239) continue;
                local flipped=(i&1)!=0;
                local texture=i==0?assets.world21.vineTop:
                    (flipped?assets.world21.vineBodyFlipped:assets.world21.vineBody);
                local x=vine.x+(flipped?6:0)-visualCameraX(g);
                if(x>=0 && x<256) screenTexture(texture,x,y+1,8,8);
            }
    } else {
        if(g.area=="sky" && g.world21.cloudPlatform.active) {
            local cloud=g.world21.cloudPlatform;
            screenOamTexture(assets.world21.cloud,cloud.displayX-visualCameraX(g),cloud.y+1,48,8);
        }
        foreach(spring in g.world21.springs) if(spring.control>0) {
        local frames=[0,0,1,2,1];local offsets=[0,0,8,16,8];
        worldTexture(g,assets.world21.springs[frames[spring.control]],spring.x,
            spring.y+offsets[spring.control]+1,16,24);
        }
    }
}

function updateWorld21DeathReload(g) {
    g.deathReloadFrames+=1;
    local frame=g.deathReloadFrames;
    if(frame==1) {
        g.checkpointPage=g.cameraX>=g.world21.descriptor.checkpoint.cameraThreshold?
            g.world21.descriptor.checkpoint.page:0;g.lives-=1;
        parityRecordEvent(g,"music","silence");
        if(g.lives<=0) {
            g.lives=0;g.state="gameOver";
            g.world21.gameOverFrames <- 0;
            return;
        }
        g.world21.masterTimer <- 0;
    } else if(frame==2) {
        g.cameraX=0;g.displayCameraX=0;
        g.player.nesXForce=0;g.player.nesXMoveForce=0;
        g.player.nesYMoveForce=0;g.player.nesYDummy=0;
        g.colorRotateOffset=0;g.displayColorPhase=0;
        g.pendingColorPhase=0;g.colorPhasePending=false;
        g.vramScrollThirtyTwo=0;g.vramAreaParserTask=0;g.vramBufferAddrCtrl=0;
    } else if(frame==3) {
        local page=g.checkpointPage,time=g.time,control=g.gameTimerControl;
        g.player=createPlayer();startWorld21(g);
        g.player.playerAnimTimerSet=0;
        g.checkpointPage=page;g.time=time;g.displayTime=time;g.gameTimerControl=control;
        // InitializeArea restores ScreenLeft from the halfway page before
        // the lives screen finishes, even though rendering stays disabled.
        g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
        g.world21.hudTimeHidden <- true;
        g.soundEvents.clear();g.soundEvents.append("silence_music");
        parityRecordEvent(g,"music","silence");g.state="deathReload";
        g.player.x=0;g.player.previousX=0;g.player.y=16;g.player.previousY=16;
        g.player.movingDir=0;
        g.nesFrameCounter=0;
    }
    // DisplayIntermediate sets ScreenTimer=7 on pass 9. It expires on
    // the next interval-divider edge plus six more 21-frame intervals.
    if(frame==9) g.world21.lifeScreenEnd <- frame+g.intervalTimerControl+1+6*21;
    if(frame==4) g.vramBufferAddrCtrl=3;
    if(!("lifeScreenEnd" in g.world21)) return;
    local end=g.world21.lifeScreenEnd;
    if(frame>end && frame<=end+12) g.vramBufferAddrCtrl=6;
    if(frame==end+13) g.vramBufferAddrCtrl=2;
    if(frame==end+17) {
        parityRecordEvent(g,"music","overworld");g.soundEvents.append("resume_music");
    } else if(frame==end+18) {
        g.player=createPlayer();
        local page=g.checkpointPage;
        initializeWorld21Checkpoint(g,page);
        // InitializeMemory clears PlayerAnimTimerSet; airborne entry does
        // not run GetPlayerAnimSpeed until Mario lands.
        g.player.playerAnimTimerSet=0;
        g.time=401;g.hurryActive=false;g.gameTimerControl=0;g.state="deathEntrance";
    } else if(frame==end+19) {
        g.state="playing";g.stateTimer=0;
        g.respawnPrimeDirection=0;g.respawnPrimeRun=false;
        g.player.parityOriginFriction=true;
        // The entrance override clears the previous A/B latch. Held buttons
        // become a fresh press on the first controllable frame after reload.
        g.input.jumpDown=false;g.input.runDown=false;
    }
}

function updateWorld21GameOver(g) {
    g.world21.gameOverFrames+=1;
    if(g.world21.gameOverFrames==1) emitSound(g,"game_over");
    if(g.world21.gameOverFrames==2) g.vramBufferAddrCtrl=3;
    if(g.world21.gameOverFrames==7) g.world21.gameOverTimer <- 0x12;
    if("gameOverTimer" in g.world21 && g.world21.gameOverTimer==0 &&
        g.world21.gameOverFrames>=7) beginTitleReturn(g);
}

function runWorld21SelfTest() {
    runOamScanlineSelfTest();
    local g=createGame();startLevel(g,2,1);
    requireSelfTest(isWorld21(g) && g.areaWidth==214 && g.flagX==3200 &&
        getTile(g,83,5)==TILE_BRICK_VINE && getTile(g,28,5)==TILE_HIDDEN_ONEUP &&
        getTile(g,82,9)==TILE_QUESTION && g.world21.springs.len()==1,
        "2-1 must use the verified map, rewards and spring");
    local coinTail=createGame();startLevel(coinTail,2,1);
    startJumpingCoin(coinTail,16,9);
    coinTail.coinEffect.phase="score";coinTail.coinEffect.scoreFrame=46;
    updateCoinEffect(coinTail,coinTail.coinEffect,FIXED_DT);
    requireSelfTest(!coinTail.coinEffect.active && coinTail.coinEffect.displayActive &&
        coinTail.coinEffect.scoreFrame==47 && coinEffectDrawY(coinTail.coinEffect)==100,
        "the final coin number must retain its prepared image after releasing the misc slot");
    updateCoinEffect(coinTail,coinTail.coinEffect,FIXED_DT);
    requireSelfTest(!coinTail.coinEffect.displayActive,
        "an inactive coin number must clear its prepared image on the next pass");
    startJumpingCoin(coinTail,16,9);
    coinTail.coinEffect.phase="score";coinTail.coinEffect.scoreFrame=46;
    startJumpingCoin(coinTail,18,9);
    updateEffects(coinTail,FIXED_DT);
    requireSelfTest(coinTail.archivedCoinEffects.len()==1 &&
        !coinTail.archivedCoinEffects[0].active && coinTail.archivedCoinEffects[0].displayActive,
        "an older coin number must retain its last prepared image alongside a newer coin");
    updateEffects(coinTail,FIXED_DT);
    requireSelfTest(coinTail.archivedCoinEffects.len()==0,
        "an archived coin number must retire after its final OAM handoff");
    local descriptor=g.world21.descriptor,links=descriptor.areaLinks;
    requireSelfTest(links.len()==2 && links[0].column==63 &&
        links[0].destination==0x2b && links[0].entrancePage==0 &&
        links[1].column==111 && links[1].destination==0x42 &&
        links[1].streamOffset==23 && descriptor.branchesPlayable,
        "2-1 must retain verified links for both connected bonus branches");
    requireSelfTest(decodeWorld21AreaLinks(ROM_WORLD_2_1_ENEMIES,1).len()==0,
        "area links must only select destinations for their encoded world");
    local selected=decodeWorld21AreaLinks([0x0f,3,0x2e,0x42,0x25,0xff],2);
    requireSelfTest(selected.len()==1 && selected[0].column==50 &&
        selected[0].entrancePage==5,
        "area-link decoding must respect page commands and entrance page bits");
    local fresh=world21LevelDescriptor();fresh.goal.flagColumn=1;
    requireSelfTest(descriptor.goal.flagColumn==200,
        "separate level loads must not share mutable descriptor tables");
    foreach(power in [0,1,2]) {
        local branch=createGame();startLevel(branch,2,1);
        branch.goombas=[];branch.plants=[];branch.score=12300;branch.coins=8;
        branch.time=321;branch.checkpointPage=6;
        branch.player.big=power>0;branch.player.fire=power==2;
        branch.player.height=power>0?32.0:16.0;
        setTile(branch,16,9,TILE_EMPTY);
        branch.player.x=103*16+10.0;branch.player.y=9*16-branch.player.height;
        branch.player.grounded=true;branch.input.down=true;
        requireSelfTest(tryWorld21BonusPipe(branch) && branch.state=="pipeDown",
            "2-1 underground entry must accept a centered grounded Down press");
        branch.input.down=false;
        for(local i=0;i<250 && !(branch.area=="underground" && branch.state=="playing");i+=1)
            simulateFixed(branch,FIXED_DT);
        requireSelfTest(branch.area=="underground" && branch.state=="playing" &&
            branch.levelCoins.len()==19 && branch.player.big==(power>0) &&
            branch.player.fire==(power==2) && branch.time<=321 && branch.score==12300,
            "bonus loading must preserve progress and powers and supply nineteen coins");
        local coin=branch.levelCoins[0];
        branch.player.x=coin.x;branch.player.y=coin.y-(power>0?4:2);
        updateLevelCoins(branch);
        requireSelfTest(!coin.active && branch.coins==9 && branch.score==12500,
            "2-1 bonus coins must use the shared award path exactly once");
        updateLevelCoins(branch);
        requireSelfTest(branch.coins==9,"collected bonus coins must not award twice");
        branch.player.x=180.0;
        branch.player.y=13*16-branch.player.height;branch.player.grounded=true;
        branch.player.facing=1;branch.input.right=true;
        for(local i=0;i<80 && branch.state=="playing";i+=1)
            simulateFixed(branch,FIXED_DT);
        requireSelfTest(branch.state=="pipeSide",
            "walking into the bonus exit must enter the pipe from the collision-stop position");
        branch.input.right=false;
        for(local i=0;i<350 && !(branch.area=="main" && branch.state=="playing");i+=1)
            simulateFixed(branch,FIXED_DT);
        requireSelfTest(branch.area=="main" && branch.state=="playing" &&
            branch.areaWidth==214 && getTile(branch,16,9)==TILE_EMPTY &&
            branch.player.x==7*256+56 && branch.player.big==(power>0) &&
            branch.player.fire==(power==2) && branch.score==12500 && branch.coins==9 &&
            !("world21Main" in branch),
            "bonus exit must restore main terrain and powers at World 2 return page seven");
    }
    local cp=createGame();startLevel(cp,2,1);initializeWorld21Parity(cp);
    initializeWorld21Checkpoint(cp,6,(cp.nesFrameCounter+255)&255);
    local loaded=[];foreach(plant in cp.plants) if(plant.awake) loaded.append(plant);
    requireSelfTest(loaded.len()==2 && loaded[0].slot==0 && loaded[0].x==1656 &&
        loaded[0].y==143 && loaded[0].moving && loaded[0].direction==-1 &&
        loaded[1].slot==1 && loaded[1].x==1848 && loaded[1].y==176 && !loaded[1].moving,
        "checkpoint six must retain the ROM's two parsed plants and pre-control movement");
    requireSelfTest(cp.nesFrameCounter==0x1a && cp.player.movingDir==0,
        "checkpoint initialization must preserve the reference control origin");
    foreach(enemy in cp.goombas) if(enemy.alive) {
        local trigger=enemy.groupIndex>=0?enemy.groupCommandX:enemy.x;
        requireSelfTest(trigger>=1536+255,
            "checkpoint parsing must discard commands behind ScreenRight, not only ScreenLeft");
    }
    local reloadCamera=createGame();startLevel(reloadCamera,2,1);
    reloadCamera.checkpointPage=6;reloadCamera.deathReloadFrames=2;
    updateWorld21DeathReload(reloadCamera);
    requireSelfTest(reloadCamera.cameraX==1536 && reloadCamera.displayCameraX==1536 &&
        reloadCamera.state=="deathReload",
        "InitializeArea must restore checkpoint camera while the lives screen is still loading");
    cp.player.x=1647;cp.player.y=128;cp.player.grounded=true;
    loaded[0].y=120;loaded[0].timer=64;loaded[0].moving=false;
    cp.nesFrameCounter=93;updateWorld12Actors(cp);
    requireSelfTest(!cp.player.dead,"piranha injury must skip odd collision passes");
    cp.nesFrameCounter=94;updateWorld12Actors(cp);
    requireSelfTest(cp.player.dead,"piranha inclusive bounding box must injure on the even pass");
    local returning=createGame();startLevel(returning,2,1);
    local returnPlant=null;foreach(plant in returning.plants) if(plant.x==1848) returnPlant=plant;
    returnPlant.y=returnPlant.baseY-24;returnPlant.awake=true;returnPlant.active=true;
    returnPlant.slot=0;returnPlant.moving=true;returnPlant.direction=-1;
    loadWorld21Underground(returning);restoreWorld21Main(returning);
    requireSelfTest(returnPlant.y==returnPlant.baseY && !returnPlant.moving &&
        returnPlant.active && returnPlant.awake,
        "return area initialization must hide a formerly raised plant in the exit pipe");
    local paused=createGame();startLevel(paused,2,1);initializeWorld21Parity(paused);
    initializeWorld21Checkpoint(paused,6,25);
    paused.player.dead=true;local frozen=paused.plants[2];
    local frozenY=frozen.y,frozenTimer=frozen.timer;
    for(local i=0;i<10;i+=1) updateWorld12Actors(paused);
    requireSelfTest(frozen.y==frozenY && frozen.timer==frozenTimer,
        "death TimerControl must freeze plant movement and its delay timer");
    local hops=0;
    foreach(e in g.goombas) if("greenJump" in e && e.greenJump) hops+=1;
    requireSelfTest(hops==3,"2-1 must retain all three jumping Paratroopas");
    local falling=createGame();startLevel(falling,2,1);
    for(local i=0;i<falling.tiles.len();i+=1) falling.tiles[i]=TILE_EMPTY;
    local walker=makeEnemyAt(384.0,6,"goomba");
    // Golden first-airborne Y bytes from the normal-entry ROM trace.
    foreach(y in [88,88,88,89,90,91,93,94,96,98,101,103]) {
        moveEnemyBody(falling,walker,FIXED_DT);
        requireSelfTest(walker.state=="falling" && walker.y-10==y,
            "a 2-1 Goomba must use ROM falling state and byte-accumulator motion");
    }
    local slots=createGame();startLevel(slots,2,1);slots.goombas=[];
    local plant=slots.plants[0];
    slots.cameraX=plant.x-8-352;
    parseWorld21PlantColumn(slots,7);
    requireSelfTest(plant.awake && plant.active && plant.slot==0,
        "the pipe parser must reserve a shared enemy slot on its column task");
    local probe=makeEnemyAt(100,12,"goomba");
    requireSelfTest(allocateEnemySlot(slots,probe) && probe.slot==1,
        "walkers must not reuse a slot occupied by a piranha");
    local reuse=createGame();startLevel(reuse,2,1);
    reuse.goombas=[];reuse.plants=[];
    reuse.world21.slotXFractions[0]=0.5;
    local inherited=makeEnemyAt(200.0,12,"goomba");
    requireSelfTest(allocateEnemySlot(reuse,inherited) && inherited.x==200.5,
        "reused enemy slots must retain their horizontal movement accumulator");
    startLevel(reuse,2,1);
    requireSelfTest(reuse.world21.slotXFractions[0]==0.0,
        "area initialization must clear enemy slot movement accumulators");
    local blockProbe=createGame();startLevel(blockProbe,2,1);
    beginWorld21Block(blockProbe);
    requireSelfTest(blockProbe.bump.slot==0,"the first bump must allocate block slot zero");
    beginWorld21Block(blockProbe);
    requireSelfTest(blockProbe.bump.slot==1,"successive bumps must alternate block OAM regions");
    local blockAddresses=[0xe8,0x68,0xb0],scoreAddresses=[0x48,0xa0,0xe8];
    for(local phase=0;phase<3;phase+=1) {
        blockProbe.world21.displayOamPhase <- phase;
        requireSelfTest(world21ShuffledOamOffset(blockProbe,0xe8)==blockAddresses[phase] &&
            world21OamOffset(blockProbe,1)==scoreAddresses[phase],
            "block and floatey OAM priority must rotate with the shared shuffle");
    }
    blockProbe.score=100;blockProbe.coins=99;local priorLives=blockProbe.lives;
    awardCoin(blockProbe,true);
    requireSelfTest(blockProbe.queuedScore==300 && blockProbe.queuedCoins==0 &&
        blockProbe.lives==priorLives+1,"block coins must queue updated HUD digits after the hundred-coin rollover");
    retainOldTileForPpu(blockProbe,55,9,TILE_QUESTION);
    requireSelfTest(blockProbe.displayTileOverrides[0].frames==1,
        "World 2-1 question-block replacement must reach the next prepared image");
    local tailStorage=createGame();startLevel(tailStorage,2,1);
    requireSelfTest(getTile(tailStorage,213,13)==TILE_GROUND,
        "the verified castle continuation must include both extra ground columns");
    setTile(tailStorage,212,4,TILE_USED);setTile(tailStorage,0,5,TILE_BRICK);
    requireSelfTest(getTile(tailStorage,212,4)==TILE_USED &&
        getTile(tailStorage,0,5)==TILE_BRICK,
        "extra tail columns must not alias the following storage row");
    local wallJump=createGame();startLevel(wallJump,2,1);
    wallJump.player.nesXSpeed=0;wallJump.player.nesXSpeedAbsolute=40;
    beginNesJump(wallJump.player);
    requireSelfTest(wallJump.player.nesYSpeed==-5 && wallJump.player.jumpForce==0x28,
        "a wall-stopped jump must use the preceding cached running magnitude");
    wallJump.world21.slot5YDummy <- 64;
    requireSelfTest(world21FlagStep(wallJump)==2 && wallJump.world21.slot5YDummy==63,
        "flag motion must inherit the slot-5 fractional carry");
    local starProbe=createGame();startLevel(starProbe,2,1);
    foreach(i,tile in starProbe.tiles) starProbe.tiles[i]=TILE_EMPTY;
    spawnPowerUp(starProbe,69,5,"star");local star=starProbe.powerups[0];
    star.emerging=false;star.visible=true;star.romY=55;star.y=63;
    movePowerUp(starProbe,star,FIXED_DT);
    requireSelfTest(star.romY==55 && star.nesYMoveForce==0x1c,
        "a newly emerged star must consume fractional gravity before changing Y");
    growWorld21Vine(starProbe,83,5);
    requireSelfTest(!star.active,"vine allocation must replace the slot-5 power-up");
    local springProbe=createGame();startLevel(springProbe,2,1);
    local springActor=springProbe.world21.springs[0],sp=springProbe.player;
    sp.x=springActor.x;sp.y=springActor.y-sp.height;sp.grounded=true;
    sp.nesYDummy=64;sp.nesXSpeed=40;
    updateWorld21Actors(springProbe);
    requireSelfTest(sp.y==springActor.y-sp.height+2 && springActor.timer==3,
        "spring landing must move Mario two pixels on the initial pass");
    sp.dead=true;local frozenSpringY=sp.y;updateWorld21Actors(springProbe);
    requireSelfTest(sp.y==frozenSpringY && springActor.timer==3,
        "death must freeze spring compression and its timer");
    sp.dead=false;
    local heldX=sp.x,heldFraction=sp.nesXMoveForce;
    updatePlayer(springProbe,FIXED_DT);
    requireSelfTest(sp.x==heldX && sp.nesXMoveForce==heldFraction && sp.nesXScroll==1,
        "spring freeze must retain position/fraction while returning its phase to scroll");
    for(local tick=0;tick<12;tick+=1) {
        springProbe.input.jumpQueued=springActor.control==2;
        updateWorld21Actors(springProbe);
    }
    requireSelfTest(sp.springReleasePending && sp.nesYSpeed==-12 && sp.nesYDummy==64,
        "late A on a compressed spring must boost launch without clearing the Y dummy");
    local landing=createGame();startLevel(landing,2,1);landing.player.x=835;
    local landed=makeEnemyAt(826,12,"koopa");landed.state="falling";
    moveEnemyBody(landing,landed,FIXED_DT);
    requireSelfTest(landed.state=="walking" && landed.vx>0 && landed.x==826.5,
        "a falling ordinary Koopa must face Mario when it lands");
    local pair=createGame();startLevel(pair,2,1);
    pair.goombas=[];pair.plants=[];pair.nesFrameCounter=151;
    pair.player.x=0;pair.player.y=32;
    local left=makeEnemyAt(100,12,"goomba"),right=makeEnemyAt(110,12,"goomba");
    left.awake=true;left.slot=0;left.vx=NES_FRAME_RATE*0.5;
    right.awake=true;right.slot=1;right.vx=-NES_FRAME_RATE*0.5;
    pair.goombas=[left,right];updateGoombas(pair,FIXED_DT);
    requireSelfTest(left.x==100.5 && right.x==110.5 && left.vx<0 && right.vx>0,
        "a later-slot collision must turn the lower slot after its movement");
    local growth=createGame();startLevel(growth,2,1);
    growth.nesFrameCounter=31;spawnPowerUp(growth,16,9,"mushroom");
    local mushroom=growth.powerups[0];movePowerUp(growth,mushroom,FIXED_DT);
    requireSelfTest(mushroom.emergePixels==0,"growth must wait for global frame phase");
    growth.nesFrameCounter=32;movePowerUp(growth,mushroom,FIXED_DT);
    requireSelfTest(mushroom.emergePixels==1 && mushroom.romY==135,
        "global frame phase must grow a newly spawned power-up immediately");
    mushroom.emerging=false;mushroom.visible=true;mushroom.romY=120;
    mushroom.y=120+POWERUP_DRAW_Y_OFFSET;
    requireSelfTest(bumpPowerUpAbove(growth,mushroom,16,9) && mushroom.nesYSpeed==-3,
        "block bumps must initialize the World 2-1 integer vertical speed");
    foreach(i,tile in growth.tiles) growth.tiles[i]=TILE_EMPTY;
    movePowerUp(growth,mushroom,FIXED_DT);
    local bumpedY=mushroom.romY;movePowerUp(growth,mushroom,FIXED_DT);
    requireSelfTest(mushroom.romY<bumpedY && (mushroom.motionRaw&2)!=0,
        "a bumped mushroom must rise and retain its stunned-state bit");
    local parser=createGame();startLevel(parser,2,1);
    parser.goombas=[];parser.plants=[];
    parser.player.x=0;parser.player.y=32;
    local active=makeEnemyAt(100,12,"goomba");
    active.awake=true;active.slot=0;parser.goombas.append(active);
    appendEnemyGroup(parser,16,0x37);
    parser.vramAreaParserTask=7;
    updateGoombas(parser,FIXED_DT);
    requireSelfTest(!parser.goombas[1].awake && active.x<100,
        "parser task 7 must pause admission while active actors keep moving");
    parser.vramAreaParserTask=6;
    updateGoombas(parser,FIXED_DT);
    requireSelfTest(parser.goombas[1].awake && parser.goombas[2].awake,
        "enemy groups must resume admission after parser task 7");
    foreach(occupiedCount in [4,5]) {
        startLevel(slots,2,1);slots.goombas=[];slots.plants=[];
        slots.player.x=0;slots.player.y=32;slots.nesFrameCounter=0;
        for(local i=0;i<occupiedCount;i+=1) {
            local enemy=makeEnemyAt(100+i*24,12,"goomba");
            enemy.awake=true;enemy.slot=i;slots.goombas.append(enemy);
        }
        appendEnemyGroup(slots,16,0x38);
        updateGoombas(slots,FIXED_DT);
        local leader=slots.goombas[occupiedCount];
        requireSelfTest(leader.awake==(occupiedCount==4),
            "a group command must wait if all five slots are occupied");
        if(occupiedCount==4) {
            requireSelfTest(!slots.goombas[5].alive && !slots.goombas[6].alive,
                "a partially spawned group must discard members that exceed capacity");
            slots.goombas[0].alive=false;updateGoombas(slots,FIXED_DT);
            requireSelfTest(!slots.goombas[5].awake && !slots.goombas[6].awake,
                "discarded group members must never appear after another slot frees");
        } else {
            slots.goombas[0].alive=false;updateGoombas(slots,FIXED_DT);
            requireSelfTest(leader.awake && !slots.goombas[6].alive,
                "an unconsumed full-buffer group must retry when a slot becomes available");
        }
    }
    startLevel(slots,2,1);slots.goombas=[];
    plant=slots.plants[0];slots.cameraX=plant.x-8-352;
    for(local i=0;i<5;i+=1) {
        local enemy=makeEnemyAt(100+i*24,12,"goomba");
        enemy.awake=true;enemy.slot=i;slots.goombas.append(enemy);
    }
    parseWorld21PlantColumn(slots,7);
    requireSelfTest(!plant.active && plant.retired,
        "a full buffer must skip a pipe's plant rather than defer it");
    slots.goombas=[];parseWorld21PlantColumn(slots,7);
    requireSelfTest(!plant.active,"a skipped plant must not spawn on a repeated parser task");
    startLevel(slots,2,1);slots.goombas=[];slots.plants=[];
    slots.cameraX=100;slots.player.x=112;slots.player.y=32;
    for(local i=0;i<5;i+=1) {
        local enemy=makeEnemyAt(i==0?27.25:180+i*24,12,"goomba");
        enemy.awake=true;enemy.slot=i;slots.goombas.append(enemy);
    }
    appendEnemyGroup(slots,16,0x38);
    updateGoombas(slots,FIXED_DT);
    requireSelfTest(!slots.goombas[0].alive && !slots.goombas[5].awake,
        "an erased slot must not be parsed again during the same enemy pass");
    updateGoombas(slots,FIXED_DT);
    requireSelfTest(slots.goombas[5].awake && slots.goombas[5].slot==0,
        "the erased slot must become available on the following enemy pass");
    hitBlock(g,83,5);
    requireSelfTest(g.world21.vines.len()==1 && g.powerups.len()==0,
        "a vine brick must not be substituted with a mushroom");
    local spring=g.world21.springs[0];
    g.player.x=spring.x;g.player.y=spring.y-g.player.height;g.player.grounded=true;
    for(local i=0;i<16;i+=1) updateWorld21Actors(g);
    requireSelfTest(g.player.springReleasePending && g.player.nesYSpeed<0,"spring must launch Mario upwards");
    g.score=12300;g.coins=19;g.lives=3;g.cameraX=1600;
    g.player.big=true;g.player.fire=true;finishPlayerDeath(g);
    for(local i=0;i<166;i+=1) simulateFixed(g,FIXED_DT);
    requireSelfTest(isWorld21(g) && g.checkpointPage==6 && g.lives==2 &&
        !g.player.big && !g.player.fire && g.score==12300 && g.coins==19,
        "2-1 death must retain world/progress and reset powers at its checkpoint");
    g.state="levelComplete";g.input.resetQueued=true;simulateFixed(g,FIXED_DT);
    requireSelfTest(isWorld21(g) && g.state=="playing" && g.player.x==40 &&
        g.score==12300 && g.coins==19 && g.lives==2,
        "2-1 course completion must restart in World 2 rather than load World 1-2");
    foreach(phase in [0,1,3,12,19,20]) foreach(page in [0,6]) {
        local reload=createGame();startLevel(reload,2,1);
        reload.cameraX=page*256;reload.score=45600;reload.coins=27;
        reload.player.big=true;reload.player.fire=true;
        finishPlayerDeath(reload);reload.intervalTimerControl=phase;
        local waited=-1,end=-1;
        for(local frame=1;frame<=195;frame+=1) {
            simulateFixed(reload,FIXED_DT);
            if(frame==9) {
                end=reload.world21.lifeScreenEnd;
                requireSelfTest(end==9+reload.intervalTimerControl+1+6*21,
                    "life-screen wait must use the interval divider phase");
            }
            if(reload.state=="playing") {waited=frame;break;}
        }
        requireSelfTest(waited==end+19 && reload.lives==2 &&
            reload.cameraX==page*256 && reload.player.x==page*256+40 &&
            !reload.player.big && !reload.player.fire && reload.score==45600 &&
            reload.coins==27 && reload.time==400 && reload.player.parityOriginFriction,
            "World 2 death reload must retain checkpoint/stats, clear powers and restore entry controls");
    }
    local depth=createGame();startLevel(depth,2,1);
    depth.player.dead=true;depth.player.deadFrames=179;
    depth.player.deathFreezeFrames=0;depth.player.y=800;
    updatePlayer(depth,FIXED_DT);
    requireSelfTest(depth.state=="playing","depth alone must not end death before its music finishes");
    updatePlayer(depth,FIXED_DT);
    requireSelfTest(depth.state=="deathReload","music completion plus depth must enter life loss");
    startLevel(depth,2,1);depth.player.dead=true;depth.player.deadFrames=400;
    depth.player.deathFreezeFrames=0;depth.player.y=32;
    updatePlayer(depth,FIXED_DT);
    requireSelfTest(depth.state=="playing","music completion alone must not skip the death fall");
    local over=createGame();startLevel(over,2,1);over.lives=1;
    over.score=12300;over.coins=17;
    over.player.dead=true;finishPlayerDeath(over);
    over.world21.masterTimer <- 47;over.intervalTimerControl=16;over.soundEvents.clear();
    simulateFixed(over,FIXED_DT);
    requireSelfTest(over.state=="gameOver" && over.lives==0 && over.player.dead &&
        over.world21.gameOverFrames==0 && over.soundEvents.len()==0,
        "last-life loss must enter Game Over before its setup/music pass");
    simulateFixed(over,FIXED_DT);
    requireSelfTest(over.soundEvents.len()==1 && over.soundEvents[0]=="game_over",
        "Game Over setup must queue its music exactly once");
    over.soundEvents.clear();
    for(local frame=2;frame<=419;frame+=1) simulateFixed(over,FIXED_DT);
    requireSelfTest(over.world21.gameOverTimer==0 && over.state=="titleLoad" &&
        over.highScore==12300 && over.soundEvents.len()==1 && over.soundEvents[0]=="silence_music",
        "Game Over expiry must silence music and begin title return, preserving the top score");
    over.soundEvents.clear();
    for(local frame=0;frame<30;frame+=1) {
        simulateFixed(over,FIXED_DT);
        requireSelfTest(over.soundEvents.len()==(frame<2?0:1),
            "title initialization must queue one additional silence on its third pass");
    }
    requireSelfTest(over.state=="titleScreen" && over.world==1 && over.level==1,
        "the title loader must complete and await a new-game input");
    over.input.startQueued=true;
    simulateFixed(over,FIXED_DT);
    for(local frame=0;frame<195 && over.state!="playing";frame+=1) simulateFixed(over,FIXED_DT);
    requireSelfTest(over.world==1 && over.level==1 && over.state=="playing" && over.lives==3 &&
        over.score==0 && over.coins==0 && !over.player.dead && !over.player.big &&
        over.highScore==12300 && over.checkpointPage==0,
        "Enter on the title must start a clean three-life World 1-1 game and retain only the top score");
    runWorld21SkySelfTest();
    print("World 2-1 main-route self-test passed.\n");
}
