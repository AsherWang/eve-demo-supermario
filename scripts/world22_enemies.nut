// Water enemy state is separate from terrain and the land-walker integrator.
function world22BlooperSpawns() {
    local result=[],page=0,data=ROM_WORLD_2_2_WATER_ENEMIES;
    for(local i=0;i<data.len() && data[i]!=255;) {
        local a=data[i],b=data[i+1],row=a&15;
        if(b&128) page+=1;
        if(row==15 && !(b&128)) {page=b&63;i+=2;continue;}
        if(row==14) {i+=3;continue;}
        if((b&63)==7)
            result.append({x=(page*16+(a>>4))*16,y=row*16+8,hard=(b&64)!=0});
        i+=2;
    }
    return result;
}

function world22FrenzyData() {
    local result={},page=0,data=ROM_WORLD_2_2_WATER_AREA;
    for(local i=2;i+1<data.len();i+=2) {
        local a=data[i],b=data[i+1],row=a&15,value=b&127;
        if(a==253) break;if(b&128) page+=1;
        if(row==13 && !(value&64)) {page=value&31;continue;}
        if(row==13 && (value==0x49 || value==0x4a))
            result[page*16+(a>>4)] <- value==0x49;
    }
    return result;
}

function world22AdvanceRandom(bytes) {
    local carry=((bytes[0]^bytes[1])&2)!=0?1:0;
    for(local i=0;i<7;i+=1) {
        local next=bytes[i]&1;bytes[i]=(bytes[i]>>1)|(carry<<7);carry=next;
    }
}

function stepWorld22Blooper(e,frame,randomByte,playerX,playerY,playerDirection) {
    if((randomByte&63)==0) {
        if(e.slot&1) e.direction=playerDirection;
        else e.direction=e.x>=playerX?2:1;
    }
    if(e.phase&2) {
        // The preceding LSR sets carry to zero for phase 2, retained by ADC.
        if(e.timer==0 && ((e.y+16)&255)>=playerY) e.phase=0;
        else if(!(frame&1)) e.y=(e.y+1)&255;
    } else if((frame&7)==0) {
        e.force=(e.force+((e.phase&1)?-1:1))&255;e.speed=e.force;
        if(!(e.phase&1) && e.force==2) e.phase+=1;
        else if((e.phase&1) && e.force==0) {e.phase+=1;e.timer=2;}
    }
    local y=(e.y-e.force)&255;
    if(y>=32) e.y=y;
    e.x+=e.direction==1?e.speed:-e.speed;
}

function initializeWorld22Enemies(g) {
    g.world22.spawns <- world22BlooperSpawns();g.world22.spawnCursor <- 0;
    g.world22.enemies <- array(5,null);
    g.world22.random <- [165,0,0,0,0,0,0];
    g.world22.frenzy <- false;g.world22.frenzyTimer <- 0;g.world22.heightMask <- 0;
    g.world22.frenzyColumn <- -1;g.world22.frenzyCommands <- world22FrenzyData();
    // Checkpoint parsing skips source commands left of the loaded screen.
    while(g.world22.spawnCursor<g.world22.spawns.len() &&
        g.world22.spawns[g.world22.spawnCursor].x<g.cameraX+255)
        g.world22.spawnCursor+=1;
}

