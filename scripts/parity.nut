// Deterministic replay/capture adapter used only by the local parity harness.
// NES controller bit order: A, B, Select, Start, Up, Down, Left, Right.
PARITY_BUTTON_A <- 0x01;
PARITY_BUTTON_B <- 0x02;
PARITY_BUTTON_SELECT <- 0x04;
PARITY_BUTTON_START <- 0x08;
PARITY_BUTTON_UP <- 0x10;
PARITY_BUTTON_DOWN <- 0x20;
PARITY_BUTTON_LEFT <- 0x40;
PARITY_BUTTON_RIGHT <- 0x80;

function parityIsEnabled() {
    return PARITY_MOVIE_ENABLED && PARITY_FRAME_MASKS.len() > 0;
}

function parityInitialize(g) {
    g.parity <- {
        frame = 0,
        awaitingCapture = false,
        done = false,
        inputMask = 0,
        eventSequence = 0
        originPending = true
    };
    if (parityIsEnabled()) {
        print("PARITY_BEGIN " + PARITY_MOVIE_NAME + " frames=" + PARITY_FRAME_MASKS.len() + "\n");
        parityRecordEvent(g, "music", g.area == "castle" ? "castle" :
            (g.area == "underground" ? "underground" : "overworld"),
            ",\"action\":\"start\",\"phase\":\"intro\"");
    }
}

function parityRecordEvent(g, type, name, extraJson = "") {
    if (!parityIsEnabled() || !("parity" in g)) return;
    print("PARITY_EVENT {\"frame\":" + g.parity.frame +
          ",\"sequence\":" + g.parity.eventSequence +
          ",\"type\":\"" + type + "\",\"name\":\"" + name + "\"" +
          extraJson + "}\n");
    g.parity.eventSequence += 1;
}

function parityApplyMask(g, mask) {
    local jump = (mask & PARITY_BUTTON_A) != 0;
    local run = (mask & PARITY_BUTTON_B) != 0;

    g.input.left = (mask & PARITY_BUTTON_LEFT) != 0;
    g.input.right = (mask & PARITY_BUTTON_RIGHT) != 0;
    g.input.up = (mask & PARITY_BUTTON_UP) != 0;
    g.input.down = (mask & PARITY_BUTTON_DOWN) != 0;

    if (run && !g.input.runDown) g.input.fireQueued = true;
    g.input.run = run;
    g.input.runDown = run;

    if (jump && !g.input.jumpDown) g.input.jumpQueued = true;
    g.input.jumpDown = jump;

    g.input.resetQueued = false;
    g.input.resetDown = false;
}

function parityAdvanceOneFrame(g) {
    if (!parityIsEnabled() || g.parity.done || g.parity.awaitingCapture) return;
    if (g.parity.frame >= PARITY_FRAME_MASKS.len()) {
        g.parity.done = true;
        return;
    }

    local mask = PARITY_FRAME_MASKS[g.parity.frame];
    g.parity.eventSequence = 0;
    g.parity.inputMask = mask;
    parityApplyMask(g, mask);
    if (g.parity.frame == 0) {
        // Mesen's saved origin frame is an observable pre-control state.  Do
        // not consume the first comparison input until the following frame.
        g.player.parityOriginFriction = true;
        g.nesFrameCounter = (g.nesFrameCounter + 1) & 0xFF;
        g.parity.awaitingCapture = true;
        return;
    }
    simulateFixed(g, FIXED_DT);
    g.input.jumpQueued = false;
    g.input.fireQueued = false;
    g.input.resetQueued = false;
    g.parity.awaitingCapture = true;
}

function parityFrameName(frame) {
    local text = frame.tostring();
    while (text.len() < 6) text = "0" + text;
    return text;
}

function parityBool(value) {
    return value ? "true" : "false";
}

