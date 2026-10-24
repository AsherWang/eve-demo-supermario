// World 1-2 uses ROM area streams; the emulator is only an offline oracle.
function world12Pipe(g, x, row, height) {
    setTile(g, x, row, TILE_PIPE_TOP_LEFT);
    setTile(g, x + 1, row, TILE_PIPE_TOP_RIGHT);
    for (local y = row + 1; y <= row + height; y += 1) {
        setTile(g, x, y, TILE_PIPE_SHAFT_LEFT);
        setTile(g, x + 1, y, TILE_PIPE_SHAFT_RIGHT);
    }
    g.plants.append({x=x*16.0+8.0, y=row*16.0, baseY=row*16.0,
                     direction=1, moving=false, timer=0, active=true});
}

function world12SidePipe(g, x, bottomRow) {
    g.sidePipeX = x;
    g.world12SidePipeBottomRow <- bottomRow;
    for (local y = 2; y < bottomRow - 1; y += 1) {
        setTile(g, x + 2, y, TILE_PIPE_SHAFT_LEFT);
        setTile(g, x + 3, y, TILE_PIPE_SHAFT_RIGHT);
    }
    setTile(g, x, bottomRow - 1, TILE_SIDE_PIPE_TOP_END);
    setTile(g, x+1, bottomRow - 1, TILE_SIDE_PIPE_TOP_SHAFT);
    setTile(g, x+2, bottomRow - 1, TILE_SIDE_PIPE_TOP_JOINT);
    setTile(g, x, bottomRow, TILE_SIDE_PIPE_BOTTOM_END);
    setTile(g, x+1, bottomRow, TILE_SIDE_PIPE_BOTTOM_SHAFT);
    setTile(g, x+2, bottomRow, TILE_SIDE_PIPE_BOTTOM_JOINT);
    // RenderSidewaysPipe's fourth column is $15 on both bottom rows.
    setTile(g, x+3, bottomRow-1, TILE_PIPE_SHAFT_RIGHT);
    setTile(g, x+3, bottomRow, TILE_PIPE_SHAFT_RIGHT);
}

function decodeWorld12Area(g, data, firstPage = 0, lastPage = 12) {
    local commands = [];
    local page = 0;
    for (local cursor = 2; cursor + 1 < data.len(); cursor += 2) {
        local a = data[cursor];
        if (a == 0xFD) break;
        local b = data[cursor+1];
        local row = a & 15;
        if ((b & 128) != 0) page += 1;
        if (row == 13 && (b & 64) == 0) { page = b & 31; continue; }
        commands.append({x=page*16+(a>>4), row=row, value=b&127});
    }
    // TerrainRenderBits is read from the ROM, two bytes per 13-row mask.
    local control = data[1] & 15;
    local cursor = 0;
    for (local x = 0; x < g.areaWidth; x += 1) {
        local worldColumn = x + firstPage*16;
        while (cursor < commands.len() && commands[cursor].x < worldColumn) {
            local c = commands[cursor];
            if (c.row == 14 && (c.value & 64) == 0) control = c.value & 15;
            cursor += 1;
        }
        for (local row = 0; row < 13; row += 1) {
            local bits = ROM_TERRAIN_MASKS[control*2+(row>=8?1:0)];
            if ((bits & (1 << (row>=8?row-8:row))) != 0)
                setTile(g, x, row+2, row>=11?TILE_GROUND:TILE_BRICK);
        }
    }
    foreach (c in commands) {
        if (c.x < firstPage*16 || c.x >= (lastPage+1)*16) continue;
        local x=c.x-firstPage*16, row=c.row+2;
        local kind=(c.value>>4)&7, n=c.value&15;
        if (c.row < 12) {
            if (kind == 0) {
                local tiles=[TILE_POWERUP_BLOCK,TILE_QUESTION,TILE_HIDDEN_COIN,
                    TILE_HIDDEN_ONEUP,TILE_BRICK_POWERUP,TILE_BRICK_VINE,
                    TILE_BRICK_STAR,TILE_BRICK_COIN,TILE_BRICK_ONEUP];
                if (n<tiles.len()) setTile(g,x,row,tiles[n]);
            } else if (kind == 2 || kind == 3) {
                fillTileRow(g,x,row,n,kind==2?TILE_BRICK:TILE_SOLID);
            } else if (kind == 4) {
                for(local i=0;i<=n;i+=1)
                    g.levelCoins.append({x=(x+i)*16.0,y=row*16.0,width=16.0,height=16.0,active=true});
            } else if (kind == 5 || kind == 6) {
                fillTileColumn(g,x,row,n,kind==5?TILE_BRICK:TILE_SOLID);
            } else if (kind == 7) {
                world12Pipe(g,x,row,n&7);
                if ((n&8)!=0) g.enterablePipes.append({x=x,row=row});
            }
        } else if (c.row == 12 && kind == 0) {
            for(local i=0;i<=n;i+=1)
                for(local y=13;y<15;y+=1) setTile(g,x+i,y,TILE_EMPTY);
        } else if (c.row == 12 && (kind==6 || kind==7)) {
            fillTileRow(g,x,kind==6?5:9,n,TILE_QUESTION);
        } else if (c.row == 15 && kind==3) {
            for(local i=0;i<=n;i+=1) {
                local height=i+1;
                if(height>8) height=8;
                fillTileColumn(g,x+i,13-height,height-1,TILE_SOLID);
            }
        } else if (c.row == 15 && kind==4) {
            world12SidePipe(g,x,(n&15)+2);
        }
    }
}

