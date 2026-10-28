function resetRound(g) {
    if(g.world==2) {startLevel(g,2,1,true);return;}
    if(g.level>=3) {startWorld1Stage(g,g.level,true);return;}
    if (g.level == 2) { g.player=createPlayer(); startWorld12(g); return; }
    local checkpointPage = g.checkpointPage;
    g.player = createPlayer();
    g.cameraX = checkpointPage * 256.0;
    if (checkpointPage > 0) {
        g.player.x = checkpointPage * 256.0 + 32.0;
        g.player.previousX = g.player.x;
    }
    g.state = "playing";
    g.stateTimer = 0.0;
    g.time = 400;
    g.hurryActive = false;
    g.displayTime = 400;
    g.queuedScore = g.score;
    g.displayScore = g.score;
    g.queuedCoins = g.coins;
    g.displayCoins = g.coins;
    g.gameTimerControl = 23;
    g.flagY = 48.0;
    g.preparedFlagY = 48.0;
    g.displayFlagY = 48.0;
    g.flagScoreY = 176.0;
    g.preparedFlagScoreY = 176.0;
    g.displayFlagScoreY = 176.0;
    g.flagScoreAge = -1;
    g.flagSoundPending = false;
    g.castleFlagVisible = false;
    g.castleFlagY = 144.0;
    g.fireworksRemaining = 0;
    g.fireworksOffsetState = -1;
    g.fireworkSpawnFrames = 0;
    g.clearDelayFrames = 0;
    g.fireworks = [];
    g.floatingScores = [];
    g.stompChain = 0;
    g.savedMain = null;
    g.areaTransitionFrames = 0;
    g.areaReloadFrames = 0;
    g.areaEntranceFrames = 0;
    g.areaReloadTarget = "underground";
    g.bump.active = false;
    g.coinEffect.active = false;
    g.coinEffect.spawnCarryYOffset = 0.0;
    g.archivedCoinEffects = [];
    g.displayTileOverrides = [];
    g.vramScrollThirtyTwo = 0;
    g.vramAreaParserTask = 0;
    g.vramBufferAddrCtrl = 0;
    buildLevel(g);
    emitSound(g, "resume_music");
}

function finishPlayerDeath(g) {
    // PlayerLoseLife is selected on this frame, but NumberofLives is not
    // decremented until the following mode-task frame.
    g.state = "deathReload";
    g.stateTimer = 0.0;
    g.deathReloadFrames = 0;
}

function saveMainArea(g) {
    g.savedMain = {
        tiles = g.tiles, goombas = g.goombas, powerups = g.powerups,
        fireballs = g.fireballs, brickDebris = g.brickDebris,
        levelCoins = g.levelCoins, cameraX = g.cameraX,
        brickCoinTimer = g.brickCoinTimer,
        brickCoinStarted = g.brickCoinStarted
    };
}

function enterUndergroundBonus(g) {
    saveMainArea(g);
    buildUndergroundBonus(g);
    g.cameraX = 0.0;
    g.player.x = 32.0;
    g.player.y = 28.0;
    g.player.previousX = g.player.x;
    g.player.previousY = g.player.y;
    g.player.vx = 0.0;
    g.player.vy = 0.0;
    g.player.nesXSpeed = 0;
    g.player.nesXForce = 0;
    g.player.nesXMoveForce = 0;
    g.player.nesYSpeed = 1;
    g.player.nesYMoveForce = 0;
    g.player.grounded = false;
    g.state = "playing";
    emitSound(g, "resume_music");
}

function resetPlayerForArea(g, x, canonicalY) {
    local wasBig = g.player.big;
    local wasFire = g.player.fire;
    g.player = createPlayer();
    g.player.big = wasBig;
    g.player.fire = wasFire;
    g.player.height = wasBig ? 32.0 : 16.0;
    g.player.x = x.tofloat();
    // The parity trace records SMB's 32-pixel sprite origin.  Small Mario's
    // collision body starts sixteen pixels lower in this implementation.
    g.player.y = canonicalY.tofloat() + (wasBig ? 0.0 : 16.0);
    g.player.previousX = g.player.x;
    g.player.previousY = g.player.y;
    g.player.preparedRelX = (g.player.x - g.cameraX) % 256.0;
    g.player.queuedRelX = g.player.preparedRelX;
    g.player.displayRelX = g.player.preparedRelX;
    g.player.preparedRelY = canonicalY.tofloat();
    g.player.queuedRelY = g.player.preparedRelY;
    g.player.displayRelY = g.player.preparedRelY;
}

function loadSavedMainArea(g) {
    local saved = g.savedMain;
    g.area = "main";
    g.areaWidth = LEVEL_WIDTH;
    g.sidePipeX = -1;
    g.tiles = saved.tiles;
    g.goombas = saved.goombas;
    g.powerups = saved.powerups;
    g.fireballs = saved.fireballs;
    g.brickDebris = saved.brickDebris;
    g.levelCoins = saved.levelCoins;
    g.brickCoinTimer = saved.brickCoinTimer;
    g.brickCoinStarted = saved.brickCoinStarted;
    g.savedMain = null;
}

function restoreMainArea(g) {
    loadSavedMainArea(g);

    local pipeColumn = 163;
    local pipeTop = GROUND_ROW;
    for (local ty = 0; ty < GROUND_ROW; ty += 1) {
        if (isSolidAt(g, pipeColumn, ty)) {
            pipeTop = ty;
            break;
        }
    }
    local finalY = pipeTop * TILE_SIZE.tofloat() - g.player.height;
    g.player.x = pipeColumn * TILE_SIZE.tofloat() + 2.0;
    g.player.y = finalY + g.player.height;
    g.player.vx = 0.0;
    g.player.vy = 0.0;
    g.player.nesXSpeed = 0;
    g.player.nesXForce = 0;
    g.player.nesXMoveForce = 0;
    g.transitionTargetY = finalY;
    g.cameraX = clampValue(g.player.x - 96.0, 0.0,
                           LEVEL_WIDTH * TILE_SIZE - LOGICAL_WIDTH);
    g.transitionTimer = 0.0;
    g.state = "pipeUp";
    emitSound(g, "pipe");
}

function tryStartAreaTransition(g) {
    if(g.world==2) return false; // World 2 bonus destinations are not connected yet.
    if(g.level>=3) return false;
    if (g.level == 2) return tryWorld12Pipe(g);
    local p = g.player;
    if (g.area == "main" && g.input.down && p.grounded) {
        local pipeLeft = 57.0 * TILE_SIZE;
        local leftFootTile = floor((p.x + 3.0) / TILE_SIZE).tointeger();
        local rightFootTile = floor((p.x + 12.0) / TILE_SIZE).tointeger();
        if (leftFootTile == 57 && rightFootTile == 58) {
            g.transitionTimer = 0.0;
            g.areaTransitionFrames = 0;
            g.areaReloadTarget = "underground";
            g.state = "pipeDown";
            emitSound(g, "pipe");
            return true;
        }
    }
    if (g.area == "underground" && p.grounded && p.facing > 0) {
        local mouthX = g.sidePipeX * TILE_SIZE.tofloat();
        if (p.x + p.width >= mouthX - 1.0) {
            // The collision/entry handoff clears the horizontal speed fraction
            // after the final ordinary control pass; position fraction remains.
            p.nesXForce = 0;
            g.transitionTimer = 0.0;
            g.areaTransitionFrames = 0;
            g.areaReloadTarget = "main";
            g.state = "pipeSide";
            emitSound(g, "pipe");
            return true;
        }
    }
    return false;
}

function updateAreaTransition(g, dt) {
    g.transitionTimer += dt;
    if (g.state == "pipeDown") {
        g.areaTransitionFrames += 1;
        g.player.y += 1.0;
        // VerticalPipeEntry moves the player for 48 frames.  On the last
        // frame the ROM selects OperMode_Task 0 while retaining subroutine 3.
        if (g.areaTransitionFrames >= 48) {
            g.areaReloadFrames = 0;
            g.state = "areaReload";
        }
    } else if (g.state == "pipeSide") {
        g.areaTransitionFrames += 1;
        local p = g.player;
        // EnterSidePipe writes speed $08 every frame until the low position
        // nybble reaches zero, then waits on the 160-frame area-change timer.
        if ((floor(p.x).tointeger() & 0x0F) != 0) {
            p.nesXSpeed = 8;
            applyNesXAcceleration(p, 1,
                g.areaTransitionFrames == 1 ? 0xD0 : 0x98);
            local deltaX = nesHorizontalDelta(p);
            p.x += deltaX;
            p.vx = p.nesXSpeed * 3.75;
        } else {
            p.nesXSpeed = 0;
            p.vx = 0.0;
        }
        if (g.areaTransitionFrames >= 160) {
            g.areaReloadFrames = 0;
            g.state = "areaReload";
        }
    } else if (g.state == "pipeUp") {
        g.player.y -= 1.0;
        if (g.player.y <= g.transitionTargetY) {
            g.player.y = g.transitionTargetY;
            g.player.grounded = true;
            g.state = "playing";
        }
    }
}

function updateAreaReload(g) {
    g.areaReloadFrames += 1;
    local frame = g.areaReloadFrames;

    // ScreenRoutines first clear the scroll registers, then on the following
    // frame reset object state and FrameCounter for the new area.
    if (frame == 1) {
        if (g.areaReloadTarget == "underground") g.cameraX = 0.0;
        g.player.nesXForce = 0;
        g.player.nesXMoveForce = 0;
        g.player.nesXScroll = 0;
        g.player.nesYMoveForce = 0;
        g.player.nesYDummy = 0;
        // Area initialization clears ColorRotateOffset ($06d4) while the
        // screen is disabled.  ColorRotation does not run again until the
        // normal game-engine pass starts after ScreenRoutines completes.
        g.colorRotateOffset = 0;
        g.displayColorPhase = 0;
        g.pendingColorPhase = 0;
        g.colorPhasePending = false;
        g.vramScrollThirtyTwo = 0;
        g.vramAreaParserTask = 0;
        g.vramBufferAddrCtrl = 0;
    } else if (frame == 2) {
        if (g.areaReloadTarget == "underground") {
            saveMainArea(g);
            buildUndergroundBonus(g);
            g.cameraX = 0.0;
        } else {
            loadSavedMainArea(g);
            g.cameraX = 10.0 * 256.0;
            // Area initialization clears all five runtime enemy slots and
            // reparses the stream from the return page.  Recreate stream
            // templates and discard commands irrecoverably behind page 10.
            g.goombas = [];
            decodeWorld11Enemies(g);
            foreach (enemy in g.goombas) {
                local triggerX = enemy.groupIndex >= 0 ?
                    enemy.groupCommandX : enemy.x;
                if (triggerX < g.cameraX - 64.0) enemy.alive = false;
            }
        }
        resetPlayerForArea(g, 0, 0);
        g.nesFrameCounter = 0;
        parityRecordEvent(g, "music", "silence");
    } else if (frame == 25) {
        parityRecordEvent(g, "music",
            g.areaReloadTarget == "underground" ? "underground" : "overworld");
        // The pipe effect stopped the previous track.  Queue the ROM's area
        // music handoff for the native mixer as well as recording the event.
        g.soundEvents.append("resume_music");
    } else if (frame == 26) {
        if (g.areaReloadTarget == "underground") {
            resetPlayerForArea(g, 24, 32);
            g.player.fallForce = 0x28;
            // The entrance profile ($01:$30) remains latched until the first
            // non-zero horizontal input after automatic entrance control ends.
            g.player.parityOriginFriction = true;
            g.areaEntranceFrames = 0;
            g.state = "areaEntrance";
        } else {
            resetPlayerForArea(g, 2616, 240);
            g.player.parityOriginFriction = true;
            g.player.fallForce = 0x28;
            g.areaEntranceFrames = 0;
            g.state = "areaExitEntrance";
        }
    }
    // ScreenRoutines selects a palette packet, twelve rendered column sets,
    // then the area-specific palette packet.  These are the actual selector
    // values written to $0773; NMI clears the selector on the following pass.
    if (frame == 3 || (frame == 21 && g.areaReloadTarget == "underground")) {
        g.vramBufferAddrCtrl = 3;
    } else if (frame == 21) {
        g.vramBufferAddrCtrl = 2;
    } else if (frame >= 9 && frame <= 20) {
        g.vramBufferAddrCtrl = 6;
    }
}

function updateAreaExitEntrance(g) {
    g.areaEntranceFrames += 1;
    g.player.y -= 1.0;
    g.player.previousY = g.player.y;
    if (g.areaEntranceFrames >= 96) {
        g.player.grounded = true;
        g.state = "playing";
    }
}

function updateAreaEntrance(g) {
    g.areaEntranceFrames += 1;
    local frame = g.areaEntranceFrames;
    // The first entrance frame is stationary.  Frames 2..16 apply the normal
    // fixed-point gravity helper, and frame 17 merely enables player control.
    if (frame >= 2 && frame <= 16) {
        local deltaY = nesVerticalDelta(g.player, false);
        g.player.y += deltaY;
        g.player.previousY = g.player.y;
        g.player.vy = g.player.nesYSpeed * NES_FRAME_RATE;
    } else if (frame == 1) {
        g.player.grounded = false;
        g.player.entranceFalling = true;
    } else if (frame >= 17) {
        g.state = "playing";
    }
}

function sampleInput(g) {
    g.input.left = keyboard.isDown("left") || keyboard.isDown("a") || keyboard.isDown("A");
    g.input.right = keyboard.isDown("right") || keyboard.isDown("d") || keyboard.isDown("D");
    g.input.up = keyboard.isDown("up") || keyboard.isDown("w") || keyboard.isDown("W");
    g.input.down = keyboard.isDown("down") || keyboard.isDown("s") || keyboard.isDown("S");
    local run = keyboard.isDown("x") || keyboard.isDown("X") ||
                keyboard.isDown("lshift") || keyboard.isDown("LShift");
    if (run && !g.input.runDown) g.input.fireQueued = true;
    g.input.run = run;
    g.input.runDown = run;

    local jump = keyboard.isDown("z") || keyboard.isDown("Z") ||
                 keyboard.isDown("space") || keyboard.isDown("Space");
    if (jump && !g.input.jumpDown) g.input.jumpQueued = true;
    g.input.jumpDown = jump;

    local reset = keyboard.isDown("r") || keyboard.isDown("R");
    if (reset && !g.input.resetDown) g.input.resetQueued = true;
    g.input.resetDown = reset;
}

function spawnPowerUp(g, tx, ty, kind) {
    local blockY = ty * TILE_SIZE.tofloat();
    g.powerups.append({
        kind = kind,
        x = tx * TILE_SIZE.tofloat(),
        // SetupPowerUp starts eight pixels above the source block.  The ROM
        // then performs seventeen one-pixel rises before enabling movement.
        y = blockY - 8.0,
        // Keep the ROM enemy-object Y separate from the host collision box.
        // OAM draws this coordinate with the original nine-pixel offset.
        romY = blockY - 8.0,
        targetY = blockY - 25.0,
        width = 16.0,
        height = 16.0,
        vx = NES_FRAME_RATE,
        vy = 0.0,
        emergeFrame = 0,
        emergePixels = 0,
        emerging = true,
        visible = false,
        settleFrame = -1,
        displayX = tx * TILE_SIZE.tofloat(),
        displayRomY = blockY - 8.0,
        displayEmerging = true,
        displayVisible = false,
        displayActive = true,
        active = true
    });
    parityRecordEvent(g, "gameplay", "powerup_spawn",
        ",\"kind\":\"" + kind + "\",\"tile_x\":" + tx + ",\"tile_y\":" + ty);
}

function startJumpingCoin(g, tx, ty) {
    // SMB has three misc-object slots ($2a-$32).  A later block hit must not
    // overwrite an older jumping coin/floatey-number object that is still
    // active in another slot.
    local occupiedMiscSlot = g.coinEffect.active;
    if (!occupiedMiscSlot) {
        foreach (oldEffect in g.archivedCoinEffects) {
            if (oldEffect.active) {
                occupiedMiscSlot = true;
                break;
            }
        }
    }
    if (g.coinEffect.active) {
        g.archivedCoinEffects.append({
            active = g.coinEffect.active,
            x = g.coinEffect.x,
            y = g.coinEffect.y,
            time = g.coinEffect.time,
            displayX = g.coinEffect.displayX,
            phase = g.coinEffect.phase,
            displayPhase = g.coinEffect.displayPhase,
            frame = g.coinEffect.frame,
            scoreFrame = g.coinEffect.scoreFrame,
            spawnCarryYOffset = g.coinEffect.spawnCarryYOffset
        });
    }
    g.coinEffect.active = true;
    // CoinBlock uses block X + 5 and block Y - 16 for the 8x16 OAM object.
    g.coinEffect.x = tx * TILE_SIZE + 5.0;
    g.coinEffect.displayX = g.coinEffect.x;
    g.coinEffect.y = ty * TILE_SIZE - 16.0;
    g.coinEffect.time = 0.0;
    g.coinEffect.phase = "coin";
    g.coinEffect.displayPhase = "coin";
    g.coinEffect.frame = 0;
    g.coinEffect.scoreFrame = 0;
    // CoinBlock intentionally executes SBC #$10 without SEC.  When slot 8 is
    // occupied, FindEmptyMiscSlot reaches CPY #$05 and leaves carry set, so
    // the newer coin starts one pixel lower.  With an empty slot 8, the
    // inherited clear carry subtracts 17 instead.  Preserve that original
    // 6502 side effect instead of special-casing a capture frame.
    g.coinEffect.spawnCarryYOffset = occupiedMiscSlot ? 1.0 : 0.0;
}

