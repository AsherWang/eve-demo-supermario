function makeEnemyAt(x, supportRow, kind) {
    local enemyHeight = kind == "koopa" ? 24.0 : 14.0;
    return {
        x = x,
        y = (supportRow + 1) * TILE_SIZE.tofloat() - enemyHeight,
        previousX = x,
        preparedX = x,
        displayX = x,
        previousY = (supportRow + 1) * TILE_SIZE.tofloat() - enemyHeight,
        preparedY = (supportRow + 1) * TILE_SIZE.tofloat() - enemyHeight,
        displayY = (supportRow + 1) * TILE_SIZE.tofloat() - enemyHeight,
        previousFacing = -1,
        preparedFacing = -1,
        displayFacing = -1,
        previousParatroopa = false,
        preparedParatroopa = false,
        displayParatroopa = false,
        width = 14.0,
        height = enemyHeight,
        vx = -KOOPA_WALK_SPEED,
        vy = 0.0,
        nesYSpeed = 0,
        nesYMoveForce = 0,
        nesYDummy = 0,
        grounded = false,
        awake = false,
        alive = true,
        slot = -1,
        state = "walking",
        // EnemyGfxHandler runs before player/enemy collision.  Preserve the
        // state it saw separately from the state mutated later in the pass.
        queuedState = "walking",
        preparedState = "walking",
        displayState = "walking",
        queuedShellFrame = 0,
        preparedShellFrame = 0,
        displayShellFrame = 0,
        erasedDisplayFrames = 0,
        erasedSlot = -1,
        stompDisplayLead = 0.0,
        stateTimer = 0.0,
        defeatedFrames = 0,
        eraseDelayPending = false,
        intervalTimer = 0,
        enemyCollisionMask = 0,
        shellFrames = 0,
        collisionCooldown = 0.0,
        playerContact = false,
        shellChain = 0,
        shellDirection = -1,
        kind = kind,
        groupCommandX = -1.0,
        groupIndex = -1
    };
}

function makeEnemy(tx, supportRow, kind) {
    return makeEnemyAt(tx * TILE_SIZE.tofloat(), supportRow, kind);
}

function fillTileRow(g, x, y, length, tile) {
    for (local offset = 0; offset <= length; offset += 1)
        setTile(g, x + offset, y, tile);
}

function fillTileColumn(g, x, y, length, tile) {
    for (local offset = 0; offset <= length; offset += 1)
        setTile(g, x, y + offset, tile);
}

function decodeWorld11Foreground(g) {
    // Header $50,$21 selects ground terrain with a two-metatile floor.  The
    // rest is SMB's original two-byte area object stream.
    for (local x = 0; x < LEVEL_WIDTH; x += 1) {
        setTile(g, x, GROUND_ROW, TILE_GROUND);
        setTile(g, x, GROUND_ROW + 1, TILE_GROUND);
    }

    local page = 0;
    local cursor = 2;
    while (cursor < ROM_WORLD_1_1_AREA_DATA.len()) {
        local first = ROM_WORLD_1_1_AREA_DATA[cursor];
        if (first == 0xFD) break;
        local second = ROM_WORLD_1_1_AREA_DATA[cursor + 1];
        cursor += 2;
        local row = first & 0x0F;
        if ((second & 0x80) != 0) page += 1;
        if (row == 0x0D && (second & 0x40) == 0) {
            page = second & 0x1F;
            continue;
        }

        local x = page * 16 + (first >> 4);
        local screenRow = row + 2;
        local objectClass = (second & 0x70) >> 4;
        local length = second & 0x0F;

        if (row < 12 && objectClass == 0) {
            local tile = TILE_EMPTY;
            if (length == 0) tile = TILE_POWERUP_BLOCK;
            else if (length == 1) tile = TILE_QUESTION;
            else if (length == 3) tile = TILE_HIDDEN_ONEUP;
            else if (length == 4 || length == 5 || length == 8) tile = TILE_BRICK;
            else if (length == 6) tile = TILE_BRICK_STAR;
            else if (length == 7) tile = TILE_BRICK_COIN;
            else if (length == 10) tile = TILE_USED;
            if (tile != TILE_EMPTY) setTile(g, x, screenRow, tile);
        } else if (row < 12 && objectClass == 2) {
            fillTileRow(g, x, screenRow, length, TILE_BRICK);
        } else if (row < 12 && objectClass == 3) {
            fillTileRow(g, x, screenRow, length, TILE_SOLID);
        } else if (row < 12 && objectClass == 5) {
            fillTileColumn(g, x, screenRow, length, TILE_BRICK);
        } else if (row < 12 && objectClass == 6) {
            fillTileColumn(g, x, screenRow, length, TILE_SOLID);
        } else if (row < 12 && objectClass == 7) {
            local pipeHeight = (length & 0x07) + 1;
            setTile(g, x, screenRow, TILE_PIPE_TOP_LEFT);
            setTile(g, x + 1, screenRow, TILE_PIPE_TOP_RIGHT);
            for (local pipeRow = 1; pipeRow < pipeHeight; pipeRow += 1) {
                setTile(g, x, screenRow + pipeRow, TILE_PIPE_SHAFT_LEFT);
                setTile(g, x + 1, screenRow + pipeRow, TILE_PIPE_SHAFT_RIGHT);
            }
        } else if (row == 12 && objectClass == 0) {
            for (local holeX = 0; holeX <= length; holeX += 1)
                for (local holeY = 10; holeY < LEVEL_HEIGHT; holeY += 1)
                    setTile(g, x + holeX, holeY, TILE_EMPTY);
        } else if (row == 12 && (objectClass == 6 || objectClass == 7)) {
            local questionRow = objectClass == 6 ? 5 : 9;
            fillTileRow(g, x, questionRow, length, TILE_QUESTION);
        } else if (row == 15 && objectClass == 3) {
            local stairRows = [3, 3, 4, 5, 6, 7, 8, 9, 10];
            local stairHeights = [7, 7, 6, 5, 4, 3, 2, 1, 0];
            for (local stairColumn = 0; stairColumn <= length; stairColumn += 1) {
                local control = 8 - stairColumn;
                if (control < 0) control = 0;
                fillTileColumn(g, x + stairColumn, stairRows[control] + 2,
                               stairHeights[control], TILE_SOLID);
            }
        } else if (row == 15 && objectClass == 2) {
            g.castleX = x * TILE_SIZE.tofloat();
        } else if (row == 13 && (second & 0x40) != 0 &&
                   (second & 0x3F) == 1) {
            g.flagX = x * TILE_SIZE.tofloat();
            // FlagpoleObject writes metatile $61 ten rows below the ball.
            setTile(g, x, 12, TILE_SOLID);
        }
    }
}

function appendEnemyGroup(g, x, groupId) {
    local groupType = groupId - 0x37;
    local count = (groupType & 1) != 0 ? 3 : 2;
    local kind = groupType >= 4 ? "koopa" : "goomba";
    local supportRow = (groupType & 2) != 0 ? 8 : 12;
    local command={started=false};
    for (local i = 0; i < count; i += 1) {
        local enemy = makeEnemyAt(x * TILE_SIZE, supportRow, kind);
        enemy.groupCommandX = x * TILE_SIZE.tofloat();
        enemy.groupIndex = i;
        enemy.groupCommand <- command;
        g.goombas.append(enemy);
    }
}

function decodeWorld11Enemies(g, data=null) {
    if(data==null) data=ROM_WORLD_1_1_ENEMY_DATA;
    local page = 0;
    local cursor = 0;
    while (cursor < data.len()) {
        local first = data[cursor];
        if (first == 0xFF) break;
        local second = data[cursor + 1];
        local row = first & 0x0F;
        if ((second & 0x80) != 0) page += 1;
        if (row == 0x0F && (second & 0x80) == 0) {
            page = second & 0x3F;
            cursor += 2;
            continue;
        }
        local x = page * 16 + (first >> 4);
        if (row == 0x0E) {
            cursor += 3;
            continue;
        }
        local enemyId = second & 0x3F;
        if ((second & 0x40) == 0) {
            if (enemyId >= 0x37 && enemyId < 0x3F) {
                appendEnemyGroup(g, x, enemyId);
            } else if (enemyId == 0x00 || enemyId == 0x06 || enemyId==0x0e) {
                local kind = enemyId == 0x06 ? "goomba" : "koopa";
                local enemy=makeEnemy(x,row+1,kind);
                if(enemyId==0x0e) enemy.greenJump <- true;
                g.goombas.append(enemy);
            }
        }
        cursor += 2;
    }
}

