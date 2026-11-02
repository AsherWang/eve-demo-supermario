// SetupVine runs both from the producer and enemy initialization. The two
// writes target one sound queue, so native audio plays the clip once.
function emitWorld21VineSound(g) {
    emitSound(g,"vine");parityRecordEvent(g,"audio","vine");
}

// World 2-1 vine and sky-area runtime. Static maps remain offline ROM data.
function saveWorld21MainForSky(g) {
    saveMainArea(g);
    g.world21.savedActors <- {plants=g.plants,checkpoint=g.checkpointPage};
    g.world21Main <- g.world21;
}

function loadWorld21Sky(g) {
    saveWorld21MainForSky(g);
    local descriptor=g.world21.descriptor;
    clearAreaObjects(g);g.plants=[];g.platforms=[];g.sidePipeX=-1;
    g.area="sky";g.areaWidth=ROM_WORLD_2_1_SKY_METATILES.len();
    g.cameraX=0;g.displayCameraX=0;
    g.world21={descriptor=descriptor,baseTiles=[],springs=[],
        vines=[{x=64.0,y=240.0,height=0.0,maximum=96}],
        slotXFractions=[0.0,0.0,0.0,0.0,0.0],
        cloudPlatform={x=256.0,y=160.0,previousX=256.0,displayX=256.0,
            width=48.0,speed=0.0,active=true,slot=0}};
    for(local x=0;x<g.areaWidth;x+=1) for(local r=0;r<13;r+=1) {
        local meta=ROM_WORLD_2_1_SKY_METATILES[x][r];
        if(meta==0xc2) g.levelCoins.append({x=x*16.0,y=(r+2)*16.0,
            width=16.0,height=16.0,active=true});
        else setTile(g,x,r+2,ROM_WORLD_2_1_SKY_BLOCKS[x][r]!=0?TILE_SOLID:TILE_EMPTY);
    }
    g.world21.baseTiles=clone g.tiles;
}

function beginWorld21SkyReturn(g) {
    g.player.vineClimbing <- false;g.player.vineAuto <- false;
    g.areaReloadTarget="main";g.areaReloadFrames=0;g.state="areaReload";
    g.world21.skyReturn <- true;
}

function world21ClimbStep(g,up,down) {
    local p=g.player;
    p.nesXSpeed=0;p.nesXForce=0;p.vx=0;
    p.nesYSpeed=up?-1:(down?1:0);
    p.nesYMoveForce=up?0x20:(down?0xff:0);
    local sum=p.nesYDummy+p.nesYMoveForce;p.nesYDummy=sum&255;
    local delta=p.nesYSpeed+(sum>>8);p.y+=delta;p.vy=delta*NES_FRAME_RATE;
    p.grounded=false;p.entranceFalling=false;
    p.playerAnimTimerSet=up?8:4;
}

function updateWorld21Climbing(g) {
    local p=g.player;
    if(!("vineClimbing" in p) || !p.vineClimbing) return false;
    if(!("vineAuto" in p)) p.vineAuto <- false;
    if("vineExitPending" in p && p.vineExitPending) {
        g.areaReloadTarget="sky";g.areaReloadFrames=0;g.state="areaReload";return true;
    }
    if(!p.vineAuto && g.input.jumpQueued) {
        p.vineClimbing=false;p.grounded=true;p.vineDetachFrames <- 8;
        return false;
    }
    if(p.y-(p.big?0:16)<32 && g.area=="main") p.vineAuto=true;
    world21ClimbStep(g,p.vineAuto || g.input.up,!p.vineAuto && g.input.down);
    local canonicalY=p.y-(p.big?0:16);
    if(!p.vineAuto && p.nesYSpeed<0 && (floor(canonicalY).tointeger()&15)>=4) p.nesYSpeed=1;
    if(canonicalY<32 && g.area=="main") p.vineAuto=true;
    if(p.vineAuto && p.y-(p.big?0:16)< -28) {
        p.vineExitPending <- true;
        return true;
    }
    if(!("climbSideFrames" in p)) p.climbSideFrames <- 0;
    if(p.climbSideFrames>0) p.climbSideFrames-=1;
    if(!p.vineAuto && (g.input.left || g.input.right) && p.climbSideFrames==0) {
        local right=g.input.right;
        p.x+=right?(p.facing>0?14:4):(p.facing>0?-4:-14);
        p.facing=right?-1:1;p.climbSideFrames=24;
        if(abs(p.x-p.vineX)>16) {p.vineClimbing=false;p.vineDetachFrames <- 8;}
    }
    if(!g.input.left && !g.input.right) p.climbSideFrames=0;
    if(!p.vineAuto) {
        local touching=false, low=floor(p.x).tointeger()&15;
        foreach(vine in g.world21.vines) {
            local rowY=p.y-(p.big?0:16)+24;
            if(low>=6 && low<10 && abs(p.x-vine.x)<=9 &&
                rowY>=vine.y-vine.height+16 && rowY<vine.y) touching=true;
        }
        if(!touching) {
            p.vineClimbing=false;p.entranceFalling=true;p.vineDetachFrames <- 8;
        }
    }
    return true;
}

