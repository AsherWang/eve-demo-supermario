eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");
foreach(area,track in {water="water",main="overworld",underground="underground",castle="castle_theme",sky="star"}) {
    local g={area=area,hurryActive=false};
    if(areaMusicName(g)!=track) throw "normal area track: "+area;
    if(areaMusicName(g,true)!="star") throw "star override: "+area;
    g.hurryActive=true;
    if(areaMusicName(g)!=(track=="castle_theme"?"castle_fast":track+"_fast")) throw "hurry track: "+area;
    if(areaMusicName(g,true)!="star_fast") throw "hurry star: "+area;
}
print("WORLD2_AUDIO_SELECTION_OK\n");

