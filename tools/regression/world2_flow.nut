eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();
loadWorld13Assets();loadWorld14Assets();loadWorld21Assets();loadWorld22Assets();loadWorld23Assets();loadWorld24Assets();
PARITY_MOVIE_ENABLED=false;
foreach(stage in [1,2,3]) foreach(power in [0,1,2]) {
    local g=createGame();startLevel(g,2,stage);g.score=19200;g.coins=36;g.lives=2;
    g.player.big=power>0;g.player.fire=power==2;g.player.height=power>0?32.0:16.0;
    g.state="levelComplete";simulateFixed(g,FIXED_DT);
    requireSelfTest(g.world==2 && g.level==stage+1 && g.score==19200 && g.coins==36 &&
        g.lives==2 && g.player.big==(power>0) && g.player.fire==(power==2),
        "World 2 cross-stage flow preserves progress and powers");
    if(stage==3) {
        requireSelfTest(g.state=="nextStageLoad","bridge completion must show the real castle loading sequence");
        for(local frame=0;frame<166;frame+=1) simulateFixed(g,FIXED_DT);
        requireSelfTest(isWorld24(g) && g.state=="playing" && g.time==300 &&
            g.player.big==(power>0) && g.player.fire==(power==2) &&
            g.score==19200 && g.coins==36 && g.lives==2,
            "castle loading must preserve all three power states and progress until control resumes");
    }
}
foreach(stage in [3,4]) foreach(camera in [1791.0,1792.0,2500.0]) {
    local g=createGame();startLevel(g,2,stage);g.cameraX=camera;
    g.player.big=true;g.player.fire=true;g.player.height=32;g.score=7300;g.coins=12;
    finishPlayerDeath(g);
    for(local f=0;f<166;f+=1) updateDeathReload(g);
    local page=stage==3 && camera>=1792?7:0;
    requireSelfTest(g.world==2 && g.level==stage && g.checkpointPage==page &&
        !g.player.big && !g.player.fire && g.lives==2 && g.score==7300 && g.coins==12,
        "World 2 bridge/castle deaths dispatch to their own checkpoint rules");
}
foreach(power in [0,1,2]) {
    local castle=createGame();startLevel(castle,2,4);
    castle.player.big=power>0;castle.player.fire=power==2;
    castle.player.height=power>0?32:16;
    castle.score=12345;castle.coins=17;castle.lives=2;
    castle.state="world24EndWorld";castle.world24.worldEndTimer=0;
    simulateFixed(castle,FIXED_DT);
    requireSelfTest(castle.world==3 && castle.level==1 && castle.state=="nextStageLoad",
        "castle completion must start the actual next-world loading sequence");
    for(local f=0;f<167;f+=1) simulateFixed(castle,FIXED_DT);
    requireSelfTest(isWorld31(castle) && castle.state=="playing" && castle.time==400 &&
        castle.player.big==(power>0) && castle.player.fire==(power==2) &&
        castle.score==12345 && castle.coins==17 && castle.lives==2,
        "next-world entry preserves progress and all three power states");
}
print("WORLD2_FLOW_OK\n");