function attachWorld21Vine(g) {
    local p=g.player;
    if(p.dead || ("vineClimbing" in p && p.vineClimbing)) return;
    if("vineDetachFrames" in p && p.vineDetachFrames>0) {p.vineDetachFrames-=1;return;}
    local canonicalY=p.y-(p.big && !p.crouching?0:16);
    local xLow=floor(p.x).tointeger()&15;
    if(xLow<6 || xLow>=10) return;
    foreach(vine in g.world21.vines) if(vine.height>=8) {
        local rowY=canonicalY+24;
        local column=floor(vine.x/16);
        if(rowY<vine.y-vine.height+16 || rowY>=vine.y) continue;
        if(floor((p.x+2)/16)!=column && floor((p.x+13)/16)!=column) continue;
        p.vineClimbing <- true;p.vineAuto <- false;p.vineX <- vine.x;p.climbSideFrames=0;
        p.x=vine.x+(p.facing>0?-7:7);
        p.nesXSpeed=0;p.nesXForce=0;p.vx=0;p.grounded=false;p.entranceFalling=false;
        break;
    }
}

function updateWorld21SkyEntrance(g) {
    local p=g.player, vine=g.world21.vines[0];
    p.previousX=p.x;p.previousY=p.y;g.areaEntranceFrames+=1;
    if(vine.height<96) return;
    local canonicalY=p.y-(p.big?0:16);
    if(canonicalY>=153) {
        setTile(g,4,13,TILE_SOLID); // invisible support supplied by the vine entrance
        p.vineClimbing <- true;world21ClimbStep(g,true,false);
    } else {
        p.vineClimbing <- true;p.nesYSpeed=0;p.nesYMoveForce=0;p.vy=0;p.playerAnimTimerSet=4;
        if(!("skyStepTimer" in g.world21)) g.world21.skyStepTimer <- 0;
        if(g.world21.skyStepTimer>0) g.world21.skyStepTimer-=1;
        if(g.world21.skyStepTimer==0) {
            p.x+=p.facing>0?14:4;p.facing=-1;g.world21.skyStepTimer=24;
            // The background vine contact aligns the first side switch;
            // the second step clears the climbing column and releases control.
            local low=floor(p.x).tointeger()&15;
            if(low>=6 && low<10) p.x=vine.x+7;
        }
        if(p.x>=72) {
            p.vineClimbing=false;p.grounded=false;p.facing=1;p.entranceFalling=true;
            p.vineDetachFrames <- 8;p.pipeExitPresentationPending <- true;g.state="playing";
        }
    }
}

function updateWorld21CloudPlatform(g) {
    if(g.area!="sky") return;
    local cloud=g.world21.cloudPlatform,p=g.player;
    if(!cloud.active) return;
    cloud.displayX=cloud.x;cloud.previousX=cloud.x;
    local oldX=cloud.x;cloud.x+=cloud.speed;
    local ridingBefore=p.grounded && abs(p.y+p.height-cloud.y)<2.5 &&
        p.x+p.width>=oldX && p.x<=oldX+cloud.width;
    world13PlatformRider(g,cloud,oldX,cloud.y,cloud.x,cloud.y,13);
    local riding=p.grounded && abs(p.y+p.height-cloud.y)<0.01 &&
        p.x+p.width>=cloud.x && p.x<=cloud.x+cloud.width;
    if(riding || ridingBefore) cloud.speed=1.0; // ROM $10 4.4 right-platform speed
    if(cloud.x<g.cameraX-73) cloud.active=false;
}