function decodeWorld12Enemies(g) {
    local data=ROM_WORLD_1_2_ENEMIES, page=0, cursor=0;
    local pageSelected=false;
    while(cursor+1<data.len() && data[cursor]!=255) {
        local a=data[cursor], b=data[cursor+1], row=a&15;
        // EnemyObjectPageSel stays set across an explicit row-$0f page
        // command until the next real object. Its high bit must not advance
        // that page a second time (notably $0f,$06 followed by $60,$b8).
        if((b&128)!=0 && !pageSelected) {page+=1;pageSelected=true;}
        if(row==15 && !pageSelected) {page=b&63;pageSelected=true;cursor+=2;continue;}
        local x=(page*16+(a>>4))*16.0;
        if(row==14) {cursor+=3;pageSelected=false;continue;}
        local id=b&63;
        if(id==0 || id==3 || id==6) {
            local e=makeEnemyAt(x,row+1,id==6?"goomba":"koopa");
            e.red <- id==3;
            g.goombas.append(e);
        } else if(id>=0x37 && id<0x3f) {
            appendEnemyGroup(g,x/16.0,id);
        } else if(id==0x26 || id==0x27) {
            // ProcessEnemyData stores the stream row directly as the 8-bit
            // Enemy_Y_Position. PosPlatform then adds $0c horizontally only.
            local platformY=row*16.0;
            // LargeLiftUp/Down use signed 8.8 speed $ff:$10 / $00:$f0.
            g.platforms.append({x=x+12.0,y=platformY,initialY=platformY,
                previousY=platformY,id=id,direction=id==0x26?-1:1,
                speed=id==0x26?-240.0/256.0:240.0/256.0,
                width=48.0,awake=false});
        }
        cursor+=2;pageSelected=false;
    }
}

function world12ResetObjects(g) {
    clearAreaObjects(g);
    g.plants=[];g.platforms=[];g.enterablePipes=[];
    g.sidePipeX=-1;
    g.world12BaseTiles=[];g.world12Metatiles=[];
    g.flagX=100000.0;g.castleX=100000.0;
    g.flagY=48.0;g.preparedFlagY=48.0;g.displayFlagY=48.0;
    g.flagScoreAge=-1;g.castleFlagVisible=false;g.fireworks=[];
    g.endLevelScrollLocked=false;
}