function retainOldTileForPpu(g, tx, ty, tile) {
    foreach (entry in g.displayTileOverrides) {
        if (entry.tx == tx && entry.ty == ty) return;
    }
    // The power-up setup path fills the VRAM update buffer one pass earlier
    // than the ordinary coin/brick paths in the captured World 1-1 trace.
    local frames = tile == TILE_POWERUP_BLOCK ? 1 : 2;
    g.displayTileOverrides.append({ tx = tx, ty = ty, tile = tile, frames = frames });
}

function awardCoin(g) {
    g.coins += 1;
    g.score += 200;
    parityRecordEvent(g, "gameplay", "coin_award");
    emitSound(g, "coin");
    if (g.coins >= 100) {
        g.coins -= 100;
        g.lives += 1;
        emitSound(g, "oneup");
    }
}

function breakBrick(g, tx, ty) {
    setTile(g, tx, ty, TILE_EMPTY);
    local baseX = tx * TILE_SIZE.tofloat();
    local baseY = ty * TILE_SIZE.tofloat();
    local velocities = [
        [-72.0, -230.0], [72.0, -230.0],
        [-48.0, -165.0], [48.0, -165.0]
    ];
    for (local i = 0; i < 4; i += 1) {
        g.brickDebris.append({
            x = baseX + ((i % 2) * 8).tofloat(),
            y = baseY + (i < 2 ? 0.0 : 8.0),
            vx = velocities[i][0],
            vy = velocities[i][1],
            life = 1.2,
            active = true
        });
    }
    g.score += 50;
    parityRecordEvent(g, "gameplay", "brick_break",
        ",\"tile_x\":" + tx + ",\"tile_y\":" + ty);
    emitSound(g, "break");
}

function bumpEnemiesAbove(g, tx, ty) {
    local blockX = tx * TILE_SIZE.tofloat();
    local blockTop = ty * TILE_SIZE.tofloat();
    foreach (enemy in g.goombas) {
        if (!enemy.alive || enemy.state == "defeated" || enemy.state == "flipped")
            continue;
        local feet = enemy.y + enemy.height;
        if (enemy.x + enemy.width <= blockX || enemy.x >= blockX + TILE_SIZE)
            continue;
        if (feet < blockTop - 5.0 || feet > blockTop + 4.0) continue;
        enemy.state = "flipped";
        enemy.vy = -190.0;
        enemy.vx = (enemy.x + enemy.width * 0.5 < blockX + 8.0) ? -46.0 : 46.0;
        enemy.grounded = false;
        g.score += 100;
        emitSound(g, "kick");
    }
}

function hitBlock(g, tx, ty) {
    local tile = getTile(g, tx, ty);
    if(isWorld21(g) && tile==TILE_BRICK_VINE) {growWorld21Vine(g,tx,ty);return;}
    if (tile == TILE_BRICK_POWERUP || tile == TILE_BRICK_ONEUP || tile == TILE_BRICK_VINE ||
        tile == TILE_HIDDEN_COIN) {
        retainOldTileForPpu(g, tx, ty, tile);
        bumpEnemiesAbove(g, tx, ty);
        g.bump.active=true;g.bump.tx=tx;g.bump.ty=ty;g.bump.tile=tile;
        g.bump.time=0.0;g.bump.frame=0;g.bump.powerupPending=true;
        parityRecordEvent(g,"gameplay","block_hit",
            ",\"tile_x\":"+tx+",\"tile_y\":"+ty+",\"tile\":"+tile);
        emitSound(g,"bump");
        setTile(g, tx, ty, TILE_USED);
        if (tile == TILE_HIDDEN_COIN) { startJumpingCoin(g, tx, ty); awardCoin(g); }
        else {
            spawnPowerUp(g, tx, ty, tile == TILE_BRICK_ONEUP ? "oneup" :
                (g.player.big ? "flower" : "mushroom"));
            emitSound(g, "powerup", "reveal");
        }
        return;
    }
    if (tile != TILE_BRICK && tile != TILE_QUESTION &&
        tile != TILE_POWERUP_BLOCK && tile != TILE_HIDDEN_ONEUP &&
        tile != TILE_BRICK_COIN && tile != TILE_BRICK_STAR) return;

    // The replacement metatile is queued after the current NMI.  The PPU
    // still shows the old block for this frame and the following capture.
    retainOldTileForPpu(g, tx, ty, tile);

    parityRecordEvent(g, "gameplay", "block_hit",
        ",\"tile_x\":" + tx + ",\"tile_y\":" + ty + ",\"tile\":" + tile);

    bumpEnemiesAbove(g, tx, ty);

    if (tile == TILE_BRICK && g.player.big) {
        foreach (item in g.powerups) bumpPowerUpAbove(g, item, tx, ty);
        breakBrick(g, tx, ty);
        return;
    }

    g.bump.active = true;
    g.bump.tx = tx;
    g.bump.ty = ty;
    g.bump.tile = tile;
    g.bump.time = 0.0;
    g.bump.frame = 0;
    g.bump.powerupPending = true;
    emitSound(g, "bump");

    if (tile == TILE_HIDDEN_ONEUP) {
        setTile(g, tx, ty, TILE_USED);
        spawnPowerUp(g, tx, ty, "oneup");
        emitSound(g, "powerup", "reveal");
    } else if (tile == TILE_BRICK_STAR) {
        setTile(g, tx, ty, TILE_USED);
        spawnPowerUp(g, tx, ty, "star");
        emitSound(g, "powerup", "reveal");
    } else if (tile == TILE_BRICK_COIN) {
        startJumpingCoin(g, tx, ty);
        awardCoin(g);
        if (!g.brickCoinStarted) {
            g.brickCoinStarted = true;
            g.brickCoinTimer = BRICK_COIN_TIME;
        } else if (g.brickCoinTimer <= 0.0) {
            setTile(g, tx, ty, TILE_USED);
        }
    } else if (tile == TILE_QUESTION || tile == TILE_POWERUP_BLOCK) {
        setTile(g, tx, ty, TILE_USED);
        if (tile == TILE_POWERUP_BLOCK) {
            spawnPowerUp(g, tx, ty, g.player.big ? "flower" : "mushroom");
            emitSound(g, "powerup", "reveal");
        } else {
            startJumpingCoin(g, tx, ty);
            awardCoin(g);
        }
    }
}

function movePlayerX(g, p, dt) {
    local nextX = p.x + p.vx * dt;
    p.sidePipeCollision = false;
    // ROM stages move first and resolve background samples after vertical
    // movement. A geometric wall snap here would impede the same contact
    // twice and erase the horizontal fractional accumulators.
    if(g.romBackgroundCollision) {p.x=nextX;return;}
    local sideOffsets = p.height > 16.0 ? [8.0, 24.0] : [p.height * 0.5];
    if (p.vx > 0.0) {
        if (g.area == "underground" && g.sidePipeX >= 0 &&
            (g.level != 2 || (p.y+p.height>(g.world12SidePipeBottomRow-1)*16 &&
                             p.y<(g.world12SidePipeBottomRow+1)*16))) {
            local mouthX = g.sidePipeX * TILE_SIZE.tofloat();
            if (nextX + p.width >= mouthX) {
                // The ROM's side sample uses an inclusive right edge, leaving
                // the object origin one pixel left of the host AABB snap.
                nextX = mouthX - p.width - 1.0;
                p.vx = 0.0;
                p.sidePipeCollision = true;
            }
        }
        local tx = floor((nextX + p.width - 0.001) / TILE_SIZE).tointeger();
        foreach (offset in sideOffsets) {
            if (p.sidePipeCollision) break;
            local ty = floor((p.y + offset) / TILE_SIZE).tointeger();
            if (isSolidAt(g, tx, ty)) {
                // The flagpole base is processed by SMB's post-movement
                // background-collision pass.  Handling it here would use the
                // pre-vertical Y coordinate and geometrically snap Mario,
                // while the ROM instead applies a one-pixel impede force.
                if (g.area == "main" && tx == floor(g.flagX / TILE_SIZE).tointeger() &&
                    ty == 12) continue;
                nextX = tx * TILE_SIZE - p.width;
                p.vx = 0.0;
                break;
            }
        }
    } else if (p.vx < 0.0) {
        local tx = floor(nextX / TILE_SIZE).tointeger();
        foreach (offset in sideOffsets) {
            local ty = floor((p.y + offset) / TILE_SIZE).tointeger();
            if (isSolidAt(g, tx, ty)) {
                nextX = (tx + 1) * TILE_SIZE;
                p.vx = 0.0;
                break;
            }
        }
    }
    p.x = nextX;
}

function movePlayerY(g, p, dt, fallingOrStationary = false) {
    local nextY = p.y + p.vy * dt;
    p.grounded = false;
    p.headCollision = false;
    p.headCollisionSpeed = 0;
    p.deepFootCollision = false;

    if (p.vy > 0.0 || (p.vy == 0.0 && fallingOrStationary)) {
        local ty = floor((nextY + p.height) / TILE_SIZE).tointeger();
        // Small-player block-buffer offsets are $03 and $0c.  The right sample
        // is inclusive at +12 rather than the host AABB's +11 edge.
        local footXs = [p.x + 3.0, p.x + 12.0];
        foreach (footX in footXs) {
            local tx = floor(footX / TILE_SIZE).tointeger();
            if (isSolidAt(g, tx, ty)) {
                // PlayerBGCollision only lands when the low nibble of the
                // sprite Y is below five.  A deeper foot hit is tail-called
                // into ImpedePlayerMove, preserving vertical motion and
                // nudging Mario one pixel sideways.  This is observable at
                // the World 1-1 flagpole base on frames 1102..1104.
                local yLow = floor(nextY).tointeger() & 0x0F;
                if (yLow < 5) {
                    nextY = ty * TILE_SIZE - p.height;
                    p.vy = 0.0;
                    p.nesYSpeed = 0;
                    p.nesYMoveForce = 0;
                    p.grounded = true;
                    p.entranceFalling = false;
                    g.stompChain = 0;
                } else {
                    p.deepFootCollision = true;
                }
                break;
            }
        }
    } else if (p.vy < 0.0) {
        // BlockBuffer_Y_Adder is $12 for small/crouching Mario.  The host body
        // is already shifted down by $10, leaving a +2 sample offset; standing
        // big Mario uses the table's +4 directly.
        local headYOffset = p.big && !p.crouching ? 4.0 : 2.0;
        local ty = floor((nextY + headYOffset) / TILE_SIZE).tointeger();
        // For a small/crouching player the ROM selects BlockBuffer_X_Adder
        // $08 (table entry $0e), not the host collision box centre at +6.
        // The two-pixel difference decides the canonical corner bump frame.
        local tx = floor((p.x + 8.0) / TILE_SIZE).tointeger();
        local tile = getTile(g, tx, ty);
        local headWithinBlock=(floor(nextY+headYOffset).tointeger()&15)>=4;
        if ((!g.romBackgroundCollision || headWithinBlock) &&
            (isSolidTile(tile) || tile == TILE_HIDDEN_ONEUP || tile == TILE_HIDDEN_COIN)) {
            // SMB samples the head point after applying the integer vertical
            // displacement and does not snap Player_Y_Position to the tile
            // boundary.  For this block the canonical result is $8d (141),
            // not the hand-authored 16 px boundary at 144.
            p.vy = 0.0;
            p.headCollision = true;
            if(g.romBackgroundCollision && (tile==TILE_SOLID || tile==TILE_GROUND)) {
                // SolidOrClimb sets +1 rather than PlayerHeadCollision's 0.
                p.headCollisionSpeed=1;
                parityRecordEvent(g,"gameplay","block_hit",
                    ",\"tile_x\":"+tx+",\"tile_y\":"+ty+",\"tile\":"+tile);
                emitSound(g,"bump");
            }
            hitBlock(g, tx, ty);
        }
    }
    p.y = nextY;
}

function impedePlayerMove(g, p, collisionDirection) {
    // collisionDirection mirrors Player_MovingDir: 1 treats the obstruction
    // as being on the right and nudges left; 2 treats it as being on the left
    // and nudges right.  The ROM only clears speed when motion is into it.
    if (collisionDirection == 1) {
        p.collisionBits = p.collisionBits & 0xFE;
        if (p.nesXSpeed < 0) return;
        p.x -= 1.0;
    } else {
        p.collisionBits = p.collisionBits & 0xFD;
        if (p.nesXSpeed >= 1) return;
        p.x += 1.0;
    }
    p.nesXSpeed = 0;
    p.vx = 0.0;
    p.sideCollisionFrames = 16;
}

function handlePlayerBackgroundSides(g, p) {
    // PlayerBGCollision initializes these permission bits before sampling
    // feet and sides; the resulting mask is consumed by next frame's
    // horizontal-friction routine.
    p.collisionBits = 0xFF;
    // A deep foot hit jumps directly to ImpedePlayerMove in the 6502 code and
    // therefore skips all side samples for this frame.
    if (p.deepFootCollision) {
        impedePlayerMove(g, p, p.movingDir);
        return;
    }
    if ((g.romBackgroundCollision || (g.level==2 && g.area=="underground")) && g.state == "playing") {
        // The ROM runs DoPlayerSideCheck after the head/feet pass in every
        // area. The old implementation only ran this pass above ground,
        // leaving the inclusive +12 foot sample supported by a wall's side.
        // Preserve the separate side-pipe mouth handling in movePlayerX.
        if (p.sidePipeCollision) return;
        local canonicalY=p.big && !p.crouching?p.y:p.y-16.0;
        foreach(side in [0,1]) {
            foreach(offset in (p.big && !p.crouching?[8.0,24.0]:[24.0])) {
                if(canonicalY<(offset==8.0?32.0:8.0) ||
                   canonicalY>=(offset==8.0?228.0:208.0)) continue;
                local tx=floor((p.x+(side==0?2.0:13.0))/TILE_SIZE).tointeger();
                local ty=floor((canonicalY+offset)/TILE_SIZE).tointeger();
                if(g.area=="main" && tx==floor(g.flagX/TILE_SIZE).tointeger() &&
                   ty>=2 && ty<=11) {
                    local xLow=floor(p.x).tointeger()&15;
                    if(xLow>=6 && xLow<10) beginFlagSequence(g);
                    return;
                }
                // The pipe's end is an entrance, not an ordinary wall.
                // The +13 side probe reaches it one pixel before movePlayerX
                // sets sidePipeCollision. Let tryWorld12Pipe consume that
                // contact instead of nudging Mario out of its entry range.
                if(side==1 && tx==g.sidePipeX && p.grounded && g.input.right &&
                   ty>=g.world12SidePipeBottomRow-1 &&
                   ty<=g.world12SidePipeBottomRow) return;
                if(isSolidAt(g,tx,ty)) {
                    impedePlayerMove(g,p,side==0?2:1);
                    return;
                }
            }
        }
        return;
    }
    local courseClear = g.state == "endLevel" ||
        g.state == "timeBonus" || g.state == "raiseFlag" ||
        g.state == "fireworks" || g.state == "postClearDelay";
    if (g.area != "main" || (g.state != "playing" && !courseClear)) return;

    local spriteY = p.big && !p.crouching ? p.y : p.y - 16.0;
    local sampleRow = floor((spriteY + 24.0) / TILE_SIZE).tointeger();
    local flagColumn = floor(g.flagX / TILE_SIZE).tointeger();
    local xLow = floor(p.x).tointeger() & 0x0F;
    local sideOffsets = [2.0, 13.0];
    // For the tall World 1-1 castle, CastleObject replaces the floor metatile
    // under its second rendered column with the collision brick at $52.  The
    // side probe's block-buffer row is 12 for small Mario.
    local castleStopColumn =
        floor(g.castleX / TILE_SIZE).tointeger() + 3;
    for (local side = 0; side < 2; side += 1) {
        local sampleColumn = floor((p.x + sideOffsets[side]) / TILE_SIZE).tointeger();
        if (g.state == "playing" && sampleColumn == flagColumn &&
            sampleRow >= 2 && sampleRow <= 11) {
            // HandleClimbingMetatile narrows the 16px metatile to raw player
            // X low-nibble values 6..9 before attaching to the pole.
            if (xLow >= 6 && xLow < 10) beginFlagSequence(g);
            return;
        }
        if (courseClear && side == 1 && sampleRow == 12 &&
            sampleColumn == castleStopColumn) {
            // PlayerBGCollision invokes ImpedePlayerMove while PlayerEndLevel
            // keeps auto-control held right.  The cleared d0 bit starts the
            // star-flag task on this pass; the position nudge remains in the
            // ordinary collision routine below.
            impedePlayerMove(g, p, 1);
            return;
        }
        if (isSolidAt(g, sampleColumn, sampleRow)) {
            // Left sample is an obstruction to leftward movement; right
            // sample is an obstruction to rightward movement.
            impedePlayerMove(g, p, side == 0 ? 2 : 1);
            return;
        }
    }
}

