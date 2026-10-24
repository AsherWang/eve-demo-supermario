function _advancePowerUpEmergence(g, item, untilFrame) {
    while (item.emergeFrame < untilFrame) movePowerUp(g, item, FIXED_DT);
}

function _powerUpFirstFallFrame(g, item, limit) {
    local restingY = item.y;
    for (local frame = 1; frame <= limit; frame += 1) {
        movePowerUp(g, item, FIXED_DT);
        if (item.y > restingY + 0.001) return frame;
    }
    return -1;
}

function runPowerUpGapSelfTest() {
    // World 1-2 has a 1-UP brick at column 89 in its top brick row. Removing
    // column 90 while the item rises creates a one-tile hole beside its source.
    local gap = createGame();
    startWorld12(gap, "underground");
    gap.goombas = [];
    gap.player.x = 0.0;
    gap.player.y = 0.0;
    requireSelfTest(getTile(gap, 89, 2) == TILE_BRICK_ONEUP &&
                    getTile(gap, 90, 2) == TILE_BRICK,
                    "World 1-2 regression requires the real 1-UP brick and its right neighbour");
    hitBlock(gap, 89, 2);
    requireSelfTest(gap.powerups.len() == 1 &&
                    gap.powerups[0].kind == "oneup",
                    "World 1-2 1-UP brick must reveal its ordinary one-up object");
    local oneUp = gap.powerups[0];
    _advancePowerUpEmergence(gap, oneUp, 34);
    requireSelfTest(oneUp.emerging,
                    "the adjacent brick must be removed during the real one-up emergence");
    breakBrick(gap, 90, 2);
    requireSelfTest(getTile(gap, 90, 2) == TILE_EMPTY,
                    "the removed right-hand brick must expose a one-tile hole");
    _advancePowerUpEmergence(gap, oneUp, 68);
    requireSelfTest(!oneUp.emerging &&
                    oneUp.y == oneUp.romY + POWERUP_DRAW_Y_OFFSET,
                    "emergence must convert the ROM Y coordinate to the host sprite Y");

    // One pixel per ROM frame puts the bottom-centre sample over column 90
    // on the eighth post-emergence pass. The one-up must begin falling then;
    // either sprite corner still overlaps the solid source block at that time.
    local firstFallFrame = _powerUpFirstFallFrame(gap, oneUp, 32);
    requireSelfTest(firstFallFrame > 0 && firstFallFrame <= 8,
                    "the one-up must fall when its centre loses the source-block support");
    requireSelfTest(gap.powerups[0].x < 90.0 * TILE_SIZE,
                    "the one-up must begin falling into column 90 instead of crossing the hole");

    // The ordinary mushroom follows the same centre-support path.
    local mushroom = createGame();
    startWorld12(mushroom, "underground");
    mushroom.goombas = [];
    mushroom.player.x = 0.0;
    mushroom.player.y = 0.0;
    requireSelfTest(getTile(mushroom, 150, 8) == TILE_BRICK_POWERUP &&
                    getTile(mushroom, 151, 8) == TILE_EMPTY,
                    "World 1-2 regression requires its real mushroom brick and open right side");
    hitBlock(mushroom, 150, 8);
    requireSelfTest(mushroom.powerups.len() == 1 &&
                    mushroom.powerups[0].kind == "mushroom",
                    "small Mario must receive the ordinary mushroom");
    local shroom = mushroom.powerups[0];
    _advancePowerUpEmergence(mushroom, shroom, 68);
    requireSelfTest(!shroom.emerging,
                    "ordinary mushroom must complete its actual emergence");
    requireSelfTest(_powerUpFirstFallFrame(mushroom, shroom, 32) > 0,
                    "ordinary mushroom must fall once its centre leaves the source block");

    // Keep the right brick in place as the control. The mushroom remains on
    // the real brick row while walking both right and left over solid support.
    local solid = createGame();
    startWorld12(solid, "underground");
    solid.goombas = [];
    solid.player.x = 0.0;
    solid.player.y = 0.0;
    hitBlock(solid, 89, 2);
    local walker = solid.powerups[0];
    _advancePowerUpEmergence(solid, walker, 68);
    local supportedY = walker.y;
    for (local frame = 0; frame < 20; frame += 1)
        movePowerUp(solid, walker, FIXED_DT);
    requireSelfTest(walker.y == supportedY && walker.vx > 0.0,
                    "a mushroom center over the intact right brick must stay supported");
    local rightX = walker.x;
    walker.vx = -NES_FRAME_RATE;
    for (local frame = 0; frame < 20; frame += 1)
        movePowerUp(solid, walker, FIXED_DT);
    requireSelfTest(walker.y == supportedY && walker.x < rightX,
                    "left traversal over solid bricks must retain floor support");

    print("Power-up gap self-test passed.\n");
}
