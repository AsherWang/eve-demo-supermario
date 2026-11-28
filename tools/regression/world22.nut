// Local movement and segmented flow coverage; not whole-level acceptance.
eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");
loadTexture=function(path) {return path;};loadAssets();loadWorld22Assets();
PARITY_MOVIE_ENABLED=false;
dofile("tests/fixtures/world22_motion.nut");
dofile("tests/fixtures/world22_enemies.nut");
requireSelfTest(ROM_WORLD_2_2_INTRO_AREA.len()==ROM_WORLD_1_2_INTRO.len(),"shared intro data length");
foreach(i,value in ROM_WORLD_2_2_INTRO_AREA)
    requireSelfTest(value==ROM_WORLD_1_2_INTRO[i],"2-2 intro must match reused surface data");
requireSelfTest(ROM_WORLD_2_2_EXIT_AREA.len()==ROM_WORLD_1_1_AREA_DATA.len(),"shared exit data length");
foreach(i,value in ROM_WORLD_2_2_EXIT_AREA)
    requireSelfTest(value==ROM_WORLD_1_1_AREA_DATA[i],"2-2 exit must match reused ground data");
local count=0;
foreach(caseIndex,rows in WORLD22_MOTION_CASES) {
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
        for(local slot=0;slot<5;slot+=1) {
            local expected=WORLD22_ENEMY_CASES[caseIndex][f][slot],e=g.world22.enemies[slot];
            if(expected==null || e==null) {
                if(expected!=null || e!=null) throw "enemy slot mismatch frame="+f+" slot="+slot;
                continue;
            }
            local actualEnemy=e.kind=="blooper"?
                [7,e.x,e.y,e.speed,e.force,e.phase,e.timer,e.direction]:
                [e.id,e.x,e.y,e.xForce,e.fishDummy,e.fishDirection,e.originY];
            for(local field=0;field<actualEnemy.len();field+=1)
                if(actualEnemy[field]!=expected[field]) throw "water enemy mismatch frame="+f+
                    " slot="+slot+" field="+field;
        }
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
foreach(power in [0,1,2]) {
    local g=createGame();startWorld22Water(g);
    g.world22.spawns=[{x=300,y=100,hard=false}];updateWorld22Enemies(g);
    local e=g.world22.enemies[0];requireSelfTest(e!=null,"contact fixture enemy must spawn");
    g.cameraX=100;g.player.x=300;g.player.y=110;g.player.nesYSpeed=2;
    g.player.big=power==1;g.player.starTimer=power==2?1.0:0.0;
    g.nesFrameCounter=1;updateWorld22Enemies(g);
    if(power==0) requireSelfTest(g.player.dead && !e.dead,"descending water contact hurts, never stomps");
    if(power==1) requireSelfTest(!g.player.big && !g.player.dead && g.player.invulnerable>0,"big swimmer takes damage");
    if(power==2) requireSelfTest(e.dead && !g.player.dead && g.score==200,"star defeats a water enemy");
}
// Exercise the real transition dispatcher, not just isolated area builders.
foreach(power in [0,1,2]) {
    local g=createGame();startLevel(g,2,1);
    g.score=12300;g.coins=27;g.player.big=power>0;g.player.fire=power==2;
    g.player.height=power>0?32.0:16.0;g.state="levelComplete";
    simulateFixed(g,FIXED_DT);
    requireSelfTest(isWorld22(g) && g.stage=="intro" && g.state=="world12Intro",
        "2-1 completion must load the real 2-2 surface entrance");
    for(local f=0;f<400 && g.state!="playing";f+=1) simulateFixed(g,FIXED_DT);
    requireSelfTest(isWorld22Water(g) && g.state=="playing" && g.time==400 &&
        g.player.big==(power>0) && g.player.fire==(power==2) && g.score==12300 && g.coins==27,
        "surface pipe must enter water with progress and powers intact");
    g.time=237;g.displayTime=237;g.cameraX=2800;g.displayCameraX=2800;
    g.player.x=3000;g.player.y=power>0?112:128;g.player.nesYSpeed=0;g.player.nesYMoveForce=0;g.player.grounded=false;g.input.right=true;
    g.world22.enemies=array(5,null);g.world22.spawnCursor=g.world22.spawns.len();
    for(local f=0;f<90 && g.state=="playing";f+=1) simulateFixed(g,FIXED_DT);
    requireSelfTest(g.state=="world12Pipe" && g.world12Target=="exit",
        "swimming right into the mouth must start exit without grounded state");
    local remaining=g.time;
    for(local f=0;f<350 && g.state!="playing";f+=1) simulateFixed(g,FIXED_DT);
    requireSelfTest(isWorld22(g) && g.stage=="exit" && g.area=="main" && g.state=="playing" &&
        g.cameraX==2816 && g.time==remaining-1 && g.player.big==(power>0) &&
        g.player.fire==(power==2) && !g.romBackgroundCollision,
        "water exit must emerge on shared ground page 11 with the source entrance timer tick and preserved powers");
    requireSelfTest(g.flagX>g.player.x && g.flagX<g.areaWidth*16,"exit has a reachable flag");
    g.input.right=true;g.input.run=true;
    for(local f=0;f<1800 && g.state!="levelComplete";f+=1) {
        g.input.jumpDown=f%40<20;g.input.jumpQueued=f%40==0;
        simulateFixed(g,FIXED_DT);
    }
    requireSelfTest(g.state=="levelComplete" && isWorld22(g) && !g.player.dead,
        "surface exit must support jumping to the flag and completing castle settlement");
    local hasNext=false,settledScore=g.score,settledCoins=g.coins;
    foreach(definition in LEVEL_DATA)
        if(definition.world==2 && definition.stage==3) hasNext=true;
    simulateFixed(g,FIXED_DT);
    for(local f=0;hasNext && isWorld22(g) && f<400;f+=1) simulateFixed(g,FIXED_DT);
    if(hasNext) requireSelfTest(g.world==2 && g.level==3 && !g.player.dead &&
        g.score==settledScore && g.coins==settledCoins && g.lives==3 &&
        g.player.big==(power>0) && g.player.fire==(power==2),
        "registered 2-3 must load after settlement with progress and powers intact");
    else requireSelfTest(g.state=="levelComplete" && isWorld22(g),
        "unregistered 2-3 must remain at its settlement boundary");
    // A separate surface-exit fixture keeps this death test in 2-2 even after
    // the campaign dispatcher supports the next registered stage.
    local exitDeath=createGame();startLevel(exitDeath,2,2);buildWorld12(exitDeath,"exit");
    exitDeath.cameraX=2816;exitDeath.player.big=power>0;exitDeath.player.fire=power==2;
    finishPlayerDeath(exitDeath);
    for(local f=0;f<166;f+=1) updateDeathReload(exitDeath);
    requireSelfTest(isWorld22Water(exitDeath) && exitDeath.checkpointPage==5 && !exitDeath.player.big &&
        !exitDeath.player.fire && exitDeath.lives==2,"death on the surface exit returns to water checkpoint");
}
local blocked=createGame();startWorld22Water(blocked);blocked.input.right=true;
foreach(y in [80,100,145,180]) {
    blocked.player.x=3012;blocked.player.y=y;
    requireSelfTest(!tryWorld22Exit(blocked),"rock above/below the mouth must not trigger exit");
}
local over=createGame();startWorld22Water(over);over.lives=1;
finishPlayerDeath(over);updateDeathReload(over);
requireSelfTest(over.state=="gameOver" && over.lives==0 && !over.player.dead &&
    over.soundEvents.find("game_over")!=null,"last water life must enter game over with sound");
over.input.resetQueued=true;simulateFixed(over,FIXED_DT);over.input.resetQueued=false;
requireSelfTest(isWorld22Water(over) && over.state=="playing" && over.lives==3 &&
    over.score==0 && !over.player.big,"game over reset starts a fresh water life");
local restart=createGame();startLevel(restart,2,2);restart.input.resetQueued=true;
simulateFixed(restart,FIXED_DT);restart.input.resetQueued=false;
requireSelfTest(isWorld22(restart) && restart.state=="world12Intro" && restart.player.x==40,
    "reset during introduction remains in World 2-2");
dofile("tools/regression/world22_interactions.nut");
print("WORLD22_REGRESSION_OK frames="+count+"\n");
