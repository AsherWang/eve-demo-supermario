persist game = null
persist assets = null
persist nativeAudio = null
persist nativeAudioCaptureTime = 0.0
persist musicState = null
persist hurryMusicTime = 0.0
persist levelTwoKeyDown = false
persist levelThreeKeyDown = false
persist levelFourKeyDown = false
persist levelFiveKeyDown = false

dofile("scripts/core.nut");
dofile("scripts/generated/rom_data.nut");
dofile("scripts/generated/hurry_audio.nut");
dofile("scripts/generated/world12_data.nut");
dofile("scripts/generated/world12_map.nut");
dofile("scripts/generated/world12_bonus_map.nut");
dofile("scripts/generated/parity_movie.nut");
dofile("scripts/level.nut");
dofile("scripts/audio.nut");
dofile("scripts/simulation.nut");
dofile("scripts/world12.nut");
dofile("scripts/generated/world13_data.nut");
dofile("scripts/generated/world13_map.nut");
dofile("scripts/world13.nut");
dofile("scripts/world14.nut");
dofile("scripts/world21.nut");
dofile("scripts/title.nut");
dofile("scripts/levels.nut");
dofile("scripts/render.nut");
dofile("scripts/parity.nut");
dofile("scripts/generated/koopa_bounce_trace.nut");
dofile("scripts/bounce_regression.nut");
dofile("scripts/powerup_regression.nut");
dofile("scripts/shell_regression.nut");

eve_init = function() {
    // Ground-area backdrop is palette index $22.  Match the Mesen 2C02
    // reference palette exactly so frame comparisons measure scene output.
    gfx.setBackgroundColor(146.0 / 255.0, 144.0 / 255.0, 1.0, 1.0);
    loadAssets();
    loadWorld13Assets();
    loadWorld14Assets();
    loadWorld21Assets();
    loadTitleAssets();
    loadAudio();
    if (!("startupSelfTests" in config) || config.startupSelfTests || parityIsEnabled()) {
        runSimulationSelfTest();
        runWorld12SelfTest();
        runWorld13SelfTest();
        runWorld14SelfTest();
        runWorld1StageFlowSelfTest();
        runWorld21SelfTest();
        runKoopaBounceSelfTest();
        runPowerUpGapSelfTest();
        runShellDefeatSelfTest();
    }
    game = createGame();
    if ("startLevel" in config && config.startLevel == 2)
        startWorld12(game, ("startArea" in config) ? config.startArea : "intro");
    if ("startLevel" in config && config.startLevel == 3) startWorld1Stage(game,3);
    if ("startLevel" in config && config.startLevel == 4) startWorld1Stage(game,4);
    if("startWorld" in config && config.startWorld==2) startLevel(game,2,1);
    if (parityIsEnabled() && "PARITY_START_LEVEL" in getroottable() && PARITY_START_LEVEL == 2)
        initializeWorld12Parity(game);
    if (parityIsEnabled() && "PARITY_START_LEVEL" in getroottable() && PARITY_START_LEVEL == 3) {
        startWorld1Stage(game,3);
        initializeWorld13Parity(game);
    }
    if (parityIsEnabled() && "PARITY_START_LEVEL" in getroottable() && PARITY_START_LEVEL == 4)
        startWorld1Stage(game,4);
    if(parityIsEnabled() && "PARITY_START_WORLD" in getroottable() && PARITY_START_WORLD==2) {
        startLevel(game,2,1);
        initializeWorld21Parity(game);
    }
    parityInitialize(game);
    if (config.previewScenario == "world12-pipes" || config.previewScenario == "world12-lifts") {
        setupWorld12ActorPreview(game,config.previewScenario);
    } else if (config.previewScenario == "underground") {
        buildUndergroundBonus(game);
        game.player.x = 40.0;
        game.player.y = 192.0;
        game.player.grounded = true;
    } else if (config.previewScenario == "flag") {
        game.cameraX = game.flagX - 112.0;
        game.player.x = game.flagX - game.player.width + 3.0;
        game.player.y = 192.0;
        game.flagY = 170.0;
        game.state = "preview";
    } else if (config.previewScenario == "castle") {
        game.cameraX = game.castleX - 120.0;
        game.castleFlagVisible = true;
        game.castleFlagY = 113.0;
        game.state = "preview";
        game.fireworks.append({ x = game.castleX + 16.0, y = 48.0, frames = 999 });
    } else if (config.previewScenario == "star") {
        game.player.x = 112.0;
        game.player.y = 176.0;
        game.player.big = true;
        game.player.height = 32.0;
        game.player.grounded = true;
        game.player.starTimer = STAR_INVINCIBLE_TIME;
        game.state = "preview";
    } else if (config.previewScenario == "flower") {
        game.player.x = 112.0;
        game.player.y = 176.0;
        game.player.big = true;
        game.player.fire = true;
        game.player.height = 32.0;
        game.player.grounded = true;
        game.player.transformFrames = 63;
        game.player.transformKind = "fire";
        game.state = "preview";
    } else if (config.previewScenario == "items") {
        foreach (enemy in game.goombas) enemy.alive = false;
        game.cameraX = 20.0 * TILE_SIZE - 112.0;
        game.player.big = true;
        game.player.height = 32.0;
        setTile(game, 20, 9, TILE_POWERUP_BLOCK);
        hitBlock(game, 20, 9);
        for (local i = 0; i < 68; i += 1)
            movePowerUp(game, game.powerups[0], FIXED_DT);
        game.state = "preview";
    } else if (config.previewScenario == "shell") {
        local previewKoopa = null;
        foreach (enemy in game.goombas) {
            if (enemy.kind == "koopa" && previewKoopa == null) {
                previewKoopa = enemy;
            } else {
                enemy.alive = false;
            }
        }
        enterKoopaShell(previewKoopa);
        previewKoopa.awake = true;
        previewKoopa.slot = 0;
        previewKoopa.queuedState = "shell";
        previewKoopa.preparedState = "shell";
        previewKoopa.displayState = "shell";
        game.cameraX = previewKoopa.x - 112.0;
        game.player.x = previewKoopa.x - 32.0;
        game.player.y = 192.0;
        game.state = "preview";
    }
    if (config.capturePreview && config.previewCameraX > 0.0) {
        game.cameraX = config.previewCameraX;
        game.displayCameraX = game.cameraX;
        game.player.x = config.previewCameraX + 32.0;
    }
    if (game.world==1 && game.level == 1 && game.area == "main") validateLevel(game);
    print("World 1-1 remake ready: arrows/A-D move, X/Shift run or throw, Z/Space jump, R reset.\n");
};