// Branch regressions exercise the public frame loop, including automatic entry.
function runWorld21SkySelfTest() {
    local side=createGame();startLevel(side,2,1);side.goombas=[];side.plants=[];
    growWorld21Vine(side,83,5);side.world21.vines[0].height=96;
    resetPlayerForArea(side,83*16-7,48);attachWorld21Vine(side);
    side.input.right=true;
    for(local frame=0;frame<25;frame+=1) simulateFixed(side,FIXED_DT);
    requireSelfTest(!side.player.vineClimbing,
        "a second side switch must release the vine instead of climbing empty space");

    foreach(power in [0,1,2]) {
        local g=createGame();startLevel(g,2,1);
        g.goombas=[];g.plants=[];g.score=12300;g.coins=8;g.lives=3;
        g.player.big=power>0;g.player.fire=power==2;
        g.player.height=power>0?32.0:16.0;
        setTile(g,16,9,TILE_EMPTY);
        growWorld21Vine(g,83,5);
        for(local i=0;i<200;i+=1) {updateWorld21Actors(g);g.nesFrameCounter=(g.nesFrameCounter+1)&255;}
        requireSelfTest(g.world21.vines[0].height==96,"main vine must stop at its ROM initialized vine height");
        resetPlayerForArea(g,83*16-7,48);g.input.up=true;
        attachWorld21Vine(g);
        requireSelfTest(g.player.vineClimbing,"side contact must attach Mario to a grown vine");
        for(local i=0;i<600 && !(g.area=="sky" && g.state=="playing");i+=1) simulateFixed(g,FIXED_DT);
        requireSelfTest(g.area=="sky" && g.state=="playing" && g.levelCoins.len()==41 &&
            g.player.big==(power>0) && g.player.fire==(power==2) && g.lives==3,
            "vine climb and automatic sky entrance must finish without losing power or lives");
        g.input.up=false;
        local cloud=g.world21.cloudPlatform;
        requireSelfTest(cloud.x==256 && cloud.speed==0,"cloud platform must wait for its first rider");
        g.player.x=260;g.player.y=160-g.player.height;g.player.previousY=g.player.y;
        g.player.nesYSpeed=0;g.player.grounded=true;
        updateWorld21CloudPlatform(g);updateWorld21CloudPlatform(g);
        requireSelfTest(cloud.speed==1 && cloud.x==257 && g.player.x==261 && g.player.grounded,
            "first rider must start the cloud and be carried horizontally");
        // An inclusive X+13 edge carries the last supported frame, then releases.
        g.cameraX=992;cloud.x=1244;cloud.speed=1;
        g.player.x=1232;g.player.y=160-g.player.height;
        g.player.previousY=g.player.y;g.player.nesYSpeed=0;g.player.grounded=true;
        simulateFixed(g,FIXED_DT);
        requireSelfTest(g.player.grounded && g.player.x==1232 && g.cameraX==992,
            "cloud rider must remain supported at its inclusive edge and locked camera");
        simulateFixed(g,FIXED_DT);
        requireSelfTest(!g.player.grounded && g.player.x==1231,
            "the cloud must release its rider after moving beyond the inclusive edge");
        g.player.x=62*16;g.player.y=250;g.player.previousY=250;
        g.player.grounded=false;g.player.nesYSpeed=4;
        for(local i=0;i<260 && !(g.area=="main" && g.state=="playing");i+=1) simulateFixed(g,FIXED_DT);
        requireSelfTest(g.area=="main" && g.state=="playing" && g.cameraX==2560 &&
            g.player.x==2600 && g.lives==3 && !g.player.dead &&
            g.player.big==(power>0) && g.player.fire==(power==2) &&
            g.score==12300 && g.coins==8 && getTile(g,16,9)==TILE_EMPTY,
            "falling from sky must return to main page ten, retain terrain, stats and powers");
    }
}
