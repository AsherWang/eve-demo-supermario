// World 2-2 water runtime; whole-level parity acceptance is still pending.
dofile("scripts/generated/world22_data.nut");
dofile("scripts/generated/world22_map.nut");
dofile("scripts/generated/world22_intro_map.nut");

function isWorld22(g) {return g.world==2 && g.level==2;}

function startWorld22(g) {
    loadWorld22Assets();
    startWorld12(g,"intro");
    g.world=2;g.romBackgroundCollision=false;
    initializeWorld22Transition(g);
}

function isWorld22Water(g) {return g.world==2 && g.level==2 && g.area=="water";}

function loadWorld22Assets() {
    if("world22" in assets) return;
    local introTiles={};
    foreach(column in ROM_WORLD_2_2_INTRO_METATILES) foreach(meta in column)
        if(meta!=0 && !(meta in introTiles)) introTiles[meta] <- loadTexture("assets/world13/metatile-"+meta+".png");
    local tiles={};
    foreach(column in ROM_WORLD_2_2_METATILES) foreach(meta in column)
        if(!(meta in tiles)) tiles[meta] <- loadTexture("assets/world22/metatile-"+meta+".png");
    local swim={},swimKick={};
    foreach(size in ["small","big"]) {
        local frames=[];
        for(local i=0;i<3;i+=1) frames.append([
            loadTexture("assets/world22/mario-"+size+"-swim-"+i+"-right.png"),
            loadTexture("assets/world22/mario-"+size+"-swim-"+i+"-left.png")]);
        swim[size] <- frames;
        local kicks=[];
        for(local i=0;i<3;i+=1) kicks.append([
            loadTexture("assets/world22/mario-"+size+"-swim-kick-"+i+"-right.png"),
            loadTexture("assets/world22/mario-"+size+"-swim-kick-"+i+"-left.png")]);
        swimKick[size] <- kicks;
    }
    local coins=[],masks=[],hudCoins=[];
    for(local phase=0;phase<6;phase+=1) {coins.append(loadTexture("assets/world22/coin-"+phase+".png"));masks.append(loadTexture("assets/world22/hud-sprite0-"+phase+".png"));hudCoins.append(loadTexture("assets/world22/hud-coin-"+phase+".png"));}
    assets.world22 <- {plants=[loadTexture("assets/world21/plant-0.png"),loadTexture("assets/world21/plant-1.png")],coins=coins,hudCoins=hudCoins,spriteZeroMasks=masks,introTiles=introTiles,metatiles=tiles,swim=swim,swimKick=swimKick,bubble=loadTexture("assets/world22/bubble.png"),deadFish=[
        [loadTexture("assets/world22/cheep-0-dead.png"),loadTexture("assets/world22/cheep-1-dead.png")],
        [loadTexture("assets/world22/red-cheep-0-dead.png"),loadTexture("assets/world22/red-cheep-1-dead.png")]],
        deadBloopers=[loadTexture("assets/world22/bloober-0-dead.png"),loadTexture("assets/world22/bloober-1-dead.png")],fish=[
        [loadTexture("assets/world22/cheep-0-flipped.png"),loadTexture("assets/world22/cheep-1-flipped.png")],
        [loadTexture("assets/world22/red-cheep-0-flipped.png"),loadTexture("assets/world22/red-cheep-1-flipped.png")]],bloopers=[
        loadTexture("assets/world22/bloober-0.png"),loadTexture("assets/world22/bloober-1.png")]};
}

function world22WhirlpoolData() {
    local holes=[],page=0;
    for(local i=2;i+1<ROM_WORLD_2_2_WATER_AREA.len();i+=2) {
        local first=ROM_WORLD_2_2_WATER_AREA[i],second=ROM_WORLD_2_2_WATER_AREA[i+1];
        if(first==0xfd) break;
        if(second&128) page+=1;
        local row=first&15,value=second&127;
        if(row==13 && !(value&64)) {page=value&31;continue;}
        if(row==12 && value<16)
            holes.append({left=(page*16+(first>>4)-1)*16,length=(value+2)*16});
    }
    return holes;
}