function playerHasFootSupport(g, p) {
    local ty = floor((p.y + p.height) / TILE_SIZE).tointeger();
    local footXs = [p.x + 3.0, p.x + 12.0];
    foreach (footX in footXs) {
        local tx = floor(footX / TILE_SIZE).tointeger();
        if (isSolidAt(g, tx, ty)) return true;
    }
    return false;
}

function killPlayer(g, causeJson = "") {
    local p = g.player;
    if (p.dead || g.state != "playing") return;
    p.dead = true;
    p.deadTimer = 0.0;
    p.deadFrames = 0;
    p.deathFreezeFrames = 15;
    p.vx = 0.0;
    p.vy = -4.0 * NES_FRAME_RATE;
    p.nesXSpeed = 0;
    if (g.level == 1) p.nesXForce = 0;
    p.nesYSpeed = -4;
    p.fallForce = 0x28;
    p.grounded = false;
    // The enemy OAM buffer has already selected its gait for this gameplay
    // pass.  Once TimerControl is raised the ROM leaves that selection
    // untouched until the death sequence reloads the area.
    local enemyGfxCounter = g.nesFrameCounter;
    g.goombaVisualFrame = (enemyGfxCounter & 0x08) != 0 ? 1 : 0;
    parityRecordEvent(g, "gameplay", "player_death", causeJson);
    emitSound(g, "death");
}

function hurtPlayer(g, enemy = null) {
    local p = g.player;
    if (p.invulnerable > 0.0 || p.starTimer > 0.0) return;
    if (!p.big) {
        local cause = enemy == null ? "" :
            ",\"cause\":\"enemy\",\"enemy_kind\":\"" + enemy.kind +
            "\",\"enemy_x\":" + enemy.x;
        killPlayer(g, cause);
        return;
    }

    parityRecordEvent(g, "gameplay", "player_damage");

    p.big = false;
    p.fire = false;
    p.crouching = false;
    p.height = 16.0;
    p.y += 16.0;
    // Ten size-animation steps at four frames each, followed by the ROM's
    // eight interval-timer counts (21 frames apiece).
    p.invulnerable = 208.0 * FIXED_DT;
    p.transformFrames = 40;
    p.transformTimer = 40.0 * FIXED_DT;
    p.transformToBig = false;
    p.transformKind = "shrink";
}

function applyNesXAcceleration(p, direction, amount) {
    if (direction > 0) {
        local sum = p.nesXForce + amount;
        p.nesXForce = sum & 0xFF;
        p.nesXSpeed += floor(sum / 256).tointeger();
    } else if (direction < 0) {
        local difference = p.nesXForce - amount;
        while (difference < 0) {
            difference += 256;
            p.nesXSpeed -= 1;
        }
        p.nesXForce = difference & 0xFF;
    }
}

function updateNesHorizontalPhysics(g, p, direction) {
    if (p.parityOriginFriction) {
        // The saved ROM origin is captured before the first normal control
        // pass.  That pass still owns the entrance profile ($01:$30), while
        // PlayerPhysicsSub prepares walking/running friction for the next NMI.
        if (direction != 0) {
            p.parityOriginFriction = false;
            applyNesXAcceleration(p, direction, 0x130);
            if (p.nesXSpeed > 0x0C) p.nesXSpeed = 0x0C;
            if (p.nesXSpeed < -0x0C) p.nesXSpeed = -0x0C;
            p.nesXSpeedAbsolute = abs(p.nesXSpeed);
            p.facing = direction;
        }
        return;
    }
    if (g.input.run && p.grounded && direction != 0) p.runningTimer = 10;
    else if (p.runningTimer > 0) p.runningTimer -= 1;

    // PlayerPhysicsSub chooses three distinct ROM table paths.  Running is
    // selected only when the held direction still equals the sticky
    // Player_MovingDir.  During a reversal, Running_Speed from the preceding
    // GetPlayerAnimSpeed pass selects friction index 2 ($d0); B alone must not
    // select index 0 ($e4).  Airborne B does not grant run speed: a slow jump
    // is capped at $18, while momentum >=$19 keeps the $28 cap.
    // $0700 is computed by the preceding friction pass, then survives a
    // background collision that clears Player_X_Speed.  The following frame
    // therefore selects its profile from this deliberately lagging value.
    local speedAbsolute = p.nesXSpeedAbsolute;
    local maximum = 0x18;
    local force = 0x98;
    local directionMatchesMotion = direction != 0 &&
        direction == (p.movingDir == 1 ? 1 : -1);
    if (p.grounded && directionMatchesMotion &&
        (g.input.run || p.runningTimer > 0)) {
        maximum = 0x28;
        force = 0xE4;
    } else if (!p.grounded && speedAbsolute >= 0x19) {
        maximum = 0x28;
        force = 0xE4;
    } else if (p.runningSpeed != 0 || speedAbsolute >= 0x21) {
        maximum = 0x18;
        force = 0xD0;
    }
    local oldSign = p.nesXSpeed > 0 ? 1 : (p.nesXSpeed < 0 ? -1 : 0);
    // ConfigureHorizontalPhysics compares FacingDir with the sticky
    // Player_MovingDir, not with the current speed sign.  This still doubles
    // friction when a collision has just reduced speed to zero.
    local facingAgainstMotion = p.facing != (p.movingDir == 1 ? 1 : -1);
    p.skidding = p.grounded && direction != 0 &&
                 direction != (p.movingDir == 1 ? 1 : -1) &&
                 abs(p.nesXSpeed) >= 0x0B;

    // OnGroundStateSub calls GetPlayerAnimSpeed after PlayerPhysicsSub has
    // fixed this frame's limits/friction, but before applying that friction.
    // Preserve that order: Running_Speed and Player_MovingDir affect the next
    // frame, while a low-speed skid can zero this frame's velocity fraction.
    if (p.grounded) {
        local animationSpeed = p.nesXSpeedAbsolute;
        p.playerAnimTimerSet = animationSpeed >= 0x1C ? 2 :
            (animationSpeed >= 0x0E ? 4 : 7);
        if (animationSpeed >= 0x1C) {
            p.runningSpeed = animationSpeed;
        } else {
            local nonAInput = g.input.run || direction != 0 ||
                g.input.up || g.input.down;
            if (nonAInput) {
                if (direction == (p.movingDir == 1 ? 1 : -1)) {
                    p.runningSpeed = 0;
                } else if (animationSpeed < 0x0B) {
                    p.movingDir = p.facing == 1 ? 1 : 2;
                    p.nesXSpeed = 0;
                    p.nesXForce = 0;
                }
            }
        }
        if (direction != 0) p.facing = direction;
    }

    local inputPresent = direction != 0;
    local inputAllowed = direction > 0 ? (p.collisionBits & 0x01) != 0 :
        (direction < 0 ? (p.collisionBits & 0x02) != 0 : false);
    local physicsDirection = inputAllowed ? direction : 0;

    if (physicsDirection == 0) {
        // The airborne handler only calls horizontal friction when a left or
        // right bit is present.  A blocked input still calls the routine, but
        // its collision-bit mask turns that input into deceleration.
        if (!p.grounded && !inputPresent) return;
        if (oldSign != 0) {
            applyNesXAcceleration(p, -oldSign, force);
            if ((oldSign > 0 && p.nesXSpeed < 0) ||
                (oldSign < 0 && p.nesXSpeed > 0)) {
                p.nesXSpeed = 0;
                p.nesXForce = 0;
            }
        }
    } else {
        // PlayerPhysicsSub doubles friction from the facing-vs-moving
        // relationship captured before the state handler.  Air control does
        // not turn Mario, so merely pressing the opposite direction in air
        // must not double the first reversal force.
        // This comparison is made before OnGroundStateSub updates facing or
        // moving direction.  The second PlayerEndLevel handoff frame therefore
        // doubles $98 to $01:$30 exactly like ordinary skid/reversal input.
        local appliedForce = facingAgainstMotion ? force * 2 : force;
        applyNesXAcceleration(p, physicsDirection, appliedForce);
        // The 6502 routine clamps only against the limit in the requested
        // direction.  Reversal friction must be allowed to decelerate a
        // faster opposite velocity through the walking cap naturally.
        if (physicsDirection > 0 && p.nesXSpeed > maximum)
            p.nesXSpeed = maximum;
        if (physicsDirection < 0 && p.nesXSpeed < -maximum)
            p.nesXSpeed = -maximum;
    }
    p.nesXSpeedAbsolute = abs(p.nesXSpeed);
}

function nesHorizontalDelta(p) {
    local rawSpeed = p.nesXSpeed & 0xFF;
    local integerPart = p.nesXSpeed >> 4;
    local sum = p.nesXMoveForce + ((rawSpeed & 0x0F) << 4);
    p.nesXMoveForce = sum & 0xFF;
    return integerPart + floor(sum / 256).tointeger();
}

function beginNesJump(p) {
    local speed = abs(p.nesXSpeed);
    local index = 0;
    if (speed >= 0x09) index = 1;
    if (speed >= 0x10) index = 2;
    if (speed >= 0x19) index = 3;
    if (speed >= 0x1C) index = 4;
    local jumpForces = [0x20, 0x20, 0x1E, 0x28, 0x28];
    local fallForces = [0x70, 0x70, 0x60, 0x90, 0x90];
    local ySpeeds = [-4, -4, -4, -5, -5];
    p.jumpForce = jumpForces[index];
    p.fallForce = fallForces[index];
    p.nesYSpeed = ySpeeds[index];
    p.nesYMoveForce = 0;
    p.nesYDummy = 0;
    p.jumpGravityActive = true;
    p.jumpOriginY = p.y;
    p.grounded = false;
}

function nesVerticalDelta(p, jumpGravityActive) {
    local positionSum = p.nesYDummy + p.nesYMoveForce;
    p.nesYDummy = positionSum & 0xFF;
    local delta = p.nesYSpeed + floor(positionSum / 256).tointeger();
    local force = (p.nesYSpeed < 0 && jumpGravityActive) ? p.jumpForce : p.fallForce;
    local velocitySum = p.nesYMoveForce + force;
    p.nesYMoveForce = velocitySum & 0xFF;
    p.nesYSpeed += floor(velocitySum / 256).tointeger();
    // SMB clamps downward speed only when both the integer speed has reached
    // the limit and the fractional speed is at least $80.  This mirrors the
    // CMP/BMI + CMP/BCC sequence in sub_apply_object_gravity; clamping as
    // soon as the integer byte exceeded four shifts the landing/death arc.
    if (p.nesYSpeed >= 4 && p.nesYMoveForce >= 0x80) {
        p.nesYSpeed = 4;
        p.nesYMoveForce = 0;
    }
    return delta;
}

function setCrouching(g, p, crouching) {
    if (!p.big || p.crouching == crouching) return;
    if (crouching) {
        p.y += 16.0;
        p.height = 16.0;
        p.crouching = true;
        return;
    }
    local standY = p.y - 16.0;
    local left = floor((p.x + 1.0) / TILE_SIZE).tointeger();
    local right = floor((p.x + p.width - 1.0) / TILE_SIZE).tointeger();
    local top = floor(standY / TILE_SIZE).tointeger();
    for (local tx = left; tx <= right; tx += 1)
        if (isSolidAt(g, tx, top)) return;
    p.y = standY;
    p.height = 32.0;
    p.crouching = false;
}

function updatePlayer(g, dt) {
    local p = g.player;
    local pendingPlatformXScroll = p.pendingPlatformXScroll;
    p.pendingPlatformXScroll = 0;
    p.previousX = p.x;
    p.previousY = p.y;
    p.sideCollisionFramesAtStart = p.sideCollisionFrames;
    if (p.sideCollisionFrames > 0) p.sideCollisionFrames -= 1;
    // ScrollHandler runs before this frame's background collision can set a
    // new SideCollisionTimer. Snapshot the already-decremented NMI value so
    // the collision frame itself scrolls, following timer frames suppress
    // scroll, and the frame where the timer reaches zero resumes it.
    p.scrollSideCollisionTimer = p.sideCollisionFrames > 0;
    if (p.invulnerable > 0.0) {
        p.invulnerable -= dt;
        if (p.invulnerable < 0.0) p.invulnerable = 0.0;
    }
    if (p.starTimer > 0.0) {
        p.starTimer -= dt;
        if (p.starTimer < 0.0) p.starTimer = 0.0;
        if (p.starMusicActive &&
            p.starTimer <= 4.0 * NES_INTERVAL_FRAMES * FIXED_DT) {
            p.starMusicActive = false;
            emitSound(g, "resume_music");
        }
    }
    if (p.throwingTimer > 0.0) {
        p.throwingTimer -= dt;
        if (p.throwingTimer < 0.0) p.throwingTimer = 0.0;
    }
    if (p.transformFrames > 0) {
        p.transformFrames -= 1;
        p.transformTimer = p.transformFrames * FIXED_DT;
        if (p.transformFrames == 0) p.transformKind = "none";
        p.vx = 0.0;
        p.nesXSpeed = 0;
        p.nesXForce = 0;
        p.nesXMoveForce = 0;
        return;
    }

    if (p.dead) {
        p.deadTimer += dt;
        p.deadFrames += 1;
        if (p.deathFreezeFrames > 0) {
            p.deathFreezeFrames -= 1;
            return;
        }
        local deathDeltaY = nesVerticalDelta(p, false);
        p.y += deathDeltaY;
        p.vy = p.nesYSpeed * NES_FRAME_RATE;
        // Verified ROM trace: death at comparison frame 191, PlayerLoseLife
        // at frame 399 (208 subsequent death-routine frames).
        if (p.deadFrames >= 208) finishPlayerDeath(g);
        return;
    }

    if (g.input.fireQueued && p.fire) spawnFireball(g);

    setCrouching(g, p, p.big && p.grounded && g.input.down);

    local direction = 0;
    if (g.input.left) direction -= 1;
    if (g.input.right) direction += 1;
    if (p.crouching) direction = 0;
    if (g.input.jumpQueued && p.grounded && !p.crouching) {
        beginNesJump(p);
        emitSound(g, "jump");
    }

    // PlayerPhysicsSub initializes a jump before PlayerMovementSubs chooses
    // OnGroundStateSub.  Thus a take-off frame must not call
    // GetPlayerAnimSpeed even though Mario was grounded at frame entry.
    // The speed sample itself precedes friction, so threshold crossings still
    // affect the following ground frame exactly as in the ROM.
    if (p.grounded) {
        local speed = p.nesXSpeedAbsolute;
        p.playerAnimTimerSet = speed >= 0x1C ? 2 :
            (speed >= 0x0E ? 4 : 7);
    }

    // PlayerPhysicsSub initializes a jump before selecting the horizontal
    // profile.  A slow jump therefore uses airborne friction ($01:$98), even
    // when B is held on the take-off frame.  The called routine also performs
    // the original ground-animation state update in its correct ordering.
    updateNesHorizontalPhysics(g, p, direction);

    local deltaX = nesHorizontalDelta(p);
    // PlayerCtrlRoutine stores Player_MovingDir from the post-friction speed
    // immediately after MovePlayerHorizontally, before ScrollHandler and
    // player/background collision can clear Player_X_Speed.  Capture the sign
    // here so an ensuing collision still leaves the ROM's sticky direction.
    local movementDirection = p.nesXSpeed > 0 ? 1 :
        (p.nesXSpeed < 0 ? 2 : 0);
    // MovePlayerHorizontally returns this signed integer displacement for the
    // same frame's ScrollHandler.
    // A horizontal moving platform writes Platform_X_Scroll after this
    // frame's ScrollHandler, so its pixel displacement is added to the next
    // frame's Player_X_Scroll.
    p.nesXScroll = deltaX + pendingPlatformXScroll;
    p.vx = deltaX / dt;
    movePlayerX(g, p, dt);
    if (p.vx == 0.0 && deltaX != 0) {
        p.nesXSpeed = 0;
        if (!("sidePipeCollision" in p) || !p.sidePipeCollision) {
            p.nesXForce = 0;
            p.nesXMoveForce = 0;
        }
    }
    if (movementDirection != 0) p.movingDir = movementDirection;
    p.vx = p.nesXSpeed * 3.75;

    if (p.grounded) {
        // OnGroundStateSub never integrates vertically.  Background collision
        // may change Player_State to falling at the end of the frame when both
        // ROM foot samples lose support; gravity begins on the next frame.
        if (playerHasFootSupport(g, p)) {
            p.vy = 0.0;
        } else {
            p.grounded = false;
            p.entranceFalling = true;
            p.vy = 0.0;
        }
    } else {
        p.grounded = false;
        // Once A is released while rising, Player_Active_Gravity switches to
        // the fall value and a later mid-air re-press cannot restore it.
        if (p.nesYSpeed < 0 && !g.input.jumpDown)
            p.jumpGravityActive = false;
        local deltaY = nesVerticalDelta(p, p.jumpGravityActive);
        p.vy = deltaY / dt;
        movePlayerY(g, p, dt, p.nesYSpeed >= 0);
        if (p.vy == 0.0 && deltaY != 0) {
            p.nesYSpeed = p.headCollision ? p.headCollisionSpeed : 0;
            // PlayerHeadCollision nulls only Player_Y_Speed.  The two fractional
            // vertical accumulators continue, which controls the first falling
            // pixels after a block bump.
            if (!("headCollision" in p) || !p.headCollision) {
                p.nesYMoveForce = 0;
            }
        } else {
            p.vy = p.nesYSpeed * NES_FRAME_RATE;
        }
    }

    if (p.y > LOGICAL_HEIGHT + 32.0) killPlayer(g);
    if (p.x < g.cameraX) {
        p.x = g.cameraX;
        if (p.vx < 0.0) p.vx = 0.0;
    }
    handlePlayerBackgroundSides(g, p);
}