function updateWorld22Enemies(g) {
    local state=g.world22,p=g.player;
    world22AdvanceRandom(state.random);
    if(p.dead || p.transformFrames>0) return;
    local camera=g.cameraX;
    if(p.nesXScroll>0 && !p.scrollSideCollisionTimer && p.preparedRelX>=80) {
        local scroll=p.nesXScroll;if(p.preparedRelX<112 && scroll>=2) scroll-=1;
        camera+=scroll;
    }
    local frame=(g.nesFrameCounter+1)&255;
    if(state.frenzyTimer>0) state.frenzyTimer-=1;
    // Task 6 parses the first column in each 32-pixel parser batch, 22
    // columns ahead of the camera. The next actor pass consumes its queue.
    if(g.vramAreaParserTask==6) {
        local column=floor(g.cameraX/32).tointeger()*2+22;
        if(column!=state.frenzyColumn && column in state.frenzyCommands) {
            state.frenzyColumn=column;state.frenzy=state.frenzyCommands[column];
        }
    }
    for(local slot=0;slot<5;slot+=1) {
        local e=state.enemies[slot];
        if(e==null) {
            if((g.vramAreaParserTask&7)==7) continue;
            local spawn=state.spawnCursor<state.spawns.len()?state.spawns[state.spawnCursor]:null;
            local fish=spawn==null || spawn.x>camera+303;
            if(fish) {
                if(!state.frenzy || state.frenzyTimer>0 || slot>=3) continue;
                if(state.heightMask==255) state.heightMask=0;
                local height=state.random[slot]&7;
                while(state.heightMask&(1<<height)) height=(height+1)&7;
                state.heightMask=state.heightMask|(1<<height);
                spawn={x=camera+287,y=[64,48,144,80,32,96,160,112][height]+8};
                state.frenzyTimer=32;
            } else if(spawn.x<camera+255 || spawn.hard) {state.spawnCursor+=1;continue;}
            e={kind=fish?"cheep":"blooper",slot=slot,x=spawn.x.tofloat(),y=spawn.y,
                speed=0,force=0,phase=0,timer=0,direction=2,
                previousX=spawn.x.tofloat(),previousY=spawn.y,
                displayX=spawn.x.tofloat(),displayY=spawn.y,displayFrame=1,
                preparedX=spawn.x.tofloat(),preparedY=spawn.y,preparedFrame=1,
                dead=false,nesYSpeed=0,nesYMoveForce=0,nesYDummy=0};
            e.id <- fish?(state.random[slot]>=170?11:10):7;
            e.xForce <- 0;e.fishDummy <- 0;
            e.fishDirection <- state.random[slot]&16;e.originY <- spawn.y;
            state.enemies[slot]=e;if(!fish) state.spawnCursor+=1;
            continue; // InitEnemyObject does not run movement on the allocation pass.
        }
        if(e.timer>0 && g.intervalTimerControl==20) e.timer-=1;
        e.displayX=e.preparedX;e.displayY=e.preparedY;e.displayFrame=e.preparedFrame;
        e.previousX=e.x;e.previousY=e.y;
        e.preparedX=e.x;e.preparedY=e.y;e.preparedFrame=e.kind=="blooper"?(e.timer==1?0:1):((frame&8)!=0?0:1);
        if(e.dead) {
            e.y+=world22VerticalDelta(e,0x20,2);
            if(e.y>255) {state.enemies[slot]=null;continue;}
        } else {
            // SmallEnemyBoundingBox $09: [3,14,13,20]. Water contact hurts;
            // descending onto a squid must never execute the land stomp path.
            local py=p.y-(p.big?0:16);
            if(!(frame&1) && e.x>=camera && e.x<camera+256 &&
                overlaps(p.x+(p.big?2:3),py+(p.big?8:20),p.big?13:11,p.big?25:13,
                    e.previousX+3,e.previousY+14,11,7)) {
                if(p.starTimer>0) {e.dead=true;e.nesYSpeed=-3;awardScoreControl(g,2);emitSound(g,"kick");}
                else {hurtPlayer(g,e);if(p.dead || p.transformFrames>0) return;}
            }
            if(e.dead) e.y+=world22VerticalDelta(e,0x20,2);
            else if(e.kind=="blooper") stepWorld22Blooper(e,frame,state.random[slot+1],p.x,
                (p.y-(p.big?0:16)).tointeger()&255,p.movingDir);
            else stepWorld22Cheep(e);
        }
        if(e.x<camera-73 || e.x>=camera+328) state.enemies[slot]=null;
    }
}

function drawWorld22Enemies(g) {
    for(local slot=4;slot>=0;slot-=1) {
        local e=g.world22.enemies[slot];if(e==null) continue;
        local frame=e.displayFrame;
        local texture=e.kind=="blooper"?assets.world22.bloopers[frame]:
            assets.world22.fish[e.id==11?1:0][frame];
        worldTexture(g,texture,e.displayX,
            e.displayY+(e.kind=="blooper" && frame==1?3:0)+1,16,24);
    }
}

function stepWorld22Cheep(e) {
    local sum=e.xForce-(e.id==10?64:128);
    e.xForce=sum&255;if(sum<0) e.x-=1;
    if(e.slot<2) return;
    local downward=e.fishDirection>=16;
    sum=e.fishDummy+(downward?32:-32);e.fishDummy=sum&255;
    if(sum<0) e.y-=1;else if(sum>=256) e.y+=1;
    local delta=e.y-e.originY;
    if(abs(delta)>=15) e.fishDirection=delta<0?16:0;
}