function buildWorld12(g, stage="underground") {
    g.level=2;g.stage=stage;
    g.area=stage=="intro" || stage=="exit"?"main":"underground";
    g.areaWidth=stage=="intro"?24:(stage=="bonus"?17:208);
    if(stage=="exit") g.areaWidth=LEVEL_WIDTH;
    world12ResetObjects(g);
    if(stage=="intro") {
        g.castleX=0.0;
        for(local x=0;x<24;x+=1) {
            setTile(g,x,13,TILE_GROUND);setTile(g,x,14,TILE_GROUND);
        }
        world12SidePipe(g,10,12);
        // IntroPipe has only its lower vertical shaft and a cap at row 9.
        for(local y=2;y<9;y+=1) {
            setTile(g,12,y,TILE_EMPTY);setTile(g,13,y,TILE_EMPTY);
        }
        setTile(g,12,9,TILE_PIPE_TOP_LEFT);setTile(g,13,9,TILE_PIPE_TOP_RIGHT);
    } else if(stage=="exit") {
        decodeWorld11Foreground(g);
        // Enemy pointer $25:$0b reuses the end of GroundArea6.
        decodeWorld11Enemies(g);
        foreach(localEnemy in g.goombas) if(localEnemy.x<11*256) localEnemy.alive=false;
    } else {
        decodeWorld12Area(g,stage=="bonus"?ROM_WORLD_1_2_BONUS:ROM_WORLD_1_2_AREA,
                          stage=="bonus"?2:0,stage=="bonus"?2:12);
        applyWorld12Map(g);
        if(stage=="underground") decodeWorld12Enemies(g);
    }
}

function applyWorld12Map(g) {
    // Offline ROM parser output provides the canonical collision/graphics
    // map, including overlapping object slots and backloaded terrain changes.
    g.levelCoins=[];
    g.world12Metatiles=array(LEVEL_WIDTH*LEVEL_HEIGHT,0);
    local mapping={};
    foreach(entry in [
        [0x54,TILE_GROUND],[0x51,TILE_BRICK],[0x52,TILE_BRICK],
        [0x55,TILE_BRICK_POWERUP],[0x56,TILE_BRICK_VINE],[0x57,TILE_BRICK_STAR],
        [0x58,TILE_BRICK_COIN],[0x59,TILE_BRICK_ONEUP],[0x5a,TILE_BRICK_POWERUP],
        [0x5b,TILE_BRICK_VINE],[0x5c,TILE_BRICK_STAR],[0x5d,TILE_BRICK_COIN],
        [0x5e,TILE_BRICK_ONEUP],[0x5f,TILE_HIDDEN_COIN],[0x60,TILE_HIDDEN_ONEUP],
        [0x61,TILE_SOLID],[0x62,TILE_SOLID],[0xc0,TILE_QUESTION],[0xc1,TILE_POWERUP_BLOCK],
        [0xc4,TILE_USED],[0x10,TILE_PIPE_TOP_LEFT],[0x11,TILE_PIPE_TOP_RIGHT],
        [0x12,TILE_PIPE_TOP_LEFT],[0x13,TILE_PIPE_TOP_RIGHT],
        [0x14,TILE_PIPE_SHAFT_LEFT],[0x15,TILE_PIPE_SHAFT_RIGHT],
        [0x1c,TILE_SIDE_PIPE_TOP_END],[0x1d,TILE_SIDE_PIPE_TOP_SHAFT],[0x1e,TILE_SIDE_PIPE_TOP_JOINT],
        [0x1f,TILE_SIDE_PIPE_BOTTOM_END],[0x20,TILE_SIDE_PIPE_BOTTOM_SHAFT],[0x21,TILE_SIDE_PIPE_BOTTOM_JOINT]])
        mapping[entry[0]]<-entry[1];
    local columns=g.stage=="bonus"?ROM_WORLD_1_2_BONUS_METATILES:ROM_WORLD_1_2_METATILES;
    for(local x=0;x<columns.len();x+=1) for(local row=0;row<13;row+=1) {
        local meta=columns[x][row];
        local y=row+2;
        local tile=meta in mapping?mapping[meta]:TILE_EMPTY;
        setTile(g,x,y,tile);
        g.world12Metatiles[tileIndex(x,y)]=meta;
        if(meta==0xc2 || meta==0xc3)
            g.levelCoins.append({x=x*16.0,y=y*16.0,width=16.0,height=16.0,active=true});
    }
    g.world12BaseTiles=clone g.tiles;
}