function updateLevelCoins(g) {
    local p = g.player;
    local spriteY = p.big && !p.crouching ? p.y : p.y - 16.0;
    local probes = [];
    if (p.big && !p.crouching) {
        // BlockBufferAdder set $00: head, left/right feet, then upper/lower
        // halves of the left and right sides (tables at $B5D2/$B5EE).
        probes = [[8.0, 4.0], [3.0, 32.0], [12.0, 32.0],
                  [2.0, 8.0], [2.0, 24.0], [13.0, 8.0], [13.0, 24.0]];
    } else {
        // Small/crouching Mario selects set $0e.  Its two vertical side
        // samples collapse onto the same coordinate, so one probe per side
        // is equivalent and preserves the original first-hit return.
        probes = [[8.0, 18.0], [3.0, 32.0], [12.0, 32.0],
                  [2.0, 24.0], [13.0, 24.0]];
    }
    foreach (probe in probes) {
        local tx = floor((p.x + probe[0]) / TILE_SIZE).tointeger();
        local ty = floor((spriteY + probe[1]) / TILE_SIZE).tointeger();
        foreach (coin in g.levelCoins) {
            if (!coin.active) continue;
            if (floor(coin.x / TILE_SIZE).tointeger() == tx &&
                floor(coin.y / TILE_SIZE).tointeger() == ty) {
                coin.active = false;
                if(g.level==3) coin.visualErasePending <- true;
                // EraseCoinMetatile writes through the second VRAM buffer.
                g.vramBufferAddrCtrl = 6;
                awardCoin(g);
                return;
            }
        }
    }
}

function collectPowerUp(g, item) {
    local p = g.player;
    item.active = false;
    parityRecordEvent(g, "gameplay", "powerup_collect",
        ",\"kind\":\"" + item.kind + "\"");
    if (item.kind == "oneup") {
        g.lives += 1;
        g.score += 1000;
        emitSound(g, "oneup");
        return;
    }
    if (item.kind == "star") {
        p.starTimer = STAR_INVINCIBLE_TIME;
        p.starMusicActive = true;
        g.score += 1000;
        emitSound(g, "powerup");
        emitSound(g, "star_music");
        return;
    }
    if (!p.big) {
        p.big = true;
        p.crouching = false;
        p.height = 32.0;
        p.y -= 16.0;
        p.transformFrames = 40;
        p.transformTimer = 40.0 * FIXED_DT;
        p.transformToBig = true;
        p.transformKind = "grow";
    } else if (!p.fire && (item.kind == "flower" || item.kind == "mushroom")) {
        // Shroom_Flower_PUp upgrades the status from before this pickup:
        // small -> Super, Super -> Fire, Fire -> unchanged, for either item.
        p.fire = true;
        p.transformFrames = 63;
        p.transformTimer = 63.0 * FIXED_DT;
        p.transformToBig = true;
        p.transformKind = "fire";
    }
    emitSound(g, "powerup");
    g.score += 1000;
}

function powerUpDrawY(item) {
    return item.emerging ? item.y + POWERUP_DRAW_Y_OFFSET : item.y;
}

function bumpPowerUpAbove(g, item, tx, ty) {
    // PowerUpObjHandler sends mushrooms/1UPs through EnemyToBGCollisionDet.
    // Flowers skip it; stars use EnemyJump instead. ChkUnderEnemy samples
    // (ROM X + $08, ROM Y + $18), not the whole sprite's bounding rectangle.
    if (!item.active || item.emerging ||
        (item.kind != "mushroom" && item.kind != "oneup")) return false;
    if (floor((item.x + 8.0) / TILE_SIZE).tointeger() != tx ||
        floor((item.romY + 24.0) / TILE_SIZE).tointeger() != ty) return false;
    // SetStun: Y -= 2, Y speed = $fd; EnemyBGCXSpdData = $10/$f0.
    // PlayerEnemyDiff selects a direction away from Mario, not unconditional
    // reversal. Horizontal speeds are 4.4 fixed point: +/-1 pixel per frame.
    item.y -= 2.0;
    item.romY -= 2.0;
    item.vy = -3.0 * NES_FRAME_RATE;
    item.vx = item.x < g.player.x ? -NES_FRAME_RATE : NES_FRAME_RATE;
    item.settleFrame = -1;
    return true;
}

function movePowerUp(g, item, dt) {
    if (item.emerging) {
        // GrowThePowerUp moves one pixel every four frames.
        item.emergeFrame += 1;
        if ((item.emergeFrame & 3) == 0) {
            item.y -= 1.0;
            item.romY -= 1.0;
            item.emergePixels += 1;
            // State values $01-$05 are not submitted to the OAM renderer.
            if (item.emergePixels >= 5) item.visible = true;
        }
        if (item.y <= item.targetY) {
            // Convert the ROM object coordinate to the host's top-left sprite
            // coordinate once the background-priority emergence is complete.
            item.y = item.targetY + POWERUP_DRAW_Y_OFFSET;
            item.romY = item.targetY;
            item.emerging = false;
            item.settleFrame = 0;
        }
        return;
    }

    // Fire flowers stay on their block after emerging. Mushrooms and one-ups
    // walk, while the star uses the original jumping-power-up movement class.
    if (item.kind == "flower") return;

    local nextX = item.x + item.vx * dt;
    local probeX = item.vx > 0.0 ? nextX + item.width - 0.001 : nextX;
    local tx = floor(probeX / TILE_SIZE).tointeger();
    local top = floor((item.y + 1.0) / TILE_SIZE).tointeger();
    local bottom = floor((item.y + item.height - 1.0) / TILE_SIZE).tointeger();
    local hitWall = false;
    for (local ty = top; ty <= bottom; ty += 1)
        if (isSolidAt(g, tx, ty)) hitWall = true;
    if (hitWall) {
        item.vx = -item.vx;
    } else {
        item.x = nextX;
    }

    // The first floor check after a mushroom exits its block sets enemy-state
    // bit 6.  Fast downward motion then needs four fractional frames before
    // EnemyLanding aligns the ROM coordinate from 119 to 120 and clears it.
    if ((item.kind == "mushroom" || item.kind == "oneup") &&
        item.settleFrame >= 0) {
        item.settleFrame += 1;
        if (item.settleFrame >= 5) {
            item.romY += 1.0;
            item.settleFrame = -1;
        }
        return;
    }

    local gravity = item.kind == "star" ? 393.75 : 857.8125;
    item.vy += gravity * dt;
    if (item.vy > 180.0) item.vy = 180.0;
    local nextY = item.y + item.vy * dt;
    if (item.vy >= 0.0) {
        local floorTy = floor((nextY + item.height - 0.001) / TILE_SIZE).tointeger();
        // ChkUnderEnemy samples one block below (ROM X + $08, ROM Y + $18).
        // A corner probe keeps a mushroom suspended while either sprite edge
        // still overlaps its old block, allowing it to cross a one-tile hole.
        local centerTx = floor((item.x + item.width * 0.5) / TILE_SIZE).tointeger();
        if (isSolidAt(g, centerTx, floorTy)) {
            nextY = floorTy * TILE_SIZE - item.height;
            item.vy = item.kind == "star" ? -180.0 : 0.0;
        }
    }
    item.y = nextY;
    if (item.kind == "mushroom" || item.kind == "oneup" || item.kind == "star")
        item.romY = item.y - 8.0;
    if (item.y > LOGICAL_HEIGHT + 32.0) item.active = false;
}

function updatePowerUps(g, dt) {
    local p = g.player;
    foreach (item in g.powerups) {
        // Enemy OAM built during the preceding game pass is the image copied
        // by the current DMA.  Stage every visual field before mutating RAM.
        item.displayActive = item.active;
        item.displayX = item.x;
        item.displayRomY = item.romY;
        item.displayEmerging = item.emerging;
        item.displayVisible = item.visible;
        if (!item.active) continue;
        movePowerUp(g, item, dt);
        // The bumped metatile ($23 in the ROM) remains available until block
        // restoration, so a mushroom arriving just after the hit can react.
        // Consuming it once prevents repeated launches during one block bump.
        if (g.bump.active && g.bump.powerupPending &&
            bumpPowerUpAbove(g, item, g.bump.tx, g.bump.ty))
            g.bump.powerupPending = false;
        if (!item.emerging && !p.dead &&
            overlaps(p.x, p.y, p.width, p.height,
                     item.x, item.y, item.width, item.height))
            collectPowerUp(g, item);
    }
}

function activeFireballCount(g) {
    local count = 0;
    foreach (fireball in g.fireballs)
        if (fireball.active) count += 1;
    return count;
}

function spawnFireball(g) {
    local p = g.player;
    if (!p.fire || p.dead || activeFireballCount(g) >= 2) return;
    g.fireballs.append({
        x = p.x + (p.facing > 0 ? 8.0 : -2.0),
        y = p.y + (p.big ? 12.0 : 4.0),
        width = 8.0,
        height = 8.0,
        vx = p.facing * FIREBALL_SPEED,
        vy = 240.0,
        nesYSpeed = 4,
        nesYMoveForce = 0,
        nesYDummy = 0,
        bouncing = false,
        active = true,
        exploding = false,
        explosionFrames = 0
    });
    parityRecordEvent(g, "gameplay", "fireball_spawn");
    p.throwingTimer = 0.16;
    emitSound(g, "fireball");
}

function fireballVerticalDelta(fireball) {
    local positionSum = fireball.nesYDummy + fireball.nesYMoveForce;
    fireball.nesYDummy = positionSum & 0xFF;
    local delta = fireball.nesYSpeed + floor(positionSum / 256).tointeger();
    local velocitySum = fireball.nesYMoveForce + 0x50;
    fireball.nesYMoveForce = velocitySum & 0xFF;
    fireball.nesYSpeed += floor(velocitySum / 256).tointeger();
    if (fireball.nesYSpeed > 3) {
        fireball.nesYSpeed = 3;
        fireball.nesYMoveForce = 0;
    }
    fireball.vy = fireball.nesYSpeed * NES_FRAME_RATE;
    return delta.tofloat();
}

function explodeFireball(fireball) {
    fireball.exploding = true;
    fireball.explosionFrames = 6;
    fireball.vx = 0.0;
    fireball.vy = 0.0;
}

function launchDefeatedEnemy(g, enemy, direction = 0) {
    if (direction == 0) {
        local playerCenter = g.player.x + g.player.width * 0.5;
        local enemyCenter = enemy.x + enemy.width * 0.5;
        direction = enemyCenter >= playerCenter ? 1 : -1;
    }
    // ChkToStunEnemies preserves the enemy type, moves it two pixels up, and
    // sets state d1 plus a -3px/frame vertical speed. ShellOrBlockDefeat then
    // adds state d5. Keep the object allocated until its ballistic path leaves
    // the screen so the existing flipped-enemy renderer can present it.
    enemy.alive = true;
    enemy.state = "flipped";
    enemy.stateTimer = 0.0;
    enemy.intervalTimer = 0;
    enemy.y -= 2.0;
    enemy.vx = direction * NES_FRAME_RATE;
    enemy.vy = -3.0 * NES_FRAME_RATE;
    enemy.grounded = false;
    enemy.collisionCooldown = 0.0;
    enemy.erasedDisplayFrames = 0;
    enemy.erasedSlot = -1;
}

function updateFireballs(g, dt) {
    foreach (fireball in g.fireballs) {
        if (!fireball.active) continue;
        if (fireball.exploding) {
            fireball.explosionFrames -= 1;
            if (fireball.explosionFrames <= 0) fireball.active = false;
            continue;
        }

        local nextX = fireball.x + fireball.vx * dt;
        local probeX = fireball.vx > 0.0 ? nextX + fireball.width : nextX;
        local wallTx = floor(probeX / TILE_SIZE).tointeger();
        local top = floor((fireball.y + 1.0) / TILE_SIZE).tointeger();
        local bottom = floor((fireball.y + fireball.height - 1.0) / TILE_SIZE).tointeger();
        local hitWall = false;
        for (local ty = top; ty <= bottom; ty += 1)
            if (isSolidAt(g, wallTx, ty)) hitWall = true;
        if (hitWall) {
            explodeFireball(fireball);
            continue;
        }
        fireball.x = nextX;

        local nextY = fireball.y + fireballVerticalDelta(fireball);
        local sampleTx = floor((fireball.x + fireball.width * 0.5) / TILE_SIZE).tointeger();
        local sampleTy = floor((nextY + fireball.height - 0.001) / TILE_SIZE).tointeger();
        if (isSolidAt(g, sampleTx, sampleTy)) {
            if (fireball.nesYSpeed < 0 || fireball.bouncing) {
                explodeFireball(fireball);
                continue;
            }
            nextY = floor(nextY / 8.0) * 8.0;
            fireball.nesYSpeed = -3;
            fireball.nesYMoveForce = 0;
            fireball.nesYDummy = 0;
            fireball.vy = -180.0;
            fireball.bouncing = true;
        } else {
            fireball.bouncing = false;
        }
        fireball.y = nextY;

        foreach (enemy in g.goombas) {
            if (!enemy.alive || enemy.state == "defeated" || enemy.state == "flipped") continue;
            if (!overlaps(fireball.x, fireball.y, fireball.width, fireball.height,
                          enemy.x, enemy.y, enemy.width, enemy.height)) continue;
            launchDefeatedEnemy(g, enemy);
            parityRecordEvent(g, "gameplay", "fireball_enemy_hit",
                ",\"enemy\":\"" + enemy.kind + "\"");
            g.score += enemy.kind == "goomba" ? 100 : 200;
            explodeFireball(fireball);
            break;
        }
        if (fireball.x < g.cameraX - 16.0 ||
            fireball.x > g.cameraX + LOGICAL_WIDTH + 16.0 ||
            fireball.y > LOGICAL_HEIGHT + 16.0) fireball.active = false;
    }
}

