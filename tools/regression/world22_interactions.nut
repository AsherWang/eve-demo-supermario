// Isolated interaction fixtures, explicitly separate from the unmodified route.
foreach(id in [7,10,11]) {
    local g=createGame();startWorld22Water(g);g.cameraX=100;
    g.world22.spawns=[{x=400,y=116,hard=false}];updateWorld22Enemies(g);
    local e=g.world22.enemies[0];requireSelfTest(e!=null,"fireball target spawn");
    e.id=id;e.kind=id==7?"blooper":"cheep";e.x=215;e.y=116;
    g.player.x=200;g.player.y=112;g.player.big=true;g.player.fire=true;g.player.height=32;
    g.input.fireQueued=true;updatePlayer(g,FIXED_DT);g.input.fireQueued=false;
    requireSelfTest(g.fireballs.len()==1,"water player handler consumes real fire input");
    updateFireballs(g,FIXED_DT);
    g.nesFrameCounter=0;updateWorld22FireballHits(g);
    requireSelfTest(!e.dead && g.score==0,"fireball contact skips odd processing frames");
    g.nesFrameCounter=1;updateWorld22FireballHits(g);
    requireSelfTest(e.dead && e.y==114 && e.nesYSpeed==-1 && g.score==200 &&
        g.fireballs[0].exploding && g.soundEvents.find("kick")!=null,
        "swimming enemy is defeated by ordinary moving fireball with water launch speed");
    updateWorld22FireballHits(g);
    requireSelfTest(g.score==200,"exploding fireball cannot award duplicate score");
    g.player.x=e.x;g.player.y=e.y+10;g.player.big=false;g.player.fire=false;g.player.height=16;
    updateWorld22Enemies(g);
    requireSelfTest(!g.player.dead,"defeated water enemy is harmless on contact");
    g.world22.spawns=[];g.world22.frenzy=false;
    for(local f=0;f<250 && g.world22.enemies[0]!=null;f+=1) updateWorld22Enemies(g);
    requireSelfTest(g.world22.enemies[0]==null,"dead water enemy leaves the slot after sinking");
}
local b=createGame();startWorld22Water(b);local rng=clone b.world22.random;
// InitializeArea clears RAM; this fixture starts with retired slots to test emission.
foreach(slot in b.world22.bubbles) {requireSelfTest(slot.y==0,"area clears bubble Y");slot.y=248;}
updateWorld22Bubbles(b);
requireSelfTest(b.world22.bubbles[2].x==49 && b.world22.bubbles[2].y==39 &&
    b.world22.bubbles[0].y==248 && b.world22.bubbles[1].y==248 && b.world22.bubbleTimer==64,
    "bubble originates at Mario's mouth; shared timer permits only one new slot");
for(local i=0;i<7;i+=1) requireSelfTest(rng[i]==b.world22.random[i],"bubbles do not consume RNG");
for(local f=0;f<65;f+=1) updateWorld22Bubbles(b);
requireSelfTest(b.world22.bubbles[2].y>=32,"bubbles retire above status bar");
b.player.transformFrames=4;local frozen=b.world22.bubbleTimer;
updateWorld22Enemies(b);
requireSelfTest(b.world22.bubbleTimer==frozen,"bubble movement freezes during transformation");
startWorld22Water(b);
requireSelfTest(b.world22.bubbles[2].y==0 && b.world22.bubbleTimer==0,"area entry resets bubble slots");
print("WORLD22_INTERACTIONS_OK\n");
