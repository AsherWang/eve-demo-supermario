// World 2-3: original bridge course, with its own map and flying-fish actors.
dofile("scripts/generated/world23_data.nut");
dofile("scripts/generated/world23_map.nut");

function isWorld23(g) {return g.world==2 && g.level==3;}

function world23LevelDescriptor() {
    return {world=2,level=3,stage="world23",areaPointer=0x27,
        metatiles=ROM_WORLD_2_3_METATILES,blocks=ROM_WORLD_2_3_BLOCKS,
        enemies=ROM_WORLD_2_3_ENEMIES,entry={x=40,y=176},
        goal={flagColumn=225,castleColumn=229},checkpoint={page=7,cameraThreshold=1792},
        time=300,music="overworld",branches=[]};
}

function loadWorld23Assets() {
    if(assets==null) loadAssets();
    if("world23" in assets) return;
    local tiles={},coins=[],questions=[],left=[],right=[];
    foreach(column in ROM_WORLD_2_3_METATILES) foreach(meta in column)
        if(meta!=0 && !(meta in tiles)) tiles[meta]<-loadTexture("assets/world23/metatile-"+meta+".png");
    for(local i=0;i<6;i+=1) {
        coins.append(loadTexture("assets/world23/coin-"+i+".png"));
        questions.append(loadTexture("assets/world23/question-"+i+".png"));
    }
    for(local i=0;i<2;i+=1) {
        left.append(loadTexture("assets/world23/fish-"+i+"-left.png"));
        right.append(loadTexture("assets/world23/fish-"+i+"-right.png"));
    }
    assets.world23 <- {metatiles=tiles,coins=coins,questions=questions,left=left,right=right};
}

function world23FrenzyCommands() {
    local commands=[],data=ROM_WORLD_2_3_AREA,page=0;
    for(local i=2;i+1<data.len() && data[i]!=253;i+=2) {
        local a=data[i],b=data[i+1],v=b&127;
        if(b&128) page+=1;
        if((a&15)==13 && !(v&64)) {page=v&31;continue;}
        if((a&15)==13 && (v==0x48 || v==0x4a))
            commands.append({column=page*16+(a>>4),enabled=v==0x48});
    }
    return commands;
}

function startWorld23(g,page=0) {
    local d=world23LevelDescriptor();
    if(TILE_STRIDE<d.metatiles.len()) throw "World 2-3 requires TILE_STRIDE >= "+d.metatiles.len();
    local big=g.player.big,fire=g.player.fire;
    clearAreaObjects(g);g.platforms=[];g.plants=[];g.enterablePipes=[];g.sidePipeX=-1;
    g.world=2;g.level=3;g.stage="world23";g.area="main";g.areaWidth=d.metatiles.len();
    g.romBackgroundCollision=true;g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
    local state={descriptor=d,baseTiles=[],enemies=array(5,null),random=[165,0,0,0,0,0,0],
        fractions=array(5,0),timer=0,frenzy=false,commands=world23FrenzyCommands(),commandCursor=0,
        spawned=0,defeated=0};
    if("world23" in g) g.world23=state;else g.world23<-state;
    for(local x=0;x<g.areaWidth;x+=1) for(local row=0;row<13;row+=1) {
        local meta=d.metatiles[x][row],block=d.blocks[x][row];
        local tile=block==0?TILE_EMPTY:TILE_SOLID;
        if(meta==0x24 || meta==0x25 || meta==0xc2 || meta==0xc3) tile=TILE_EMPTY;
        if(meta==0x54) tile=TILE_GROUND;
        if(meta==0xc0) tile=TILE_QUESTION;
        if(meta==0xc1) tile=TILE_POWERUP_BLOCK;
        setTile(g,x,row+2,tile);
        if(meta==0xc2 || meta==0xc3)
            g.levelCoins.append({x=x*16.0,y=(row+2)*16.0,width=16.0,height=16.0,active=true});
    }
    state.baseTiles=clone g.tiles;
    g.flagX=d.goal.flagColumn*16.0;g.castleX=d.goal.castleColumn*16.0;
    g.flagY=48.0;g.preparedFlagY=48.0;g.displayFlagY=48.0;g.flagScoreAge=-1;
    g.castleFlagVisible=false;g.preparedCastleFlagY=144.0;g.displayCastleFlagY=144.0;
    g.fireworks=[];g.endLevelScrollLocked=false;
    resetPlayerForArea(g,page*256+40,176);g.player.big=big;g.player.fire=fire;
    g.player.height=big?32.0:16.0;g.player.grounded=true;g.player.entranceFalling=false;
    g.player.fallForce=0x28;
    g.state="playing";g.stateTimer=0.0;g.checkpointPage=page;
    g.time=300;g.displayTime=300;g.gameTimerControl=23;g.hurryActive=false;
    g.soundEvents.append("resume_music");
    // Backloading restores the last area frenzy command preceding the first parsed screen.
    while(state.commandCursor<state.commands.len() && state.commands[state.commandCursor].column<page*16+24) {
        state.frenzy=state.commands[state.commandCursor].enabled;state.commandCursor+=1;
    }
}