function moveEnemyBody(g, e, dt) {
    local collisionX = e.x;
    if (g.level != 3 && "red" in e && e.red && e.state == "walking" && e.grounded) {
        local footX=e.vx<0?e.x:e.x+e.width;
        if(!isSolidAt(g,floor(footX/16).tointeger(),floor((e.y+e.height+1)/16).tointeger()))
            e.vx=-e.vx;
    }
    local world13GroundWalker = g.level == 3 &&
        (e.kind == "goomba" ||
         (e.kind == "koopa" && e.state != "shell" &&
          e.state != "shellMoving" && e.state != "flipped" &&
          !("paratroopa" in e && e.paratroopa)));
    if (world13GroundWalker) {
        local supportRow = floor((e.y + e.height) / TILE_SIZE).tointeger();
        local supportColumn = floor((collisionX + 8.0) / TILE_SIZE).tointeger();
        if (isSolidAt(g, supportColumn, supportRow)) {
            if (e.state == "falling") {
                // EnemyToBGCollisionDet runs before EnemyMovementSubs. Its
                // foot probe uses the current Y coordinate; EnemyLanding only
                // snaps while the ROM origin's low nibble is $08-$0c. This
                // leaves the transient overshoot visible for one falling
                // pass and lands the enemy on the following pass.
                local originY = floor(e.y).tointeger() - 10;
                local landingNibble = originY & 0x0f;
                if (landingNibble >= 8 && landingNibble <= 12) {
                    local landedOrigin = (originY & 0xf0) | 8;
                    e.y = (landedOrigin + 10).tofloat();
                    e.nesYSpeed = 0;
                    e.nesYMoveForce = 0;
                    e.vy = 0.0;
                }
                e.state = "walking";
                e.grounded = true;
            }
        } else if (e.state == "walking" && e.kind=="koopa" &&
                   e.red && !("paratroopa" in e)) {
            // ChkForRedKoopa turns an ordinary red Koopa at its bottom-middle
            // probe instead of allowing the walking state to become falling.
            e.vx=-e.vx;
            e.grounded=true;
        } else if (e.state == "walking") {
            // EnemyBGCollision runs before EnemyMovementSubs. A ground walker
            // with no bottom-middle support enters state $01 and therefore
            // spends this pass in the falling routine.
            e.state = "falling";
            e.grounded = false;
        }
    }
    local greenJump=("greenJump" in e) && e.greenJump && e.state=="walking";
    if(greenJump) {
        if(e.grounded) {e.nesYSpeed=-3;e.nesYMoveForce=0;e.grounded=false;}
        local positionSum=e.nesYDummy+e.nesYMoveForce;
        e.nesYDummy=positionSum&255;
        e.vy=(e.nesYSpeed+floor(positionSum/256).tointeger())/dt;
        local forceSum=e.nesYMoveForce+0x1c;
        e.nesYMoveForce=forceSum&255;e.nesYSpeed+=floor(forceSum/256).tointeger();
        if(e.nesYSpeed>=3 && e.nesYMoveForce>=0x80) {
            e.nesYSpeed=3;e.nesYMoveForce=0;
        }
    } else if (!world13GroundWalker) {
        e.vy += 857.8125 * dt;
        if (e.vy > 180.0) e.vy = 180.0;
    }

    // RunNormalEnemies checks background at the current actor position and
    // only then dispatches movement.  Side samples are x+$00 and x+$10.
    local probeX = e.vx > 0.0 ? e.x + 16.0 : e.x;
    if (g.level == 2 && g.area == "underground") probeX += e.vx * dt;
    local tx = floor(probeX / TILE_SIZE).tointeger();
    local top = floor((e.y + 1.0) / TILE_SIZE).tointeger();
    local bottom = floor((e.y + e.height - 1.0) / TILE_SIZE).tointeger();
    local hitWall = false;
    local wallRow = top;
    for (local ty = top; ty <= bottom; ty += 1)
        if (isSolidAt(g, tx, ty)) {hitWall = true;wallRow = ty;}
    if (hitWall) {
        if (g.level == 2 && g.area == "underground") {
            // Group spawns can start inside a two-column pipe. A direction
            // flip alone leaves the probe embedded and flips it back next
            // frame. Resolve against the entire solid span before turning.
            local edge = tx;
            if (e.vx > 0.0) {
                while (edge >= 0 && isSolidAt(g, edge, wallRow)) edge -= 1;
                local boundary=(edge + 1) * TILE_SIZE - 16.0;
                if(e.x>boundary) e.x=boundary;
            } else {
                while (edge < g.areaWidth && isSolidAt(g, edge, wallRow)) edge += 1;
                local boundary=edge * TILE_SIZE.tofloat();
                if(e.x<boundary) e.x=boundary;
            }
        }
        e.vx = -e.vx;
        if (e.kind == "koopa") e.shellDirection = e.vx >= 0.0 ? 1 : -1;
    }
    e.x += e.vx * dt;

    local nextY = e.y + e.vy * dt;
    if (e.state == "falling" && world13GroundWalker) {
        // MoveD_EnemyVertically uses downward force $3d and maximum speed $03.
        // The first pass consumes only the byte-sized movement force, so the
        // integer Y remains unchanged until its accumulator carries.
        local positionSum = e.nesYDummy + e.nesYMoveForce;
        e.nesYDummy = positionSum & 0xFF;
        local delta = e.nesYSpeed + floor(positionSum / 256).tointeger();
        local forceSum = e.nesYMoveForce + 0x3D;
        e.nesYMoveForce = forceSum & 0xFF;
        e.nesYSpeed += floor(forceSum / 256).tointeger();
        if (e.nesYSpeed >= 3 && e.nesYMoveForce >= 0x80) {
            e.nesYSpeed = 3;
            e.nesYMoveForce = 0;
        }
        nextY = e.y + delta;
        e.vy = e.nesYSpeed * NES_FRAME_RATE;
    }
    if (nextY >= e.y && !world13GroundWalker) {
        local floorTy = floor((nextY + e.height) / TILE_SIZE).tointeger();
        // BlockBufferChk_Enemy checks the bottom-middle probe (X+8, Y+18),
        // not both edges. A trailing edge touching an adjacent column must not
        // keep a Goomba walking over a ledge.
        local floorTx = floor((collisionX + 8.0) / TILE_SIZE).tointeger();
        if (isSolidAt(g, floorTx, floorTy)) {
            nextY = floorTy * TILE_SIZE - e.height;
            e.vy = 0.0;
            e.grounded = true;
            if (e.state == "falling") {
                e.state = "walking";
                e.nesYSpeed = 0;
                e.nesYMoveForce = 0;
                e.nesYDummy = 0;
            }
        }
    }
    e.y = nextY;
    if (e.y > LOGICAL_HEIGHT + 32.0) e.alive = false;
}

function stompGoomba(e) {
    e.state = "defeated";
    // HandleStompedShellE writes $10 to EnemyIntervalTimer. ChkKillGoomba
    // erases a Goomba when the 21-frame interval bank reaches $0e, so the
    // visible lifetime depends on the current interval phase rather than a
    // fixed number of ordinary frames.
    e.intervalTimer = 0x10;
    e.stateTimer = 2.0 * 21.0 * FIXED_DT;
    // State $04 suppresses movement but does not clear Enemy_X_Speed.  It
    // can consequently still be reversed by enemy-to-enemy collision.
}

function enterKoopaShell(e) {
    local bottom = e.y + e.height;
    e.shellDirection = e.vx >= 0.0 ? 1 : -1;
    e.state = "shell";
    e.stateTimer = KOOPA_REVIVE_FRAMES * FIXED_DT;
    e.shellFrames = KOOPA_REVIVE_FRAMES;
    e.intervalTimer = 0x10;
    e.height = 14.0;
    e.y = bottom - e.height;
    e.vx = 0.0;
    e.vy = 0.0;
    e.shellChain = 0;
    e.collisionCooldown = 0.12;
}

function stopKoopaShell(e) {
    e.state = "shell";
    e.stateTimer = KOOPA_REVIVE_FRAMES * FIXED_DT;
    e.shellFrames = KOOPA_REVIVE_FRAMES;
    e.intervalTimer = 0x10;
    e.vx = 0.0;
    e.shellChain = 0;
    e.collisionCooldown = 0.12;
}

function kickKoopaShell(g, e) {
    local scoreControl = 3 + g.stompChain;
    local remainingIntervals = e.intervalTimer;
    if (remainingIntervals < 3) {
        local nearRevivalControls = [10, 6, 4];
        scoreControl = nearRevivalControls[remainingIntervals];
    }
    awardScoreControl(g, scoreControl);
    e.state = "shellMoving";
    e.stateTimer = 0.0;
    e.shellFrames = 0;
    e.shellChain = 0;
    e.collisionCooldown = 0.16;
    local playerCenter = g.player.x + g.player.width * 0.5;
    local shellCenter = e.x + e.width * 0.5;
    e.shellDirection = playerCenter < shellCenter ? 1 : -1;
    e.vx = e.shellDirection * KOOPA_SHELL_SPEED;
    parityRecordEvent(g, "gameplay", "shell_kick");
    emitSound(g, "kick");
}

function reviveKoopa(e, frameCounter = 0) {
    local bottom = e.y + e.height;
    e.state = "walking";
    e.stateTimer = 0.0;
    e.shellFrames = 0;
    e.intervalTimer = 0;
    e.height = 24.0;
    e.y = bottom - e.height;
    e.shellDirection = (frameCounter & 1) == 0 ? 1 : -1;
    e.vx = e.shellDirection * KOOPA_WALK_SPEED;
    e.collisionCooldown = 0.2;
}

function koopaShellAnimationFrame(state, intervalTimer, frameCounter) {
    // EnemyGfxHandler keeps the plain shell while the interval timer is >=5.
    // Only its last four intervals may expose feet; a kicked shell suppresses
    // this animation regardless of how long it has moved.
    if (state != "shell" || intervalTimer >= 5) return 0;
    return (frameCounter & 0x08) == 0 ? 1 : 0;
}

function awardScoreControl(g, control) {
    local scores = [0, 100, 200, 400, 500, 800,
                    1000, 2000, 4000, 5000, 8000];
    if (control >= 11) {
        g.lives += 1;
        emitSound(g, "oneup");
        return;
    }
    if (control < 0) control = 0;
    g.score += scores[control];
    // FloateyNumbersRoutine runs before PrintStatusBarNumbers in the same
    // game-engine pass, so this score is eligible for the immediately queued
    // status-bar update rather than waiting for the next pass.
    g.queuedScore = g.score;
}

function awardStomp(g, enemy, scoreControl=-1) {
    if(scoreControl<0) {g.stompChain+=1;scoreControl=g.stompChain;}
    // SetupFloateyNumber writes $30.  FloateyNumbersRoutine awards when the
    // pre-decrement value reaches $2b, which is five subsequent game frames
    // after the collision in the captured NTSC execution.
    // The reference capture has already run the first routine pass at the
    // collision boundary: timer $2f and Y one pixel above Enemy_Y_Position.
    local walkingKoopa=enemy.kind=="koopa" && enemy.state!="shell" &&
        enemy.state!="shellMoving";
    local scoreY = enemy.y - (walkingKoopa ? 1.0 : 11.0);
    g.floatingScores.append({
        frames = 5,
        timer = 47,
        control = scoreControl,
        awarded = false,
        age = 0,
        owner = enemy,
        erasedAge = 0,
        x = floor(enemy.x - g.cameraX).tofloat(),
        y = scoreY,
        displayY = scoreY
    });
}

function updateFloatingScores(g) {
    for (local i = g.floatingScores.len() - 1; i >= 0; i -= 1) {
        local floating = g.floatingScores[i];
        floating.age += 1;
        // EraseEnemyObject also clears its floatey control. Keep only the
        // two prepared OAM passes after the owning slot is released.
        if(!floating.owner.alive) floating.erasedAge += 1;
        floating.displayY = floating.y;
        if(floating.y>=24.0) floating.y -= 1.0;
        floating.timer -= 1;
        if (!floating.awarded) floating.frames -= 1;
        if (!floating.awarded && floating.frames <= 0) {
            awardScoreControl(g, floating.control);
            floating.awarded = true;
        }
        if (floating.timer <= -2 || floating.erasedAge >= 1) g.floatingScores.remove(i);
    }
}

function updateShellEnemyCollisions(g) {
    // EnemiesCollision visits each lower-index object once for every later
    // object. Do the same here so every overlapping pair is processed once.
    for (local firstIndex = 0; firstIndex < g.goombas.len(); firstIndex += 1) {
        local first = g.goombas[firstIndex];
        if (!first.alive) continue;
        for (local secondIndex = 0; secondIndex < firstIndex; secondIndex += 1) {
            local second = g.goombas[secondIndex];
            if (!second.alive) continue;
            local firstMoving = first.kind == "koopa" &&
                first.state == "shellMoving";
            local secondMoving = second.kind == "koopa" &&
                second.state == "shellMoving";
            if (!firstMoving && !secondMoving) continue;
            if (first.state == "defeated" || first.state == "flipped" ||
                second.state == "defeated" || second.state == "flipped")
                continue;
            if (!overlaps(first.x, first.y, first.width, first.height,
                          second.x, second.y, second.width, second.height))
                continue;
            if (firstMoving && secondMoving) {
                // Both d7 states enter ProcEnemyCollisions. The unresolved
                // SetupFloateyNumber #6 write on the first shell is replaced
                // by ShellOrBlockDefeat's type score, while the second shell
                // receives the chain score. FloateyNumbersRoutine consumes only
                // these final controls after enemy processing, so #6 is not an
                // additional award. The chain belongs to the first shell.
                launchDefeatedEnemy(g, first);
                launchDefeatedEnemy(g, second);
                awardScoreControl(g, 2);
                awardScoreControl(g, 4 + first.shellChain);
                emitSound(g, "kick");
                first.shellChain += 1;
                continue;
            }
            local shell = firstMoving ? first : second;
            local other = firstMoving ? second : first;
            // ShellOrBlockDefeat stuns the complete enemy object before adding
            // defeated state d5. Do not erase the victim: shell kills retain
            // its type and follow the same airborne animation as other flips.
            launchDefeatedEnemy(g, other);
            awardScoreControl(g, 4 + shell.shellChain);
            emitSound(g, "kick");
            shell.shellChain += 1;
        }
    }
}

function allocateEnemySlot(g, enemy) {
    for (local slot = 0; slot < 5; slot += 1) {
        local occupied = false;
        foreach (other in g.goombas) {
            if (other != enemy && other.awake && other.alive &&
                other.slot == slot) {
                occupied = true;
                break;
            }
        }
        if (g.level == 3 && "world13Bullets" in g) {
            foreach (bullet in g.world13Bullets) {
                if (bullet.active && bullet.slot == slot) {
                    occupied = true;
                    break;
                }
            }
        }
        if (g.level == 3 && "platforms" in g) {
            foreach (platform in g.platforms) {
                if (platform.awake && !platform.retired &&
                    platform.slot == slot) {
                    occupied = true;
                    break;
                }
            }
        }
        if (!occupied) {
            if (g.level == 3 && "platforms" in g) {
                foreach (platform in g.platforms) {
                    if (platform.retired && platform.lastSlot == slot &&
                        "fraction" in platform)
                        enemy.x+=platform.fraction/256.0;
                    if (platform.retired && platform.lastSlot == slot &&
                        "verticalDummy" in platform) {
                        // Enemy object slots retain the vertical fractional
                        // accumulator after EraseEnemyObject. InitVStf clears
                        // speed and move force, but not this dummy byte.
                        enemy.nesYDummy = platform.verticalDummy & 0xff;
                    }
                }
            }
            enemy.slot = slot;
            enemy.enemyCollisionMask = 0;
            return true;
        }
    }
    return false;
}

function releaseEnemySlot(enemy) {
    enemy.slot = -1;
    enemy.enemyCollisionMask = 0;
}

function updateNormalEnemyCollisions(g) {
    // sub_enemies_collision runs only when FrameCounter bit 0 is set.
    if ((g.nesFrameCounter & 1) == 0) return;
    for (local firstIndex = 0; firstIndex < g.goombas.len(); firstIndex += 1) {
        local first = g.goombas[firstIndex];
        if (!first.awake || !first.alive || first.slot < 0 ||
            first.state == "flipped") continue;
        // GetEnemyBoundBox moves a fully offscreen actor's box to $ff, and
        // EnemiesCollision rejects any nonzero masked offscreen bits.
        if (first.x < g.cameraX ||
            first.x >= g.cameraX + LOGICAL_WIDTH) continue;
        for (local secondIndex = 0; secondIndex < firstIndex; secondIndex += 1) {
            local second = g.goombas[secondIndex];
            if (!second.awake || !second.alive || second.slot < 0 ||
                second.state == "flipped") continue;
            if (second.x < g.cameraX ||
                second.x >= g.cameraX + LOGICAL_WIDTH) continue;
            local firstBit = 1 << second.slot;
            local secondBit = 1 << first.slot;
            // SmallEnemyBoundingBox control $09 is [$03,$0e,$0d,$14].
            // Its horizontal interval is therefore origin+3 through
            // origin+13 inclusive (11 pixels), not the full sprite width.
            local touching = overlaps(first.x + 3.0, first.y, 11.0, first.height,
                                      second.x + 3.0, second.y, 11.0, second.height);
            if (!touching) {
                first.enemyCollisionMask = first.enemyCollisionMask & ~firstBit;
                second.enemyCollisionMask = second.enemyCollisionMask & ~secondBit;
                continue;
            }
            if ((first.enemyCollisionMask & firstBit) != 0 ||
                (second.enemyCollisionMask & secondBit) != 0) continue;
            first.enemyCollisionMask = first.enemyCollisionMask | firstBit;
            second.enemyCollisionMask = second.enemyCollisionMask | secondBit;
            // Shell handling is performed by updateShellEnemyCollisions.  For
            // two normal states ProcessEnemyCollisions calls EnemyTurnAround
            // for both objects; a stomped Goomba's zero speed remains zero.
            if (first.state != "shellMoving" && second.state != "shellMoving") {
                first.vx = -first.vx;
                second.vx = -second.vx;
                if (first.kind == "koopa")
                    first.shellDirection = first.vx >= 0.0 ? 1 : -1;
                if (second.kind == "koopa")
                    second.shellDirection = second.vx >= 0.0 ? 1 : -1;
            }
        }
    }
}