function parityStateJson(g, frame) {
    local p = g.player;
    local actorsJson="[", actorSeparator="";
    if(g.level==4 && "world14" in g) foreach(bar in g.world14.firebars) {
        if(!bar.awake || bar.retired) continue;
        actorsJson+=actorSeparator+"{\"kind\":\"firebar\",\"slot\":"+bar.slot+
            ",\"x\":"+bar.x+",\"y\":"+bar.y+",\"spin_low\":"+bar.spinLow+
            ",\"spin_high\":"+bar.spinHigh+"}";
        actorSeparator=",";
    }
    if(g.level==3 && "platforms" in g) foreach(platform in g.platforms) {
        actorsJson+=actorSeparator+"{\"kind\":\"platform\",\"id\":"+platform.id+
            ",\"x\":"+platform.x+",\"y\":"+platform.y+
            ",\"awake\":"+parityBool(platform.awake)+"}";
        actorSeparator=",";
    }
    actorsJson+="]";
    local canonicalYWorld = p.big && !p.crouching ? p.y : p.y - 16.0;
    local canonicalY = floor(canonicalYWorld).tointeger() & 0xFF;
    local firstEnemyJson = "{\"active\":false}";
    local firstEnemy = null;
    foreach (candidate in g.goombas) {
        // The reference extractor reports the lowest active NES slot whose
        // identifier is a Goomba, not the first level-stream template.
        if (candidate.kind == "goomba" && candidate.awake && candidate.alive &&
            candidate.slot >= 0 &&
            (firstEnemy == null || candidate.slot < firstEnemy.slot)) {
            firstEnemy = candidate;
        }
    }
    if (firstEnemy != null) {
        local e = firstEnemy;
        firstEnemyJson = "{\"active\":true" +
            ",\"slot\":" + e.slot +
            ",\"x\":" + floor(e.x) + ",\"y\":" +
                (e.kind == "goomba" ? e.y - 10.0 : e.y) +
            ",\"id\":" + (e.kind == "goomba" ? 6 : 0) +
            ",\"x_speed_raw\":" + floor(e.vx / NES_FRAME_RATE * 16.0) +
            ",\"state_raw\":" + (e.state == "walking" ? 0 :
                (e.kind == "goomba" && e.state == "defeated" ? 4 : 1)) +
            ",\"state\":\"" + e.state + "\"}";
    }
    local enemiesJson = "[";
    local enemySeparator = "";
    for (local slot = 0; slot < 5; slot += 1) {
        foreach (e in g.goombas) {
            if (!e.awake || !e.alive || e.slot != slot) continue;
            enemiesJson += enemySeparator + "{\"slot\":" + e.slot +
                ",\"x\":" + floor(e.x) +
                ",\"y\":" + floor(e.y) +
                ",\"kind\":\"" + e.kind + "\"" +
                ",\"x_speed_raw\":" + floor(e.vx / NES_FRAME_RATE * 16.0) +
                ",\"state\":\"" + e.state + "\"}";
            enemySeparator = ",";
        }
    }
    enemiesJson += "]";
    local powerupJson = "{\"active\":false}";
    foreach (item in g.powerups) {
        if (!item.active) continue;
        local kindRaw = item.kind == "flower" ? 1 :
            (item.kind == "star" ? 2 : (item.kind == "oneup" ? 3 : 0));
        local stateRaw = item.emerging ? 1 + item.emergePixels :
            (item.settleFrame >= 1 && item.settleFrame <= 4 ? 0xC0 : 0x80);
        powerupJson = "{\"active\":true" +
            ",\"kind\":\"" + item.kind + "\"" +
            ",\"kind_raw\":" + kindRaw +
            ",\"state_raw\":" + stateRaw +
            ",\"x\":" + floor(item.x) +
            ",\"y\":" + floor(item.romY) +
            ",\"x_speed_raw\":" + (item.emerging ? 0 :
                floor(item.vx / NES_FRAME_RATE * 16.0)) +
            ",\"visible\":" + parityBool(item.visible) + "}";
        break;
    }
    local operMode = 1;
    local operModeTask = 3;
    local engineSubroutine = 8;
    if (g.state == "playing" && p.dead) {
        engineSubroutine = 11;
    } else if (g.state == "deathReload") {
        local modeTwoFrame=isWorld21(g) && "lifeScreenEnd" in g.world21?
            g.world21.lifeScreenEnd+16:164;
        if (g.deathReloadFrames == 0) {
            engineSubroutine = 6;
        } else if (g.deathReloadFrames <= 2) {
            operModeTask = 0;
            engineSubroutine = 0;
        } else if (g.deathReloadFrames < modeTwoFrame) {
            operModeTask = 1;
            engineSubroutine = 0;
        } else if (g.deathReloadFrames == modeTwoFrame) {
            operModeTask = 2;
            engineSubroutine = 0;
        } else {
            engineSubroutine = 0;
        }
    } else if (g.state == "deathEntrance") {
        engineSubroutine = 7;
    } else if (g.state == "pipeDown") {
        engineSubroutine = 3;
    } else if (g.state == "pipeSide") {
        engineSubroutine = 2;
    } else if (g.state == "areaReload") {
        engineSubroutine = 0;
        if (g.areaReloadFrames <= 1) {
            operModeTask = 0;
            engineSubroutine = g.areaReloadTarget == "main" ? 2 : 3;
        } else if (g.areaReloadFrames < 24) {
            operModeTask = 1;
        } else if (g.areaReloadFrames == 24) {
            operModeTask = 2;
        }
    } else if (g.state == "areaEntrance") {
        engineSubroutine = 7;
    } else if (g.state == "areaExitEntrance") {
        engineSubroutine = 7;
    } else if (g.state == "nextStageLoad") {
        operModeTask = g.stageLoadFrames <= 1 ? 0 :
            (g.stageLoadFrames < 163 ? 1 : (g.stageLoadFrames == 163 ? 2 : 3));
        engineSubroutine = g.stageLoadFrames <= 1 ? 5 :
            (g.stageLoadFrames == 165 ? 7 : 0);
    } else if (g.state == "endLevel" || g.state == "timeBonus" ||
               g.state == "raiseFlag" || g.state == "fireworks" ||
               g.state == "postClearDelay" || g.state == "levelComplete") {
        // These host states are phases of the ROM's PlayerEndLevel routine.
        engineSubroutine = 5;
    } else if (g.state == "flagSlide") {
        engineSubroutine = 4;
    }
    local playerStateRaw = 0;
    if (g.state == "areaEntrance") {
        playerStateRaw = g.areaEntranceFrames == 0 ? 0 : 2;
    } else if (g.state == "areaExitEntrance") {
        playerStateRaw = 0;
    } else if (g.state != "areaReload") {
        playerStateRaw = (g.state == "flagSlide" ||
            (g.state == "endLevel" && p.endLevelClimbing)) ? 3 :
            (p.entranceFalling ? 2 : ((p.dead || !p.grounded) ? 1 : 0));
    }
    return "{\"frame\":" + frame +
        ",\"input_mask\":" + g.parity.inputMask +
        ",\"state\":\"" + g.state + "\"" +
        ",\"world\":"+g.world+",\"level\":" + g.level +
        ",\"area\":\"" + g.area + "\"" +
        ",\"player\":{\"x\":" + p.x + ",\"y\":" + canonicalY +
        ",\"previous_x\":" + p.previousX +
        ",\"previous_y\":" + p.previousY +
        ",\"facing\":" + p.facing +
        ",\"facing_direction_raw\":" + (p.facing == 1 ? 1 : 2) +
        ",\"moving_direction_raw\":" + p.movingDir +
        ",\"running_speed_raw\":" + p.runningSpeed +
        ",\"x_speed_absolute\":" + p.nesXSpeedAbsolute +
        ",\"running_timer\":" + p.runningTimer +
        ",\"collision_bits_raw\":" + p.collisionBits +
        ",\"end_level_climbing\":" + parityBool(p.endLevelClimbing) +
        ",\"entrance_falling\":" + parityBool(p.entranceFalling) +
        ",\"crouching\":" + parityBool(p.crouching) +
        ",\"skidding\":" + parityBool(p.skidding) +
        ",\"vx\":" + p.vx + ",\"vy\":" + p.vy +
        ",\"x_speed_raw\":" + p.nesXSpeed +
        ",\"y_speed_raw\":" + p.nesYSpeed +
        ",\"y_move_force\":" + p.nesYMoveForce +
        ",\"y_move_dummy\":" + p.nesYDummy +
        ",\"x_acceleration_fraction\":" + p.nesXForce +
        ",\"x_position_fraction\":" + p.nesXMoveForce +
        ",\"state_raw\":" + playerStateRaw +
        ",\"size_raw\":" + (p.big ? 0 : 1) +
        ",\"status_raw\":" + (p.fire ? 2 : (p.big ? 1 : 0)) +
        ",\"big\":" + parityBool(p.big) +
        ",\"fire\":" + parityBool(p.fire) +
        ",\"grounded\":" + parityBool(p.grounded && !p.dead) + "}" +
        ",\"player_animation\":{\"timer\":" + p.playerAnimTimer +
        ",\"timer_set\":" + p.playerAnimTimerSet +
        ",\"control\":" + p.playerAnimCtrl +
        ",\"prepared_frame\":" + p.animationFrame +
        ",\"display_frame\":" + p.displayAnimationFrame + "}" +
        ",\"camera_x\":" + g.cameraX +
        ",\"display_camera_x\":" + g.displayCameraX +
        ",\"previous_scroll_amount\":" + g.previousScrollAmount +
        ",\"frame_counter\":" + ((g.nesFrameCounter + 255) & 0xFF) +
        ",\"color_rotation_offset\":" + g.colorRotateOffset +
        ",\"vram_scheduler\":{\"scroll_thirty_two\":" + g.vramScrollThirtyTwo +
        ",\"area_parser_task\":" + g.vramAreaParserTask +
        ",\"buffer_addr_ctrl\":" + g.vramBufferAddrCtrl + "}" +
        ",\"coin_effect\":{\"active\":" + parityBool(g.coinEffect.active) +
        ",\"phase\":\"" + g.coinEffect.phase + "\"" +
        ",\"frame\":" + g.coinEffect.frame +
        ",\"score_frame\":" + g.coinEffect.scoreFrame +
        ",\"x\":" + g.coinEffect.x +
        ",\"display_x\":" + g.coinEffect.displayX +
        ",\"spawn_carry_y_offset\":" + g.coinEffect.spawnCarryYOffset +
        ",\"visible_counter\":" + ((g.nesFrameCounter + 254) & 0xFF) +
        ",\"tile_frame\":" + ((((g.nesFrameCounter + 254) & 0xFF) >> 1) & 3) + "}" +
        ",\"enemy0\":" + firstEnemyJson +
        ",\"powerup\":" + powerupJson +
        ",\"enemies\":" + enemiesJson +
        ",\"actors\":" + actorsJson +
        ",\"rom_state\":{\"oper_mode\":" + operMode +
        ",\"oper_mode_task\":" + operModeTask +
        ",\"game_engine_subroutine\":" + engineSubroutine + "}" +
        ",\"score\":" + g.score +
        ",\"coins\":" + g.coins +
        ",\"lives\":" + g.lives +
        ",\"time\":" + g.time + "}";
}

function parityShouldCapture(frame) {
    foreach (captureFrame in PARITY_CAPTURE_FRAMES) {
        if (captureFrame == frame) return true;
    }
    return false;
}

function parityCaptureRenderedFrame(g) {
    if (!parityIsEnabled() || !g.parity.awaitingCapture || g.parity.done) return;

    local frame = g.parity.frame;
    if (parityShouldCapture(frame)) {
        local path = PARITY_OUTPUT_DIR + "/frames/frame-" + parityFrameName(frame) + ".png";
        if (!gfx.saveFramePng(path)) return;
    }

    print("PARITY_STATE " + parityStateJson(g, frame) + "\n");
    g.parity.originPending=false;
    g.parity.frame += 1;
    g.parity.awaitingCapture = false;
    if (g.parity.frame >= PARITY_FRAME_MASKS.len()) {
        g.parity.done = true;
        print("PARITY_DONE frames=" + g.parity.frame + "\n");
    }
}
