// World 2-1 main route and underground bonus prototype; sky entry remains pending.
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
        branchesPlayable=false};
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

function loadWorld21Assets() {
    if(assets==null) loadAssets();
    if("world21" in assets) return;
    local metatiles={};
    foreach(column in ROM_WORLD_2_1_METATILES) foreach(meta in column)
        if(meta!=0 && !(meta in metatiles))
            metatiles[meta] <- loadTexture("assets/world13/metatile-"+meta+".png");
    assets.world21 <- {metatiles=metatiles,
        wingsRight=[loadTexture("assets/world21/paratroopa-0.png"),loadTexture("assets/world21/paratroopa-1.png")],
        wingsLeft=[loadTexture("assets/world21/paratroopa-0-left.png"),loadTexture("assets/world21/paratroopa-1-left.png")],
        plants=[loadTexture("assets/world21/plant-0.png"),loadTexture("assets/world21/plant-1.png")],
        springs=[loadTexture("assets/world21/spring-0.png"),loadTexture("assets/world21/spring-1.png"),loadTexture("assets/world21/spring-2.png")],
        vineTop=loadTexture("assets/world21/vine-top.png"),vineBody=loadTexture("assets/world21/vine-body.png")};
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
    foreach(pair in [[0x51,TILE_BRICK],[0x52,TILE_BRICK],[0x54,TILE_GROUND],
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
        p.facing>0 && p.x+p.width>=13*16-1;
    if(!entering && !leaving) return false;
    g.transitionTimer=0;g.areaTransitionFrames=0;
    g.areaReloadTarget=entering?"underground":"main";
    g.state=entering?"pipeDown":"pipeSide";
    p.nesXForce=0;emitSound(g,"pipe");return true;
}

function loadWorld21Underground(g) {
    saveMainArea(g);
    g.world21.savedActors <- {plants=g.plants,checkpoint=g.checkpointPage};
    // Snapshot mutable objects without sharing the new branch's actor arrays.
    g.world21Main <- g.world21;
    clearAreaObjects(g);g.plants=[];g.platforms=[];
    g.area="underground";g.areaWidth=16;g.sidePipeX=13;
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

function restoreWorld21Main(g) {
    local main=g.world21Main,actors=main.savedActors;
    loadSavedMainArea(g);g.areaWidth=ROM_WORLD_2_1_METATILES.len();
    g.world21=main;g.plants=actors.plants;g.checkpointPage=actors.checkpoint;
    delete main.savedActors;delete g.world21Main;
    g.cameraX=7*256.0;g.displayCameraX=g.cameraX;
    foreach(e in g.goombas) if(e.x<g.cameraX-64) {e.alive=false;e.slot=-1;}
}

function updateWorld21BonusReload(g) {
    g.areaReloadFrames+=1;local frame=g.areaReloadFrames;
    if(frame==1) {
        g.player.nesXForce=0;g.player.nesXMoveForce=0;g.player.nesXScroll=0;
        g.player.nesYMoveForce=0;g.player.nesYDummy=0;
        g.colorRotateOffset=0;g.displayColorPhase=0;g.pendingColorPhase=0;
        g.colorPhasePending=false;g.vramScrollThirtyTwo=0;
        g.vramAreaParserTask=0;g.vramBufferAddrCtrl=0;
    } else if(frame==2) {
        if(g.areaReloadTarget=="underground") loadWorld21Underground(g);
        else restoreWorld21Main(g);
        resetPlayerForArea(g,0,0);g.nesFrameCounter=0;
        parityRecordEvent(g,"music","silence");
    } else if(frame==25) {
        parityRecordEvent(g,"music",g.area=="underground"?"underground":"overworld");
        g.soundEvents.append("resume_music");
    } else if(frame==26) {
        resetPlayerForArea(g,g.area=="underground"?24:7*256+56,
            g.area=="underground"?32:240);
        g.player.parityOriginFriction=true;g.player.fallForce=0x28;
        g.areaEntranceFrames=0;
        g.state=g.area=="underground"?"areaEntrance":"areaExitEntrance";
    }
    if(frame==3 || (frame==21 && g.areaReloadTarget=="underground")) g.vramBufferAddrCtrl=3;
    else if(frame==21) g.vramBufferAddrCtrl=2;
    else if(frame>=9 && frame<=20) g.vramBufferAddrCtrl=6;
}

function growWorld21Vine(g,tx,ty) {
    retainOldTileForPpu(g,tx,ty,TILE_BRICK_VINE);
    setTile(g,tx,ty,TILE_USED);
    g.world21.vines.append({x=tx*16.0,y=ty*16.0,height=0.0});
    emitSound(g,"powerup","reveal");
    parityRecordEvent(g,"gameplay","vine_revealed");
}

function updateWorld21Actors(g) {
    foreach(plant in g.plants) if(plant.awake &&
        (!plant.active || plant.x<g.cameraX-73.0)) {
        plant.active=false;plant.slot=-1;plant.retired=true;
    }
    // Shared piranha behavior; this course has no World 1-2 lift objects.
    updateWorld12Actors(g);
    foreach(vine in g.world21.vines) if(vine.height<96.0) vine.height+=0.5;
    local p=g.player;
    foreach(spring in g.world21.springs) {
        if(spring.control==0) {
            if(p.grounded && abs(p.y+p.height-spring.y)<1.0 &&
                p.x+12>spring.x && p.x<spring.x+16) {
                spring.control=1;spring.timer=3;spring.force=-7;
            }
        } else {
            if(spring.control>=2 && g.input.jumpQueued) spring.force=-12;
            spring.timer-=1;
            if(spring.timer<=0) {spring.control+=1;spring.timer=4;}
            if(spring.control>=5) {
                spring.control=0;p.grounded=false;p.nesYSpeed=spring.force;
                p.nesYMoveForce=0;p.nesYDummy=0;p.jumpGravityActive=false;p.fallForce=0x70;
                p.vy=p.nesYSpeed*NES_FRAME_RATE;emitSound(g,"jump");
            } else {
                local offsets=[0,0,8,16,8];
                p.y=spring.y-p.height+offsets[spring.control];
                p.grounded=true;p.nesYSpeed=0;p.vy=0.0;
            }
        }
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
        foreach(plant in g.plants) if(plant.active)
            worldTexture(g,assets.world21.plants[(g.nesFrameCounter/8)%2],plant.x,plant.y+1,16,24);
        foreach(vine in g.world21.vines)
            for(local y=0;y<vine.height;y+=8)
                worldTexture(g,y==0?assets.world21.vineTop:assets.world21.vineBody,
                    vine.x,vine.y-vine.height+y,14,8);
    } else foreach(spring in g.world21.springs) if(spring.control>0) {
        local frames=[0,0,1,2,1];local offsets=[0,0,8,16,8];
        worldTexture(g,assets.world21.springs[frames[spring.control]],spring.x,
            spring.y+offsets[spring.control]+1,16,24);
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
        g.checkpointPage=page;g.time=time;g.displayTime=time;g.gameTimerControl=control;
        g.soundEvents.clear();g.state="deathReload";
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
        resetPlayerForArea(g,page*256+40,176);
        g.player.movingDir=0;
        g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
        foreach(enemy in g.goombas) if(enemy.x<g.cameraX) enemy.alive=false;
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
    local g=createGame();startLevel(g,2,1);
    requireSelfTest(isWorld21(g) && g.areaWidth==212 && g.flagX==3200 &&
        getTile(g,83,5)==TILE_BRICK_VINE && getTile(g,28,5)==TILE_HIDDEN_ONEUP &&
        getTile(g,82,9)==TILE_QUESTION && g.world21.springs.len()==1,
        "2-1 must use the verified map, rewards and spring");
    local descriptor=g.world21.descriptor,links=descriptor.areaLinks;
    requireSelfTest(links.len()==2 && links[0].column==63 &&
        links[0].destination==0x2b && links[0].entrancePage==0 &&
        links[1].column==111 && links[1].destination==0x42 &&
        links[1].streamOffset==23 && !descriptor.branchesPlayable,
        "2-1 must retain verified links without claiming playable branches");
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
        branch.player.x=13*16-branch.player.width;
        branch.player.y=13*16-branch.player.height;branch.player.grounded=true;
        branch.player.facing=1;branch.input.right=true;
        requireSelfTest(tryWorld21BonusPipe(branch) && branch.state=="pipeSide",
            "bonus exit must enter the right-facing side pipe");
        branch.input.right=false;
        for(local i=0;i<350 && !(branch.area=="main" && branch.state=="playing");i+=1)
            simulateFixed(branch,FIXED_DT);
        requireSelfTest(branch.area=="main" && branch.state=="playing" &&
            branch.areaWidth==212 && getTile(branch,16,9)==TILE_EMPTY &&
            branch.player.x==7*256+56 && branch.player.big==(power>0) &&
            branch.player.fire==(power==2) && branch.score==12500 && branch.coins==9 &&
            !("world21Main" in branch),
            "bonus exit must restore main terrain and powers at World 2 return page seven");
    }
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
    requireSelfTest(!g.player.grounded && g.player.nesYSpeed<0,"spring must launch Mario upwards");
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
    for(local frame=0;frame<30;frame+=1) simulateFixed(over,FIXED_DT);
    requireSelfTest(over.state=="titleScreen" && over.world==1 && over.level==1,
        "the title loader must complete and await a new-game input");
    over.input.startQueued=true;
    simulateFixed(over,FIXED_DT);
    for(local frame=0;frame<195 && over.state!="playing";frame+=1) simulateFixed(over,FIXED_DT);
    requireSelfTest(over.world==1 && over.level==1 && over.state=="playing" && over.lives==3 &&
        over.score==0 && over.coins==0 && !over.player.dead && !over.player.big &&
        over.highScore==12300 && over.checkpointPage==0,
        "Enter on the title must start a clean three-life World 1-1 game and retain only the top score");
    print("World 2-1 main-route self-test passed.\n");
}