function updateGoombas(g, dt) {
    local p = g.player;
    // Enemy stream parsing follows ScrollHandler in the original frame.  Use
    // the screen edge that this frame's pending scroll will expose.
    local projectedCameraX = g.cameraX;
    if (p.nesXScroll > 0 && !p.scrollSideCollisionTimer) {
        local positionForScroll = p.previousX - g.cameraX;
        if (positionForScroll >= 80.0) {
            local scroll = p.nesXScroll;
            if (positionForScroll < 112.0 && scroll >= 2) scroll -= 1;
            projectedCameraX += scroll;
        }
    }
    // RunNormalEnemies performs inter-enemy collision before dispatching
    // movement, so its boxes represent the positions entering this frame.
    updateNormalEnemyCollisions(g);
    foreach (e in g.goombas) {
        if (!e.alive) continue;
        if (p.dead) continue;
        e.previousX=e.x;e.previousY=e.y;
        e.previousFacing=e.vx<0?-1:(e.vx>0?1:
            (("world13Facing" in e)?e.world13Facing:-1));
        e.previousParatroopa=("paratroopa" in e) && e.paratroopa;
        // Sample before player collision, then retain OAM presentation latency.
        e.queuedShellFrame = koopaShellAnimationFrame(e.state,e.intervalTimer,g.nesFrameCounter);
        local playerWasDead = p.dead;
        if (e.collisionCooldown > 0.0) {
            e.collisionCooldown -= dt;
            if (e.collisionCooldown < 0.0) e.collisionCooldown = 0.0;
        }
        if (e.state == "defeated") {
            if (e.intervalTimer == 0x0E) {
                if (g.level == 3 && !e.eraseDelayPending) {
                    // The Goomba remains active for the pass that first
                    // observes $0e; EraseEnemyObject is exposed on the
                    // following game frame in the captured route.
                    e.eraseDelayPending = true;
                } else {
                    // Keep the two prepared OAM images after the gameplay
                    // slot is erased; its floatey control clears separately.
                    e.erasedDisplayFrames = 2;
                    e.erasedSlot = e.slot;
                    e.alive = false;
                    releaseEnemySlot(e);
                }
            }
            continue;
        }
        if (e.state == "flipped") {
            e.vy += 620.0 * dt;
            e.x += e.vx * dt;
            e.y += e.vy * dt;
            if (e.y > LOGICAL_HEIGHT + 32.0) e.alive = false;
            continue;
        }

        // The area parser makes the World 1-1 Goomba visible 48 px beyond the
        // right edge.  Its load frame only allocates the object slot; movement
        // starts on the following frame.
        if (!e.awake) {
            local triggerX = e.groupIndex >= 0 ? e.groupCommandX : e.x;
            // The parser adds $30 to ScreenRight_X_Pos and masks the low
            // nibble before comparing the stream object's 16-pixel column.
            local parserBoundary = floor((projectedCameraX +
                LOGICAL_WIDTH - 1.0 + 48.0) / 16.0) * 16.0;
            if (triggerX > parserBoundary) continue;
            if (e.groupIndex >= 0) {
                // SpawnEnemyGroup snapshots the right screen edge and adds
                // $18 for each member; the stream object's X is only a gate.
                e.x = projectedCameraX + LOGICAL_WIDTH - 1.0 + e.groupIndex * 24.0;
            }
            if (!allocateEnemySlot(g, e)) continue;
            e.awake = true;
            continue;
        }
        if (e.kind == "koopa" && e.state == "shell") {
            e.shellFrames = e.intervalTimer * NES_INTERVAL_FRAMES;
            e.stateTimer = e.shellFrames * FIXED_DT;
        }
        local playerBoxY = p.y + (p.big && !p.crouching ? 8.0 : 4.0);
        local playerBoxHeight = p.big && !p.crouching ? 24.0 : 12.0;
        local enemyBoxY = e.kind == "goomba" ? e.y + 4.0 : e.y + 9.0;
        local enemyBoxHeight = e.kind == "goomba" ? 6.0 : 12.0;
        local playerBoxX=p.x+3.0,playerBoxWidth=10.0;
        local enemyBoxX=e.x+3.0,enemyBoxWidth=10.0;
        if(e.kind=="koopa") {
            // TallBBox ($03) is relative to the ROM origin, which stays at
            // the same Y after a stomp. Only our 14px shell body moves down.
            local shell=e.state=="shell" || e.state=="shellMoving";
            enemyBoxY=e.y-(shell?10.0:0.0)+9.0;
            enemyBoxHeight=13.0;enemyBoxX=e.x+2.0;enemyBoxWidth=13.0;
            local tall=p.big && !p.crouching;
            playerBoxX=p.x+(tall?2.0:3.0);playerBoxWidth=tall?13.0:11.0;
            playerBoxHeight=tall?25.0:13.0;
        }
        local touching=overlaps(playerBoxX,playerBoxY,playerBoxWidth,playerBoxHeight,
                                enemyBoxX,enemyBoxY,enemyBoxWidth,enemyBoxHeight);
        local collisionPass=(g.nesFrameCounter&1)==0;
        if(e.kind=="koopa" && collisionPass && !touching) e.playerContact=false;
        local stompedThisFrame = false;
        if (collisionPass && !p.dead && touching &&
            (e.kind!="koopa" || !e.playerContact)) {
            if(e.kind=="koopa") e.playerContact=true;
            if (p.starTimer > 0.0) {
                launchDefeatedEnemy(g, e);
                parityRecordEvent(g, "gameplay", "star_enemy_hit",
                    ",\"enemy\":\"" + e.kind + "\"");
                g.score += e.kind == "goomba" ? 100 : 200;
                continue;
            }
            // ChkForPlayerInjury branches directly to EnemyStomped for a
            // positive Player_Y_Speed. Koopa's body collision box begins
            // below its head, so a previous-feet/head test rejects valid hits.
            if (e.kind == "koopa" && e.state == "shell") {
                // HandlePECollisions kicks a stationary shell even when
                // Mario is descending. Only a moving shell is stomped again.
                kickKoopaShell(g,e);
            } else if (p.nesYSpeed > 0 ||
                       (e.kind=="koopa" && p.nesYSpeed<=0 &&
                        (p.big && !p.crouching ? p.y : p.y-16.0)+12.0<e.y)) {
                local demotedParatroopa=false;
                parityRecordEvent(g, "gameplay", "enemy_stomp",
                    ",\"enemy\":\"" + e.kind + "\",\"enemy_state\":\"" + e.state + "\"");
                if (e.kind == "goomba") {
                    stompGoomba(e);
                } else if (e.state == "walking") {
                    if("greenJump" in e && e.greenJump) {
                        e.greenJump=false;demotedParatroopa=true;e.nesYSpeed=0;
                        e.nesYMoveForce=0;e.vy=0.0;
                    } else demotedParatroopa=g.level==3 && demoteWorld13Paratroopa(g,e);
                    if(!demotedParatroopa) enterKoopaShell(e);
                } else if (e.state == "shellMoving") {
                    stopKoopaShell(e);
                } else {
                    stopKoopaShell(e);
                }
                emitSound(g, "stomp");
                p.vy = -4.0 * NES_FRAME_RATE;
                p.nesYSpeed = -4;
                // SBnce writes only Player_Y_Speed. Preserve the fractional
                // force left by the downward movement pass (typically $fe),
                // which advances the bounce to -3 on the following frame.
                p.grounded = false;
                // SetupFloateyNumber copies Enemy_Rel_XPos, which has already
                // incorporated the pending ScrollHandler result for this pass.
                local savedCameraX = g.cameraX;
                g.cameraX = projectedCameraX;
                awardStomp(g,e,demotedParatroopa?3:
                    (g.level==3 && e.kind=="koopa"?2:-1));
                g.cameraX = savedCameraX;
                // HandleStompedShellE changes the state before
                // EnemyMovementSubs is dispatched, so a stomped enemy does
                // not receive its pending half-pixel movement. Keep the ROM's
                // integer Enemy_X_Position as the stopped coordinate. The
                // relative-X value already prepared for OAM can nevertheless
                // carry the preceding half-pixel phase for one more image.
                e.stompDisplayLead = e.x > floor(e.x) ? 1.0 : 0.0;
                if(!demotedParatroopa) e.x = floor(e.x).tofloat();
                stompedThisFrame = true;
            } else if (e.kind == "koopa" || e.collisionCooldown <= 0.0) {
                hurtPlayer(g, e);
            } else {
                // A newly kicked/stopped shell briefly ignores the player who
                // caused the transition, matching SMB's collision-bit delay.
            }
        }
        // RunNormalEnemies performs player collision before EnemyMovementSubs.
        // A lethal collision raises TimerControl, so that same frame must not
        // advance the enemy another half pixel.
        if (!playerWasDead && p.dead) continue;
        if (stompedThisFrame) continue;
        if(e.kind=="koopa" && e.state=="shell" && e.intervalTimer==0)
            reviveKoopa(e,g.nesFrameCounter);
        moveEnemyBody(g, e, dt);
        // OffscreenBoundsCheck reaches `SBC #$48` with carry clear for a
        // normal Goomba: the preceding `CPY #con_piranha_plant` fails with
        // Y=$06.  The effective bound is therefore screen-left-$49 (73 px),
        // despite the source comment describing a 72-pixel extension.
        if (e.x < projectedCameraX - 73.0) {
            e.alive = false;
            releaseEnemySlot(e);
            continue;
        }
    }
    updateShellEnemyCollisions(g);
}

function updateCoinEffect(g, effect, dt) {
    if (!effect.active) return;
    // Misc-object OAM still displays the pre-update phase on the transition
    // from the ballistic coin to its floatey score number.
    effect.displayPhase = effect.phase;
    effect.time += dt;
    if (effect.phase == "coin") {
        effect.frame += 1;
        // State 1 is the ballistic coin.  Once downward speed reaches five,
        // the ROM increments Misc_State and the slot becomes a floatey number.
        if (effect.frame > 31) {
            effect.phase = "score";
            effect.scoreFrame = 1;
        }
    } else {
        // ProcJumpCoin keeps floatey-number objects screen-relative by adding
        // the preceding ScrollAmount to their stored horizontal coordinate.
        // OAM DMA still displays the coordinate prepared before this update.
        effect.displayX = effect.x;
        effect.x += g.previousScrollAmount;
        effect.scoreFrame += 1;
        if (effect.scoreFrame > 46) effect.active = false;
    }
}

function updateEffects(g, dt) {
    if (g.brickCoinTimer > 0.0) {
        g.brickCoinTimer -= dt;
        if (g.brickCoinTimer < 0.0) g.brickCoinTimer = 0.0;
    }
    if (g.bump.active) {
        g.bump.time += dt;
        g.bump.frame += 1;
        if (g.bump.frame > 15) g.bump.active = false;
    }
    updateCoinEffect(g, g.coinEffect, dt);
    for (local effectIndex = g.archivedCoinEffects.len() - 1;
         effectIndex >= 0; effectIndex -= 1) {
        local effect = g.archivedCoinEffects[effectIndex];
        updateCoinEffect(g, effect, dt);
        if (!effect.active) g.archivedCoinEffects.remove(effectIndex);
    }
    foreach (piece in g.brickDebris) {
        if (!piece.active) continue;
        piece.vy += 760.0 * dt;
        piece.x += piece.vx * dt;
        piece.y += piece.vy * dt;
        piece.life -= dt;
        if (piece.life <= 0.0 || piece.y > LOGICAL_HEIGHT + 16.0)
            piece.active = false;
    }
}

function updateCamera(g) {
    if (g.area == "underground" && !(g.level == 2 && g.stage == "underground")) {
        g.cameraX = 0.0;
        g.displayCameraX = 0.0;
        g.previousScrollAmount = 0.0;
        return;
    }
    local p = g.player;
    local scrollAmount = 0;
    if ((g.state == "playing" || g.state == "pipeDown" ||
         g.flagContactScrollPending ||
         (g.state == "endLevel" && !g.endLevelScrollLocked)) &&
        (!p.dead || p.deadTimer == 0.0) &&
        p.nesXScroll > 0 && !p.scrollSideCollisionTimer) {
        // Player_Pos_ForScroll is prepared from the preceding frame's player
        // position. ScrollHandler starts at $50; below $70 it removes one
        // pixel from displacements of two or more pixels.
        local positionForScroll = (g.state == "pipeDown" ?
            floor(p.x + 0.5).tofloat() : p.previousX) - g.cameraX;
        if (g.state == "pipeDown" && g.areaTransitionFrames == 1) {
            scrollAmount = p.nesXScroll;
        } else if (positionForScroll >= 80.0) {
            scrollAmount = p.nesXScroll;
            if (positionForScroll < 112.0 && scrollAmount >= 2)
                scrollAmount -= 1;
        }
    }
    g.cameraX += scrollAmount;
    local maximum = g.areaWidth * TILE_SIZE - LOGICAL_WIDTH;
    g.cameraX = clampValue(g.cameraX, 0.0, maximum.tofloat());
    // The PPU renders the frame from the left edge that existed before this
    // pass applied ScrollAmount.  Keep that display edge separate from the
    // RAM-side ScreenLeft_X_Pos used by gameplay and parity state checks.
    g.displayCameraX = clampValue(g.cameraX - scrollAmount,
                                  0.0, maximum.tofloat());
    g.previousScrollAmount = scrollAmount;
    g.flagContactScrollPending = false;
    // HalfwayPageNybbles stores page 5 for World 1-1.  It is only retained
    // after the left edge has actually reached that page.
    if (g.world==1 && g.level == 1 && g.area == "main" && g.cameraX >= 5.0 * 256.0)
        g.checkpointPage = 5;
}

function updateVramAreaParserScheduler(g) {
    // SMB accumulates ScrollAmount in ScrollThirtyTwo ($073d).  Each crossed
    // 32-pixel boundary starts the eight AreaParserTaskHandler passes.  Tasks
    // 6, 5, 2 and 1 render columns; task 0 appends attributes.  All five
    // select VRAM buffer 2 through VRAM_Buffer_AddrCtrl ($0773 = $06).
    // Replaying this state machine from the ROM source reproduces the exact
    // buffer-selection trace, including palette packets deferred by scrolling.
    g.vramScrollThirtyTwo += g.previousScrollAmount.tointeger();
    // UpdScrollVar accumulates ScrollThirtyTwo before testing whether another
    // gameplay pass has already selected VRAM buffer 2. A coin erased in this
    // same frame queues $06 there, so the parser waits one pass but the scroll
    // accumulator still advances.
    if (g.vramBufferAddrCtrl == 6) return;
    if (g.vramAreaParserTask == 0) {
        if (g.vramScrollThirtyTwo < 32) return;
        g.vramScrollThirtyTwo -= 32;
        g.vramAreaParserTask = 8;
    }
    g.vramAreaParserTask -= 1;
    local completedTask = g.vramAreaParserTask;
    if (completedTask == 6 || completedTask == 5 ||
        completedTask == 2 || completedTask == 1 || completedTask == 0)
        g.vramBufferAddrCtrl = 6;
}

function beginFlagSequence(g) {
    local p = g.player;
    // HandleClimbing compares Player_Y_Position against FlagpoleYPosData.
    // Small/crouching Mario still owns a 32px sprite with a transparent top row.
    local spriteY = p.big && !p.crouching ? p.y : p.y - 16.0;
    local thresholds = [0x18, 0x22, 0x50, 0x68, 0x90];
    local awards = [5000, 2000, 800, 400, 100];
    local scoreIndex = 4;
    while (scoreIndex > 0 && spriteY < thresholds[scoreIndex]) scoreIndex -= 1;
    g.flagScoreIndex <- scoreIndex;
    g.flagScoreAward <- awards[scoreIndex];
    // The floatey number begins at the pole base immediately, while a high
    // grab defers the score tally itself until the flag reaches the bottom.
    g.flagScoreAge = 0;
    // For a low grab (Player_Y >= $a2), FlagpoleRoutine reaches its award
    // branch later in this same frame.  The current World 1-1 TAS exercises
    // that path; higher grabs will be split into the slide lifecycle when the
    // course-clear state machine is brought under state comparison.
    local digit = g.time % 10;
    g.fireworksRemaining = digit == 1 ? 1 : (digit == 3 ? 3 : (digit == 6 ? 6 : 0));
    g.fireworksOffsetState = digit == 1 ? 5 : (digit == 3 ? 3 : (digit == 6 ? 0 : -1));
    // A grab at or below $a2 is awarded by FlagpoleRoutine in the collision
    // frame itself, advancing directly to PlayerEndLevel (subroutine 5).
    local lowGrab = spriteY >= 0xA2;
    if (!lowGrab) {
        // The collision-frame FlagpoleRoutine performs the first fixed-point
        // flag step. Its floatey score moves two pixels in the opposite
        // direction and both values enter the ordinary OAM staging pipeline.
        g.flagY += 1.0;
        g.flagScoreY -= 2.0;
    }
    if (lowGrab) {
        // A low grab already satisfies FlagpoleRoutine's player-Y threshold,
        // so the score is awarded in the collision frame. Higher grabs wait
        // for the moving flag object to reach its $aa bottom threshold.
        g.score += awards[scoreIndex];
        g.queuedScore = g.score;
        g.flagScoreAge = 0;
    }
    g.state = lowGrab ? "endLevel" : "flagSlide";
    // HandleClimbing always queues silence and the flag-slide SFX.  A low
    // grab can advance directly to PlayerEndLevel in this same frame, so
    // FlagpoleSlide never consumes the SFX queue; only silence is observable.
    parityRecordEvent(g, "music", "silence");
    g.soundEvents.append("silence_music");
    g.flagSoundPending = !lowGrab;
    g.stateTimer = 0.0;
    p.endLevelClimbing = lowGrab;
    p.endLevelFirstFrame = lowGrab;
    p.climbSideFrames = 24;
    g.endLevelScrollLocked = true;
    // The collision pass sets ScrollLock after PlayerControl has already
    // produced this frame's X scroll. ScrollHandler still consumes that one
    // pending displacement on the flag-contact frame.
    g.flagContactScrollPending = true;
    // Facing right uses ClimbXPositionAdder $f9: metatile origin - 7.
    p.x = g.flagX - 7.0;
    p.vx = 0.0;
    p.nesXSpeed = 0;
    p.nesXForce = 0;
    parityRecordEvent(g, "gameplay", "flagpole_touch",
        ",\"score_award\":" + awards[scoreIndex]);
}