function world22VerticalDelta(p,gravity,maximum) {
    local position=p.nesYDummy+p.nesYMoveForce;
    p.nesYDummy=position&255;
    local dy=p.nesYSpeed+(position>>8);
    local velocity=p.nesYMoveForce+gravity;
    p.nesYMoveForce=velocity&255;p.nesYSpeed+=velocity>>8;
    if(p.nesYSpeed>=maximum && p.nesYMoveForce>=128) {
        p.nesYSpeed=maximum;p.nesYMoveForce=0;
    }
    return dy;
}

function updateWorld22Whirlpools(g) {
    local p=g.player;p.swimWhirlpool=false;
    if(p.dead || g.state!="playing") return;
    for(local i=g.world22.whirlpools.len()-1;i>=0;i-=1) {
        local hole=g.world22.whirlpools[i];
        if(p.x<hole.left || p.x>hole.left+hole.length) continue;
        // WhirlpoolProcessing runs after player graphics/background collision.
        // Its second gravity integration uses $10 and a downward limit of 1.
        // The water reference origin is post-NMI; the next movement pass
        // observes the next counter value before the host end-of-frame increment.
        if((g.nesFrameCounter+1)&1) {
            if(p.x>hole.left+hole.length/2) p.x-=1;
            else if(p.collisionBits&1) p.x+=1;
        }
        p.swimWhirlpool=true;
        p.y+=world22VerticalDelta(p,16,1);
        return;
    }
}

function startWorld22Water(g, page=0, recordMusic=true) {
    g.world=2;g.level=2;g.stage="water";g.area="water";
    g.areaWidth=ROM_WORLD_2_2_METATILES.len();g.romBackgroundCollision=true;
    clearAreaObjects(g);g.plants=[];g.platforms=[];g.enterablePipes=[];
    g.sidePipeX=189;g.world12SidePipeBottomRow <- 8;g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
    g.world22 <- {whirlpools=world22WhirlpoolData(),scrollLocked=false,scrollColumns={}};
    initializeWorld22Enemies(g);
    g.world22.bubbles <- [];g.world22.bubbleTimer <- 0;g.world22.oamPhase <- 0;g.world22.displayOamPhase <- 0;
    for(local i=0;i<3;i+=1) g.world22.bubbles.append({x=0.0,y=0,force=0,drawX=0.0,drawY=248});
    g.savedMain=null;g.flagX=100000.0;g.castleX=100000.0;
    for(local x=0;x<g.areaWidth;x+=1) for(local r=0;r<13;r+=1) {
        local meta=ROM_WORLD_2_2_METATILES[x][r];
        local coin=meta==0xc3;
        setTile(g,x,r+2,(!coin && ROM_WORLD_2_2_BLOCKS[x][r]!=0)?TILE_SOLID:TILE_EMPTY);
        if(coin) g.levelCoins.append({x=x*16.0,y=(r+2)*16.0,width=16.0,height=16.0,active=true});
    }
    resetPlayerForArea(g,page*256+40,page>0?176:32);
    g.player.grounded=false;g.player.movingDir=0;
    g.player.swimTimer <- 0;g.player.swimPreviousA <- false;
    g.player.swimGravity <- 0x28;g.player.swimWhirlpool <- false;
    g.player.fallForce=0x28;
    g.state="playing";g.stateTimer=0.0;g.checkpointPage=page;
    g.time=400;g.displayTime=400;g.gameTimerControl=23;
    g.hurryActive=false;
    g.soundEvents.clear();
    g.soundEvents.append("resume_music");
    if(recordMusic) parityRecordEvent(g,"music","water");
}

function initializeWorld22SwimProbe(g) {
    // First controllable state in the independently captured ROM fixture.
    // This seeds only the origin; subsequent frames are simulated normally.
    startWorld22Water(g,0,false);
    local p=g.player;
    p.y=68.0;p.previousY=p.y;p.nesYSpeed=3;
    p.nesYMoveForce=200;p.nesYDummy=240;
    p.jumpOriginY=16.0;p.preparedRelY=52;p.queuedRelY=52;p.displayRelY=52;
    g.nesFrameCounter=59;g.intervalTimerControl=10;
    g.world22.random=[166,179,254,153,100,86,158];
}

