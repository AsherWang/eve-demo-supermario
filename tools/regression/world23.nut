// Isolated mechanics tests deliberately set up contacts. They are NOT route evidence.
eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();PARITY_MOVIE_ENABLED=false;
dofile("tools/regression/world23_hooks.nut");loadWorld23Assets();
dofile("tests/fixtures/world23_fish_motion.nut");
foreach(i,r in WORLD23_FISH_SPAWNS) {
    local t=createGame();startWorld23(t);t.player.x=r[1];t.player.nesXSpeed=r[2]>=128?r[2]-256:r[2];
    t.world23.random=clone r[3];t.world23.yDummies[r[0]]=r[4];spawnWorld23Fish(t,r[0]);
    local e=t.world23.enemies[r[0]],expected=r[5];
    requireSelfTest(e.x==expected[0] && e.y==expected[1] && (e.speed&255)==expected[2] &&
        (e.nesYSpeed&255)==expected[4] && e.nesYMoveForce==expected[5] && e.nesYDummy==expected[6] &&
        e.direction==r[6] && t.world23.timer==r[7],"ROM fish spawn register tuple "+i);
}
foreach(i,pair in WORLD23_FISH_MOTION) {
    local r=pair[0],expected=pair[1];
    local e={y=r[1],nesYSpeed=r[4]>=128?r[4]-256:r[4],nesYMoveForce=r[5],nesYDummy=r[6],dead=false};
    stepWorld23Fish(e);
    local speed=r[2]>=128?r[2]-256:r[2],sum=r[3]+(speed<<4);
    requireSelfTest(r[0]+(sum>>8)==expected[0] && (sum&255)==expected[3],
        "ROM fish horizontal register pair "+i);
    requireSelfTest(e.y==expected[1] && (e.nesYSpeed&255)==expected[4] &&
        e.nesYMoveForce==expected[5] && e.nesYDummy==expected[6],
        "ROM fish vertical register pair "+i);
}
local g=createGame();initializeWorld23Diagnostic(g);
requireSelfTest(g.world==2 && g.level==3 && g.stage=="world23" && g.flagX==3600,
    "2-3 must retain its own level identity and goal");
local commands=world23FrenzyCommands();
requireSelfTest(commands.len()==3 && commands[0].column==26 && commands[0].enabled &&
    commands[1].column==137 && commands[2].column==197 && !commands[2].enabled,
    "ROM frenzy start/restart/end must be decoded without treating hard-mode enemies as normal actors");
foreach(camera in [0,1791,1792,3200]) {
    local t=createGame();startWorld23(t);t.cameraX=camera;t.score=12300;t.coins=17;
    t.player.big=true;t.player.fire=true;finishPlayerDeath(t);
    for(local f=0;f<200 && t.state!="playing";f+=1) updateWorld23DeathReload(t);
    local page=camera>=1792?7:0;
    requireSelfTest(isWorld23(t) && t.player.x==page*256+40 && t.cameraX==page*256 &&
        t.lives==2 && t.score==12300 && t.coins==17 && !t.player.big && !t.player.fire,
        "death reload must retain progress and choose World 2-3 page 7");
}
local a=createGame(),b=createGame();startWorld23(a);startWorld23(b);
requireSelfTest(consumeWorld23EnemyCommand(a,3,321) && a.world23.enemies[3]==null &&
    a.world23.enemyCursor==4,"hard-only command must consume one parser pass without spawning");
a.world23.random=[206,75,215,64,238,111,179];
requireSelfTest(!consumeWorld23EnemyCommand(a,4,321),"next future command must defer to frenzy");
spawnWorld23Fish(a,4);
requireSelfTest(a.world23.timer==72 && a.world23.enemies[4]==null,
    "failed fourth-slot fish initialization still sets the exact frenzy delay");
a.world23.enemyCursor=16;a.world23.enemyPage=8;a.world23.enemyPageSelected=false;
requireSelfTest(consumeWorld23EnemyCommand(a,3,2016) && a.world23.enemies[3].id==10 &&
    a.world23.enemies[3].x==2304 && a.world23.enemies[3].y==248,
    "page-bit row-f pair must preserve its original below-screen green fish actor");
foreach(slot in [0,1,2]) spawnWorld23Fish(a,slot);
a.cameraX=2193;a.world23.timer=1;a.world23.frenzy=true;
a.world23.random=[83,209,119,213,57,144,227];
// One shift produces the ROM frame-1010 bytes [169,232,187,106,28,200,241].
updateWorld23Actors(a);
requireSelfTest(a.world23.enemyCursor==20 && a.world23.timer==96,
    "stream terminator must permit slot-5 failed initialization to reset the timer");
spawnWorld23Fish(a,0);
requireSelfTest(b.world23.enemies[0]==null && b.world23.random[0]==165,
    "level instances must own their mutable enemy and random state");
local e=a.world23.enemies[0],minY=e.y;
for(local f=0;f<230;f+=1) {stepWorld23Fish(e);if(e.y<minY) minY=e.y;}
requireSelfTest(minY<100 && e.y>255,"flying fish must rise from below and fall out naturally");
foreach(power in [0,1,2]) {
    local t=createGame();startWorld23(t);spawnWorld23Fish(t,0);
    local fish=t.world23.enemies[0];fish.x=t.player.x;fish.y=t.player.y-10;
    t.player.big=power==1;t.player.starTimer=power==2?1.0:0.0;t.nesFrameCounter=2;
    updateWorld23Actors(t);
    if(power==0) requireSelfTest(t.player.dead,"small Mario side contact must be lethal");
    if(power==1) requireSelfTest(!t.player.big && t.player.invulnerable>0,"big Mario must shrink");
    if(power==2) requireSelfTest(fish.dead && !t.player.dead,"star must defeat fish");
}
local stompGame=createGame();startWorld23(stompGame);spawnWorld23Fish(stompGame,0);
local stompFish=stompGame.world23.enemies[0];stompFish.y=120;stompFish.nesYDummy=91;
defeatWorld23Fish(stompGame,stompFish,true);
requireSelfTest(stompGame.player.nesYSpeed==-3 && stompFish.speed==0 && stompFish.nesYSpeed==0 &&
    stompFish.nesYMoveForce==0 && stompFish.nesYDummy==91 && stompFish.y==118 && stompGame.score==0,
    "special fish stomp must preserve dummy, shift Y, use fd bounce, and defer points");
for(local f=0;f<5;f+=1) updateFloatingScores(stompGame);
requireSelfTest(stompGame.score==200,"fish points must use the shared delayed score display");
local fireGame=createGame();startWorld23(fireGame);spawnWorld23Fish(fireGame,0);
local target=fireGame.world23.enemies[0];target.x=300;target.y=120;
local shot={x=303,y=134,active=true,exploding=false,explosionFrames=0,vx=4.0,vy=0.0};
fireGame.fireballs.append(shot);updateWorld23Actors(fireGame);
requireSelfTest(target.dead && shot.exploding && shot.explosionFrames==6,
    "fish fireball contact must retain the shared six-frame explosion");
print("WORLD23_REGRESSION_OK\n");