function decodeUndergroundBonusRoom(g) {
    // L_UndergroundArea3 is shared by several worlds.  World 1-1 enters page
    // zero, ending at the first scroll-lock/page boundary ($4d,$c7).
    // Row-$0e commands alter TerrainControl.  This room changes from floor-2
    // to ceiling-1/floor-5 at column 3, then back at column 10.  Decode the
    // same 16 two-byte masks used by AreaParserTaskHandler instead of assuming
    // a flat floor; otherwise the first underground jump misses its platform.
    local terrainMasks = [
        0x00, 0x00, 0x00, 0x18, 0x01, 0x18, 0x07, 0x18,
        0x0F, 0x18, 0xFF, 0x18, 0x01, 0x1F, 0x07, 0x1F,
        0x0F, 0x1F, 0x81, 0x1F, 0x01, 0x00, 0x8F, 0x1F,
        0xF1, 0x1F, 0xF9, 0x18, 0xF1, 0x18, 0xFF, 0x1F
    ];
    local terrainAt = array(g.areaWidth, 1);
    local terrainControl = 1;
    local terrainPage = 0;
    local terrainCursor = 2;
    local nextColumn = 0;
    while (terrainCursor < ROM_UNDERGROUND_BONUS_AREA_DATA.len()) {
        local first = ROM_UNDERGROUND_BONUS_AREA_DATA[terrainCursor];
        if (first == 0xFD) break;
        local second = ROM_UNDERGROUND_BONUS_AREA_DATA[terrainCursor + 1];
        terrainCursor += 2;
        if ((second & 0x80) != 0) terrainPage += 1;
        if (terrainPage > 0) break;
        local column = first >> 4;
        // The renderer's buffered object slots make the raised-floor command
        // at column 3 visible from column 4, while the restore command at
        // column 10 is already active for column 10.
        local newControl = second & 0x0F;
        // AreaParserTaskHandler submits the terrain column before applying a
        // row-$0e control command, so both transitions begin one column later.
        local activationColumn = column + 1;
        while (nextColumn < activationColumn && nextColumn < g.areaWidth) {
            terrainAt[nextColumn] = terrainControl;
            nextColumn += 1;
        }
        if ((first & 0x0F) == 0x0E && (second & 0x40) == 0)
            terrainControl = newControl;
    }
    while (nextColumn < g.areaWidth) {
        terrainAt[nextColumn] = terrainControl;
        nextColumn += 1;
    }
    for (local x = 0; x < g.areaWidth; x += 1) {
        local control = terrainAt[x];
        local upperMask = terrainMasks[control * 2];
        local lowerMask = terrainMasks[control * 2 + 1];
        for (local parserRow = 0; parserRow < 13; parserRow += 1) {
            local mask = parserRow < 8 ? upperMask : lowerMask;
            local bit = 1 << (parserRow < 8 ? parserRow : parserRow - 8);
            if ((mask & bit) != 0) {
                local screenRow = parserRow + 2;
                // Underground terrain uses cracked rock only for the two
                // bottom floor rows.  Ceiling and raised-floor masks use the
                // regular brick metatile with the underground palette.
                setTile(g, x, screenRow,
                        screenRow >= 13 ? TILE_GROUND : TILE_SOLID);
            }
        }
    }

    local page = 0;
    local cursor = 2;
    while (cursor < ROM_UNDERGROUND_BONUS_AREA_DATA.len()) {
        local first = ROM_UNDERGROUND_BONUS_AREA_DATA[cursor];
        if (first == 0xFD) break;
        local second = ROM_UNDERGROUND_BONUS_AREA_DATA[cursor + 1];
        cursor += 2;
        local row = first & 0x0F;
        if ((second & 0x80) != 0) page += 1;
        if (page > 0) break;

        local x = first >> 4;
        local screenRow = row + 2;
        local objectClass = (second & 0x70) >> 4;
        local length = second & 0x0F;
        if (row < 12 && objectClass == 4) {
            for (local offset = 0; offset <= length; offset += 1) {
                g.levelCoins.append({
                    x = (x + offset) * TILE_SIZE.tofloat(),
                    y = screenRow * TILE_SIZE.tofloat(),
                    width = 16.0, height = 16.0, active = true
                });
            }
        } else if (row < 12 && objectClass == 5) {
            fillTileColumn(g, x, screenRow, length, TILE_BRICK);
        }
    }

    // ExitPipe ($df,$4a): the ROM renderer expands this into a two-row,
    // three-column sideways pipe.  Preserve those exact metatile roles.
    g.sidePipeX = 13;
    setTile(g, 13, 11, TILE_SIDE_PIPE_TOP_END);
    setTile(g, 14, 11, TILE_SIDE_PIPE_TOP_SHAFT);
    setTile(g, 15, 11, TILE_SIDE_PIPE_TOP_JOINT);
    setTile(g, 13, 12, TILE_SIDE_PIPE_BOTTOM_END);
    setTile(g, 14, 12, TILE_SIDE_PIPE_BOTTOM_SHAFT);
    setTile(g, 15, 12, TILE_SIDE_PIPE_BOTTOM_JOINT);
    // The right half of the vertical exit pipe lies on the following
    // nametable.  Column 15 exposes its left shaft for rows 2..10.
    for (local row = 2; row <= 10; row += 1)
        setTile(g, 15, row, TILE_PIPE_SHAFT_LEFT);
}

function clearAreaObjects(g) {
    g.tiles = array(LEVEL_WIDTH * LEVEL_HEIGHT, TILE_EMPTY);
    g.goombas = [];
    g.powerups = [];
    g.fireballs = [];
    g.brickDebris = [];
    g.levelCoins = [];
    g.brickCoinTimer = 0.0;
    g.brickCoinStarted = false;
}

function buildLevel(g) {
    g.area = "main";
    g.areaWidth = LEVEL_WIDTH;
    g.sidePipeX = -1;
    clearAreaObjects(g);
    decodeWorld11Foreground(g);
    decodeWorld11Enemies(g);
}

function buildUndergroundBonus(g) {
    g.area = "underground";
    g.areaWidth = 17;
    clearAreaObjects(g);
    decodeUndergroundBonusRoom(g);
}

function validateLevel(g) {
    if (!isSolidAt(g, 0, GROUND_ROW)) throw "level validation: spawn ground is missing";
    if (isSolidAt(g, 69, GROUND_ROW)) throw "level validation: first canonical gap is blocked";
    if (getTile(g, 16, 9) != TILE_QUESTION) throw "level validation: opening coin block missing";
    if (getTile(g, 21, 9) != TILE_POWERUP_BLOCK) throw "level validation: opening power-up block missing";
    if (g.goombas.len() != 17) throw "level validation: ROM enemy stream decode incomplete";
    if (g.flagX <= LOGICAL_WIDTH) throw "level validation: flag must be beyond the opening screen";
}

function createPlayer() {
    return {
        // Player_X_Position is $28 at the first controllable World 1-1 frame.
        // The collision origin remains 16 px below the 32 px OAM sprite origin.
        x = 40.0, y = 192.0,
        previousX = 40.0, previousY = 192.0,
        width = 12.0, height = 16.0,
        vx = 0.0, vy = 0.0,
        // $0705 is the friction/acceleration fraction.  $0400 is a separate
        // position-integration fraction; sharing them accelerates Mario early.
        nesXSpeed = 0, nesXSpeedAbsolute = 0,
        nesXForce = 0, nesXMoveForce = 0, nesXScroll = 0,
        nesYSpeed = 0, nesYMoveForce = 0, nesYDummy = 0,
        jumpForce = 0x20, fallForce = 0x70,
        jumpGravityActive = false,
        jumpOriginY = 192.0,
        runningTimer = 0,
        // Mirrors Running_Speed: a sticky copy written by
        // GetPlayerAnimSpeed, not the current velocity magnitude.
        runningSpeed = 0,
        // PlayerAnimTimer/PlayerAnimCtrl ($0781/$070d).  animationFrame is
        // the CHR frame prepared by gameplay; displayAnimationFrame is the
        // preceding OAM image currently visible on the PPU.
        playerAnimTimer = 0,
        playerAnimTimerSet = 7,
        playerAnimCtrl = 0,
        animationFrame = -1,
        preparedAnimationFrame = -1,
        queuedAnimationFrame = -1,
        displayAnimationFrame = -1,
        preparedFacing = 1,
        queuedFacing = 1,
        displayFacing = 1,
        // OAM DMA exposes the sprite coordinates prepared by the preceding
        // gameplay pass.  Keep both preparation and display stages explicit.
        preparedRelX = 40.0,
        preparedRelY = 176.0,
        queuedRelX = 40.0,
        queuedRelY = 176.0,
        displayRelX = 40.0,
        displayRelY = 176.0,
        parityOriginFriction = false,
        entranceFalling = false,
        sidePipeCollision = false,
        // SideCollisionTimer ($0785) gates scrolling after an obstructing
        // background collision.  Keep the direction selected by the ROM too;
        // it is intentionally sticky while horizontal speed is zero.
        sideCollisionFrames = 0,
        sideCollisionFramesAtStart = 0,
        scrollSideCollisionTimer = false,
        pendingPlatformXScroll = 0,
        movingDir = 1,
        collisionBits = 0xFF,
        deepFootCollision = false,
        climbSideFrames = 24,
        endLevelClimbing = false,
        courseClearHidden = false,
        endLevelFirstFrame = false,
        grounded = true,
        headCollision = false,
        headCollisionSpeed = 0,
        facing = 1,
        crouching = false,
        skidding = false,
        big = false,
        fire = false,
        starTimer = 0.0,
        starMusicActive = false,
        transformTimer = 0.0,
        transformFrames = 0,
        transformToBig = false,
        transformKind = "none",
        throwingTimer = 0.0,
        invulnerable = 0.0,
        dead = false,
        deadTimer = 0.0,
        deadFrames = 0,
        deathFreezeFrames = 0
    };
}

