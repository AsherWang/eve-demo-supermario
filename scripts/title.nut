// Single-player title return. The original CHR menu is extracted offline.
dofile("scripts/generated/title_data.nut");
function loadTitleAssets() {
    if(!("titleOverlay" in assets)) assets.titleOverlay <- loadTexture("assets/title/overlay.png");
}

function beginTitleReturn(g) {
    local best=g.score;
    if("highScore" in g && g.highScore>best) best=g.highScore;
    g.highScore <- best;
    g.title <- {frames=0,previousWorld=g.world,previousLevel=g.level};
    g.state="titleLoad";
    g.soundEvents.append("silence_music");parityRecordEvent(g,"music","silence");
}

function startTitleNewGame(g) {
    // Start clears game counters before the next VRAM HUD update. Preserve
    // the displayed score for the final title frame already queued to PPU.
    g.score=0;g.coins=0;g.lives=3;
    g.queuedScore=0;g.queuedCoins=0;g.displayCoins=0;
    g.state="newGameLoad";g.title.loadFrames <- 0;g.checkpointPage=0;
    g.soundEvents.clear();g.player.dead=false;
    g.input.jumpDown=false;g.input.runDown=false;
    g.input.startQueued=false;g.input.resetQueued=false;
    parityRecordEvent(g,"gameplay","new_game");
    g.nesFrameCounter=(g.nesFrameCounter+1)&255;
}

function tickTitleDivider(g) {
    g.intervalTimerControl-=1;
    if(g.intervalTimerControl<0) g.intervalTimerControl=20;
}

function updateTitlePalette(g) {
    if(g.colorPhasePending && g.vramBufferAddrCtrl!=6) {
        g.displayColorPhase=g.pendingColorPhase;g.colorPhasePending=false;
    }
    if((g.nesFrameCounter&7)==0) {
        g.pendingColorPhase=g.colorRotateOffset;g.colorPhasePending=true;
        g.colorRotateOffset=(g.colorRotateOffset+1)%6;
    }
}

function updateTitleNewGameLoad(g) {
    g.title.loadFrames+=1;
    local frame=g.title.loadFrames;
    g.vramBufferAddrCtrl=0;
    if(frame!=2) tickTitleDivider(g);
    if(frame==1) {
        g.cameraX=0;g.displayCameraX=0;
        g.player.nesXForce=0;g.player.nesXMoveForce=0;
        g.player.nesYMoveForce=0;g.player.nesYDummy=0;
        g.colorRotateOffset=0;g.displayColorPhase=0;g.colorPhasePending=false;
    } else if(frame==2) {
        local time=g.time,interval=g.intervalTimerControl;
        startLevel(g,1,1,true);g.state="newGameLoad";g.soundEvents.clear();
        resetPlayerForArea(g,0,0);g.player.movingDir=0;
        g.time=time;g.displayTime=time;g.intervalTimerControl=interval;g.nesFrameCounter=0;
        g.colorRotateOffset=0;g.displayColorPhase=0;
        g.pendingColorPhase=0;g.colorPhasePending=false;
    }
    if(frame==3) g.vramBufferAddrCtrl=3; // InitializeScreen palette
    if(frame==8) g.title.waitEnd <- frame+g.intervalTimerControl+1+6*21;
    if("waitEnd" in g.title) {
        local end=g.title.waitEnd;
        if(frame>end && frame<=end+12) g.vramBufferAddrCtrl=6; // initial area columns
        if(frame==end+13) g.vramBufferAddrCtrl=2; // area palette
        if(frame==end+17) {g.soundEvents.append("resume_music");parityRecordEvent(g,"music","overworld");}
        if(frame==end+18) {
            resetPlayerForArea(g,40,176);g.player.grounded=true;g.player.movingDir=0;
            g.time=401;g.displayTime=401;g.gameTimerControl=0;
        } else if(frame==end+19) {
            g.state="playing";g.time=400;g.displayTime=401;g.gameTimerControl=24;
            g.player.parityOriginFriction=true;
            g.input.jumpDown=false;g.input.runDown=false;
        }
        if(frame>=end+18) updateTitlePalette(g);
    }
    g.nesFrameCounter=(g.nesFrameCounter+1)&255;
}