function drawWorld23Background(g) {screenRect(0,0,256,240,146.0/255,144.0/255,1.0);}

function world23TileTexture(g,tx,ty,tile) {
    if(ty<2 || ty>=15 || tx<0 || tx>=g.areaWidth) return null;
    local meta=ROM_WORLD_2_3_METATILES[tx][ty-2];
    if(meta==0 || meta==0x24 || meta==0x25 || meta==0xc2 || meta==0xc3) return null;
    if(tile!=g.world23.baseTiles[tileIndex(tx,ty)]) return tileTexture(g,tile);
    if(meta==0xc0 || meta==0xc1) return assets.world23.questions[g.displayColorPhase%6];
    return meta in assets.world23.metatiles?assets.world23.metatiles[meta]:null;
}

function world23AdvanceRandom(bytes) {
    local carry=((bytes[0]^bytes[1])&2)!=0?1:0;
    for(local i=0;i<7;i+=1) {local next=bytes[i]&1;bytes[i]=(bytes[i]>>1)|(carry<<7);carry=next;}
}

function spawnWorld23Fish(g,slot) {
    local s=g.world23,p=g.player,r=s.random;
    s.timer=[16,96,32,72][r[slot+1]&3];
    if(slot>=3) return;
    local seed=r[slot]&3;
    local group=p.nesXSpeed==0?0:((p.nesXSpeed&255)<0x19?4:8);
    local index=group+seed;
    local randomIndex=(r[slot+1]&3)!=0?(r[slot+2]&15):index;
    local speed=[14,5,6,14,28,32,16,12,30,34,24,20][index],direction=1;
    // InitFlyingCheepCheep retains Y from the speed lookup when the player moves.
    local offsetIndex=p.nesXSpeed==0?randomIndex:index;
    if(p.nesXSpeed==0 && (offsetIndex&2)) {speed=-speed;direction=2;}
    local offset=[128,48,64,128,48,80,80,112,32,64,128,160,112,64,144,104][offsetIndex];
    local x=floor(p.x).tointeger()+((offsetIndex&2)?offset:-offset);
    s.enemies[slot]={kind="flying_cheep",slot=slot,x=x,y=248,previousX=x,previousY=248,
        displayX=x,displayY=248,preparedX=x,preparedY=248,displayFrame=0,preparedFrame=0,
        speed=speed,direction=direction,nesYSpeed=-5,nesYMoveForce=0,nesYDummy=0,
        dead=false,age=0};
    s.spawned+=1;
}

function stepWorld23Fish(e,gravity=13) {
    local sum=e.nesYDummy+e.nesYMoveForce;
    e.y+=e.nesYSpeed+(sum>>8);e.nesYDummy=sum&255;
    local velocity=e.nesYMoveForce+gravity;
    e.nesYMoveForce=velocity&255;e.nesYSpeed+=velocity>>8;
    if(e.nesYSpeed>=5 && e.nesYMoveForce>=128) {e.nesYSpeed=5;e.nesYMoveForce=0;}
    if(!e.dead) {
        local reference=ROM_WORLD_2_3_FISH_Y_REFERENCE[e.nesYMoveForce>>4];
        local delta=(e.y-reference)&255;if(delta>=128) delta=256-delta;
        if(delta<8) e.nesYMoveForce=(e.nesYMoveForce+16)&255;
    }
}