function createGame() {
    local g = {
        world = 1, level = 1, stage = "world11",
        plants = [], platforms = [], enterablePipes = [],
        world12BaseTiles = [], world12Metatiles = [], savedWorld12 = null,
        world12Target = "underground", world12PipeMode = "side", world12TransitionFrames = 0,
        warpWorld = 0,
        accumulator = 0.0,
        simTime = 0.0,
        cameraX = 0.0,
        // The PPU consumes the scroll prepared before the current gameplay
        // pass.  Keep that display position separate from the latest RAM-side
        // camera value used by collision and state parity.
        displayCameraX = 0.0,
        previousScrollAmount = 0.0,
        vramPrimaryBytes = 0,
        displayBackgroundYOffset = 0.0,
        area = "main",
        romBackgroundCollision = false,
        areaWidth = LEVEL_WIDTH,
        sidePipeX = -1,
        savedMain = null,
        transitionTimer = 0.0,
        // Area transitions are sequenced by NES frames.  Keep explicit
        // counters instead of wall-clock thresholds so parity replays expose
        // the same OperMode_Task / GameEngineSubroutine lifecycle as the ROM.
        areaTransitionFrames = 0,
        areaReloadFrames = 0,
        areaEntranceFrames = 0,
        // PlayerEndLevel task 5 increments LevelNumber and calls ChgAreaMode.
        // The next area observes one game-engine pass before its loader clears
        // the player/camera, then exposes an initialized zero-position player.
        stageLoadFrames = 0,
        areaReloadTarget = "underground",
        transitionTargetY = 0.0,
        score = 0,
        coins = 0,
        // Status-bar digit updates are written to a VRAM buffer and become
        // visible on the second captured frame after gameplay mutates RAM.
        queuedScore = 0,
        displayScore = 0,
        queuedCoins = 0,
        displayCoins = 0,
        lives = 3,
        time = 400,
        hurryActive = false,
        displayTime = 400,
        // RAM $0787 is 23 at the captured first controllable frame.  The
        // global timer pass decrements it before RunGameTimer tests for zero;
        // RunGameTimer then reloads the NTSC value $18 (24).
        gameTimerControl = 23,
        // FrameCounter at the first controllable frame of the verified ROM
        // origin state.  Player/enemy collision runs only on even values.
        nesFrameCounter = 0x99,
        // UpdateScreen begins the comparison at interval phase zero. The
        // counter reloads to $14 after underflow and controls the slower
        // EnemyIntervalTimer bank used by stomped Goombas and shells.
        intervalTimerControl = 0,
        // RAM $06d4 points to the next ColorRotatePalette entry.  The first
        // controllable reference frame has already displayed entry zero.
        colorRotateOffset = 1,
        displayColorPhase = 0,
        pendingColorPhase = 0,
        colorPhasePending = false,
        // The area parser owns VRAM buffer 2 ($0341).  When it selects that
        // buffer via $0773, NMI leaves a queued palette packet in buffer 1
        // for one more frame.  These two fields mirror $073d/$071f so the
        // palette transfer follows the ROM scheduler instead of a guessed
        // fixed delay.
        vramScrollThirtyTwo = 0,
        vramAreaParserTask = 0,
        vramBufferAddrCtrl = 0,
        // EnemyGfxHandler renders from the frame counter that entered the
        // gameplay pass.  TimerControl freezes this selection on death.
        goombaVisualFrame = 0,
        checkpointPage = 0,
        state = "playing",
        stateTimer = 0.0,
        previewCaptured = false,
        flagX = 198.0 * TILE_SIZE,
        flagY = 48.0,
        preparedFlagY = 48.0,
        displayFlagY = 48.0,
        flagScoreY = 176.0,
        preparedFlagScoreY = 176.0,
        displayFlagScoreY = 176.0,
        flagScoreAge = -1,
        flagContactScrollPending = false,
        flagSoundPending = false,
        castleX = 205.0 * TILE_SIZE,
        castleFlagVisible = false,
        castleFlagY = 144.0,
        fireworksRemaining = 0,
        fireworksOffsetState = -1,
        fireworkSpawnFrames = 0,
        clearDelayFrames = 0,
        endLevelScrollLocked = false,
        endLevelUnlockFrames = 0,
        deathReloadFrames = 0,
        // The ROM's first post-entrance player-physics pass occurs after the
        // RAM trace point used by the parity harness.  Preserve that pending
        // input so the following captured frame starts from the same state.
        respawnPrimeDirection = 0,
        respawnPrimeRun = false,
        fireworks = [],
        floatingScores = [],
        soundEvents = [],
        player = createPlayer(),
        tiles = [],
        goombas = [],
        powerups = [],
        fireballs = [],
        brickDebris = [],
        levelCoins = [],
        brickCoinTimer = 0.0,
        brickCoinStarted = false,
        stompChain = 0,
        bump = { active = false, powerupPending = false, tx = 0, ty = 0, tile = TILE_EMPTY,
                 time = 0.0, frame = 0 },
        // Metatile replacements follow the same buffered PPU path.  Entries
        // temporarily retain the old visible metatile while collision already
        // observes the new value in g.tiles.
        displayTileOverrides = [],
        archivedCoinEffects = [],
        coinEffect = {
            active = false, x = 0.0, y = 0.0, time = 0.0,
            displayX = 0.0,
            phase = "coin", displayPhase = "coin", frame = 0, scoreFrame = 0,
            spawnCarryYOffset = 0.0
        },
        input = {
            left = false, right = false, up = false, down = false,
            run = false, runDown = false,
            fireQueued = false,
            jumpDown = false, jumpQueued = false,
            resetDown = false, resetQueued = false
            startDown = false, startQueued = false
        }
    };
    buildLevel(g);
    return g;
}

function requireSelfTest(condition, message) {
    if (!condition) throw "simulation self-test failed: " + message;
}

