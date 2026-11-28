// Source-driven World 2-2 automatic entrance and area-loading tasks.
// Called by the shared transition dispatcher; no movie/frame-index conditions.
function world22EntranceControl(g, pipe) {
    local p=g.player;
    local direction=1;
    if(pipe) {p.nesXSpeed=(p.x.tointeger()&15)?8:0;direction=p.nesXSpeed?1:0;}
    if(direction) {
        local force=p.movingDir==1?0x98:0x130;
        p.movingDir=1;p.facing=1;
        applyNesXAcceleration(p,1,force);
        if(p.nesXSpeed>12) p.nesXSpeed=12;
    }
    p.nesXSpeedAbsolute=abs(p.nesXSpeed);
    p.nesXScroll=nesHorizontalDelta(p);p.x+=p.nesXScroll;p.vx=p.nesXSpeed*3.75;
    local t=g.world22Transition;
    if(t.target=="water" && p.x>=g.sidePipeX*16-13 && (p.x.tointeger()&15)!=0) {
        if(!t.behindPipe) {emitSound(g,"pipe");t.behindPipe=true;}
        t.areaTimer=g.cameraX>=256?0x34:0xa0;
    }
    if(pipe) {
        t.areaTimer-=1;
        if(t.areaTimer==0) {if(t.target=="water") parityRecordEvent(g,"music","silence");t.phase="header";t.screenDisabled=true;t.operTask=0;g.state="world22Load";}
    }
}

function initializeWorld22Transition(g) {
    g.world22Transition <- {phase="intro",hudTimeReady=false,behindPipe=false,areaTimer=0,screenTask=12,
        columns=0,operTask=3,engineTask=7,screenDisabled=false,target="water",playerYHigh=1,
        random=[165,0,0,0,0,0,0]};
    g.player.movingDir=0;g.player.parityOriginFriction=false;
    g.time=401;g.displayTime=401;g.gameTimerControl=0;
    // SetupEntrance follows the 24 initialization tasks before auto-control.
    g.nesFrameCounter=24;
}