function world22TileTexture(g,tx,ty) {
    if(ty<2) return null;
    local meta=ROM_WORLD_2_2_METATILES[tx][ty-2];
    if(meta==0xc3) {
        foreach(coin in g.levelCoins)
            if(coin.x==tx*16 && coin.y==ty*16 && !coin.active &&
                !("visualErasePending" in coin && coin.visualErasePending)) return assets.world22.metatiles[0x87];
        return assets.world22.coins[g.displayColorPhase];
    }
    return assets.world22.metatiles[meta];
}

function beginWorld22Swim(g) {
    local p=g.player;
    if(!p.grounded && p.swimTimer==0 && p.nesYSpeed<0) return;
    p.swimTimer=32;p.nesYDummy=0;
    p.nesYMoveForce=p.swimWhirlpool?0:128;
    p.nesYSpeed=p.swimWhirlpool?-1:-2;
    p.swimGravity=p.swimWhirlpool?4:13;
    p.fallForce=p.swimWhirlpool?9:10;
    p.jumpOriginY=p.y;p.grounded=false;
    if(p.y-(p.big?0:16)<20) p.nesYSpeed=0;
    emitSound(g,"stomp");
}

function updateWorld22Swimming(g,dt) {
    local p=g.player;
    if(p.swimTimer>0) p.swimTimer-=1;
    if(g.input.jumpQueued) beginWorld22Swim(g);
    local direction=(g.input.right?1:0)-(g.input.left?1:0);
    // GetPlayerAnimSpeed runs in the water movement handler, including in air.
    // GetPlayerAnimSpeed compares raw direction bits: no horizontal input (0)
    // equals an unset MovingDir (0), even when B alone is held. The shared
    // signed-direction adapter currently maps unset to left; avoid that false
    // skid/reset while stationary. No friction is applied in this source path.
    if(direction==0 && p.movingDir==0 && p.nesXSpeed==0) {
        p.playerAnimTimerSet=7;p.runningSpeed=0;
    } else updateNesHorizontalPhysics(g,p,direction);
    if(direction!=0) p.facing=direction;
    local dx=nesHorizontalDelta(p);
    p.nesXScroll=dx;p.vx=dx/dt;
    local movement=p.nesXSpeed>0?1:(p.nesXSpeed<0?2:0);
    movePlayerX(g,p,dt);
    if(p.vx==0 && dx!=0) {p.nesXSpeed=0;p.nesXForce=0;p.nesXMoveForce=0;}
    if(movement!=0) p.movingDir=movement;
    p.vx=p.nesXSpeed*3.75;
    if(p.grounded && playerHasFootSupport(g,p)) {p.vy=0;p.nesYSpeed=0;p.nesYMoveForce=0;}
    else {
        p.grounded=false;
        if(p.nesYSpeed>=0 || (!(g.input.jumpDown && p.swimPreviousA) &&
            ((p.jumpOriginY-p.y).tointeger()&255)>=1)) p.swimGravity=p.fallForce;
        if(p.y-(p.big?0:16)<20) p.swimGravity=24;
        local dy=world22VerticalDelta(p,p.swimGravity,4);
        p.vy=dy/dt;movePlayerY(g,p,dt,p.nesYSpeed>=0);
        if(p.vy==0 && dy!=0) {
            p.nesYSpeed=p.headCollision?p.headCollisionSpeed:0;
            if(!p.headCollision) p.nesYMoveForce=0;
        } else p.vy=p.nesYSpeed*NES_FRAME_RATE;
    }
    p.swimPreviousA=g.input.jumpDown;
    if(p.x<=g.cameraX) {p.x=g.cameraX;if(p.nesXSpeed<0) {p.nesXSpeed=0;p.vx=0;}}
    if(p.y>LOGICAL_HEIGHT+32) killPlayer(g);
    handlePlayerBackgroundSides(g,p);
    if(g.input.fireQueued && p.fire && !p.dead && p.y-(p.big?0:16)<208)
        spawnFireball(g);
}

