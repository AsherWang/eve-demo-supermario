// Stage entry definitions. Loaders own their existing area builders; mutable
// tiles/entities stay in the game state, never in this shared registry.
LEVEL_DATA <- [
    {world=1, stage=1, load=function(g) {
        resetPlayerForArea(g,40,176);
        g.soundEvents.append("resume_music");
    }},
    {world=1, stage=2, load=function(g) {startWorld12(g);}},
    {world=1, stage=3, load=function(g) {startWorld13(g);}},
    {world=1, stage=4, load=function(g) {startWorld14(g);}},
    {world=2, stage=1, load=function(g) {startWorld21(g);}}
];

function getLevelData(world, stage) {
    foreach(definition in LEVEL_DATA)
        if(definition.world==world && definition.stage==stage) return definition;
    throw "Unsupported world/stage";
}
