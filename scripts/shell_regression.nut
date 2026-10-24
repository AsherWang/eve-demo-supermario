function shellRegressionEnemy(x, slot, kind, state) {
    local enemy = makeEnemyAt(x, GROUND_ROW, kind);
    enemy.awake = true;
    enemy.alive = true;
    enemy.slot = slot;
    enemy.state = state;
    enemy.queuedState = state;
    enemy.preparedState = state;
    enemy.displayState = state;
    if (state == "shellMoving") {
        enemy.height = 14.0;
        enemy.y = (GROUND_ROW + 1) * TILE_SIZE.tofloat() - enemy.height;
        enemy.vx = KOOPA_SHELL_SPEED;
        enemy.shellDirection = 1;
    }
    return enemy;
}

function shellRegressionGame() {
    local g = createGame();
    g.goombas = [];
    g.cameraX = 0.0;
    g.displayCameraX = 0.0;
    g.score = 0;
    g.queuedScore = 0;
    g.nesFrameCounter = 0;
    g.soundEvents = [];
    g.player.x = 0.0;
    g.player.y = 0.0;
    g.player.vx = 0.0;
    g.player.vy = 0.0;
    g.player.dead = false;
    return g;
}

function runShellDefeatSelfTest() {
    local g = shellRegressionGame();
    local shell = shellRegressionEnemy(120.0, 0, "koopa", "shellMoving");
    local goomba = shellRegressionEnemy(
        120.0, 1, "goomba", "walking");
    goomba.y = shell.y;
    g.goombas = [shell, goomba];

    local startY = goomba.y;
    simulateFixed(g, FIXED_DT);
    requireSelfTest(goomba.alive && goomba.kind == "goomba" &&
                    goomba.state == "flipped" && goomba.vy < 0.0 &&
                    goomba.y == startY - 2.0,
                    "shell defeat must retain and launch a goomba with the ROM two-pixel stun offset");
    requireSelfTest(shell.shellChain == 1 && g.score == 500,
                    "first moving-shell victim must advance the chain and award score control 4");
    requireSelfTest(g.soundEvents.len() == 1 && g.soundEvents[0] == "kick",
                    "shell defeat must request the original enemy-smack sound");

    local rose = false;
    local fell = false;
    local reachedFlippedDisplay = false;
    local previousY = goomba.y;
    for (local frame = 0; frame < 180 && goomba.alive; frame += 1) {
        simulateFixed(g, FIXED_DT);
        if (goomba.y < previousY) rose = true;
        if (rose && goomba.y > previousY) fell = true;
        if (goomba.alive && goomba.displayState == "flipped")
            reachedFlippedDisplay = true;
        previousY = goomba.y;
    }
    requireSelfTest(rose && fell && reachedFlippedDisplay,
                    "defeated shell victim must remain live and visibly flip through an upward then downward arc");
    requireSelfTest(!goomba.alive && goomba.y > LOGICAL_HEIGHT + 32.0,
                    "defeated shell victim must disappear only after its airborne path reaches past the lower bound");

    local koopaGame = shellRegressionGame();
    local koopaShell = shellRegressionEnemy(180.0, 0, "koopa", "shellMoving");
    local walkingKoopa = shellRegressionEnemy(180.0, 1, "koopa", "walking");
    walkingKoopa.y = koopaShell.y;
    koopaGame.goombas = [koopaShell, walkingKoopa];
    simulateFixed(koopaGame, FIXED_DT);
    requireSelfTest(walkingKoopa.alive && walkingKoopa.kind == "koopa" &&
                    walkingKoopa.state == "flipped" && walkingKoopa.vy < 0.0,
                    "moving shell must launch a normal koopa without changing its type");

    local chainGame = shellRegressionGame();
    local chainShell = shellRegressionEnemy(240.0, 0, "koopa", "shellMoving");
    local firstVictim = shellRegressionEnemy(240.0, 1, "goomba", "walking");
    local secondVictim = shellRegressionEnemy(240.0, 2, "goomba", "walking");
    firstVictim.y = chainShell.y;
    secondVictim.y = chainShell.y;
    chainGame.goombas = [chainShell];
    updateShellEnemyCollisions(chainGame);
    requireSelfTest(chainShell.shellChain == 0 && chainGame.score == 0,
                    "a shell with no overlapping victim must not advance its chain");
    chainGame.goombas = [chainShell, firstVictim];
    updateShellEnemyCollisions(chainGame);
    chainGame.goombas = [chainShell, firstVictim, secondVictim];
    updateShellEnemyCollisions(chainGame);
    requireSelfTest(firstVictim.alive && secondVictim.alive &&
                    firstVictim.state == "flipped" && secondVictim.state == "flipped" &&
                    chainShell.shellChain == 2 && chainGame.score == 1300,
                    "moving-shell chain must retain both victims and award score controls 4 then 5");

    local shellPairGame = shellRegressionGame();
    local secondShell = shellRegressionEnemy(
        300.0, 0, "koopa", "shellMoving");
    local firstShell = shellRegressionEnemy(
        300.0, 1, "koopa", "shellMoving");
    secondShell.vx = -KOOPA_SHELL_SPEED;
    firstShell.vx = KOOPA_SHELL_SPEED;
    shellPairGame.goombas = [secondShell, firstShell];
    updateShellEnemyCollisions(shellPairGame);
    requireSelfTest(firstShell.alive && secondShell.alive &&
                    firstShell.state == "flipped" &&
                    secondShell.state == "flipped" &&
                    firstShell.vy < 0.0 && secondShell.vy < 0.0,
                    "two moving shells must retain and launch both shell victims");
    requireSelfTest(firstShell.shellChain == 1 &&
                    secondShell.shellChain == 0 &&
                    shellPairGame.score == 700,
                    "two-shell collision must keep the first shell's 200-point type score and the second shell's score-control-4 chain score; the transient control 6 must not award");
    requireSelfTest(shellPairGame.soundEvents.len() == 1 &&
                    shellPairGame.soundEvents[0] == "kick",
                    "two-shell defeat must leave one final enemy-smack sound request");
}
