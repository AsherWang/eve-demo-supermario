LOGICAL_WIDTH <- 256;
LOGICAL_HEIGHT <- 240;
PIXEL_SCALE <- 3;
TILE_SIZE <- 16;
LEVEL_WIDTH <- 212;
LEVEL_HEIGHT <- 15;
GROUND_ROW <- 13;
// SMB advances gameplay from the NTSC NMI, not a nominal 60.000 Hz clock.
NES_FRAME_RATE <- 60.0988;
FIXED_DT <- 1.0 / NES_FRAME_RATE;
NES_INTERVAL_FRAMES <- 21;
MAX_STEPS_PER_FRAME <- 8;
PI <- 3.1415926536;
KOOPA_WALK_SPEED <- NES_FRAME_RATE * 0.5;
KOOPA_SHELL_SPEED <- NES_FRAME_RATE * 3.0;
KOOPA_REVIVE_FRAMES <- 16 * 21;
STAR_INVINCIBLE_TIME <- 0x23 * NES_INTERVAL_FRAMES * FIXED_DT;
BRICK_COIN_TIME <- 0x0B * NES_INTERVAL_FRAMES * FIXED_DT;
FIREBALL_SPEED <- NES_FRAME_RATE * 4.0;
// DrawPowerUp adds eight pixels before writing OAM; the NES PPU displays a
// sprite one scanline below its OAM Y value.
POWERUP_DRAW_Y_OFFSET <- 9.0;

TILE_EMPTY <- 0;
TILE_GROUND <- 1;
TILE_BRICK <- 2;
TILE_QUESTION <- 3;
TILE_USED <- 4;
TILE_PIPE_TOP_LEFT <- 5;
TILE_PIPE_TOP_RIGHT <- 6;
TILE_PIPE_SHAFT_LEFT <- 7;
TILE_PIPE_SHAFT_RIGHT <- 8;
TILE_POWERUP_BLOCK <- 9;
TILE_HIDDEN_ONEUP <- 10;
TILE_BRICK_COIN <- 11;
TILE_BRICK_STAR <- 12;
TILE_SOLID <- 13;
TILE_SIDE_PIPE_TOP_END <- 14;
TILE_SIDE_PIPE_TOP_SHAFT <- 15;
TILE_SIDE_PIPE_TOP_JOINT <- 16;
TILE_SIDE_PIPE_BOTTOM_END <- 17;
TILE_SIDE_PIPE_BOTTOM_SHAFT <- 18;
TILE_SIDE_PIPE_BOTTOM_JOINT <- 19;
TILE_BRICK_POWERUP <- 20;
TILE_BRICK_ONEUP <- 21;
TILE_HIDDEN_COIN <- 22;
TILE_BRICK_VINE <- 23;

function clampValue(value, minimum, maximum) {
    if (value < minimum) return minimum;
    if (value > maximum) return maximum;
    return value;
}

function approachValue(value, target, amount) {
    if (value < target) {
        value += amount;
        if (value > target) value = target;
    } else if (value > target) {
        value -= amount;
        if (value < target) value = target;
    }
    return value;
}

function overlaps(ax, ay, aw, ah, bx, by, bw, bh) {
    return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;
}

function tileIndex(tx, ty) {
    return ty * LEVEL_WIDTH + tx;
}

function getTile(g, tx, ty) {
    if (tx < 0) return TILE_GROUND;
    if (tx >= g.areaWidth || ty < 0 || ty >= LEVEL_HEIGHT) return TILE_EMPTY;
    return g.tiles[tileIndex(tx, ty)];
}

function setTile(g, tx, ty, value) {
    if (tx < 0 || tx >= g.areaWidth || ty < 0 || ty >= LEVEL_HEIGHT) return;
    g.tiles[tileIndex(tx, ty)] = value;
}

function isSolidTile(value) {
    return value == TILE_GROUND || value == TILE_SOLID || value == TILE_BRICK ||
           value == TILE_BRICK_POWERUP || value == TILE_BRICK_ONEUP || value == TILE_BRICK_VINE ||
           value == TILE_BRICK_COIN || value == TILE_BRICK_STAR ||
           value == TILE_QUESTION || value == TILE_POWERUP_BLOCK ||
           value == TILE_USED ||
           value == TILE_PIPE_TOP_LEFT || value == TILE_PIPE_TOP_RIGHT ||
           value == TILE_PIPE_SHAFT_LEFT || value == TILE_PIPE_SHAFT_RIGHT ||
           value == TILE_SIDE_PIPE_TOP_END || value == TILE_SIDE_PIPE_TOP_SHAFT ||
           value == TILE_SIDE_PIPE_TOP_JOINT || value == TILE_SIDE_PIPE_BOTTOM_END ||
           value == TILE_SIDE_PIPE_BOTTOM_SHAFT || value == TILE_SIDE_PIPE_BOTTOM_JOINT;
}

function isSolidAt(g, tx, ty) {
    return isSolidTile(getTile(g, tx, ty));
}