function startWorld12(g, stage="intro") {
    buildWorld12(g,stage);
    resetPlayerForArea(g,stage=="exit"?11*256+40:40,176);
    if(stage=="underground" || stage=="bonus") resetPlayerForArea(g,40,32);
    g.player.grounded=stage=="intro" || stage=="exit";
    if (!g.player.grounded) g.player.fallForce=0x28;
    g.cameraX=stage=="exit"?11*256.0:0.0;g.displayCameraX=g.cameraX;
    g.checkpointPage=0;g.time=400;g.displayTime=400;g.gameTimerControl=23;
    g.hurryActive=false;
    g.state=stage=="intro"?"world12Intro":"playing";
    g.world12TransitionFrames=0;
    g.soundEvents.append("resume_music");
}

function startWorld12Transition(g,target,mode) {
    g.world12Target=target;g.world12PipeMode=mode;
    g.world12TransitionFrames=0;g.state="world12Pipe";
    emitSound(g,"pipe");
}

function syncWorld12Player(g) {
    local p=g.player;
    p.previousX=p.x;p.previousY=p.y;
    p.displayRelX=p.x-g.cameraX;p.displayRelY=p.y-(p.big?0:16);
    p.preparedRelX=p.displayRelX;p.queuedRelX=p.displayRelX;
    p.preparedRelY=p.displayRelY;p.queuedRelY=p.displayRelY;
}

function updateWorld12Transition(g) {
    if(g.state=="world12Intro") {
        local p=g.player;
        p.x+=1.0;p.facing=1;p.animationFrame=(g.world12TransitionFrames/8)%3;
        p.displayAnimationFrame=p.animationFrame;
        g.world12TransitionFrames+=1;
        if(p.x>=10*16-13) startWorld12Transition(g,"underground","side");
        syncWorld12Player(g);
        return true;
    }
    if(g.state!="world12Pipe") return false;
    g.world12TransitionFrames+=1;
    local f=g.world12TransitionFrames;
    local entryFrames=g.world12PipeMode=="side"?160:48;
    if(f<=entryFrames) {
        if(g.world12PipeMode=="side") {
            if((floor(g.player.x).tointeger()&15)!=0) g.player.x+=0.5;
        }
        else g.player.y+=1.0;
    } else if(f==entryFrames+26) {
        local target=g.world12Target;
        if(target=="warp") {
            // The selected destination is outside the currently implemented
            // worlds. Expose that boundary instead of loading an incorrect map.
            g.state="warpComplete";
            return true;
        }
        if(target=="return") {
            buildWorld12(g,"underground");
            // E_UndergroundArea3 page 3: $1e,$40,$07 returns to area $40,
            // entry page 7. PlayerEntranceXPos selects $38 for pipe exit.
            resetPlayerForArea(g,7*256+56,240);
            g.cameraX=7*256.0;g.displayCameraX=g.cameraX;
            foreach(e in g.goombas) if(e.x<g.cameraX-64) e.alive=false;
        } else if(target=="exit") {
            buildWorld12(g,"exit");
            resetPlayerForArea(g,11*256+56,240);
            g.cameraX=11*256.0;g.displayCameraX=g.cameraX;
        } else {
            buildWorld12(g,target);
            resetPlayerForArea(g,24,32);
            g.cameraX=0.0;g.displayCameraX=0.0;
        }
        g.soundEvents.append("resume_music");
    } else if(f>=entryFrames+27) {
        if((g.world12Target=="exit" || g.world12Target=="return") && f<entryFrames+123) {
            g.player.y-=1.0;
        } else {
            g.state="playing";
            g.player.grounded=g.stage=="exit" || g.world12Target=="return";
            g.player.nesYSpeed=0;g.player.nesYMoveForce=0;
        }
    }
    syncWorld12Player(g);
    return true;
}