function updateWorld22Transition(g) {
    if(!("world22Transition" in g)) return false;
    // Shared background collision may initiate the side pipe before the
    // stage post-collision helper; adopt that real transition on the next pass.
    if(g.state=="world12Pipe" && g.world22Transition.phase=="done" && g.world12Target=="exit")
        beginWorld22ExitTasks(g);
    local t=g.world22Transition,p=g.player;
    // The final rising-pipe pass still prepares behind-background OAM,
    // even though it enables player control for the following pass.
    t.risePass <- t.phase=="rise";
    local initializeFrame=t.phase=="initialize";
    local bubblePass=t.phase=="drop";
    local pipeActorPass=t.phase=="exitPipe";
    local gameplayPass=["intro","exitPipe","setup","rise","drop"].find(t.phase)!=null;
    if(g.state!="world12Intro" && g.state!="world22Load" && g.state!="world22Entrance" &&
        !(g.state=="world12Pipe" && t.phase!="done")) return false;
    if(g.colorPhasePending && g.vramBufferAddrCtrl!=6) {
        g.displayColorPhase=g.pendingColorPhase;g.colorPhasePending=false;
    }
    g.vramBufferAddrCtrl=0;
    if(g.input.resetQueued) {resetRound(g);return true;}
    if(t.phase!="initialize") {
        g.intervalTimerControl-=1;if(g.intervalTimerControl<0) g.intervalTimerControl=20;
        world22AdvanceRandom(t.random);
    }
    p.previousX=p.x;p.previousY=p.y;
    if(t.phase=="intro" || t.phase=="exitPipe") {
        world22EntranceControl(g,t.behindPipe || t.phase=="exitPipe");
    } else if(t.phase=="header") {
        // LoadAreaPointer/GetAreaDataAddresses precedes InitializeArea.
        t.phase="initialize";t.screenTask=0;g.cameraX=0;g.displayCameraX=0;
        g.vramScrollThirtyTwo=0;g.vramAreaParserTask=0;g.colorRotateOffset=0;
        g.colorPhasePending=false;g.pendingColorPhase=0;
        p.nesXForce=0;p.nesXMoveForce=0;p.nesYDummy=0;t.behindPipe=false;
    } else if(t.phase=="initialize") {
        parityRecordEvent(g,"music","silence");
        local remaining=g.time,random=t.random;
        if(t.target=="water") startWorld22Water(g,0,false);
        else {
            buildWorld12(g,"exit");g.romBackgroundCollision=false;g.cameraX=2816;g.displayCameraX=2816;
            // GroundArea6 pipe objects create Piranhas in worlds after World 1.
            for(local x=176;x<g.areaWidth;x+=1) for(local y=2;y<13;y+=1)
                if(getTile(g,x,y)==TILE_PIPE_TOP_LEFT) g.plants.append({x=x*16.0+8,y=y*16.0,baseY=y*16.0,
                    direction=1,moving=false,timer=0,active=true});
        }
        g.soundEvents.clear(); // Music begins at SecondaryGameSetup, after the blank loader.
        p=g.player;
        g.world22Transition=t;t.random=random;g.world22.random=random;
        g.time=remaining;g.displayTime=remaining;g.gameTimerControl=0;
        p.x=0;p.y=p.big?0:16;t.playerYHigh=0;p.facing=0;p.grounded=true;p.movingDir=0;
        p.nesYSpeed=0;p.nesYMoveForce=0;p.nesYDummy=0;p.swimGravity=0;
        g.nesFrameCounter=0;g.colorRotateOffset=0;g.displayColorPhase=0;t.hudTimeReady=false;t.operTask=1;t.engineTask=0;
        t.phase="screen";t.screenTask=0;t.columns=11;g.state="world22Load";
    } else if(t.phase=="screen") {
        if(t.screenTask==0) g.vramBufferAddrCtrl=3;
        else if(t.screenTask==8) g.vramBufferAddrCtrl=6;
        else if(t.screenTask==9) g.vramBufferAddrCtrl=t.target=="water"?1:2;
        switch(t.screenTask) {
        case 4:t.screenTask=6;break; // Skip intermediate lives display for pipe areas.
        case 6:t.screenTask=8;break;
        case 8:t.columns-=1;if(t.columns<0) t.screenTask=9;break;
        case 12:t.operTask=2;t.phase="secondary";break;
        default:t.screenTask+=1;break;
        }
    } else if(t.phase=="secondary") {
        t.operTask=3;t.screenDisabled=false;t.phase="setup";
        parityRecordEvent(g,"music",t.target=="water"?"water":"overworld");g.soundEvents.append("resume_music");
    } else if(t.phase=="setup") {
        resetPlayerForArea(g,t.target=="water"?40:11*256+56,t.target=="water"?0:240);
        t.playerYHigh=1;p=g.player;p.grounded=true;p.movingDir=0;p.preparedVisible <- false;
        p.swimTimer <- 0;p.swimPreviousA <- false;p.swimGravity <- 0;p.swimWhirlpool <- false;
        p.fallForce=40;t.engineTask=7;t.phase=t.target=="water"?"drop":"rise";g.state="world22Entrance";
        if(t.target=="water") {
            local bubble=g.world22.bubbles[0];
            bubble.x=p.x+9;bubble.y=248;
            bubble.force=(256-ROM_WORLD_2_2_BUBBLE_ENTRANCE[0])&255;
            g.world22.bubbleTimer=ROM_WORLD_2_2_BUBBLE_ENTRANCE[1];
            updateWorld22Bubbles(g,false);
        }
    } else if(t.phase=="rise") {
        p.y-=1;
        if(p.y-(p.big?0:16)<145) {t.phase="done";t.engineTask=8;g.state="playing";g.gameTimerControl=24;g.time-=1;}
    } else if(t.phase=="drop") {
        local y=p.y-(p.big?0:16);
        if(y>=48) {
            t.phase="done";t.engineTask=8;g.state="playing";
            g.gameTimerControl=24;g.time-=1;
        } else if(p.grounded) p.grounded=false;
        else {
            p.swimGravity=y<20?24:40;
            p.y+=world22VerticalDelta(p,p.swimGravity,4);
            p.vy=p.nesYSpeed*NES_FRAME_RATE;
        }
    }
    if(bubblePass) updateWorld22Bubbles(g);
    if(pipeActorPass) updateWorld22Enemies(g,false);
    if(gameplayPass && ((g.nesFrameCounter+1)&7)==0) {
        g.pendingColorPhase=g.colorRotateOffset;g.colorPhasePending=true;
        g.colorRotateOffset=(g.colorRotateOffset+1)%6;
    }
    if(!initializeFrame) g.nesFrameCounter=(g.nesFrameCounter+1)&255;
    return true;
}

function initializeWorld22Parity(g) {
    startLevel(g,2,2);
    // Reference origin is first completed automatic entrance-control pass.
    // Only origin registers are seeded; subsequent tasks use the source rules.
    g.intervalTimerControl=3;
    updateWorld22Transition(g);
    updatePlayerAnimationState(g);preparePlayerPresentation(g);
    g.world22Transition.random=[145,90,120,204,61,165,222];
}

function beginWorld22ExitTasks(g) {
    local random=("world22Transition" in g)?g.world22Transition.random:g.world22.random;
    g.world22Transition <- {phase="exitPipe",hudTimeReady=true,behindPipe=true,areaTimer=g.cameraX>=256?52:160,
        screenTask=12,columns=0,operTask=3,engineTask=2,screenDisabled=false,
        target="exit",playerYHigh=1,random=random};
}
