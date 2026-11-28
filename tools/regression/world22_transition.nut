// Independent recorded entrance diagnostic; fixture never enters runtime.
eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();loadWorld22Assets();PARITY_MOVIE_ENABLED=false;
dofile("tests/fixtures/world22_entrance.nut");
local g=createGame();initializeWorld22Parity(g);
for(local f=0;f<WORLD22_ENTRANCE.len();f+=1) {
 if(f>0) requireSelfTest(updateWorld22Transition(g),"entrance handler consumes each task");
 local p=g.player,row=[p.x,p.y-(p.big?0:16),p.nesXSpeed,p.nesXForce,p.nesXMoveForce,p.nesYSpeed,p.nesYMoveForce,p.nesYDummy,p.grounded,g.nesFrameCounter,g.time];
 foreach(k,value in row) requireSelfTest(value==WORLD22_ENTRANCE[f][k],"entrance frame="+f+" field="+k+" actual="+value+" expected="+WORLD22_ENTRANCE[f][k]);
}
requireSelfTest(g.state=="playing" && g.area=="water","complete automatic entrance reaches controllable water");
print("WORLD22_ENTRANCE_OK frames="+WORLD22_ENTRANCE.len()+"\n");
