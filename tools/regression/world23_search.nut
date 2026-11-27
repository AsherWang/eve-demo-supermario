// Search controller inputs only. Every trial begins at the normal entrance;
// no actor, player, damage, terrain, or timer state is patched during a trial.
eve_init <- function() {};eve_update <- function(dt) {};eve_render <- function() {};eve_quit <- function() {};
dofile("main.nut");loadTexture=function(path) {return path;};loadAssets();PARITY_MOVIE_ENABLED=false;
dofile("tools/regression/world23_hooks.nut");loadWorld23Assets();
local best=0.0;
for(local trial=0;trial<600;trial+=1) {
    local g=createGame();initializeWorld23Diagnostic(g);
    local random=trial+1,hold=0,wait=trial%31,masks=[],lastJump=-100;
    for(local f=0;f<3600;f+=1) {
        random=(random*1103515245+12345)&0x7fffffff;
        local mask=130,p=g.player;
        if(f<=wait) mask=0;
        else if(g.state=="playing") {
            if(p.grounded && f-lastJump>8) {
                local ahead=12+(trial%7)*5;
                local foot=floor((p.y+p.height+2)/16).tointeger();
                local tx=floor((p.x+ahead)/16).tointeger();
                local hazard=!isSolidAt(g,tx,foot) || isSolidAt(g,tx,foot-1);
                foreach(e in g.world23.enemies) if(e!=null && !e.dead &&
                    e.x>p.x-20 && e.x<p.x+60 && e.y>p.y-55 && e.y<p.y+40) hazard=true;
                if(hazard || (random%100)<(trial%9)) {hold=12+(trial%22);lastJump=f;}
            }
            if(hold>0) {mask=mask|1;hold-=1;}
        } else mask=0;
        masks.append(mask);parityApplyMask(g,mask);simulateFixed(g,FIXED_DT);
        g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
        if(g.player.x>best) best=g.player.x;
        if(g.player.dead || g.lives!=3) break;
        if(g.state=="levelComplete") {
            print("WORLD23_SEARCH_SUCCESS trial="+trial+" frames="+masks.len()+" fish="+g.world23.spawned+"\n");
            print("MASKS [");foreach(i,m in masks) {if(i) print(",");print(m);}print("]\n");
            return;
        }
    }
    if(trial%50==0) print("SEARCH trial="+trial+" best="+best+"\n");
}
throw "No successful route; best="+best;