function autoControlPlayerEndLevel(g, dt) {
    local savedLeft = g.input.left;
    local savedRight = g.input.right;
    local savedRun = g.input.run;
    local savedRunDown = g.input.runDown;
    local savedJumpDown = g.input.jumpDown;
    local savedJumpQueued = g.input.jumpQueued;
    local savedFireQueued = g.input.fireQueued;
    g.input.left = false;
    g.input.right = true;
    g.input.run = false;
    g.input.runDown = false;
    g.input.jumpDown = false;
    g.input.jumpQueued = false;
    g.input.fireQueued = false;
    updatePlayer(g, dt);
    g.input.left = savedLeft;
    g.input.right = savedRight;
    g.input.run = savedRun;
    g.input.runDown = savedRunDown;
    g.input.jumpDown = savedJumpDown;
    g.input.jumpQueued = savedJumpQueued;
    g.input.fireQueued = savedFireQueued;
}

function updateCourseClear(g, dt) {
    local p = g.player;
    g.stateTimer += dt;
    if (g.flagScoreAge >= 0) g.flagScoreAge += 1;
    // StarFlagTaskControl runs alongside PlayerEndLevel; subroutine $05 stays
    // selected while time, flag, fireworks and the final delay execute.
    local timedSettlement = g.state == "timeBonus" ||
        g.state == "raiseFlag" || g.state == "fireworks" ||
        g.state == "postClearDelay";
    if (timedSettlement) autoControlPlayerEndLevel(g, dt);
    if (g.state == "endLevel") {
        if (g.endLevelUnlockFrames > 0) {
            g.endLevelUnlockFrames -= 1;
            if (g.endLevelUnlockFrames == 0) g.endLevelScrollLocked = false;
        }
        if (p.endLevelClimbing) {
            // The first PlayerEndLevel pass enters ClimbingMovement with the
            // jump's residual vertical state, then pole collision zeros it.
            if (p.endLevelFirstFrame) {
                p.y -= 4.0;
                p.nesYSpeed = 0;
                p.nesYMoveForce = 0;
                p.endLevelFirstFrame = false;
            }
            if (p.climbSideFrames > 0) p.climbSideFrames -= 1;
            if (p.climbSideFrames == 0) {
                // ClimbSideXDelta: right-facing/right-input = +$0e;
                // left-facing/right-input = +$04.
                p.x += p.facing > 0 ? 14.0 : 4.0;
                p.facing = -1;
                p.climbSideFrames = 24;
                local xLow = floor(p.x).tointeger() & 0x0F;
                if (xLow < 6 || xLow >= 10) {
                    p.endLevelClimbing = false;
                    p.grounded = playerHasFootSupport(g, p);
                    p.entranceFalling = !p.grounded;
                }
            }
        } else {
            // PlayerEndLevel supplies held-right input to the ordinary player
            // control path; preserve the replay's real input around that call.
            autoControlPlayerEndLevel(g, dt);

            local canonicalY = p.big && !p.crouching ? p.y : p.y - 16.0;
            if (g.endLevelScrollLocked && canonicalY >= 0xAE) {
                if (g.endLevelUnlockFrames == 0) {
                    // EndLevel clears ScrollLock after this frame's
                    // ScrollHandler; the next pass unlocks and scrolls.
                    g.endLevelUnlockFrames = 1;
                    emitSound(g, "course_clear");
                }
            }
            // PlayerEndLevel advances StarFlagTaskControl only after
            // PlayerBGCollision clears d0 of Player_CollisionBits.
            if ((p.collisionBits & 0x01) == 0) {
                // ScrollHandler still consumes this pass's Player_X_Scroll.
                g.flagContactScrollPending = true;
                g.state = "timeBonus";
                g.stateTimer = 0.0;
            }
        }
    } else if (g.state == "flagSlide") {
        if (g.flagSoundPending) {
            g.flagSoundPending = false;
            emitSound(g, "flag");
        }
        // FlagpoleSlide forces controller Down while Player_Y_Position is
        // below $9e. ClimbingMovement uses speed $01:$ff, retaining the
        // pre-collision Y dummy; this normally advances two pixels per frame.
        local targetY = 0x9E + ((p.big && !p.crouching) ? 0.0 : 16.0);
        if (p.y < targetY) {
            p.nesYSpeed = 1;
            p.nesYMoveForce = 0xFF;
            local positionSum = p.nesYDummy + p.nesYMoveForce;
            p.nesYDummy = positionSum & 0xFF;
            p.y += p.nesYSpeed + floor(positionSum / 256).tointeger();
        } else {
            p.nesYSpeed = 0;
            p.nesYMoveForce = 0;
        }
        local flagWasAtBottom = g.flagY >= 170.0;
        if (!flagWasAtBottom) {
            // The flag object carries speed $18 (1.5 fixed-point pixels),
            // producing the observed two-pixel integer cadence in this path.
            g.flagY += 2.0;
            g.flagScoreY -= 2.0;
            if (g.flagY > 171.0) g.flagY = 171.0;
            if (g.flagScoreY < 52.0) g.flagScoreY = 52.0;
        }
        if (p.y >= targetY && flagWasAtBottom) {
            // FlagpoleRoutine advances to PlayerEndLevel. Its first forced-
            // right climbing pass switches Mario to the pole's far side;
            // a second switch 24 frames later releases him to fall/walk.
            g.score += g.flagScoreAward;
            g.queuedScore = g.score;
            p.endLevelClimbing = true;
            p.endLevelFirstFrame = false;
            p.climbSideFrames = 1;
            g.state = "endLevel";
            g.stateTimer = 0.0;
        }
    } else if (g.state == "autoWalk") {
        // PlayerEndLevel feeds a held-right input through normal fixed-point
        // player physics rather than using an arbitrary constant speed.
        applyNesXAcceleration(p, 1, 0x98);
        if (p.nesXSpeed > 0x18) p.nesXSpeed = 0x18;
        p.x += nesHorizontalDelta(p);
        p.vx = p.nesXSpeed * 3.75;
        if (p.x >= g.castleX + 35.0) {
            p.vx = 0.0;
            g.flagContactScrollPending = true;
            g.state = "timeBonus";
            g.stateTimer = 0.0;
        }
    } else if (g.state == "timeBonus") {
        // AwardGameTimerPoints subtracts one timer unit and adds 50 every frame.
        if (g.time > 0) {
            // AwardGameTimerPoints requests the timer sound on FrameCounter bit 2.
            if ((g.nesFrameCounter & 0x04) != 0) emitSound(g, "timer_tick");
            g.time -= 1;
            g.score += 50;
            g.queuedScore = g.score;
        } else {
            // Task 2 observes zero on the next frame and advances to task 3;
            // task 3 does not begin raising the flag until its own next pass.
            g.castleFlagVisible = true;
            g.castleFlagY = 144.0;
            g.state = "raiseFlag";
            g.stateTimer = 0.0;
        }
    } else if (g.state == "raiseFlag") {
        // RaiseFlagSetoffFWorks decrements $90 until it has crossed $72.
        if (g.castleFlagY >= 0x72) {
            g.castleFlagY -= 1.0;
        } else {
            g.fireworkSpawnFrames = 0;
            if (g.fireworksRemaining > 0) {
                g.state = "fireworks";
            } else {
                // World 1-3 enters DelayToAreaEnd with IntervalTimerControl at
                // $0c. Its six interval-bank reloads land on frames 1702,
                // 1723, 1744, 1765, 1786 and 1807; task 5 is visible on the
                // following pass at 1808.
                g.clearDelayFrames = g.level == 3 ? 118 : 6 * 21;
                g.state = "postClearDelay";
            }
        }
    } else if (g.state == "fireworks") {
        if (g.fireworkSpawnFrames > 0) g.fireworkSpawnFrames -= 1;
        if (g.fireworksRemaining > 0 && g.fireworkSpawnFrames == 0) {
            local xOffsets = [0x00, 0x30, 0x60, 0x60, 0x00, 0x20];
            local yPositions = [0x60, 0x40, 0x70, 0x40, 0x60, 0x30];
            g.fireworksRemaining -= 1;
            local index = g.fireworksRemaining + g.fireworksOffsetState;
            g.fireworks.append({
                x = g.castleX + 32.0 - 48.0 + xOffsets[index],
                y = yPositions[index].tofloat(),
                frames = 24
            });
            g.fireworkSpawnFrames = 32;
        } else if (g.fireworksRemaining == 0 && g.fireworks.len() == 0) {
            g.clearDelayFrames = g.level == 3 ? 118 : 6 * 21;
            g.state = "postClearDelay";
        }
    } else if (g.state == "postClearDelay") {
        if (g.clearDelayFrames > 0) g.clearDelayFrames -= 1;
        if (g.clearDelayFrames <= 0) {
            g.state = "levelComplete";
            g.stateTimer = 0.0;
        }
    }
}

function updateTimer(g) {
    if (g.player.dead || g.gameTimerControl != 0) return;
    if (g.time > 0) {
        if (g.time == 100 && !g.hurryActive) {
            g.hurryActive = true;
            emitSound(g,"hurry");
        }
        // US SMB1 constants.inc: con_game_timer_reload = $18.  This value is
        // a frame timer, not a 0.4-second wall-clock approximation.
        g.gameTimerControl = 0x18;
        g.time -= 1;
    }
    if (g.time <= 0) {
        g.time = 0;
        killPlayer(g);
    }
}

function updatePlayerAnimationState(g) {
    local p = g.player;

    if (p.dead) return;
    if (g.state == "flagSlide") {
        // Player_State $03 with downward Y speed uses the two climbing frames.
        // ClimbingMovement starts from $08, then halves it for positive
        // (downward) Y speed.  The US ROM trace therefore reloads $04 while
        // FlagpoleSlide forces down input. ProcessPlayerAction advances
        // AnimCtrl over the exclusive upper bound $02.
        p.playerAnimTimerSet = 4;
        if (p.nesYSpeed == 0) {
            p.animationFrame = -5;
            p.playerAnimCtrl = 0;
            return;
        }
        p.animationFrame = p.playerAnimCtrl == 0 ? -5 : -6;
        if (p.playerAnimTimer == 0) {
            p.playerAnimTimer = p.playerAnimTimerSet;
            p.playerAnimCtrl += 1;
            if (p.playerAnimCtrl >= 2) p.playerAnimCtrl = 0;
        }
        return;
    }
    if (g.state == "endLevel" && p.endLevelClimbing) {
        // Player_State $03 with zero vertical speed selects the first climbing
        // graphics entry ($80 big / $a0 small) without advancing AnimCtrl.
        p.animationFrame = -5;
        p.playerAnimCtrl = 0;
        return;
    }
    if (p.entranceFalling) {
        p.animationFrame = p.playerAnimCtrl;
        return;
    }
    if (!p.grounded && !p.entranceFalling) {
        p.animationFrame = -2; // jumping/falling
        p.playerAnimCtrl = 0;
        return;
    }
    if (p.crouching) {
        p.animationFrame = -3;
        p.playerAnimCtrl = 0;
        return;
    }
    if (p.skidding) {
        p.animationFrame = -4;
        p.playerAnimCtrl = 0;
        return;
    }

    // EnterSidePipe selects the walking graphics path even on its first frame,
    // where Player_X_Speed is still zero; the subroutine starts writing $08
    // on the following frame.
    local moving = p.nesXSpeed != 0 || g.state == "pipeSide" ||
        g.state == "autoWalk" ||
        (g.state == "playing" && (g.input.left || g.input.right));
    if (!moving) {
        p.animationFrame = -1; // standing
        p.playerAnimCtrl = 0;
        return;
    }

    // GetPlayerAnimSpeed selects ROM table {2,4,7} from the absolute 4.4
    // horizontal speed.  ProcessPlayerAction selects the current frame before
    // an expired timer advances PlayerAnimCtrl.
    p.animationFrame = p.playerAnimCtrl;
    if (p.playerAnimTimer == 0) {
        p.playerAnimTimer = p.playerAnimTimerSet;
        p.playerAnimCtrl += 1;
        if (p.playerAnimCtrl >= 3) p.playerAnimCtrl = 0;
    }
}

function updateFireworks(g, dt) {
    foreach (burst in g.fireworks) burst.frames -= 1;
    for (local i = g.fireworks.len() - 1; i >= 0; i -= 1) {
        if (g.fireworks[i].frames <= 0) {
            g.fireworks.remove(i);
            g.score += 500;
            emitSound(g, "blast");
        }
    }
}

function updateDeathReload(g) {
    if(g.world==2 || g.level>=3) {updateWorld1StageDeath(g);return;}
    if (g.level == 2) {
        g.deathReloadFrames += 1;
        if (g.deathReloadFrames == 1) {
            // PlayerLoseLife reads the current area's ScreenLeft_PageLoc.
            // World 1-2 uses the low nybble of HalfwayPageNybbles $56.
            g.checkpointPage=(g.stage!="bonus" && g.stage!="intro" &&
                g.cameraX>=6.0*256.0)?6:0;
            g.lives -= 1;
            if (g.lives <= 0) {g.state="gameOver";emitSound(g,"game_over");return;}
        }
        if (g.deathReloadFrames >= 166) respawnWorld12(g);
        return;
    }
    g.deathReloadFrames += 1;
    local frame = g.deathReloadFrames;
    if (frame == 1) {
        g.lives -= 1;
        if (g.lives <= 0) {
            g.lives = 0;
            g.player.dead = false;
            g.state = "gameOver";
            g.stateTimer = 0.0;
            emitSound(g, "game_over");
            return;
        }
        parityRecordEvent(g, "music", "silence");
    } else if (frame == 2) {
        // PrimaryGameSetup clears scroll and sprite-object fractional state
        // one frame before InitializeArea replaces the player object.
        g.cameraX = 0.0;
        g.player.nesXForce = 0;
        g.player.nesXMoveForce = 0;
        g.player.nesYMoveForce = 0;
        g.player.nesYDummy = 0;
        g.colorRotateOffset = 0;
        g.displayColorPhase = 0;
        g.pendingColorPhase = 0;
        g.colorPhasePending = false;
        g.vramScrollThirtyTwo = 0;
        g.vramAreaParserTask = 0;
        g.vramBufferAddrCtrl = 0;
    } else if (frame == 3) {
        parityRecordEvent(g, "music", "silence");
        buildLevel(g);
        g.cameraX = 0.0;
        g.player = createPlayer();
        g.player.x = 0.0;
        g.player.previousX = 0.0;
        g.player.y = 16.0;
        g.player.previousY = 16.0;
        // The engine resets FrameCounter during area initialization.  The
        // common end-of-frame increment below then exposes zero to the trace.
        g.nesFrameCounter = 0;
    } else if (frame == 165) {
        parityRecordEvent(g, "music", "overworld");
        // The semantic ROM trace does not drive the live audio mixer.
        // Restart the runtime music at the same frame as the ROM queue.
        g.soundEvents.append("resume_music");
    } else if (frame == 166) {
        // InitializeGameTimer writes 401 while the entrance handler is still
        // observable.  On the next frame RunGameTimer immediately subtracts
        // one and reloads $0787 to $18, exposing 400 in normal control.
        g.time = 401;
        g.hurryActive = false;
        g.gameTimerControl = 0;
        g.player = createPlayer();
        g.state = "deathEntrance";
    } else if (frame == 167) {
        g.state = "playing";
        g.stateTimer = 0.0;
        g.respawnPrimeDirection = (g.input.right ? 1 : 0) - (g.input.left ? 1 : 0);
        g.respawnPrimeRun = g.input.run;
    }
    // The lives screen queues its palette once, waits for the screen timer,
    // renders twelve area column sets, then queues the player palette packet.
    if (frame == 4) {
        g.vramBufferAddrCtrl = 3;
    } else if (frame >= 149 && frame <= 160) {
        g.vramBufferAddrCtrl = 6;
    } else if (frame == 161) {
        g.vramBufferAddrCtrl = 2;
    }
}

function beginNextWorld1StageLoad(g, dt) {
    // PlayerEndLevel task 5 increments LevelNumber and returns after
    // ChgAreaMode. The current player, camera and frame counter remain
    // observable for this pass; the loader begins on the next frame.
    // Task 5 runs AutoControlPlayer and PlayerBGCollision before incrementing
    // LevelNumber. Perform that final player-physics pass first so the task's
    // visible speed and integration fractions are preserved.
    autoControlPlayerEndLevel(g, dt);
    g.loadingRenderCameraX <- g.cameraX;
    g.loadingPlayerBig <- g.player.big;
    g.loadingPlayerFire <- g.player.fire;
    g.level += 1;
    g.state = "nextStageLoad";
    g.stageLoadFrames = 0;
    g.stateTimer = 0.0;
    g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
    parityRecordEvent(g, "music", "silence");
}