function updateWorld22DeathReload(g) {
    g.deathReloadFrames+=1;
    if(g.deathReloadFrames==1) {
        g.checkpointPage=g.cameraX>=1280?5:0;
        g.lives-=1;
        if(g.lives<=0) {
            g.lives=0;g.state="gameOver";g.player.dead=false;
            emitSound(g,"game_over");return;
        }
    }
    if(g.deathReloadFrames>=166) {
        local page=g.checkpointPage;
        g.player=createPlayer();startWorld22Water(g,page);
    }
}

// The mouth occupies map rows 7/8. Require the entire collision body to
// fit the opening; swimming alongside its upper rock must not enter it.
function tryWorld22Exit(g) {
    local p=g.player;
    if(!isWorld22Water(g) || p.dead || !p.grounded || !g.input.right) return false;
    if(p.x+13<g.sidePipeX*16 || p.x>=g.sidePipeX*16+16 ||
        p.y<112 || p.y+p.height>144) return false;
    startWorld12Transition(g,"exit","side");
    beginWorld22ExitTasks(g);
    return true;
}

// ProcessFireballsAndBubbles: three slots in reverse order, sharing one timer.
// Reuses the enemy LFSR without advancing it, so bubble animation cannot change
// enemy allocation or the preserved 1800-frame motion diagnostic.
function updateWorld22Bubbles(g, tickTimer=true) {
    local state=g.world22,p=g.player;
    state.displayOamPhase=state.oamPhase;state.oamPhase=(state.oamPhase+1)%3;
    if(tickTimer && state.bubbleTimer>0) state.bubbleTimer-=1;
    for(local slot=2;slot>=0;slot-=1) {
        local b=state.bubbles[slot],bit=state.random[slot+1]&1;
        b.drawX=b.x;b.drawY=b.y;
        if(b.y==248) {
            if(state.bubbleTimer>0) continue;
            // LSR facing direction leaves carry set on the right: ADC adds 9.
            b.x=p.x+(p.facing>0?9:0);b.y=(p.y-(p.big?0:16)+8).tointeger();
            state.bubbleTimer=bit?32:64;
        }
        local sum=b.force-(bit?80:255);b.force=sum&255;
        if(sum<0) b.y=(b.y-1)&255;
        if(b.y<32) b.y=248;
    }
}

function drawWorld22Bubbles(g) {
    if(g.player.y-(g.player.big?0:16)>=256) return;
    for(local slot=2;slot>=0;slot-=1) {
        local b=g.world22.bubbles[slot];
        oamBase=slot==0?0x24:world22OamOffset(g,slot==1?0xf8:0xfc);
        if(b.drawY!=248) screenOamTexture(assets.world22.bubble,b.drawX-visualCameraX(g),b.drawY+1,8,8);
    }
}

dofile("scripts/world22_transition.nut");

// Row-$0d $46/$47 objects toggle ScrollLock when the area parser consumes
// their column. The shared scheduler calls this after completing task 7 or 3.
function parseWorld22AreaColumn(g,task) {
    if(!isWorld22Water(g) || (task!=7 && task!=3)) return;
    local column=floor(g.cameraX/32).tointeger()*2+(task==7?22:23);
    if(column in g.world22.scrollColumns) return;
    g.world22.scrollColumns[column] <- true;
    local page=0,data=ROM_WORLD_2_2_WATER_AREA;
    for(local i=2;i+1<data.len();i+=2) {
        local a=data[i],b=data[i+1],row=a&15,value=b&127;
        if(a==253) break;if(b&128) page+=1;
        if(row==13 && !(value&64)) {page=value&31;continue;}
        if(row==13 && (value==0x46 || value==0x47) && page*16+(a>>4)==column)
            g.world22.scrollLocked=!g.world22.scrollLocked;
    }
}

function world22OamOffset(g,baseOffset) {
    local offsets=[0,0x58,0xa0];local value=baseOffset+offsets[g.world22.displayOamPhase];
    return value>=256?(value+0x28)&255:value;
}
