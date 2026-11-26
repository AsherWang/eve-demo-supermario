// Diagnostic coverage only; campaign entry, enemies and exit are not complete.
eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");
loadTexture=function(path) {return path;};loadAssets();loadWorld22Assets();
PARITY_MOVIE_ENABLED=false;
dofile("tests/fixtures/world22_motion.nut");
local count=0;
foreach(rows in WORLD22_MOTION_CASES) {
    local g=createGame();initializeWorld22SwimProbe(g);parityInitialize(g);
    for(local f=0;f<rows.len();f+=1) {
        local r=rows[f];parityApplyMask(g,r[0]);
        if(f>0) simulateFixed(g,FIXED_DT);
        g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
        local p=g.player;
        local actual=[p.x,p.y-(p.big?0:16),p.nesXSpeed,p.nesYSpeed,
            p.nesXForce,p.nesXMoveForce,p.nesYMoveForce,p.nesYDummy,p.grounded?1:0,
            p.facing>0?1:2,p.movingDir,g.cameraX];
        for(local field=0;field<actual.len();field+=1)
            if(actual[field]!=r[field+1]) throw "water motion mismatch frame="+f+" field="+field+
                " expected="+r[field+1]+" actual="+actual[field];
        count+=1;
    }
}
foreach(camera in [1279.0,1280.0,2200.0]) {
    local g=createGame();startWorld22Water(g);g.cameraX=camera;
    g.score=12300;g.coins=27;g.player.big=true;g.player.fire=true;
    finishPlayerDeath(g);
    for(local f=0;f<166;f+=1) updateDeathReload(g);
    local page=camera>=1280?5:0;
    requireSelfTest(g.world==2 && g.level==2 && g.area=="water" &&
        g.player.x==page*256+40 && g.player.y==(page>0?192:48) &&
        g.cameraX==page*256 && g.lives==2 &&
        !g.player.big && !g.player.fire && g.score==12300 && g.coins==27,
        "water death must retain progress, restore small Mario and choose its own checkpoint");
}
local first=createGame(),second=createGame();startWorld22Water(first);startWorld22Water(second);
requireSelfTest(!isSolidAt(first,0,5) && isSolidAt(first,0,13),
    "water scenery is not solid; rocks are solid");
requireSelfTest(first.levelCoins.len()>0,"water coin objects must be collectible");
first.levelCoins[0].active=false;
requireSelfTest(second.levelCoins[0].active,"water instances must not share coin state");
local holes=world22WhirlpoolData();
requireSelfTest(holes.len()==3 && holes[0].left==1040 && holes[0].length==96 &&
    holes[1].left==2080 && holes[1].length==160 && holes[2].left==2496 && holes[2].length==128,
    "water hole commands must yield the original whirlpool ranges");
print("WORLD22_REGRESSION_OK frames="+count+"\n");