eve_update = function(dt) {
    if (parityIsEnabled()) {
        parityAdvanceOneFrame(game);
        flushSoundEvents(game);
        updateMusic(dt);
        return;
    }

    local frameDt = dt;
    if (frameDt < 0.0) frameDt = 0.0;
    if (frameDt > 0.25) frameDt = 0.25;

    sampleInput(game);
    local levelTwoKey=keyboard.isDown("F2");
    if(levelTwoKey && !levelTwoKeyDown) startWorld12(game);
    levelTwoKeyDown=levelTwoKey;
    local levelThreeKey=keyboard.isDown("F3");
    if(levelThreeKey && !levelThreeKeyDown) startWorld1Stage(game,3);
    levelThreeKeyDown=levelThreeKey;
    local levelFourKey=keyboard.isDown("F4");
    if(levelFourKey && !levelFourKeyDown) startWorld1Stage(game,4);
    levelFourKeyDown=levelFourKey;
    local levelFiveKey=keyboard.isDown("F5");
    if(levelFiveKey && !levelFiveKeyDown) startLevel(game,2,1);
    levelFiveKeyDown=levelFiveKey;
    game.accumulator += frameDt;

    local steps = 0;
    while (game.accumulator >= FIXED_DT && steps < MAX_STEPS_PER_FRAME) {
        simulateFixed(game, FIXED_DT);
        game.accumulator -= FIXED_DT;
        game.input.jumpQueued = false;
        game.input.fireQueued = false;
        game.input.resetQueued = false;
        steps += 1;
    }

    flushSoundEvents(game);
    updateMusic(frameDt);

    if (steps == MAX_STEPS_PER_FRAME && game.accumulator >= FIXED_DT)
        game.accumulator = 0.0;
};

eve_render = function() {
    // saveFramePng reads the last presented buffer. Consume that buffer
    // before preparing the next one, including the initial OAM/VRAM page.
    if (parityIsEnabled()) parityCaptureRenderedFrame(game);
    renderGame(game);
    if (config.capturePreview && !game.previewCaptured && game.simTime > 0.5) {
        local previewName = "world-1-" + game.level + "-" + config.previewScenario + "-preview.png";
        if (gfx.saveFramePng(previewName)) game.previewCaptured = true;
    }
};

eve_reload <- function() { eve_init(); };

eve_quit = function() {
    if (nativeAudio != null) nativeAudio.close();
};