function tryWorld12Pipe(g) {
    if(g.stage=="underground" && g.input.down && g.player.grounded) {
        foreach(pipe in g.enterablePipes) {
            local left=floor((g.player.x+3)/16).tointeger();
            local right=floor((g.player.x+12)/16).tointeger();
            if(left==pipe.x && right==pipe.x+1 &&
               abs(g.player.y+g.player.height-pipe.row*16)<2) {
                // Only $c2:$02 in the enemy stream leads to the bonus room.
                if(pipe.x>=178) {
                    g.warpWorld=pipe.x==178?4:(pipe.x==182?3:2);
                    startWorld12Transition(g,"warp","down");return true;
                }
                if(pipe.x!=103) continue;
                startWorld12Transition(g,"bonus","down");return true;
            }
        }
    }
    if((g.stage=="underground" || g.stage=="bonus") && g.sidePipeX>=0 &&
       g.player.grounded && g.input.right &&
       g.player.y+g.player.height>=(g.world12SidePipeBottomRow-1)*16 &&
       g.player.y<(g.world12SidePipeBottomRow+1)*16 &&
       g.player.x+g.player.width>=g.sidePipeX*16-1) {
        startWorld12Transition(g,g.stage=="bonus"?"return":"exit","side");return true;
    }
    return false;
}

function updateWorld12Platforms(g) {
    local p=g.player;
    foreach(platform in g.platforms) {
        if(!platform.awake) {
            local parserBoundary=floor((g.cameraX+LOGICAL_WIDTH-1.0+48.0)/16.0)*16.0;
            if(platform.x-12.0>parserBoundary) continue;
            platform.awake=true;
        }

        // RunLargePlatform checks collision at the old coordinate, advances
        // Enemy_Y_Position, then calls PositionPlayerOnVPlat. Keep that order.
        local previousY=platform.y;
        local unwrappedY=previousY+platform.speed;
        platform.previousY=previousY;
        platform.y=unwrappedY;
        if(platform.y<0.0) platform.y+=256.0;
        if(platform.y>=256.0) platform.y-=256.0;

        if(p.dead || p.nesYSpeed<0.0) continue;
        local previousFeet=p.previousY+p.height;
        local currentFeet=p.y+p.height;
        local wasRiding=abs(previousFeet-previousY)<=2.0;
        local crossedTop=previousFeet<=previousY+2.0 &&
            currentFeet>=unwrappedY;
        if(!wasRiding && !crossedTop) continue;
        if(p.x+p.width<=platform.x || p.x>=platform.x+platform.width) continue;

        // PositionPlayerOnVPlat clears Player_Y_Speed and MoveForce. The low
        // Y byte wraps at 256, so the rider crosses the same screen boundary.
        p.y=platform.y-p.height;
        p.grounded=true;
        p.vy=0.0;
        p.nesYSpeed=0;
        p.nesYMoveForce=0;
    }
}

function updateWorld12Actors(g) {
    local p=g.player;
    foreach(plant in g.plants) {
        if(!plant.active || plant.x>g.cameraX+304 || plant.x<g.cameraX-32) continue;
        if(plant.timer>0) plant.timer-=1;
        else {
            if(!plant.moving) {
                if(plant.direction>0 && abs(p.x-plant.x)<33) continue;
                plant.direction=-plant.direction;plant.moving=true;
            }
            // MovePiranhaPlant compares only the destination of this leg,
            // and only after its odd-frame movement. Testing both endpoints
            // on a skipped frame reverses a new rise at its starting point.
            if((g.nesFrameCounter&1)!=0) {
                local target=plant.direction<0?plant.baseY-24:plant.baseY;
                plant.y=clampValue(plant.y+plant.direction,plant.baseY-24,plant.baseY);
                if(plant.y==target) {
                    plant.moving=false;plant.timer=64;
                }
            }
        }
        foreach(ball in g.fireballs) {
            if(ball.active && !ball.exploding && overlaps(ball.x,ball.y,ball.width,ball.height,
                plant.x+3,plant.y+1,10,22)) {
                plant.active=false;g.score+=200;explodeFireball(ball);emitSound(g,"kick");
            }
        }
        if(plant.active && plant.y<plant.baseY && !p.dead &&
           overlaps(p.x+3,p.y+4,10,p.height-4,plant.x+3,plant.y+1,10,22)) {
            if(p.starTimer>0) {plant.active=false;g.score+=200;}
            else hurtPlayer(g);
        }
    }
    updateWorld12Platforms(g);
}