function defeatWorld23Fish(g,e,stomp=false) {
    e.dead=true;e.nesYSpeed=-3;g.world23.defeated+=1;
    awardScoreControl(g,2);emitSound(g,stomp?"stomp":"kick");
    parityRecordEvent(g,"gameplay",stomp?"enemy_stomp":"enemy_kick",",\"enemy\":\"flying_cheep\"");
    if(stomp) {g.player.nesYSpeed=-4;g.player.vy=-4*NES_FRAME_RATE;g.player.grounded=false;}
}

function updateWorld23Actors(g) {
    if(!isWorld23(g)) return;
    local s=g.world23,p=g.player;
    world23AdvanceRandom(s.random);
    if(p.dead || p.transformFrames>0) return;
    if(s.timer>0) s.timer-=1;
    local parsedColumn=floor(g.cameraX/32).tointeger()*2+22;
    if(g.vramAreaParserTask==6)
        while(s.commandCursor<s.commands.len() && s.commands[s.commandCursor].column<=parsedColumn) {
            s.frenzy=s.commands[s.commandCursor].enabled;s.commandCursor+=1;
        }
    for(local slot=0;slot<5;slot+=1) {
        local e=s.enemies[slot];
        if(e==null) {
            if(s.frenzy && s.timer==0 && (g.vramAreaParserTask&7)!=7) spawnWorld23Fish(g,slot);
            continue;
        }
        e.displayX=e.preparedX;e.displayY=e.preparedY;e.displayFrame=e.preparedFrame;
        e.previousX=e.x;e.previousY=e.y;e.preparedX=e.x;e.preparedY=e.y;
        e.preparedFrame=((g.nesFrameCounter+1)&8)!=0?0:1;
        if(!e.dead) {
            foreach(fireball in g.fireballs)
                if(fireball.active && overlaps(fireball.x,fireball.y,8,8,e.x+3,e.y+14,11,7)) {
                    fireball.active=false;defeatWorld23Fish(g,e);break;
                }
            local py=p.y-(p.big?0:16);
            if(!e.dead && !((g.nesFrameCounter+1)&1) && e.x>=g.cameraX && e.x<g.cameraX+256 &&
                overlaps(p.x+(p.big?2:3),py+(p.big?8:20),p.big?13:11,p.big?25:13,e.x+3,e.y+14,11,7)) {
                if(p.starTimer>0) defeatWorld23Fish(g,e);
                else if(p.nesYSpeed>0 && p.previousY+p.height<=e.y+20) defeatWorld23Fish(g,e,true);
                else {hurtPlayer(g,e);if(p.dead || p.transformFrames>0) return;}
            }
        }
        if(!e.dead) {
            local sum=s.fractions[slot]+(e.speed<<4);
            e.x+=sum>>8;s.fractions[slot]=sum&255;
        }
        stepWorld23Fish(e,e.dead?32:13);e.age+=1;
        if(e.x<g.cameraX-72 || (e.age>8 && e.y>255)) s.enemies[slot]=null;
    }
}

function drawWorld23Actors(g) {
    foreach(e in g.world23.enemies) if(e!=null) {
        local texture=e.direction==1?assets.world23.right[e.displayFrame]:assets.world23.left[e.displayFrame];
        worldTexture(g,texture,e.displayX,e.displayY+1,16,24);
    }
}

function updateWorld23DeathReload(g) {
    g.deathReloadFrames+=1;
    if(g.deathReloadFrames==1) {
        g.checkpointPage=g.cameraX>=1792?7:0;g.lives-=1;
        if(g.lives<=0) {g.lives=0;g.state="gameOver";g.player.dead=false;emitSound(g,"game_over");return;}
    }
    if(g.deathReloadFrames>=166) {
        local page=g.checkpointPage;g.player=createPlayer();startWorld23(g,page);
    }
}
