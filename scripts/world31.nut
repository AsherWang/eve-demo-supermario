// Authentic World 3-1 entrance dependency for the World 2-4 ending.
// Full World 3-1 enemies/bonus branches remain outside whole-level acceptance.
dofile("scripts/generated/world31_data.nut");
dofile("scripts/generated/world31_map.nut");
function isWorld31(g) {return g.world==3 && g.level==1;}
function world31LevelDescriptor() {
    return {world=3,level=1,stage="world31",metatiles=ROM_WORLD_3_1_METATILES,
        blocks=ROM_WORLD_3_1_BLOCKS,enemies=ROM_WORLD_3_1_ENEMIES,
        entry={x=40,y=176},goal={flagColumn=200,castleColumn=204},time=400};
}
function loadWorld31Assets() {
    if("world31" in assets) return;
    local metatiles={};
    foreach(column in ROM_WORLD_3_1_METATILES) foreach(meta in column)
        if(meta!=0 && !(meta in metatiles)) metatiles[meta] <- loadTexture("assets/world31/metatile-"+meta+".png");
    assets.world31 <- {metatiles=metatiles};
}
function startWorld31(g) {
    loadWorld31Assets();
    if("world31Main" in g) delete g.world31Main;
    local descriptor=world31LevelDescriptor();
    g.world=descriptor.world;g.level=descriptor.level;g.stage=descriptor.stage;g.area="main";
    g.areaWidth=descriptor.metatiles.len();g.romBackgroundCollision=true;
    clearAreaObjects(g);g.plants=[];g.platforms=[];g.enterablePipes=[];
    g.sidePipeX=-1;g.cameraX=0.0;g.displayCameraX=0.0;
    local state={descriptor=descriptor,baseTiles=[],vines=[],springs=[],
        slotXFractions=[0.0,0.0,0.0,0.0,0.0]};
    if("world31" in g) g.world31=state; else g.world31 <- state;
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
        local meta=ROM_WORLD_3_1_METATILES[x][row],block=ROM_WORLD_3_1_BLOCKS[x][row];
        local tile=meta in mapping?mapping[meta]:(block!=0?TILE_SOLID:TILE_EMPTY);
        setTile(g,x,row+2,tile);
        if(meta==0x10 || meta==0x12)
            g.plants.append({x=x*16.0+8.0,y=(row+2)*16.0,baseY=(row+2)*16.0,
                direction=1,moving=false,timer=0,active=false,awake=false,
                retired=false,slot=-1,enemyCollisionMask=0});
        if(meta==0x67) state.springs.append({x=x*16.0,y=(row+2)*16.0,control=0,timer=0,force=-7,
            awake=false,active=false,retired=false,slot=-1,enemyCollisionMask=0});
    }
    state.baseTiles=clone g.tiles;
    decodeWorld11Enemies(g,descriptor.enemies);
    g.flagX=descriptor.goal.flagColumn*16.0;g.castleX=descriptor.goal.castleColumn*16.0;g.flagY=48.0;
    g.preparedFlagY=48.0;g.displayFlagY=48.0;g.castleFlagVisible=false;
    g.preparedCastleFlagY=144.0;g.displayCastleFlagY=144.0;
    resetPlayerForArea(g,descriptor.entry.x,descriptor.entry.y);g.player.grounded=true;g.player.entranceFalling=false;
    g.state="playing";g.stateTimer=0.0;g.checkpointPage=0;
    g.time=descriptor.time;g.displayTime=descriptor.time;g.gameTimerControl=23;g.hurryActive=false;
    g.soundEvents.append("resume_music");
}

function world31TileTexture(g,tx,ty,tile) {
    if(ty<2 || ty>=15 || tx<0 || tx>=g.areaWidth) return null;
    local meta=ROM_WORLD_3_1_METATILES[tx][ty-2];
    if(meta==0 || meta==0x24 || meta==0x25 || meta==0x5f || meta==0x60) return null;
    if(tile!=g.world31.baseTiles[tileIndex(tx,ty)]) return tileTexture(g,tile);
    if(meta==0xc0 || meta==0xc1) return assets.tiles.questions[g.displayColorPhase];
    return meta in assets.world31.metatiles?assets.world31.metatiles[meta]:null;
}

function beginWorld31Load(g) {
    local scene=clone g;
    scene.player=clone g.player;scene.world24=clone g.world24;
    g.loadingScene <- scene;
    g.loadingWorldTransition <- true;
    g.loadingWaited <- false;
    g.loadingRenderWorld <- g.world;
    g.loadingRenderLevel <- g.level;
    g.loadingRenderCameraX <- g.cameraX;
    g.loadingPlayerBig <- g.player.big;
    g.loadingPlayerFire <- g.player.fire;
    g.loadingRemainingTime <- g.time;
    g.world=3;g.level=1;g.state="nextStageLoad";g.stageLoadFrames=0;
}