function runWorld12LiftSelfTest() {
    local g=createGame();startWorld12(g,"underground");
    requireSelfTest(g.platforms.len()==4,"1-2 lift decode count");
    local expected=[
        {x=139*16.0+12.0,y=112.0,direction=1},
        {x=139*16.0+12.0,y=208.0,direction=1},
        {x=154*16.0+12.0,y=16.0,direction=-1},
        {x=154*16.0+12.0,y=144.0,direction=-1}
    ];
    for(local i=0;i<expected.len();i+=1) {
        local lift=g.platforms[i],want=expected[i];
        requireSelfTest(abs(lift.x-want.x)<0.001 && abs(lift.y-want.y)<0.001,
            "1-2 lift must use ROM row Y and PosPlatform X");
        requireSelfTest(lift.direction==want.direction &&
            abs(abs(lift.speed)-240.0/256.0)<0.001,
            "1-2 large lift must use ROM 8.8 direction and speed");
        requireSelfTest(getTile(g,floor(lift.x/16).tointeger(),13)==TILE_EMPTY,
            "ROM lift columns must align with map gaps, not the exit brick wall");
    }

    // ProcessEnemyData admits a platform through its extended right edge;
    // the first activated frame advances it once, as RunLargePlatform does.
    g.goombas=[];g.plants=[];
    local activate=g.platforms[0];
    g.cameraX=activate.x-12.0-(LOGICAL_WIDTH-1.0+48.0)-1.0;
    updateWorld12Platforms(g);
    requireSelfTest(!activate.awake && abs(activate.y-112.0)<0.001,
        "1-2 lift must remain dormant beyond the parser boundary");
    g.cameraX=activate.x-12.0-(LOGICAL_WIDTH-1.0+48.0);
    updateWorld12Platforms(g);
    requireSelfTest(activate.awake && abs(activate.y-(112.0+15.0/16.0))<0.001,
        "1-2 lift must activate and move at the ROM parser boundary");

    // Run an ascending lift through several 256-pixel cycles while Mario is
    // attached. The old 32-pixel seed put his feet 32 pixels inside or below
    // the lift, and the old one-way contact test dropped him on descent.
    startWorld12(g,"underground");
    g.goombas=[];g.plants=[];g.state="playing";g.cameraX=0.0;
    local rising=g.platforms[3];
    rising.awake=true;
    local p=g.player;
    p.x=rising.x+16.0;p.y=rising.y-p.height;
    p.previousX=p.x;p.previousY=p.y;
    p.grounded=true;p.vy=0.0;p.nesYSpeed=0;p.nesYMoveForce=0;
    local risingWraps=0;
    for(local frame=0;frame<720;frame+=1) {
        simulateFixed(g,FIXED_DT);
        requireSelfTest(abs((p.y+p.height)-rising.y)<0.001,
            "rider must stay attached to a rising 1-2 lift");
        if(rising.previousY<32.0 && rising.y>224.0) risingWraps+=1;
    }
    requireSelfTest(risingWraps>=2 && abs(rising.x-(154*16.0+12.0))<0.001,
        "rising 1-2 lift must wrap repeatedly without horizontal drift");

    // Drive a descending lift through its wrap in the opposite direction.
    startWorld12(g,"underground");
    g.goombas=[];g.plants=[];g.state="playing";g.cameraX=0.0;
    local falling=g.platforms[0];
    falling.awake=true;
    p=g.player;
    p.x=falling.x+16.0;p.y=falling.y-p.height;
    p.previousX=p.x;p.previousY=p.y;
    p.grounded=true;p.vy=0.0;p.nesYSpeed=0;p.nesYMoveForce=0;
    local fallingWraps=0;
    for(local frame=0;frame<400;frame+=1) {
        simulateFixed(g,FIXED_DT);
        requireSelfTest(abs((p.y+p.height)-falling.y)<0.001,
            "rider must stay attached to a descending 1-2 lift");
        if(falling.previousY>224.0 && falling.y<32.0) fallingWraps+=1;
    }
    requireSelfTest(fallingWraps>=1,"descending 1-2 lift must cross the Y wrap");
    print("World 1-2 lift self-test passed.\n");
}

