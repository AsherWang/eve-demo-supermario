// Shared World 1 entry points. Level-specific data and actors live in their
// own scripts; all entries preserve the score, coin tally and lives.
function startWorld1Stage(g, stage, newLife=false) {
    return startLevel(g,1,stage,newLife);
}

function startLevel(g, world, stage, newLife=false) {
    if((world!=1 || stage<1 || stage>4) && !(world==2 && stage==1))
        throw "Unsupported world/stage";
    local score=g.score, coins=g.coins, lives=g.lives, input=g.input;
    local frameCounter=g.nesFrameCounter;
    local big=!newLife && g.player.big, fire=!newLife && g.player.fire;
    local fresh=createGame();
    foreach(key,value in fresh) g[key]=value;
    g.score=score;g.queuedScore=score;g.displayScore=score;
    g.coins=coins;g.queuedCoins=coins;g.displayCoins=coins;
    g.lives=lives;g.input=input;
    g.player.big=big;g.player.fire=fire;g.player.height=big?32.0:16.0;
    if(world==2) {g.nesFrameCounter=frameCounter;startWorld21(g);}
    else if(stage==1) {
        resetPlayerForArea(g,40,176);
        g.soundEvents.append("resume_music");
    } else if(stage==2) startWorld12(g);
    else if(stage==3) startWorld13(g);
    else if(stage==4) startWorld14(g);
    else throw "World 1 stage must be in 1..4";
}

function updateWorld1StageDeath(g) {
    g.deathReloadFrames+=1;
    if(g.deathReloadFrames==1) {
        g.checkpointPage=g.world==2 ? (g.cameraX>=1536.0?6:0) :
            (g.level==3 && g.cameraX>=1024.0?4:0);
        g.lives-=1;
        if(g.lives<=0) {
            g.state="gameOver";g.player.dead=false;
            emitSound(g,"game_over");return;
        }
    }
    if(g.deathReloadFrames>=166) {
        local world=g.world,stage=g.level,page=g.checkpointPage;
        startLevel(g,world,stage,true);
        if(page>0) {
            g.checkpointPage=page;
            g.cameraX=page*256.0;g.displayCameraX=g.cameraX;
            resetPlayerForArea(g,page*256+40,176);
            g.player.grounded=true;g.player.entranceFalling=false;
            foreach(enemy in g.goombas)
                if(enemy.x<g.cameraX+LOGICAL_WIDTH-1) enemy.alive=false;
        }
    }
}

function runWorld1StageFlowSelfTest() {
    foreach(power in [0,1,2]) {
        local g=createGame();
        startWorld1Stage(g,3);
        g.player.big=power>0;g.player.fire=power==2;
        g.player.height=power>0?32.0:16.0;
        g.score=15300;g.coins=2;
        g.state="levelComplete";
        for(local frame=0;frame<167;frame+=1) simulateFixed(g,FIXED_DT);
        requireSelfTest(g.level==4 && g.state=="playing" &&
            g.player.big==(power>0) && g.player.fire==(power==2) &&
            g.score==15300 && g.coins==2 && g.time==300,
            "1-3 course clear must finish loading 1-4 and retain powers/progress");
        local entranceX=g.player.x;
        g.input.right=true;
        for(local frame=0;frame<20;frame+=1) simulateFixed(g,FIXED_DT);
        requireSelfTest(g.player.x>entranceX && !g.player.dead,
            "1-4 must accept movement after the 1-3 loading sequence");
    }
    foreach(stage in [3,4]) {
        local g=createGame();g.score=12000;g.coins=17;g.lives=3;
        g.player.big=true;g.player.fire=true;
        startWorld1Stage(g,stage);
        requireSelfTest(g.level==stage && g.player.big && g.player.fire &&
            g.score==12000 && g.coins==17 && g.lives==3,
            "World 1 stage entry must preserve persistent player progress");
        finishPlayerDeath(g);
        for(local frame=0;frame<166;frame+=1) updateWorld1StageDeath(g);
        requireSelfTest(g.level==stage && g.lives==2 && !g.player.big &&
            !g.player.fire && !g.player.dead && g.score==12000 && g.coins==17,
            "new World 1 stage lives must reset powers without losing progress");
    }
}