function runSimulationSelfTest() {
    runPowerUpStatusSelfTest();
    runKoopaRevivalSelfTest();
    requireSelfTest(ROM_BACK_SCENERY_OFFSETS.len() == 3,
                    "ROM scenery offset table must contain three themes");
    requireSelfTest(ROM_BACK_SCENERY_DATA.len() == 144,
                    "ROM scenery data must contain three 48-column patterns");
    requireSelfTest(ROM_BACK_SCENERY_METATILES.len() == 36,
                    "ROM scenery metatile table must contain twelve objects");
    requireSelfTest(ROM_BACK_SCENERY_DATA[0x30] == 0x97,
                    "World 1-1 scenery must start with the original hill descriptor");
    requireSelfTest(ROM_WORLD_1_1_QUESTION_POWERUPS.len() == 3,
                    "World 1-1 must contain three ROM-defined question power-ups");
    requireSelfTest(ROM_WORLD_1_1_QUESTION_COINS.len() == 10,
                    "World 1-1 must contain ten ROM-defined question coins");
    requireSelfTest(ROM_WORLD_1_1_AREA_DATA.len() == 101 &&
                    ROM_WORLD_1_1_AREA_DATA[100] == 0xFD,
                    "World 1-1 foreground stream must be complete");
    requireSelfTest(ROM_WORLD_1_1_ENEMY_DATA.len() == 30 &&
                    ROM_WORLD_1_1_ENEMY_DATA[29] == 0xFF,
                    "World 1-1 enemy stream must be complete");

    local romLayoutTest = createGame();
    requireSelfTest(getTile(romLayoutTest, 69, GROUND_ROW) == TILE_EMPTY &&
                    getTile(romLayoutTest, 70, GROUND_ROW) == TILE_EMPTY,
                    "first ROM hole must span columns 69-70");
    requireSelfTest(getTile(romLayoutTest, 134, 12) == TILE_SOLID &&
                    getTile(romLayoutTest, 137, 9) == TILE_SOLID,
                    "first ROM staircase must decode column by column");
    requireSelfTest(romLayoutTest.flagX == 198.0 * TILE_SIZE &&
                    romLayoutTest.castleX == 202.0 * TILE_SIZE,
                    "flagpole and castle must come from the ROM stream");
    requireSelfTest(getTile(romLayoutTest, 198, 12) == TILE_SOLID,
                    "flagpole must include the ROM solid base block");
    local goombaCount = 0;
    local koopaCount = 0;
    local firstEnemyX = 999999.0;
    local koopaX = -1.0;
    foreach (enemy in romLayoutTest.goombas) {
        if (enemy.kind == "goomba") goombaCount += 1;
        if (enemy.kind == "koopa") {
            koopaCount += 1;
            koopaX = enemy.x;
        }
        if (enemy.x < firstEnemyX) firstEnemyX = enemy.x;
    }
    requireSelfTest(goombaCount == 16 && koopaCount == 1,
                    "ROM stream must decode sixteen goombas and one green koopa");
    requireSelfTest(romLayoutTest.goombas[0].vx == -KOOPA_WALK_SPEED &&
                    KOOPA_SHELL_SPEED == NES_FRAME_RATE * 3.0,
                    "normal enemy $f8 and kicked-shell $30 speeds must match ROM 4.4 units");
    requireSelfTest(firstEnemyX == 22.0 * TILE_SIZE &&
                    koopaX == 107.0 * TILE_SIZE,
                    "ROM enemy coordinates must not use hand-authored positions");

    local walkPhysics = createGame();
    walkPhysics.player.grounded = true;
    for (local i = 0; i < 120; i += 1)
        updateNesHorizontalPhysics(walkPhysics, walkPhysics.player, 1);
    requireSelfTest(walkPhysics.player.nesXSpeed == 0x18,
                    "ground walking must cap at ROM speed $18");
    local runPhysics = createGame();
    runPhysics.player.grounded = true;
    runPhysics.input.run = true;
    for (local i = 0; i < 120; i += 1)
        updateNesHorizontalPhysics(runPhysics, runPhysics.player, 1);
    requireSelfTest(runPhysics.player.nesXSpeed == 0x28,
                    "ground running must cap at ROM speed $28");
    local airPhysics = createGame();
    airPhysics.player.grounded = false;
    airPhysics.input.run = true;
    for (local i = 0; i < 120; i += 1)
        updateNesHorizontalPhysics(airPhysics, airPhysics.player, 1);
    requireSelfTest(airPhysics.player.nesXSpeed == 0x18,
                    "B must not promote a slow airborne jump to run speed");
    local coastPhysics = createGame();
    coastPhysics.player.grounded = true;
    coastPhysics.player.nesXSpeed = 0x28;
    updateNesHorizontalPhysics(coastPhysics, coastPhysics.player, 0);
    requireSelfTest(coastPhysics.player.nesXSpeed < 0x28 &&
                    coastPhysics.player.nesXSpeed > 0x18,
                    "released run speed must coast with ROM friction $d0");

    requireSelfTest(ROM_UNDERGROUND_BONUS_AREA_DATA[0] == 0x48 &&
                    ROM_UNDERGROUND_BONUS_AREA_DATA[1] == 0x01,
                    "underground room must retain its ROM area header");
    local undergroundTest = createGame();
    undergroundTest.goombas = [];
    undergroundTest.player.x = 57.0 * TILE_SIZE + 10.0;
    undergroundTest.player.y = 11.0 * TILE_SIZE - undergroundTest.player.height;
    undergroundTest.player.grounded = true;
    undergroundTest.input.down = true;
    simulateFixed(undergroundTest, FIXED_DT);
    requireSelfTest(undergroundTest.state == "pipeDown",
                    "down on World 1-1 pipe column 57 must start pipe entry");
    for (local i = 0; i < 96; i += 1)
        simulateFixed(undergroundTest, FIXED_DT);
    requireSelfTest(undergroundTest.area == "underground" &&
                    undergroundTest.levelCoins.len() == 19,
                    "pipe entry must load ROM bonus room page zero and nineteen coins");
    local undergroundResumeCount = 0;
    foreach (sound in undergroundTest.soundEvents)
        if (sound == "resume_music") undergroundResumeCount += 1;
    requireSelfTest(undergroundResumeCount == 1,
                    "pipe entry must queue the underground music exactly once");
    undergroundTest.soundEvents.clear();
    undergroundTest.input.down = false;
    undergroundTest.input.right = true;
    undergroundTest.player.x = 13.0 * TILE_SIZE - undergroundTest.player.width;
    undergroundTest.player.y = GROUND_ROW * TILE_SIZE - undergroundTest.player.height;
    undergroundTest.player.grounded = true;
    simulateFixed(undergroundTest, FIXED_DT);
    requireSelfTest(undergroundTest.state == "pipeSide",
                    "right at the bonus-room exit must start sideways pipe travel");
    for (local i = 0; i < 300; i += 1)
        simulateFixed(undergroundTest, FIXED_DT);
    requireSelfTest(undergroundTest.area == "main" &&
                    undergroundTest.state == "playing" &&
                    undergroundTest.player.x > 160.0 * TILE_SIZE,
                    "bonus-room exit must restore the main area at return pipe");
    local overworldResumeCount = 0;
    foreach (sound in undergroundTest.soundEvents)
        if (sound == "resume_music") overworldResumeCount += 1;
    requireSelfTest(overworldResumeCount == 1,
                    "pipe exit must queue the overworld music exactly once");

    local overlayTest = createGame();
    overlayTest.state = "areaReload";
    overlayTest.areaReloadTarget = "underground";
    overlayTest.areaReloadFrames = 1;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "sky",
                    "underground load must hide the staged spawn immediately");
    overlayTest.areaReloadFrames = 3;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "sky",
                    "underground load must keep the sky through frame 3");
    overlayTest.areaReloadFrames = 4;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "black",
                    "underground load must switch to black on frame 4");
    overlayTest.areaReloadFrames = 25;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "black",
                    "underground load must stay black through frame 25");
    overlayTest.areaReloadFrames = 26;
    requireSelfTest(areaTransitionOverlay(overlayTest) == null,
                    "underground load must expose the prepared scene on frame 26");
    overlayTest.state = "areaEntrance";
    overlayTest.areaEntranceFrames = 1;
    requireSelfTest(areaTransitionOverlay(overlayTest) == null,
                    "underground entrance must expose the prepared scene");
    overlayTest.state = "areaReload";
    overlayTest.areaReloadTarget = "main";
    overlayTest.areaReloadFrames = 1;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "black",
                    "overworld return must start with a black screen");
    overlayTest.areaReloadFrames = 22;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "black",
                    "overworld return must stay black through frame 22");
    overlayTest.areaReloadFrames = 23;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "sky",
                    "overworld return must expose the sky on frame 23");
    overlayTest.areaReloadFrames = 25;
    requireSelfTest(areaTransitionOverlay(overlayTest) == "sky",
                    "overworld return must keep the sky through frame 25");
    overlayTest.areaReloadFrames = 26;
    requireSelfTest(areaTransitionOverlay(overlayTest) == null,
                    "overworld return must expose the prepared scene on frame 26");
    overlayTest.state = "areaExitEntrance";
    overlayTest.areaEntranceFrames = 1;
    requireSelfTest(areaTransitionOverlay(overlayTest) == null,
                    "overworld entrance must expose the prepared scene");

    local t = createGame();
    t.goombas = [];

    for (local i = 0; i < 8; i += 1) simulateFixed(t, FIXED_DT);
    requireSelfTest(t.player.grounded, "player must settle on spawn ground");

    local startX = t.player.x;
    t.input.right = true;
    for (local i = 0; i < 30; i += 1) simulateFixed(t, FIXED_DT);
    requireSelfTest(t.player.x > startX + 12.0, "right input must accelerate the player");

    t.input.jumpDown = true;
    t.input.jumpQueued = true;
    simulateFixed(t, FIXED_DT);
    t.input.jumpQueued = false;
    requireSelfTest(t.player.vy < 0.0 && !t.player.grounded, "jump must leave the ground");

    t.input.right = false;
    t.input.jumpDown = true;
    t.player.x = 16.0 * TILE_SIZE + 2.0;
    t.player.y = 162.0;
    t.player.nesXSpeed = 0;
    t.player.nesYSpeed = -3;
    t.player.nesYMoveForce = 0;
    t.player.nesYDummy = 0;
    for (local i = 0; i < 4 && getTile(t, 16, 9) == TILE_QUESTION; i += 1)
        updatePlayer(t, FIXED_DT);
    requireSelfTest(getTile(t, 16, 9) == TILE_USED, "head bump must consume a coin block");
    requireSelfTest(t.coins == 1, "question block must award one coin");
    requireSelfTest(t.coinEffect.x == 16.0 * TILE_SIZE + 5.0 &&
                    t.coinEffect.y == 9.0 * TILE_SIZE - 16.0,
                    "jumping coin must use the ROM block-relative OAM origin");

    // Exercise the actual renderer's placement, not only the stored spawn Y.
    // The upper question block at (22,5) is 64 pixels above the lower row.
    local lowCoinTest = createGame();
    local highCoinTest = createGame();
    startJumpingCoin(lowCoinTest, 23, 9);
    hitBlock(highCoinTest, 22, 5);
    requireSelfTest(highCoinTest.coinEffect.active &&
                    getTile(highCoinTest, 22, 5) == TILE_USED,
                    "upper question block must spawn a coin");
    for (local tick = 0; tick < 78; tick += 1) {
        updateCoinEffect(lowCoinTest, lowCoinTest.coinEffect, FIXED_DT);
        updateCoinEffect(highCoinTest, highCoinTest.coinEffect, FIXED_DT);
        requireSelfTest(coinEffectDrawY(lowCoinTest.coinEffect) -
                        coinEffectDrawY(highCoinTest.coinEffect) == 64.0,
                        "coin and score rendering must follow the source row throughout their lifetime");
        if (tick == 2)
            requireSelfTest(coinEffectDrawY(lowCoinTest.coinEffect) == 118.0 &&
                            coinEffectDrawY(highCoinTest.coinEffect) == 54.0,
                            "first visible coin must preserve the reference trajectory relative to its block");
    }
    local stackedCoinsTest = createGame();
    startJumpingCoin(stackedCoinsTest, 22, 5);
    startJumpingCoin(stackedCoinsTest, 23, 9);
    local archivedCoin = stackedCoinsTest.archivedCoinEffects[0];
    archivedCoin.frame = 3;
    stackedCoinsTest.coinEffect.frame = 3;
    requireSelfTest(coinEffectDrawY(archivedCoin) == 54.0 &&
                    coinEffectDrawY(stackedCoinsTest.coinEffect) == 119.0,
                    "overlapping coins must keep independent row origins and the misc-slot carry offset");
    archivedCoin.displayPhase = "score";
    archivedCoin.scoreFrame = 2;
    requireSelfTest(coinEffectDrawY(archivedCoin) == 58.0,
                    "archived upper coin score must stay relative to its own block");

    local headSampleTest = createGame();
    headSampleTest.goombas = [];
    setTile(headSampleTest, 20, 9, TILE_QUESTION);
    setTile(headSampleTest, 21, 9, TILE_QUESTION);
    headSampleTest.player.x = 330.0;
    headSampleTest.player.y = 158.0;
    headSampleTest.player.vy = -NES_FRAME_RATE;
    movePlayerY(headSampleTest, headSampleTest.player, FIXED_DT);
    requireSelfTest(getTile(headSampleTest, 20, 9) == TILE_QUESTION &&
                    getTile(headSampleTest, 21, 9) == TILE_USED,
                    "head collision must use the ROM centre sample at block corners");

    local itemTest = createGame();
    itemTest.goombas = [];
    hitBlock(itemTest, 21, 9);
    requireSelfTest(getTile(itemTest, 21, 9) == TILE_USED,
                    "power-up block must become used");
    requireSelfTest(itemTest.powerups.len() == 1,
                    "power-up block must spawn a mushroom");
    requireSelfTest(itemTest.powerups[0].kind == "mushroom",
                    "small Mario must reveal a mushroom");
    requireSelfTest(itemTest.coins == 0,
                    "power-up block must not award a coin");
    requireSelfTest(itemTest.powerups[0].vx == NES_FRAME_RATE,
                    "mushroom speed $10 must equal one pixel per frame");
    requireSelfTest(itemTest.powerups[0].y == 9.0 * TILE_SIZE - 8.0 &&
                    !itemTest.powerups[0].visible,
                    "power-up must begin eight pixels above the block and stay hidden");
    for (local i = 0; i < 19; i += 1)
        movePowerUp(itemTest, itemTest.powerups[0], FIXED_DT);
    requireSelfTest(!itemTest.powerups[0].visible,
                    "power-up states $01-$05 must remain outside OAM");
    movePowerUp(itemTest, itemTest.powerups[0], FIXED_DT);
    requireSelfTest(itemTest.powerups[0].visible &&
                    itemTest.powerups[0].emergePixels == 5,
                    "power-up must first render after its fifth rise pixel");
    requireSelfTest(powerUpDrawY(itemTest.powerups[0]) ==
                    9.0 * TILE_SIZE - 4.0,
                    "first visible power-up pixels must remain behind the source block");
    for (local i = 20; i < 67; i += 1)
        movePowerUp(itemTest, itemTest.powerups[0], FIXED_DT);
    requireSelfTest(itemTest.powerups[0].emerging,
                    "power-up must still be emerging before ROM frame 68");
    movePowerUp(itemTest, itemTest.powerups[0], FIXED_DT);
    requireSelfTest(!itemTest.powerups[0].emerging,
                    "power-up must finish its seventeen-pixel rise on ROM frame 68");
    requireSelfTest(itemTest.powerups[0].y == 8.0 * TILE_SIZE,
                    "fully emerged power-up must rest directly on the source block");
    collectPowerUp(itemTest, itemTest.powerups[0]);
    requireSelfTest(itemTest.player.big && itemTest.player.transformFrames == 40 &&
                    itemTest.player.transformKind == "grow",
                    "mushroom growth must use ten four-frame ROM animation steps");

    local flowerTest = createGame();
    flowerTest.player.big = true;
    flowerTest.player.height = 32.0;
    hitBlock(flowerTest, 21, 9);
    requireSelfTest(flowerTest.powerups.len() == 1,
                    "Super Mario power-up block must spawn one item");
    requireSelfTest(flowerTest.powerups[0].kind == "flower",
                    "Super Mario must reveal a fire flower");
    collectPowerUp(flowerTest, flowerTest.powerups[0]);
    requireSelfTest(flowerTest.player.fire && flowerTest.player.big &&
                    flowerTest.player.height == 32.0,
                    "collecting a fire flower must retain Super Mario's size");
    requireSelfTest(flowerTest.player.transformFrames == 63 &&
                    flowerTest.player.transformKind == "fire",
                    "fire-flower transformation must use a palette-only cycle");
    flowerTest.simTime = 4.0 * FIXED_DT;
    requireSelfTest(playerPalettePhase(flowerTest) == 1,
                    "fire-flower palette must advance every four frames");

    local injuryTest = createGame();
    injuryTest.player.big = true;
    injuryTest.player.height = 32.0;
    hurtPlayer(injuryTest);
    requireSelfTest(injuryTest.player.transformFrames == 40 &&
                    injuryTest.player.invulnerable == 208.0 * FIXED_DT,
                    "injury must preserve the ROM size-change and interval timers");

    local oneUpTest = createGame();
    requireSelfTest(getTile(oneUpTest, 64, 8) == TILE_HIDDEN_ONEUP,
                    "ROM hidden one-up block must exist at 64,8");
    requireSelfTest(!isSolidTile(TILE_HIDDEN_ONEUP),
                    "unrevealed one-up block must not block normal movement");
    oneUpTest.goombas = [];
    oneUpTest.player.x = 64.0 * TILE_SIZE + 2.0;
    oneUpTest.player.y = GROUND_ROW * TILE_SIZE - oneUpTest.player.height;
    oneUpTest.player.grounded = true;
    oneUpTest.input.jumpDown = true;
    oneUpTest.input.jumpQueued = true;
    simulateFixed(oneUpTest, FIXED_DT);
    oneUpTest.input.jumpQueued = false;
    for (local i = 0; i < 45 &&
         getTile(oneUpTest, 64, 8) == TILE_HIDDEN_ONEUP; i += 1)
        simulateFixed(oneUpTest, FIXED_DT);
    requireSelfTest(getTile(oneUpTest, 64, 8) == TILE_USED,
                    "jumping into hidden one-up block must reveal it");
    requireSelfTest(oneUpTest.powerups.len() == 1 &&
                    oneUpTest.powerups[0].kind == "oneup",
                    "hidden block must reveal a one-up mushroom");
    local livesBeforeOneUp = oneUpTest.lives;
    collectPowerUp(oneUpTest, oneUpTest.powerups[0]);
    requireSelfTest(oneUpTest.lives == livesBeforeOneUp + 1,
                    "one-up mushroom must add one life");

    local contentTest = createGame();
    foreach (point in ROM_WORLD_1_1_QUESTION_COINS) {
        local isCoinBlock = getTile(contentTest, point[0], point[1]) == TILE_QUESTION;
        requireSelfTest(isCoinBlock,
                        "ROM coin block mismatch at " + point[0] + "," + point[1]);
    }
    foreach (point in ROM_WORLD_1_1_QUESTION_POWERUPS) {
        local isPowerupBlock =
            getTile(contentTest, point[0], point[1]) == TILE_POWERUP_BLOCK;
        requireSelfTest(isPowerupBlock,
                        "ROM power-up block mismatch at " + point[0] + "," + point[1]);
    }
    local coinBlockCount = 0;
    local powerupBlockCount = 0;
    foreach (tile in contentTest.tiles) {
        if (tile == TILE_QUESTION) coinBlockCount += 1;
        if (tile == TILE_POWERUP_BLOCK) powerupBlockCount += 1;
    }
    requireSelfTest(coinBlockCount == ROM_WORLD_1_1_QUESTION_COINS.len(),
                    "question coin count must match the ROM");
    requireSelfTest(powerupBlockCount == ROM_WORLD_1_1_QUESTION_POWERUPS.len(),
                    "question power-up count must match the ROM");

    local specialBlockTest = createGame();
    specialBlockTest.goombas = [];
    requireSelfTest(getTile(specialBlockTest, 94, 9) == TILE_BRICK_COIN,
                    "ROM multi-coin brick must exist at 94,9");
    requireSelfTest(getTile(specialBlockTest, 101, 9) == TILE_BRICK_STAR,
                    "ROM star brick must exist at 101,9");
    hitBlock(specialBlockTest, 94, 9);
    requireSelfTest(specialBlockTest.coins == 1 &&
                    getTile(specialBlockTest, 94, 9) == TILE_BRICK_COIN,
                    "multi-coin brick must remain reusable during its timer");
    specialBlockTest.brickCoinTimer = 0.0;
    hitBlock(specialBlockTest, 94, 9);
    requireSelfTest(specialBlockTest.coins == 2 &&
                    getTile(specialBlockTest, 94, 9) == TILE_USED,
                    "expired multi-coin brick must pay its final coin and become used");
    hitBlock(specialBlockTest, 101, 9);
    requireSelfTest(getTile(specialBlockTest, 101, 9) == TILE_USED &&
                    specialBlockTest.powerups.len() == 1 &&
                    specialBlockTest.powerups[0].kind == "star",
                    "star brick must reveal a star and become used");
    local starItem = specialBlockTest.powerups[0];
    for (local i = 0; i < 68; i += 1)
        movePowerUp(specialBlockTest, starItem, FIXED_DT);
    movePowerUp(specialBlockTest, starItem, FIXED_DT);
    local starLandingY = starItem.y;
    movePowerUp(specialBlockTest, starItem, FIXED_DT);
    requireSelfTest(starItem.vy < 0.0 && starItem.y < starLandingY &&
                    starItem.romY == starItem.y - 8.0,
                    "emerged star must bounce and publish its vertical ROM coordinate");
    collectPowerUp(specialBlockTest, specialBlockTest.powerups[0]);
    requireSelfTest(specialBlockTest.player.starTimer == STAR_INVINCIBLE_TIME,
                    "star collection must start the invincibility timer");
    requireSelfTest(specialBlockTest.player.starMusicActive &&
                    specialBlockTest.soundEvents.len() >= 2 &&
                    specialBlockTest.soundEvents[specialBlockTest.soundEvents.len() - 1] ==
                        "star_music",
                    "star collection must switch to StarPowerMusic");
    specialBlockTest.simTime = 2.0 * FIXED_DT;
    requireSelfTest(playerPalettePhase(specialBlockTest) == 1,
                    "star palette must advance every two frames");
    specialBlockTest.player.starTimer = 2.0;
    specialBlockTest.simTime = 8.0 * FIXED_DT;
    requireSelfTest(playerPalettePhase(specialBlockTest) == 1,
                    "expiring star palette must slow to eight-frame cadence");
    specialBlockTest.player.starTimer =
        4.0 * NES_INTERVAL_FRAMES * FIXED_DT + FIXED_DT * 0.5;
    specialBlockTest.player.starMusicActive = true;
    specialBlockTest.soundEvents.clear();
    updatePlayer(specialBlockTest, FIXED_DT);
    requireSelfTest(!specialBlockTest.player.starMusicActive &&
                    specialBlockTest.soundEvents.len() == 1 &&
                    specialBlockTest.soundEvents[0] == "resume_music",
                    "StarPowerMusic must restore area music at timer interval four");

    local fireballTest = createGame();
    fireballTest.player.big = true;
    fireballTest.player.fire = true;
    fireballTest.player.height = 32.0;
    spawnFireball(fireballTest);
    spawnFireball(fireballTest);
    spawnFireball(fireballTest);
    requireSelfTest(activeFireballCount(fireballTest) == 2,
                    "fire Mario must be limited to two active fireballs");
    local firstFireballDelta = fireballVerticalDelta(fireballTest.fireballs[0]);
    requireSelfTest(firstFireballDelta == 4.0 &&
                    fireballTest.fireballs[0].nesYSpeed == 3,
                    "fireball must move down four pixels once, then clamp to ROM speed three");
    local fireballTarget = fireballTest.goombas[0];
    fireballTest.cameraX = fireballTarget.x - 100.0;
    fireballTest.fireballs[0].x = fireballTarget.x;
    fireballTest.fireballs[0].y = fireballTarget.y;
    updateFireballs(fireballTest, 0.0);
    requireSelfTest(fireballTarget.alive && fireballTarget.state == "flipped" &&
                    fireballTarget.vy < 0.0 && fireballTest.fireballs[0].exploding,
                    "fireball must launch a defeated enemy instead of erasing it");
    requireSelfTest(fireballTest.fireballs[0].explosionFrames == 6,
                    "fireball explosion must begin at ROM state $80 and last six frames");
    for (local i = 0; i < 5; i += 1) updateFireballs(fireballTest, FIXED_DT);
    requireSelfTest(fireballTest.fireballs[0].active,
                    "fireball explosion must remain active through its sixth rendered frame");
    updateFireballs(fireballTest, FIXED_DT);
    requireSelfTest(!fireballTest.fireballs[0].active,
                    "fireball explosion must clear when state reaches frame six");

    local brickTest = createGame();
    brickTest.player.big = true;
    brickTest.player.height = 32.0;
    hitBlock(brickTest, 20, 9);
    requireSelfTest(getTile(brickTest, 20, 9) == TILE_EMPTY,
                    "Super Mario must break brick blocks");
    requireSelfTest(brickTest.brickDebris.len() == 4,
                    "broken brick must spawn four debris pieces");
    requireSelfTest(brickTest.soundEvents.len() == 1 &&
                    brickTest.soundEvents[0] == "break",
                    "broken brick must queue shatter noise without the bump sound");

    local smallBrickTest = createGame();
    local bumpedEnemy = smallBrickTest.goombas[0];
    bumpedEnemy.x = 20.0 * TILE_SIZE;
    bumpedEnemy.y = 9.0 * TILE_SIZE - bumpedEnemy.height;
    hitBlock(smallBrickTest, 20, 9);
    requireSelfTest(getTile(smallBrickTest, 20, 9) == TILE_BRICK,
                    "small Mario must not break brick blocks");
    requireSelfTest(bumpedEnemy.state == "flipped" && bumpedEnemy.vy < 0.0,
                    "a bumped block must flip an enemy standing above it");

    local shroomBumpTest = createGame();
    shroomBumpTest.goombas = [];
    shroomBumpTest.player.x = 368.0;
    shroomBumpTest.player.y = 160.0;
    setTile(shroomBumpTest, 23, 9, TILE_BRICK);
    spawnPowerUp(shroomBumpTest, 22, 9, "mushroom");
    local shroom = shroomBumpTest.powerups[0];
    for (local i = 0; i < 73; i += 1) movePowerUp(shroomBumpTest, shroom, FIXED_DT);
    shroom.x = 358.0;
    hitBlock(shroomBumpTest, 23, 9);
    updatePowerUps(shroomBumpTest, FIXED_DT);
    requireSelfTest(shroom.vx > 0.0 && shroomBumpTest.bump.powerupPending,
                    "front brick must wait for the mushroom's bottom-centre probe, not sprite-edge overlap");
    updatePowerUps(shroomBumpTest, FIXED_DT);
    requireSelfTest(shroom.vx == -NES_FRAME_RATE && shroom.vy == -3.0 * NES_FRAME_RATE &&
                    shroom.y == 126.0 && shroom.romY == 118.0 &&
                    !shroomBumpTest.bump.powerupPending,
                    "mushroom entering the bumped front brick must launch up and away from Mario");
    local launchedX = shroom.x;
    updatePowerUps(shroomBumpTest, FIXED_DT);
    requireSelfTest(shroom.x < launchedX && shroom.y < 126.0 && shroom.active,
                    "bumped mushroom must continue moving left/up without being destroyed or relaunched");
    for (local i = 0; i < 90 && shroom.vy != 0.0; i += 1)
        updatePowerUps(shroomBumpTest, FIXED_DT);
    requireSelfTest(shroom.active && shroom.vx < 0.0 && shroom.vy == 0.0,
                    "bumped mushroom must land and keep walking");

    foreach (kind in ["mushroom", "oneup", "flower", "star"]) {
        local bumpKindTest = createGame();
        bumpKindTest.player.x = 300.0;
        spawnPowerUp(bumpKindTest, 22, 9, kind);
        local item = bumpKindTest.powerups[0];
        requireSelfTest(!bumpPowerUpAbove(bumpKindTest, item, 22, 9),
                        "emerging power-ups must not be bumped");
        item.emerging = false;
        item.y = 128.0;
        item.romY = 120.0;
        item.settleFrame = -1;
        local shouldBump = kind == "mushroom" || kind == "oneup";
        requireSelfTest(bumpPowerUpAbove(bumpKindTest, item, 22, 9) == shouldBump,
                        "only mushroom and 1UP use the stunned-enemy block response");
        if (shouldBump) {
            requireSelfTest(item.vx == NES_FRAME_RATE,
                            "Mario on the left must send the mushroom right, not blindly reverse it");
            item.active = false;
            requireSelfTest(!bumpPowerUpAbove(bumpKindTest, item, 22, 9),
                            "collected power-ups must not be bumped");
        }
    }

    // Exercise drawCastle's real call order and coordinates without a GPU
    // dependency. Restore the renderer before evaluating assertions.
    local castleLayerTest = createGame();
    castleLayerTest.castleFlagVisible = true;
    castleLayerTest.castleFlagY = 113.0;
    local castleDraws = [];
    local savedWorldTexture = worldTexture;
    worldTexture = function(g, texture, x, y, width, height) {
        castleDraws.append({ texture = texture, x = x, y = y });
    };
    drawCastle(castleLayerTest);
    worldTexture = savedWorldTexture;
    requireSelfTest(castleDraws.len() > 1 &&
                    castleDraws[0].texture == assets.scenery.castleFlag &&
                    castleDraws[0].x == castleLayerTest.castleX + 32.0 &&
                    castleDraws[0].y == 114.0,
                    "castle flag must draw behind brickwork at OAM Y+1, retaining the ROM rise endpoint");

    local shellTest = createGame();
    local testKoopa = null;
    local testGoomba = null;
    foreach (enemy in shellTest.goombas) {
        if (enemy.kind == "koopa" && testKoopa == null) testKoopa = enemy;
        if (enemy.kind == "goomba" && testGoomba == null) testGoomba = enemy;
    }
    requireSelfTest(testKoopa != null && testGoomba != null,
                    "shell regression requires one koopa and one goomba");
    foreach(big in [false,true]) {
        local collisionTest=createGame();
        local turtle=makeEnemyAt(100.0,12,"koopa");
        turtle.awake=true;turtle.slot=0;collisionTest.goombas=[turtle];
        collisionTest.nesFrameCounter=0;
        local mario=collisionTest.player;
        mario.big=big;mario.height=big?32.0:16.0;
        mario.x=100.0;mario.previousX=100.0;
        mario.y=turtle.y+12-mario.height;mario.previousY=mario.y-3;
        mario.nesYSpeed=3;mario.vy=3*NES_FRAME_RATE;
        updateGoombas(collisionTest,FIXED_DT);
        requireSelfTest(turtle.state=="shell" && !mario.dead && mario.nesYSpeed==-4,
                        "descending small/big Mario must stomp a walking koopa");
    }
    foreach(big in [false,true]) foreach(winged in [false,true]) {
        local collisionTest=createGame();
        local turtle=makeEnemyAt(100.0,12,"koopa");
        turtle.awake=true;turtle.slot=0;turtle.greenJump <- winged;
        collisionTest.goombas=[turtle];collisionTest.nesFrameCounter=0;
        local mario=collisionTest.player;
        mario.big=big;mario.height=big?32.0:16.0;
        mario.x=100.0;mario.y=big?166.0:182.0;
        mario.nesYSpeed=-5;mario.vy=-5*NES_FRAME_RATE;mario.grounded=false;
        updateGoombas(collisionTest,FIXED_DT);
        requireSelfTest(turtle.state=="walking" &&
            (winged?(!turtle.greenJump && !mario.dead && mario.nesYSpeed==-4):
                (big?(!mario.dead && mario.transformKind=="shrink"):mario.dead)),
            "upward contact must injure Mario on normal Koopas; only a winged Koopa uses the high-position stomp rule");
    }
    foreach(fraction in [0.0,0.5,0.999]) foreach(offset in [11.0,12.0]) {
        local edgeTest=createGame();
        local turtle=makeEnemyAt(100.0+fraction,12,"koopa");
        turtle.awake=true;turtle.slot=0;edgeTest.goombas=[turtle];
        edgeTest.nesFrameCounter=0;
        local mario=edgeTest.player;
        mario.x=100.0+offset;mario.y=180.0;mario.nesYSpeed=4;
        mario.vy=4*NES_FRAME_RATE;mario.grounded=false;
        updateGoombas(edgeTest,FIXED_DT);
        requireSelfTest(!mario.dead &&
            (offset==11.0?(turtle.state=="shell" && mario.nesYSpeed==-4):
                          (turtle.state=="walking" && mario.nesYSpeed==4)),
            "Koopa collision must use integer inclusive edges regardless of half-pixel movement phase");
    }
    foreach(gap in [0.0,1.0]) {
        local edgeTest=createGame();
        local enemy=makeEnemyAt(100.5,12,"goomba");
        enemy.awake=true;enemy.slot=0;edgeTest.goombas=[enemy];edgeTest.nesFrameCounter=0;
        local mario=edgeTest.player;
        mario.x=94.0;mario.y=182.0-gap;mario.nesYSpeed=-5;
        mario.vy=-5*NES_FRAME_RATE;mario.grounded=false;
        updateGoombas(edgeTest,FIXED_DT);
        requireSelfTest(mario.dead==(gap==0.0),
            "Goomba and Mario inclusive vertical edges must touch, while a one-pixel gap must miss");
    }
    local clearMusicTest=createGame();
    clearMusicTest.state="timeBonus";clearMusicTest.time=1;
    clearMusicTest.soundEvents=[];
    updateCourseClear(clearMusicTest,FIXED_DT);
    requireSelfTest(clearMusicTest.state=="timeBonus" && clearMusicTest.time==0 &&
                    clearMusicTest.soundEvents.len()==0,
                    "timer exhaustion must wait for the following star-flag task");
    updateCourseClear(clearMusicTest,FIXED_DT);
    requireSelfTest(clearMusicTest.state=="raiseFlag" && clearMusicTest.soundEvents.len()==0,
                    "castle flag rise must not restart the course-clear music");
    local timerSoundTest=createGame();
    timerSoundTest.state="timeBonus";timerSoundTest.time=2;
    timerSoundTest.nesFrameCounter=4;timerSoundTest.soundEvents=[];
    updateCourseClear(timerSoundTest,FIXED_DT);
    requireSelfTest(timerSoundTest.soundEvents.len()==1 &&
                    timerSoundTest.soundEvents[0]=="timer_tick" && timerSoundTest.time==1,
                    "time conversion must request the runtime timer sound on counter bit 2");
    timerSoundTest.nesFrameCounter=0;timerSoundTest.soundEvents=[];
    updateCourseClear(timerSoundTest,FIXED_DT);
    requireSelfTest(timerSoundTest.soundEvents.len()==0 && timerSoundTest.time==0,
                    "time conversion must skip timer sound when counter bit 2 is clear");
    enterKoopaShell(testKoopa);
    requireSelfTest(testKoopa.state == "shell" && testKoopa.vx == 0.0 &&
                    testKoopa.shellFrames == 16 * 21,
                    "stomped koopa must use the ROM's sixteen interval revive timer");
    shellTest.player.x = testKoopa.x - 20.0;
    kickKoopaShell(shellTest, testKoopa);
    requireSelfTest(testKoopa.state == "shellMoving" && testKoopa.vx > 0.0 &&
                    shellTest.score == 400,
                    "shell kicked from the left must move right and award base kick score");
    stopKoopaShell(testKoopa);
    requireSelfTest(testKoopa.state == "shell" && testKoopa.vx == 0.0,
                    "stomping a moving shell must stop it");
    testKoopa.stateTimer = 0.0;
    reviveKoopa(testKoopa);
    requireSelfTest(testKoopa.state == "walking" && testKoopa.height == 24.0,
                    "stationary shell must revive into a walking koopa");
    enterKoopaShell(testKoopa);
    shellTest.player.x = testKoopa.x - 20.0;
    kickKoopaShell(shellTest, testKoopa);
    testGoomba.x = testKoopa.x;
    testGoomba.y = testKoopa.y;
    updateShellEnemyCollisions(shellTest);
    requireSelfTest(testGoomba.alive && testGoomba.state == "flipped" &&
                    testKoopa.shellChain == 1,
                    "moving shell must launch its victim while advancing the chain");

    local scoreControlTest = createGame();
    scoreControlTest.score = 0;
    scoreControlTest.lives = 3;
    for (local i = 0; i < 10; i += 1) awardStomp(scoreControlTest, testGoomba);
    for (local i = 0; i < 5; i += 1) updateFloatingScores(scoreControlTest);
    requireSelfTest(scoreControlTest.score == 22000 && scoreControlTest.stompChain == 10,
                    "airborne stomp chain must follow 100 through 8000 point controls");
    awardStomp(scoreControlTest, testGoomba);
    for (local i = 0; i < 5; i += 1) updateFloatingScores(scoreControlTest);
    requireSelfTest(scoreControlTest.lives == 4,
                    "eleventh chained stomp must award a one-up");

    foreach (pipeColumn in [46, 57]) {
        foreach (big in [false, true]) {
            local pipeTest = createGame();
            pipeTest.goombas = [];
            pipeTest.player.big = big;
            pipeTest.player.height = big ? 32.0 : 16.0;
            pipeTest.player.x = pipeColumn * TILE_SIZE - pipeTest.player.width;
            pipeTest.player.y = GROUND_ROW * TILE_SIZE - pipeTest.player.height;
            pipeTest.player.grounded = true;
            pipeTest.input.right = true;
            pipeTest.input.run = false;
            pipeTest.input.jumpDown = true;
            pipeTest.input.jumpQueued = true;
            local highestY = pipeTest.player.y;
            simulateFixed(pipeTest, FIXED_DT);
            pipeTest.input.jumpQueued = false;
            for (local i = 0; i < 89; i += 1) {
                simulateFixed(pipeTest, FIXED_DT);
                if (pipeTest.player.y < highestY) highestY = pipeTest.player.y;
            }
            local clearedTop = highestY + pipeTest.player.height <= 9.0 * TILE_SIZE;
            local clearedPipe = pipeTest.player.x > (pipeColumn + 2) * TILE_SIZE;
            local sizeName = big ? "Super Mario" : "small Mario";
            requireSelfTest(clearedTop,
                            sizeName + " must rise above pipe " + pipeColumn);
            requireSelfTest(clearedPipe,
                            sizeName + " must clear pipe " + pipeColumn + " from its base");
        }
    }

    local timerTest = createGame();
    timerTest.goombas = [];
    timerTest.gameTimerControl = 0;
    updateTimer(timerTest);
    requireSelfTest(timerTest.time == 399,
                    "course timer must decrement once per original 24-frame interval");
    timerTest.time=101;timerTest.gameTimerControl=0;timerTest.soundEvents=[];
    updateTimer(timerTest);
    requireSelfTest(timerTest.time==100 && !timerTest.hurryActive && timerTest.soundEvents.len()==0,
                    "hurry must not trigger on 101 to 100");
    timerTest.gameTimerControl=0;updateTimer(timerTest);
    requireSelfTest(timerTest.time==99 && timerTest.hurryActive &&
                    timerTest.soundEvents.len()==1 && timerTest.soundEvents[0]=="hurry",
                    "100 to 99 must trigger the ROM hurry request exactly once");
    timerTest.gameTimerControl=0;updateTimer(timerTest);
    requireSelfTest(timerTest.soundEvents.len()==1,"hurry must not repeat below 100");
    timerTest.lives = 1;
    finishPlayerDeath(timerTest);
    requireSelfTest(timerTest.state == "deathReload" && timerTest.lives == 1,
                    "PlayerLoseLife selection must precede the life decrement");
    updateDeathReload(timerTest);
    requireSelfTest(timerTest.state == "gameOver" && timerTest.lives == 0,
                    "last life must enter Game Over on the following mode-task frame");

    local checkpointTest = createGame();
    checkpointTest.player.x = 5.0 * 256.0 + 120.0;
    checkpointTest.cameraX = 5.0 * 256.0;
    updateCamera(checkpointTest);
    resetRound(checkpointTest);
    requireSelfTest(checkpointTest.checkpointPage == 5 &&
                    checkpointTest.player.x == 5.0 * 256.0 + 32.0,
                    "World 1-1 deaths after page five must use the ROM halfway page");

    requireSelfTest(createGame().flagY == 48.0,
                    "flagpole flag must start at the ROM $30 Y position");
    local scoreCases = [[39.0, 5000], [50.0, 2000], [96.0, 800],
                        [120.0, 400], [160.0, 100]];
    foreach (scoreCase in scoreCases) {
        local scoreTest = createGame();
        scoreTest.player.y = scoreCase[0];
        beginFlagSequence(scoreTest);
        requireSelfTest(scoreTest.flagScoreAward == scoreCase[1],
                        "flagpole score must follow FlagpoleYPosData");
    }

    local clearTest = createGame();
    clearTest.goombas = [];
    clearTest.time = 1;
    clearTest.player.y = 39.0;
    beginFlagSequence(clearTest);
    requireSelfTest(clearTest.state == "flagSlide" &&
                    clearTest.fireworksRemaining == 1 &&
                    clearTest.fireworksOffsetState == 5,
                    "flag sequence must derive fireworks and offset from the timer digit");
    clearTest.player.playerAnimTimer = 0;
    clearTest.player.playerAnimCtrl = 0;
    clearTest.player.nesYSpeed = 1;
    updatePlayerAnimationState(clearTest);
    requireSelfTest(clearTest.player.animationFrame == -5 &&
                    clearTest.player.playerAnimTimer == 4 &&
                    clearTest.player.playerAnimCtrl == 1,
                    "flag slide must start ROM climbing frame one with downward timer reload four");
    clearTest.player.playerAnimTimer = 0;
    updatePlayerAnimationState(clearTest);
    requireSelfTest(clearTest.player.animationFrame == -6 &&
                    clearTest.player.playerAnimCtrl == 0,
                    "flag slide must alternate both ROM climbing frames");
    clearTest.state = "endLevel";
    clearTest.player.endLevelClimbing = false;
    clearTest.player.grounded = true;
    clearTest.player.nesXSpeed = 1;
    clearTest.player.playerAnimTimer = 0;
    clearTest.player.playerAnimCtrl = 0;
    updatePlayerAnimationState(clearTest);
    clearTest.player.playerAnimTimer = 0;
    updatePlayerAnimationState(clearTest);
    requireSelfTest(clearTest.player.animationFrame == 1 &&
                    clearTest.player.playerAnimCtrl == 2,
                    "PlayerEndLevel automatic walk must advance the ROM walking cycle");
    local lowFlagTest = createGame();
    lowFlagTest.goombas = [];
    lowFlagTest.player.y = 150.0;
    beginFlagSequence(lowFlagTest);
    for (local i = 0; i < 64; i += 1)
        updateCourseClear(lowFlagTest, FIXED_DT);
    requireSelfTest(lowFlagTest.flagY == 171.0 &&
                    lowFlagTest.state == "endLevel" &&
                    lowFlagTest.player.endLevelClimbing,
                    "high flag grab must enter PlayerEndLevel after the flag bottom stop");
    local castleCollisionTest = createGame();
    castleCollisionTest.goombas = [];
    castleCollisionTest.state = "endLevel";
    castleCollisionTest.player.x = castleCollisionTest.castleX + 34.0;
    // Internal small-Mario Y is the ROM Y plus the 16px sprite offset.
    castleCollisionTest.player.y = 192.0;
    castleCollisionTest.player.grounded = true;
    castleCollisionTest.player.endLevelClimbing = false;
    castleCollisionTest.player.nesXSpeed = 24;
    castleCollisionTest.player.nesXSpeedAbsolute = 24;
    castleCollisionTest.player.nesXForce = 232;
    castleCollisionTest.player.nesXMoveForce = 192;
    updateCourseClear(castleCollisionTest, FIXED_DT);
    requireSelfTest(castleCollisionTest.state == "timeBonus" &&
                    castleCollisionTest.player.x == castleCollisionTest.castleX + 35.0 &&
                    castleCollisionTest.player.nesXSpeed == 0 &&
                    (castleCollisionTest.player.collisionBits & 0x01) == 0,
                    "castle doorway must use ImpedePlayerMove and the right collision bit");
    updateCourseClear(castleCollisionTest, FIXED_DT);
    requireSelfTest(castleCollisionTest.player.x == castleCollisionTest.castleX + 34.0 &&
                    castleCollisionTest.player.nesXSpeed == 0,
                    "a blocked PlayerEndLevel pass must retain the doorway position");
    updateCourseClear(castleCollisionTest, FIXED_DT);
    requireSelfTest(castleCollisionTest.player.collisionBits == 0xFF,
                    "castle collision permissions must recover after clear side probes");
    clearTest.state = "autoWalk";
    clearTest.score = clearTest.flagScoreAward;
    clearTest.player.x = clearTest.castleX + 35.0;
    updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.state == "timeBonus",
                    "automatic castle walk must lead into time-score conversion");
    updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.time == 0 && clearTest.score == 5050 &&
                    clearTest.state == "timeBonus",
                    "remaining time must convert by one unit and fifty points per frame");
    updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.state == "raiseFlag",
                    "exhausted time must advance StarFlagTaskControl next frame");
    for (local i = 0; i < 31; i += 1) updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.castleFlagY == 113.0 && clearTest.state == "raiseFlag",
                    "castle star flag must rise from $90 through $72 one pixel per frame");
    updateCourseClear(clearTest, FIXED_DT);
    updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.state == "fireworks" &&
                    clearTest.fireworksRemaining == 0 && clearTest.fireworks.len() == 1 &&
                    clearTest.fireworks[0].x == clearTest.castleX + 16.0 &&
                    clearTest.fireworks[0].y == 48.0 &&
                    clearTest.fireworks[0].frames == 24,
                    "one-firework ending must use ROM position index five");
    for (local i = 0; i < 24; i += 1) updateFireworks(clearTest, FIXED_DT);
    requireSelfTest(clearTest.fireworks.len() == 0 && clearTest.score == 5550,
                    "a three-frame firework must last 24 frames and award 500 points");
    updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.state == "postClearDelay" &&
                    clearTest.clearDelayFrames == 126,
                    "finished fireworks must start the six-interval end delay");
    for (local i = 0; i < 126; i += 1) updateCourseClear(clearTest, FIXED_DT);
    requireSelfTest(clearTest.state == "levelComplete",
                    "six interval timers must complete the World 1-1 clear flow");

    local fireworkOrderTest = createGame();
    fireworkOrderTest.state = "fireworks";
    fireworkOrderTest.fireworksRemaining = 1;
    fireworkOrderTest.fireworksOffsetState = 5;
    simulateFixed(fireworkOrderTest, FIXED_DT);
    requireSelfTest(fireworkOrderTest.fireworks.len() == 1 &&
                    fireworkOrderTest.fireworks[0].frames == 24,
                    "new fireworks must not lose a rendered frame on their spawn tick");

    print("World 1-1 simulation self-test passed.\n");
}