function runWorld12SelfTest() {
    local g=createGame();startWorld12(g,"underground");
    requireSelfTest(g.areaWidth==208 && g.level==2,"1-2 area dimensions");
    requireSelfTest(getTile(g,10,9)==TILE_POWERUP_BLOCK,"1-2 opening mushroom at ROM column 10");
    runWorld12LiftSelfTest();
    startWorld12(g,"underground");
    requireSelfTest(g.plants.len()==6,"1-2 six ROM pipe plants");
    requireSelfTest(g.sidePipeX==166,"1-2 exit pipe at ROM column 166");
    requireSelfTest(getTile(g,80,13)==TILE_EMPTY,"1-2 gap at ROM column 80");
    requireSelfTest(getTile(g,103,10)==TILE_PIPE_TOP_LEFT,"1-2 bonus pipe at ROM column 103");
    g.player.x=166*16-16;g.player.y=0;g.player.height=16;
    g.player.grounded=true;g.input.right=true;
    requireSelfTest(!tryWorld12Pipe(g),"1-2 roof bypass must not enter the side pipe");
    g.player.vx=60;movePlayerX(g,g.player,FIXED_DT);
    requireSelfTest(!g.player.sidePipeCollision,"1-2 side pipe must not block the roof route");
    g.player.x=166*16-g.player.width-1;g.player.y=144;
    requireSelfTest(tryWorld12Pipe(g),"1-2 side pipe mouth accepts the player");
    startWorld12(g,"underground");
    startWorld12Transition(g,"bonus","down");
    for(local i=0;i<76;i+=1) updateWorld12Transition(g);
    requireSelfTest(g.stage=="bonus" && g.state=="playing","1-2 bonus-room transition");
    startWorld12Transition(g,"return","side");
    for(local i=0;i<284;i+=1) updateWorld12Transition(g);
    requireSelfTest(g.stage=="underground" && g.player.x==1848,"1-2 bonus return");
    startWorld12Transition(g,"exit","side");
    for(local i=0;i<284;i+=1) updateWorld12Transition(g);
    requireSelfTest(g.stage=="exit" && g.area=="main","1-2 surface exit");
    startWorld12(g,"intro");
    foreach(row in [10,11,12])
        requireSelfTest(getTile(g,13,row)==TILE_PIPE_SHAFT_RIGHT,
                        "1-2 intro pipe right shaft must reach the floor");
    runWorld12PlantSelfTest();
    runWorld12EnemyPipeSelfTest();
    print("World 1-2 simulation self-test passed.\n");
}

function runWorld12PlantSelfTest() {
    local g=createGame();startWorld12(g,"underground");
    local plant=g.plants[0];
    g.plants=[plant];g.platforms=[];
    g.cameraX=plant.x-128;g.player.x=plant.x-80;
    g.nesFrameCounter=0;
    updateWorld12Actors(g);
    requireSelfTest(plant.moving && plant.direction==-1 && plant.y==plant.baseY,
                    "a skipped plant movement frame must not complete the new rise");
    local reachedTop=false,reachedBottom=false;
    for(local frame=1;frame<=4000;frame+=1) {
        g.nesFrameCounter=frame&255;
        updateWorld12Actors(g);
        requireSelfTest(plant.y>=plant.baseY-24 && plant.y<=plant.baseY,
                        "plant must remain inside its 24-pixel pipe travel for long cycles");
        if(plant.y==plant.baseY-24) reachedTop=true;
        if(reachedTop && plant.y==plant.baseY) reachedBottom=true;
    }
    requireSelfTest(reachedTop && reachedBottom,"plant must both emerge and retract");
    plant.y=plant.baseY;plant.direction=1;plant.moving=false;plant.timer=0;
    g.player.x=plant.x;
    for(local frame=0;frame<128;frame+=1) {
        g.nesFrameCounter=frame;updateWorld12Actors(g);
    }
    requireSelfTest(plant.y==plant.baseY && !plant.moving,
                    "a player at the pipe must prevent a hidden plant from emerging");
}