function updateNextWorld1StageLoad(g) {
    g.vramBufferAddrCtrl = 0;
    if (g.stageLoadFrames == 0) {
        // ChgAreaMode has selected OperMode_Task 0 but the screen is still
        // disabled. ResetSpritesAndScreenTimer clears the visible camera and
        // the player's integration fractions while preserving raw X/speed.
        g.cameraX = 0.0;
        g.displayCameraX = 0.0;
        g.previousScrollAmount = 0.0;
        g.player.nesYDummy = 0;
        g.player.nesXForce = 0;
        g.player.nesXMoveForce = 0;
        g.colorRotateOffset = 0;
        g.pendingColorPhase = 0;
        g.colorPhasePending = false;
        g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
        g.stageLoadFrames = 1;
        return;
    }
    if (g.stageLoadFrames == 1) {
        // InitializeArea replaces the player object with zeroed RAM before the
        // entrance routine places it on the new stage. Keep the level data
        // loaded now so the draw path remains valid during the loading screen.
        startWorld1Stage(g, g.level);
        g.soundEvents.clear();
        g.state = "nextStageLoad";
        g.stageLoadFrames = 2;
        g.cameraX = 0.0;
        g.displayCameraX = 0.0;
        g.previousScrollAmount = 0.0;
        g.player = createPlayer();
        g.player.x = 0.0;
        // Player_Y_Position becomes zero before the entrance routine; the
        // host stores small Mario's collision origin 16 pixels below that OAM
        // origin.
        g.player.y = 16.0;
        g.player.previousX = 0.0;
        g.player.previousY = 16.0;
        g.player.preparedRelX = 0.0;
        g.player.preparedRelY = 0.0;
        // parityRecordState exposes the pre-increment FrameCounter as
        // (nesFrameCounter - 1) & $ff. One therefore reports zero here.
        g.nesFrameCounter = 1;
        g.time = 0;
        g.displayTime = 0;
        g.colorRotateOffset = 0;
        parityRecordEvent(g, "music", "silence");
        return;
    }
    g.stageLoadFrames += 1;
    g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
    if (g.stageLoadFrames == 3) {
        // ScreenRoutineTask queues the initialized area's palette packet
        // once. NMI consumes it on the following pass.
        g.vramBufferAddrCtrl = 3;
    }
    if (g.stageLoadFrames >= 148 && g.stageLoadFrames <= 159)
        g.vramBufferAddrCtrl = 6;
    else if (g.stageLoadFrames == 160)
        g.vramBufferAddrCtrl = 4;
    if (g.stageLoadFrames == 164) {
        parityRecordEvent(g, "music", "castle");
        g.soundEvents.append("resume_music");
    }
    if (g.stageLoadFrames == 165) {
        // ScreenRoutines and SecondaryGameSetup finish before InitializeGame
        // places the player. Preserve the NMI counter across host setup.
        local frameCounter = g.nesFrameCounter;
        local stage = g.level;
        g.player.big = g.loadingPlayerBig;
        g.player.fire = g.loadingPlayerFire;
        startWorld1Stage(g, stage);
        g.soundEvents.clear();
        g.nesFrameCounter = frameCounter;
        g.colorRotateOffset = 0;
        g.pendingColorPhase = 0;
        g.displayColorPhase = 0;
        g.colorPhasePending = false;
        g.state = "nextStageLoad";
        g.stageLoadFrames = 165;
        g.time = 301;
        g.displayTime = 301;
        return;
    }
    if (g.stageLoadFrames == 166) {
        g.state = "playing";
        g.time = 300;
        g.displayTime = 300;
        g.gameTimerControl = 24;
    }
}

function preparePlayerPresentation(g) {
    // Player OAM is prepared after gameplay and transferred on the following
    // NMI.  The captured PPU frame therefore displays the relative position
    // and graphics selection from two simulation stages earlier.
    g.player.displayRelX = g.player.preparedRelX;
    g.player.displayRelY = g.player.preparedRelY;
    g.player.queuedRelX = g.player.preparedRelX;
    g.player.queuedRelY = g.player.preparedRelY;
    g.player.preparedRelX = floor(g.player.x - g.cameraX).tofloat();
    local canonicalPlayerY = g.player.big && !g.player.crouching ?
        g.player.y : g.player.y - 16.0;
    g.player.preparedRelY = floor(canonicalPlayerY).tofloat();
    g.player.displayAnimationFrame = g.player.preparedAnimationFrame;
    g.player.queuedAnimationFrame = g.player.preparedAnimationFrame;
    g.player.preparedAnimationFrame = g.player.animationFrame;
    // Facing is read while PlayerGfxHandler builds OAM, then traverses the
    // staging page and DMA page.  A direction flip is therefore visible two
    // rendered frames after the RAM-facing byte changes.
    g.player.displayFacing = g.player.preparedFacing;
    g.player.queuedFacing = g.player.preparedFacing;
    g.player.preparedFacing = g.player.facing;
}

function simulateFixed(g, dt) {
    g.simTime += dt;
    if (g.state == "nextStageLoad") {
        updateNextWorld1StageLoad(g);
        return;
    }
    if (g.stageLoadFrames == 166) g.stageLoadFrames = 167;
    if (g.level <= 3 && g.state == "levelComplete") {
        if(g.world==2) {
            if(g.input.resetQueued) resetRound(g);
            return; // World 2-2 is not implemented; never load World 1-2 here.
        }
        // Preserve the established 1-1 parity endpoint; newer whole-route
        // movies include the next stage and therefore must cross this edge.
        if(!(g.level==1 && parityIsEnabled())) {
            if (g.level == 3) beginNextWorld1StageLoad(g, dt);
            else startWorld1Stage(g,g.level+1);
        }
        return;
    }
    if (g.level == 2 && updateWorld12Transition(g)) return;
    if (g.level == 4 && updateWorld14Transition(g)) {
        if(g.player.playerAnimTimer>0) g.player.playerAnimTimer-=1;
        updatePlayerAnimationState(g);
        preparePlayerPresentation(g);
        g.displayScore = g.queuedScore;
        g.queuedScore = g.score;
        g.displayTime = g.time;
        g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
        return;
    }
    // A sprite retained from the preceding pass is consumed by this pass's
    // render. Values set later below therefore survive until the next call.
    foreach (enemy in g.goombas) {
        if (enemy.erasedDisplayFrames > 0)
            enemy.erasedDisplayFrames -= 1;
    }
    // NMI consumes exactly one selected VRAM buffer.  Preserve the selection
    // made by the preceding gameplay pass before preparing this pass's state.
    local secondaryBufferWasSelected = g.vramBufferAddrCtrl == 6;
    g.displayBackgroundYOffset = 0.0;
    if(g.level==3 && !secondaryBufferWasSelected && g.vramPrimaryBytes>=64)
        g.displayBackgroundYOffset=1.0;
    if(!secondaryBufferWasSelected) g.vramPrimaryBytes=0;
    local scoreBeforeVram=g.score,timeBeforeVram=g.time;
    g.vramBufferAddrCtrl = 0;
    // UpdateScreen consumes the status and metatile VRAM work prepared by the
    // preceding gameplay pass.  The capture adapter observes one additional
    // frame of latency between RAM mutation and visible PPU output.
    if(!secondaryBufferWasSelected) g.displayScore = g.queuedScore;
    g.queuedScore = g.score;
    if(!secondaryBufferWasSelected) g.displayCoins = g.queuedCoins;
    g.queuedCoins = g.coins;
    foreach(coin in g.levelCoins)
        if("visualErasePending" in coin) coin.visualErasePending=false;
    for (local overrideIndex = g.displayTileOverrides.len() - 1;
         overrideIndex >= 0; overrideIndex -= 1) {
        local entry = g.displayTileOverrides[overrideIndex];
        entry.frames -= 1;
        if (entry.frames <= 0) g.displayTileOverrides.remove(overrideIndex);
    }
    // NMI processes only the buffer selected by VRAM_Buffer_AddrCtrl.  A
    // palette packet queued in buffer 1 remains pending while the preceding
    // gameplay pass selected area-parser buffer 2.
    if (g.colorPhasePending) {
        if (!secondaryBufferWasSelected) {
            g.displayColorPhase = g.pendingColorPhase;
            g.colorPhasePending = false;
        }
    }
    // Status-bar VRAM is prepared before RunGameTimer mutates the RAM digits.
    // The timer digits share primary VRAM buffer 1 with the palette packet.
    // If NMI selected the area-parser buffer, retain the previous PPU digits
    // until buffer 1 is consumed on a later frame.
    if (!secondaryBufferWasSelected) g.displayTime = g.time;
    local animationState = g.state;
    g.player.courseClearHidden=animationState=="timeBonus" ||
        animationState=="raiseFlag" || animationState=="fireworks" ||
        animationState=="postClearDelay" || animationState=="levelComplete";
    local processPlayerAnimation = !g.player.dead &&
        (animationState == "playing" || animationState == "pipeDown" ||
         animationState == "pipeSide" || animationState == "areaEntrance" ||
          animationState == "areaExitEntrance" || animationState == "endLevel" ||
          animationState == "flagSlide" || animationState == "autoWalk");
    if (processPlayerAnimation && g.player.playerAnimTimer > 0)
        g.player.playerAnimTimer -= 1;
    if (g.input.resetQueued) {
        if (g.state == "gameOver") {
            g.score = 0;
            g.coins = 0;
            g.lives = 3;
            g.checkpointPage = 0;
        }
        resetRound(g);
        g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
        return;
    }

    // Existing fireworks advance before this frame can create a new one. This
    // preserves all 24 rendered frames (three ROM tiles, eight frames each).
    updateFireworks(g, dt);
    updateFloatingScores(g);

    // UpdateScreen decrements the RAM timer slots before the game-engine
    // subroutine runs.  It continues through pipe/entrance transitions, while
    // RunGameTimer itself is gated by the final subroutine state below.
    if (g.gameTimerControl > 0) g.gameTimerControl -= 1;
    // IntervalTimerControl is a 21-frame divider shared by the enemy interval
    // timers. ScreenRoutineTask leaves TimerControl at one for the first area
    // loading pass, freezing both timer banks for exactly that frame.
    local freezeIntervalTimers = g.state == "areaReload" &&
        g.areaReloadFrames == 1;
    if (!freezeIntervalTimers) {
        g.intervalTimerControl -= 1;
        if (g.intervalTimerControl < 0) {
            g.intervalTimerControl = 0x14;
            foreach (enemy in g.goombas) {
                if (enemy.awake && enemy.alive && enemy.slot >= 0 &&
                    enemy.intervalTimer > 0) {
                    enemy.intervalTimer -= 1;
                }
            }
        }
    }

    if (g.state == "playing") {
        if (g.respawnPrimeDirection != 0) {
            local currentRun = g.input.run;
            g.input.run = g.respawnPrimeRun;
            updateNesHorizontalPhysics(g, g.player, g.respawnPrimeDirection);
            g.input.run = currentRun;
            g.respawnPrimeDirection = 0;
            g.respawnPrimeRun = false;
        }
        updatePlayer(g, dt);
        if (g.state == "playing" && !tryStartAreaTransition(g)) {
            updatePowerUps(g, dt);
            updateFireballs(g, dt);
            updateGoombas(g, dt);
            updateLevelCoins(g);
            if (g.level == 2) updateWorld12Actors(g);
            if (g.level == 3) updateWorld13Actors(g);
            if (g.level == 4) updateWorld14Actors(g);
            if(isWorld21(g)) updateWorld21Actors(g);
        } else if (g.state == "pipeDown" || g.state == "pipeSide") {
            // Pipe-entry player control is a game-engine subroutine; normal
            // enemy objects still run on the transition's first frame.
            updateGoombas(g, dt);
        }
    } else if (g.state == "endLevel" || g.state == "flagSlide" ||
               g.state == "autoWalk" ||
               g.state == "timeBonus" || g.state == "raiseFlag" ||
               g.state == "fireworks" || g.state == "postClearDelay") {
        updateCourseClear(g, dt);
    } else if (g.state == "pipeDown" || g.state == "pipeSide" ||
               g.state == "pipeUp") {
        // Normal enemy handlers continue while Mario is being moved through
        // the entrance pipe, until area initialization clears the slots.
        updateGoombas(g, dt);
        updateAreaTransition(g, dt);
    } else if (g.state == "areaReload") {
        updateAreaReload(g);
    } else if (g.state == "areaEntrance") {
        updateAreaEntrance(g);
    } else if (g.state == "areaExitEntrance") {
        updateAreaExitEntrance(g);
        // Normal enemy processing resumes on the second pipe-exit entrance
        // frame.  The World 1-1 group therefore allocates at parity frame 765
        // and has already walked for 166 frames when Mario stomps it.
        if (g.areaEntranceFrames >= 2) updateGoombas(g, dt);
    } else if (g.state == "deathReload") {
        updateDeathReload(g);
    } else if (g.state == "deathEntrance") {
        // The ROM exposes one entrance frame before normal control resumes.
        updateDeathReload(g);
    }
    // Entrance handlers may select normal control during this same frame.
    // RunGameTimer therefore observes the expired control slot immediately,
    // as seen at underground-entry, pipe-exit, and death-respawn boundaries.
    if (g.state == "playing" && !g.player.dead) updateTimer(g);
    if (processPlayerAnimation) {
        if (animationState == "pipeSide") {
            g.player.nesXSpeedAbsolute = abs(g.player.nesXSpeed);
            local speed = g.player.nesXSpeedAbsolute;
            g.player.playerAnimTimerSet = speed >= 0x1C ? 2 :
                (speed >= 0x0E ? 4 : 7);
        }
        updatePlayerAnimationState(g);
    }
    // The ROM builds enemy OAM before PlayerEnemyCollision mutates state.
    // Together with the capture adapter's one-frame presentation latency, the
    // three-stage queue reproduces the state visible in the prepared OAM.
    foreach (enemy in g.goombas) {
        enemy.displayState = enemy.preparedState;
        enemy.preparedState = enemy.queuedState;
        enemy.queuedState = enemy.state;
        enemy.displayY = enemy.preparedY;
        enemy.preparedY = enemy.previousY;
        enemy.displayX = enemy.preparedX;
        enemy.preparedX = enemy.previousX;
        enemy.displayFacing=enemy.preparedFacing;
        enemy.preparedFacing=enemy.previousFacing;
        enemy.displayParatroopa=enemy.preparedParatroopa;
        enemy.preparedParatroopa=enemy.previousParatroopa;
        enemy.displayShellFrame = enemy.preparedShellFrame;
        enemy.preparedShellFrame = enemy.queuedShellFrame;
    }
    updateCamera(g);
    // sub_game_core_routine reaches UpdateScrollVariables for every gameplay
    // subroutine while OperMode_Task is 3, including pipe/entrance and course
    // clear handlers.  Use the state selected at entry to this pass so a
    // transition made during gameplay does not suppress the final parser step.
    local ranGameEngine = animationState == "playing" ||
        animationState == "pipeDown" || animationState == "pipeSide" ||
        animationState == "pipeUp" || animationState == "areaEntrance" ||
        animationState == "areaExitEntrance" ||
        animationState == "deathEntrance" || animationState == "endLevel" ||
        animationState == "flagSlide" || animationState == "autoWalk" ||
        animationState == "timeBonus" || animationState == "raiseFlag" ||
        animationState == "fireworks" || animationState == "postClearDelay" ||
        (animationState == "areaReload" &&
            (g.state == "areaEntrance" || g.state == "areaExitEntrance")) ||
        (animationState == "deathReload" && g.state == "deathEntrance");
    if (ranGameEngine) updateVramAreaParserScheduler(g);
    // Misc object processing consumes this pass's ScrollAmount.  Updating it
    // after ScrollHandler keeps jumping-coin world X and relative OAM X in
    // lockstep with the ROM instead of lagging alternating 2/3px scrolls.
    updateEffects(g, dt);
    preparePlayerPresentation(g);
    // Flagpole sprites use the same object-OAM handoff as Mario. Keep the raw
    // object coordinates separate from the DMA page currently being shown.
    g.displayFlagY = g.preparedFlagY;
    g.preparedFlagY = g.flagY;
    g.displayFlagScoreY = g.preparedFlagScoreY;
    g.preparedFlagScoreY = g.flagScoreY;
    // ColorRotation reads FrameCounter before the common end-of-frame
    // increment.  Area initialization/lives display skip the routine.
    if(g.level==3) {
        if(g.score!=scoreBeforeVram) g.vramPrimaryBytes+=9;
        if(g.time!=timeBeforeVram) g.vramPrimaryBytes+=6;
    }
    if (ranGameEngine && (g.nesFrameCounter & 0x07) == 0 &&
        (g.level!=3 || g.vramPrimaryBytes<0x31)) {
        if(g.level==3) g.vramPrimaryBytes+=7;
        g.pendingColorPhase = g.colorRotateOffset;
        g.colorPhasePending = true;
        g.colorRotateOffset += 1;
        if (g.colorRotateOffset >= 6) g.colorRotateOffset = 0;
    }
    g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
}
