// Diagnostic-only dispatch adapter for the pre-integration baseline.
// No player coordinates, collision immunity, or actors are changed by this adapter.
dofile("scripts/world23.nut");
if(TILE_STRIDE<244) TILE_STRIDE=244;
local registered=false;
foreach(d in LEVEL_DATA) if(d.world==2 && d.stage==3) registered=true;
if(!registered) LEVEL_DATA.append({world=2,stage=3,load=function(g) {startWorld23(g);}});
local originalWorld13Update=updateWorld13Actors;
updateWorld13Actors=function(g) {
    if(isWorld23(g)) updateWorld23Actors(g);else originalWorld13Update(g);
};
local originalStageDeath=updateWorld1StageDeath;
updateWorld1StageDeath=function(g) {
    if(isWorld23(g)) updateWorld23DeathReload(g);else originalStageDeath(g);
};

function initializeWorld23Diagnostic(g) {
    startLevel(g,2,3);
    parityInitialize(g);
}