function runWorld12EnemyPipeSelfTest() {
    local g=createGame();startWorld12(g,"underground");
    local leftPipe=103*TILE_SIZE.tofloat(),rightPipe=109*TILE_SIZE.tofloat();
    foreach(kind in ["goomba","koopa"]) {
        local enemy=makeEnemyAt(leftPipe+8,12,kind);
        enemy.grounded=true;
        for(local frame=0;frame<1200;frame+=1) {
            moveEnemyBody(g,enemy,FIXED_DT);
            requireSelfTest(enemy.x>=leftPipe+32 && enemy.x+16<=rightPipe,
                            "a grouped enemy must leave a pipe and bounce between pipe walls");
        }
        enemy=makeEnemyAt(leftPipe+8,12,kind);
        enemy.vx=KOOPA_WALK_SPEED;enemy.grounded=true;
        moveEnemyBody(g,enemy,FIXED_DT);
        requireSelfTest(enemy.x+16<=leftPipe && enemy.vx<0,
                        "an embedded right-moving enemy must resolve left of the whole pipe");
    }
}

// Development-only visual scenes; movement uses the same runtime actor passes.
function setupWorld12ActorPreview(g,scenario) {
    startWorld12(g,"underground");
    local p=g.player;
    p.big=true;p.fire=true;p.height=32;
    g.goombas=[];
    if(scenario=="world12-pipes") {
        g.cameraX=103*16.0-80;p.x=103*16.0-48;p.y=176;p.grounded=true;
        g.platforms=[];
        local enemy=makeEnemyAt(103*16.0+8,12,"goomba");
        enemy.awake=true;enemy.slot=0;g.goombas.append(enemy);
        for(local frame=0;frame<48;frame+=1) {
            g.nesFrameCounter=frame;
            moveEnemyBody(g,enemy,FIXED_DT);
            updateWorld12Actors(g);
        }
    } else {
        g.plants=[];
        local lift=g.platforms[3];lift.awake=true;
        g.cameraX=lift.x-112;p.x=lift.x+16;p.y=lift.y-p.height;
        p.previousY=p.y;p.grounded=true;
        for(local frame=0;frame<64;frame+=1) simulateFixed(g,FIXED_DT);
    }
    g.displayCameraX=g.cameraX;
    syncWorld12Player(g);
    g.state="preview";
}

function drawWorld12Actors(g, behind) {
    if(behind) {
        foreach(plant in g.plants) {
            if(!plant.active) continue;
            local phase=(g.nesFrameCounter/8)%2;
            worldTexture(g,assets.world12.plants[phase],floor(plant.x),floor(plant.y)+1,16,24);
        }
    } else {
        foreach(platform in g.platforms) {
            if(platform.awake)
                worldTexture(g,assets.world12.platform,floor(platform.x),floor(platform.y)+1,48,8);
        }
        if(g.stage=="underground" && g.cameraX>=176*16) {
            drawHudGlyphs([0x20,0x0E,0x15,0x0C,0x18,0x16,0x0E,0x24,0x1D,0x18,0x24,
                0x20,0x0A,0x1B,0x19,0x24,0x23,0x18,0x17,0x0E,0x2B],40,64);
            foreach(entry in [{x=178,n=4},{x=182,n=3},{x=186,n=2}])
                worldTexture(g,assets.hudFont[entry.n],entry.x*16+12,128,8,8);
        }
    }
}

function initializeWorld12Parity(g) {
    startWorld12(g,"underground");
    g.areaEntranceFrames=0;g.state="areaEntrance";
    for(local frame=0;frame<17;frame+=1) updateAreaEntrance(g);
    g.player.y+=nesVerticalDelta(g.player,false);
    g.player.vy=g.player.nesYSpeed*NES_FRAME_RATE;
    // Captured first PlayerCtrlRoutine frame: FrameCounter=$2a.
    g.nesFrameCounter=42;g.colorRotateOffset=3;g.displayColorPhase=2;
    g.pendingColorPhase=3;g.colorPhasePending=true;
    g.player.movingDir=0;
    for(local frame=0;frame<19;frame+=1) updateGoombas(g,FIXED_DT);
    syncWorld12Player(g);
    g.player.animationFrame=0;g.player.displayAnimationFrame=0;
    g.player.preparedAnimationFrame=0;g.player.queuedAnimationFrame=0;
    // Captured origin frame: player OAM X/Y are 40/50 and the rendered
    // 16x32 canvas begins at Y=46.  Preserve that already-visible page while
    // the first controllable simulation stage prepares its next OAM values.
    g.player.displayRelY=46;g.player.preparedRelY=48;g.player.queuedRelY=48;
}