function updateTitleFlow(g) {
    if(g.state=="newGameLoad") {updateTitleNewGameLoad(g);return;}
    g.vramBufferAddrCtrl=0;
    local next=g.title.frames+1;
    if(!(g.state=="titleLoad" && (next==2 || next==3))) tickTitleDivider(g);
    if(g.state=="titleScreen" && (g.input.startQueued || g.input.resetQueued)) {
        startTitleNewGame(g);return;
    }
    g.title.frames+=1;
    local frame=g.title.frames;
    if(g.state=="titleLoad") {
        if(frame>=10 && frame<=21) g.vramBufferAddrCtrl=6; // twelve area-column tasks
        if(frame==22) g.vramBufferAddrCtrl=2;
        if(frame==25) g.vramBufferAddrCtrl=5; // copied CHR title packet
    }
    if(g.state=="titleLoad") {
        if(frame==1) {
            g.world=1;g.level=1;g.lives=1;g.cameraX=0;g.displayCameraX=0;
            g.player.nesXForce=0;g.player.nesXMoveForce=0;
            g.player.nesYMoveForce=0;g.player.nesYDummy=0;
            // InitializeGame clears these bytes before InitializeArea.
            g.player.romSizeRaw <- 0;
            g.colorRotateOffset=0;g.displayColorPhase=0;g.colorPhasePending=false;
            g.vramScrollThirtyTwo=0;g.vramAreaParserTask=0;g.vramBufferAddrCtrl=0;
        } else if(frame==2) {
            local time=g.time,control=g.gameTimerControl,interval=g.intervalTimerControl;
            startLevel(g,1,1,true);g.soundEvents.clear();
            g.state="titleLoad";g.time=time;g.displayTime=time;g.gameTimerControl=control;
            g.intervalTimerControl=interval;
            resetPlayerForArea(g,0,0);g.player.movingDir=0;
            g.player.romSizeRaw <- 0;
            g.nesFrameCounter=0;g.goombas=[];
            g.colorRotateOffset=0;g.displayColorPhase=0;g.pendingColorPhase=0;
            g.colorPhasePending=false;
        } else if(frame==25) {
            // CopyTitleScreen uses RAM $0300..$0439 as a VRAM packet buffer.
            // Its tail aliases the inactive player's movement accumulators.
            g.player.nesXMoveForce=ROM_TITLE_PACKET[0x100];
            g.player.nesYDummy=ROM_TITLE_PACKET[0x116];
            g.player.nesYMoveForce=ROM_TITLE_PACKET[0x133];
        } else if(frame==26) {
            // ClearBuffers runs immediately after the CHR copy, including
            // its $0400 page aliases, before PrimaryGameSetup runs.
            g.player.nesXMoveForce=0;g.player.nesYDummy=0;g.player.nesYMoveForce=0;
        } else if(frame==28) {
            g.lives=3;g.player.nesXMoveForce=0;
            g.player.nesYDummy=0;g.player.nesYMoveForce=0;
            g.player.romSizeRaw=1;
        }
        else if(frame==29) {
            resetPlayerForArea(g,40,176);g.player.movingDir=0;
            g.player.grounded=true;g.time=401;g.displayTime=401;g.gameTimerControl=0;
        } else if(frame==30) g.state="titleScreen";
    }
    g.input.startQueued=false;
    // InitializeArea occupies two passes around the zeroed frame counter.
    if(frame>=29) updateTitlePalette(g);
    if(!(g.state=="titleLoad" && frame==3))
        g.nesFrameCounter=(g.nesFrameCounter+1)&255;
}

function drawTitleFlow(g) {
    if(g.state=="newGameLoad") {
        local frame=g.title.loadFrames;
        if(frame>=8 && !("waitEnd" in g.title && frame>g.title.waitEnd)) {
            drawIntermediateLives(g);return;
        }
        if(frame>=2) {
            // The uploaded palette is visible while PPU rendering is disabled.
            local ready=("waitEnd" in g.title) && frame>=g.title.waitEnd+14;
            screenRect(0.0,0.0,LOGICAL_WIDTH,LOGICAL_HEIGHT,
                ready?146.0/255.0:0.0,ready?144.0/255.0:0.0,ready?1.0:0.0);return;
        }
    }
    local frame=g.title.frames;
    if(g.state=="titleLoad" && frame<4) {
        screenRect(0.0,0.0,LOGICAL_WIDTH,LOGICAL_HEIGHT,0.0,0.0,0.0);
        local world=g.world,level=g.level;
        g.world=g.title.previousWorld;g.level=g.title.previousLevel;
        g.state="gameOverScreen";drawHud(g);g.state="titleLoad";
        g.world=world;g.level=level;
        drawHudGlyphs([0x10,0x0a,0x16,0x0e,0x24,0x18,0x1f,0x0e,0x1b],88,128);
        return;
    }
    if(g.state=="titleLoad" && frame<24) {
        screenRect(0.0,0.0,LOGICAL_WIDTH,LOGICAL_HEIGHT,0.0,0.0,0.0);return;
    }
    // Title CHR copy and setup keep rendering disabled after palette upload.
    if(g.state=="titleLoad" && frame<=28) {
        screenRect(0.0,0.0,LOGICAL_WIDTH,LOGICAL_HEIGHT,146.0/255.0,144.0/255.0,1.0);return;
    }
    drawBackground(g);drawTiles(g);
    local state=g.state;g.state="titleScreen";drawHud(g);g.state=state;
    if(frame>=27) {
        screenTexture(assets.titleOverlay,0,0,256,240);
        drawHudNumber(g.highScore,6,136,184);
    }
    if(frame>=30) drawPlayer(g);
}
