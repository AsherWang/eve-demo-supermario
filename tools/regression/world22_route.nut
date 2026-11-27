// Input-only whole-course diagnostic. No fixture state is installed after startLevel.
function runWorld22WholeRoute(masks) {
    local g=createGame();startLevel(g,2,2);parityInitialize(g);
    requireSelfTest(g.state=="world12Intro" && g.stage=="intro" && g.player.x==40 &&
        g.player.y==192 && g.time==400,"route begins at normal surface entrance");
    local previous="",pages={},holes={},squid=false,fish=false,water=false,exit=false,flag=false;
    local waterFrames=0,firstWater=-1,sidePipe=-1,firstExit=-1,flagFrame=-1,complete=-1;
    for(local f=0;f<masks.len();f+=1) {
        g.parity.frame=f;g.parity.inputMask=masks[f];
        parityApplyMask(g,masks[f]);if(f>0) simulateFixed(g,FIXED_DT);
        g.input.jumpQueued=false;g.input.fireQueued=false;g.input.resetQueued=false;
        local p=g.player;
        requireSelfTest(!p.dead && g.lives==3 && p.invulnerable==0 && p.starTimer==0 &&
            !p.big && !p.fire && g.world==2 && g.level==2,
            "route must remain small, alive, unprotected, and in 2-2: frame="+f);
        if(isWorld22Water(g) && g.state=="playing") {
            water=true;waterFrames+=1;if(firstWater<0) firstWater=f;
            pages[floor(p.x/256).tointeger()] <- true;
            foreach(i,hole in g.world22.whirlpools)
                if(p.swimWhirlpool && p.x>=hole.left && p.x<=hole.left+hole.length) holes[i] <- true;
            foreach(e in g.world22.enemies) if(e!=null) {
                if(e.kind=="blooper") squid=true;else fish=true;
            }
        }
        if(water && g.area=="water" && g.state=="world12Pipe" && sidePipe<0) {
            sidePipe=f;
            requireSelfTest(p.x>=3000 && p.y>=112 && p.y+p.height<=144,
                "side pipe must be reached through the real mouth");
        }
        if(g.stage=="exit" && g.state=="playing") {exit=true;if(firstExit<0) firstExit=f;}
        if(g.state=="flagSlide") {flag=true;if(flagFrame<0) flagFrame=f;}
        if(g.state=="levelComplete") {complete=f;requireSelfTest(f==masks.len()-1,"movie ends at settlement boundary");}
        local key=g.stage+":"+g.state;
        if(key!=previous) {
            print("ROUTE_EVENT {\"frame\":"+f+",\"stage\":\""+g.stage+"\",\"state\":\""+g.state+"\"}\n");
            previous=key;
        }
        print("ROUTE_STATE "+parityStateJson(g,f)+"\n");
    }
    for(local page=0;page<12;page+=1) requireSelfTest(page in pages,"water page visited="+page);
    requireSelfTest(water && exit && flag && complete>=0 && firstWater<sidePipe &&
        sidePipe<firstExit && firstExit<flagFrame && flagFrame<complete &&
        holes.len()==3 && squid && fish && waterFrames>1800 && g.coins>0 && g.time==0,
        "complete course, all whirlpools, active enemies, coins, flag and settlement required");
    print("WORLD22_ROUTE_OK {\"frames\":"+masks.len()+",\"entrance_frame\":0,\"water_frame\":"+firstWater+
        ",\"side_pipe_frame\":"+sidePipe+",\"surface_exit_frame\":"+firstExit+",\"flag_frame\":"+flagFrame+
        ",\"settlement_frame\":"+complete+",\"coins\":"+g.coins+",\"score\":"+g.score+
        ",\"lives\":"+g.lives+",\"water_pages\":"+pages.len()+",\"whirlpools\":"+holes.len()+"}\n");
}
