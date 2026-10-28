// Simulation-only regression entry. Texture handles are placeholders; image
// and device-audio checks are separate tests against real packaged builds.
eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");
loadTexture=function(path) {return path;};
loadAssets();loadWorld13Assets();loadWorld14Assets();
PARITY_MOVIE_ENABLED=false;
local suites=[
    ["simulation",runSimulationSelfTest], ["world12",runWorld12SelfTest],
    ["world13",runWorld13SelfTest], ["world14",runWorld14SelfTest],
    ["stage-flow",runWorld1StageFlowSelfTest], ["koopa-bounce",runKoopaBounceSelfTest],
    ["powerup-gap",runPowerUpGapSelfTest], ["shell-defeat",runShellDefeatSelfTest]
];
foreach(suite in suites) {
    suite[1].call(getroottable());print("REGRESSION_PASS "+suite[0]+"\n");
}
foreach(stage in [1,2,3,4]) {
    local g=createGame();startWorld1Stage(g,stage);
    if(stage==2) startWorld12(g,"underground");
    g.score=12300;g.coins=19;g.lives=3;
    g.player.big=true;g.player.fire=true;g.player.height=32.0;
    finishPlayerDeath(g);
    for(local frame=0;frame<166;frame+=1) simulateFixed(g,FIXED_DT);
    requireSelfTest(g.level==stage && g.lives==2 && !g.player.dead &&
        !g.player.big && !g.player.fire && g.score==12300 && g.coins==19,
        "all World 1 stages must reset powers and retain progress on the next life");
}
foreach(stage in [1,2,3]) foreach(power in [0,1,2]) {
    local g=createGame();startWorld1Stage(g,stage);
    g.player.big=power>0;g.player.fire=power==2;
    g.player.height=power>0?32.0:16.0;
    g.score=12300;g.coins=19;g.lives=3;g.state="levelComplete";
    for(local frame=0;frame<167;frame+=1) simulateFixed(g,FIXED_DT);
    print("FLOW stage="+stage+" power="+power+" state="+g.state+" level="+g.level+"\n");
    requireSelfTest(g.level==stage+1 && !g.player.dead &&
        g.player.big==(power>0) && g.player.fire==(power==2) &&
        g.score==12300 && g.coins==19 && g.lives==3,
        "World 1 transitions must retain progress and powers for every form");
}
foreach(state in ["world14Axe","world14VictoryWalk","world14Rescue","world14EndWorld","worldComplete"]) {
    local g=createGame();startWorld14(g);g.state=state;
    g.score=12300;g.coins=19;g.lives=2;
    g.input.resetQueued=true;simulateFixed(g,FIXED_DT);
    requireSelfTest(g.state=="playing" && g.level==4 && !g.player.dead &&
        g.player.x==40.0 && !g.player.big && g.score==12300 &&
        g.coins==19 && g.lives==2,
        "R must restart during every castle ending state");
}
print("REGRESSION_PASS world1-release-flow\n");
print("WORLD1_REGRESSION_OK\n");
eve_init=function() {};eve_update=function(dt) {};eve_render=function() {};eve_quit=function() {};