function runPowerUpStatusSelfTest() {
    foreach(kind in ["mushroom","flower"]) {
        for(local status=0;status<3;status+=1) {
            local g=createGame(),p=g.player;
            p.big=status>0;p.fire=status==2;p.height=p.big?32.0:16.0;
            p.y=208.0-p.height;
            p.transformFrames=status==2?7:0;
            p.transformKind=status==2?"fire":"grow";
            spawnPowerUp(g,21,9,kind);
            collectPowerUp(g,g.powerups[0]);
            requireSelfTest(p.big && p.height==32 && p.y+p.height==208,
                            "power-up must grow once while preserving the player's feet");
            requireSelfTest(p.fire==(status>0),
                            "a small player must not gain fire from an existing flower");
            requireSelfTest(p.transformFrames==(status==0?40:(status==1?63:7)),
                            "pickup must use one growth/fire transition and not restart Fire Mario");
            requireSelfTest(g.score==1000 && !g.powerups[0].active,
                            "each power-up must be consumed and scored exactly once");
        }
    }
}

function runKoopaRevivalSelfTest() {
    for(local counter=0;counter<16;counter+=1) {
        requireSelfTest(koopaShellAnimationFrame("shell",16,counter)==0 &&
                        koopaShellAnimationFrame("shell",5,counter)==0,
                        "a fresh shell must keep its feet hidden at every animation phase");
        requireSelfTest(koopaShellAnimationFrame("shellMoving",1,counter)==0,
                        "a moving shell must never show the revival feet");
        requireSelfTest(koopaShellAnimationFrame("shell",4,counter)==((counter&8)==0?1:0),
                        "only the last four interval ticks may alternate the shell warning");
    }
    foreach(phase in [0,20]) {
        local g=createGame();
        local enemy=makeEnemy(20,12,"koopa");
        enemy.awake=true;enemy.slot=0;
        g.goombas=[enemy];g.intervalTimerControl=phase;
        enterKoopaShell(enemy);
        local lifetime=phase+1+15*NES_INTERVAL_FRAMES;
        local sawWarning=false;
        for(local frame=1;frame<lifetime;frame+=1) {
            simulateFixed(g,FIXED_DT);
            requireSelfTest(enemy.state=="shell","shell must wait for the shared interval bank");
            if(enemy.intervalTimer>=5)
                requireSelfTest(enemy.displayShellFrame==0 && enemy.queuedShellFrame==0,
                                "shell must not expose feet before its revival warning window");
            if(enemy.displayShellFrame==1) sawWarning=true;
        }
        requireSelfTest(sawWarning,"stationary shell must warn before revival");
        simulateFixed(g,FIXED_DT);
        requireSelfTest(enemy.state=="walking" && enemy.height==24 && enemy.intervalTimer==0,
                        "shell revival must occur on the shared interval expiry");
    }
}
