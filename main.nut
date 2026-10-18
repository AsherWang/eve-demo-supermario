persist game = null
persist assets = null
persist soundSources = null
persist musicState = null

dofile("scripts/core.nut");
dofile("scripts/generated/rom_data.nut");
dofile("scripts/generated/parity_movie.nut");
dofile("scripts/level.nut");
dofile("scripts/audio.nut");
dofile("scripts/simulation.nut");
dofile("scripts/render.nut");
dofile("scripts/parity.nut");

eve_init = function() {
    gfx.setBackgroundColor(0.47, 0.49, 0.93, 1.0);
    loadAssets();
    loadAudio();
    runSimulationSelfTest();
    game = createGame();
    parityInitialize(game);
    if (config.previewScenario == "underground") {
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
        game.cameraX = previewKoopa.x - 112.0;
        game.player.x = previewKoopa.x - 32.0;
        game.player.y = 192.0;
        game.state = "preview";
    }
    if (config.capturePreview && config.previewCameraX > 0.0) {
        game.cameraX = config.previewCameraX;
        game.player.x = config.previewCameraX + 32.0;
    }
    if (game.area == "main") validateLevel(game);
    print("World 1-1 remake ready: arrows/A-D move, X/Shift run or throw, Z/Space jump, R reset.\n");
};

eve_update = function(dt) {
    if (parityIsEnabled()) {
        parityAdvanceOneFrame(game);
        flushSoundEvents(game);
        updateMusic();
        return;
    }

    local frameDt = dt;
    if (frameDt < 0.0) frameDt = 0.0;
    if (frameDt > 0.25) frameDt = 0.25;

    sampleInput(game);
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
    updateMusic();

    if (steps == MAX_STEPS_PER_FRAME && game.accumulator >= FIXED_DT)
        game.accumulator = 0.0;
};

eve_render = function() {
    renderGame(game);
    if (parityIsEnabled()) parityCaptureRenderedFrame(game);
    if (config.capturePreview && !game.previewCaptured && game.simTime > 0.5) {
        local previewName = "world-1-1-" + config.previewScenario + "-preview.png";
        if (gfx.saveFramePng(previewName)) game.previewCaptured = true;
    }
};

eve_reload <- function() { eve_init(); };
