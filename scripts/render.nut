function loadTexture(path) {
    return gfx.newTextureFromFile(path);
}

function loadSmallMarioSet(path) {
    return {
        standRight = loadTexture(path + "/stand-right.png"),
        standLeft = loadTexture(path + "/stand-left.png"),
        walkRight = [
            loadTexture(path + "/walk-1-right.png"),
            loadTexture(path + "/walk-2-right.png"),
            loadTexture(path + "/walk-3-right.png")
        ],
        walkLeft = [
            loadTexture(path + "/walk-1-left.png"),
            loadTexture(path + "/walk-2-left.png"),
            loadTexture(path + "/walk-3-left.png")
        ],
        jumpRight = loadTexture(path + "/jump-right.png"),
        jumpLeft = loadTexture(path + "/jump-left.png"),
        skidRight = loadTexture(path + "/skid-right.png"),
        skidLeft = loadTexture(path + "/skid-left.png")
    };
}

function loadBigMarioSet(path) {
    local result = loadSmallMarioSet(path);
    result.crouchRight <- loadTexture(path + "/crouch-right.png");
    result.crouchLeft <- loadTexture(path + "/crouch-left.png");
    return result;
}

function loadAssets() {
    if (assets != null) return;

    assets = {
        tiles = {
            ground = loadTexture("assets/tiles/ground.png"),
            solid = loadTexture("assets/tiles/solid.png"),
            brick = loadTexture("assets/tiles/brick.png"),
            question = loadTexture("assets/tiles/question.png"),
            questions = [
                loadTexture("assets/tiles/question-0.png"),
                loadTexture("assets/tiles/question-1.png"),
                loadTexture("assets/tiles/question-2.png"),
                loadTexture("assets/tiles/question-3.png"),
                loadTexture("assets/tiles/question-4.png"),
                loadTexture("assets/tiles/question-5.png")
            ],
            used = loadTexture("assets/tiles/used.png"),
            pipeTopLeft = loadTexture("assets/tiles/pipe-top-left.png"),
            pipeTopRight = loadTexture("assets/tiles/pipe-top-right.png"),
            pipeShaftLeft = loadTexture("assets/tiles/pipe-shaft-left.png"),
            pipeShaftRight = loadTexture("assets/tiles/pipe-shaft-right.png"),
            undergroundBrick = loadTexture("assets/tiles/underground-brick.png"),
            sidePipeTopEnd = loadTexture("assets/tiles/side-pipe-top-end.png"),
            sidePipeTopShaft = loadTexture("assets/tiles/side-pipe-top-shaft.png"),
            sidePipeTopJoint = loadTexture("assets/tiles/side-pipe-top-joint.png"),
            sidePipeBottomEnd = loadTexture("assets/tiles/side-pipe-bottom-end.png"),
            sidePipeBottomShaft = loadTexture("assets/tiles/side-pipe-bottom-shaft.png"),
            sidePipeBottomJoint = loadTexture("assets/tiles/side-pipe-bottom-joint.png")
        },
        mario = {
            standRight = loadTexture("assets/mario/stand-right.png"),
            standLeft = loadTexture("assets/mario/stand-left.png"),
            walkRight = [
                loadTexture("assets/mario/walk-1-right.png"),
                loadTexture("assets/mario/walk-2-right.png"),
                loadTexture("assets/mario/walk-3-right.png")
            ],
            walkLeft = [
                loadTexture("assets/mario/walk-1-left.png"),
                loadTexture("assets/mario/walk-2-left.png"),
                loadTexture("assets/mario/walk-3-left.png")
            ],
            jumpRight = loadTexture("assets/mario/jump-right.png"),
            jumpLeft = loadTexture("assets/mario/jump-left.png"),
            skidRight = loadTexture("assets/mario/skid-right.png"),
            skidLeft = loadTexture("assets/mario/skid-left.png"),
            deadRight = loadTexture("assets/mario/dead-right.png"),
            deadLeft = loadTexture("assets/mario/dead-left.png")
        },
        marioBig = {
            standRight = loadTexture("assets/mario-big/stand-right.png"),
            standLeft = loadTexture("assets/mario-big/stand-left.png"),
            walkRight = [
                loadTexture("assets/mario-big/walk-1-right.png"),
                loadTexture("assets/mario-big/walk-2-right.png"),
                loadTexture("assets/mario-big/walk-3-right.png")
            ],
            walkLeft = [
                loadTexture("assets/mario-big/walk-1-left.png"),
                loadTexture("assets/mario-big/walk-2-left.png"),
                loadTexture("assets/mario-big/walk-3-left.png")
            ],
            jumpRight = loadTexture("assets/mario-big/jump-right.png"),
            jumpLeft = loadTexture("assets/mario-big/jump-left.png"),
            crouchRight = loadTexture("assets/mario-big/crouch-right.png"),
            crouchLeft = loadTexture("assets/mario-big/crouch-left.png"),
            skidRight = loadTexture("assets/mario-big/skid-right.png"),
            skidLeft = loadTexture("assets/mario-big/skid-left.png")
        },
        marioFire = {
            standRight = loadTexture("assets/mario-fire/stand-right.png"),
            standLeft = loadTexture("assets/mario-fire/stand-left.png"),
            walkRight = [
                loadTexture("assets/mario-fire/walk-1-right.png"),
                loadTexture("assets/mario-fire/walk-2-right.png"),
                loadTexture("assets/mario-fire/walk-3-right.png")
            ],
            walkLeft = [
                loadTexture("assets/mario-fire/walk-1-left.png"),
                loadTexture("assets/mario-fire/walk-2-left.png"),
                loadTexture("assets/mario-fire/walk-3-left.png")
            ],
            jumpRight = loadTexture("assets/mario-fire/jump-right.png"),
            jumpLeft = loadTexture("assets/mario-fire/jump-left.png"),
            crouchRight = loadTexture("assets/mario-fire/crouch-right.png"),
            crouchLeft = loadTexture("assets/mario-fire/crouch-left.png"),
            skidRight = loadTexture("assets/mario-fire/skid-right.png"),
            skidLeft = loadTexture("assets/mario-fire/skid-left.png"),
            throwRight = loadTexture("assets/mario-fire/fireball-right.png"),
            throwLeft = loadTexture("assets/mario-fire/fireball-left.png")
        },
        enemies = {
            goomba = loadTexture("assets/enemies/goomba.png"),
            goombaDefeated = loadTexture("assets/enemies/goomba-defeated.png"),
            koopaRight = [
                loadTexture("assets/enemies/green-koopa-1-right.png"),
                loadTexture("assets/enemies/green-koopa-2-right.png")
            ],
            koopaLeft = [
                loadTexture("assets/enemies/green-koopa-1-left.png"),
                loadTexture("assets/enemies/green-koopa-2-left.png")
            ],
            greenShell = [
                loadTexture("assets/enemies/green-shell-1.png"),
                loadTexture("assets/enemies/green-shell-2.png")
            ]
        },
        items = {
            coin = loadTexture("assets/items/coin.png"),
            jumpCoins = [
                loadTexture("assets/items/jump-coin-0.png"),
                loadTexture("assets/items/jump-coin-1.png"),
                loadTexture("assets/items/jump-coin-2.png"),
                loadTexture("assets/items/jump-coin-3.png")
            ],
            mushroom = loadTexture("assets/items/mushroom.png"),
            flower = loadTexture("assets/items/fire-flower.png"),
            oneUp = loadTexture("assets/items/one-up.png"),
            star = loadTexture("assets/items/star.png"),
            fireballs = [
                loadTexture("assets/items/fireball-1.png"),
                loadTexture("assets/items/fireball-2.png")
            ],
            fireballExplosions = [
                loadTexture("assets/items/fireball-explosion-1.png"),
                loadTexture("assets/items/fireball-explosion-2.png"),
                loadTexture("assets/items/fireball-explosion-3.png")
            ],
            brickFragment = loadTexture("assets/items/brick-fragment.png"),
            undergroundCoins = [
                loadTexture("assets/items/underground-coin-0.png"),
                loadTexture("assets/items/underground-coin-1.png"),
                loadTexture("assets/items/underground-coin-2.png"),
                loadTexture("assets/items/underground-coin-3.png"),
                loadTexture("assets/items/underground-coin-4.png"),
                loadTexture("assets/items/underground-coin-5.png")
            ]
        },
        hudFont = [
            loadTexture("assets/hud-font/00.png"),
            loadTexture("assets/hud-font/01.png"),
            loadTexture("assets/hud-font/02.png"),
            loadTexture("assets/hud-font/03.png"),
            loadTexture("assets/hud-font/04.png"),
            loadTexture("assets/hud-font/05.png"),
            loadTexture("assets/hud-font/06.png"),
            loadTexture("assets/hud-font/07.png"),
            loadTexture("assets/hud-font/08.png"),
            loadTexture("assets/hud-font/09.png"),
            loadTexture("assets/hud-font/0A.png"),
            loadTexture("assets/hud-font/0B.png"),
            loadTexture("assets/hud-font/0C.png"),
            loadTexture("assets/hud-font/0D.png"),
            loadTexture("assets/hud-font/0E.png"),
            loadTexture("assets/hud-font/0F.png"),
            loadTexture("assets/hud-font/10.png"),
            loadTexture("assets/hud-font/11.png"),
            loadTexture("assets/hud-font/12.png"),
            loadTexture("assets/hud-font/13.png"),
            loadTexture("assets/hud-font/14.png"),
            loadTexture("assets/hud-font/15.png"),
            loadTexture("assets/hud-font/16.png"),
            loadTexture("assets/hud-font/17.png"),
            loadTexture("assets/hud-font/18.png"),
            loadTexture("assets/hud-font/19.png"),
            loadTexture("assets/hud-font/1A.png"),
            loadTexture("assets/hud-font/1B.png"),
            loadTexture("assets/hud-font/1C.png"),
            loadTexture("assets/hud-font/1D.png"),
            loadTexture("assets/hud-font/1E.png"),
            loadTexture("assets/hud-font/1F.png"),
            loadTexture("assets/hud-font/20.png"),
            loadTexture("assets/hud-font/21.png"),
            loadTexture("assets/hud-font/22.png"),
            loadTexture("assets/hud-font/23.png"),
            loadTexture("assets/hud-font/24.png"),
            loadTexture("assets/hud-font/25.png"),
            loadTexture("assets/hud-font/26.png"),
            loadTexture("assets/hud-font/27.png"),
            loadTexture("assets/hud-font/28.png"),
            loadTexture("assets/hud-font/29.png"),
            loadTexture("assets/hud-font/2A.png"),
            loadTexture("assets/hud-font/2B.png"),
            loadTexture("assets/hud-font/2C.png"),
            loadTexture("assets/hud-font/2D.png"),
            loadTexture("assets/hud-font/2E.png")
        ],
        scenery = {
            bushLeft = loadTexture("assets/scenery/bush-left.png"),
            bushMiddle = loadTexture("assets/scenery/bush-middle.png"),
            bushRight = loadTexture("assets/scenery/bush-right.png"),
            hillLeft = loadTexture("assets/scenery/hill-left.png"),
            hillLeftBottom = loadTexture("assets/scenery/hill-left-bottom.png"),
            hillMiddleTop = loadTexture("assets/scenery/hill-middle-top.png"),
            hillMiddleBottom = loadTexture("assets/scenery/hill-middle-bottom.png"),
            hillRight = loadTexture("assets/scenery/hill-right.png"),
            hillRightBottom = loadTexture("assets/scenery/hill-right-bottom.png"),
            cloudLeft = loadTexture("assets/scenery/cloud-left.png"),
            cloudMiddle = loadTexture("assets/scenery/cloud-middle.png"),
            cloudRight = loadTexture("assets/scenery/cloud-right.png"),
            cloudBottomLeft = loadTexture("assets/scenery/cloud-bottom-left.png"),
            cloudBottomMiddle = loadTexture("assets/scenery/cloud-bottom-middle.png"),
            cloudBottomRight = loadTexture("assets/scenery/cloud-bottom-right.png"),
            flagBall = loadTexture("assets/scenery/flag-ball.png"),
            flagShaft = loadTexture("assets/scenery/flag-shaft.png"),
            flagpoleFlag = loadTexture("assets/scenery/flagpole-flag.png"),
            castleFlag = loadTexture("assets/scenery/castle-flag.png"),
            castleTop = loadTexture("assets/scenery/castle-top.png"),
            castleTopBrick = loadTexture("assets/scenery/castle-top-brick.png"),
            castleWall = loadTexture("assets/scenery/castle-wall.png"),
            castleWindowLeft = loadTexture("assets/scenery/castle-window-left.png"),
            castleWindowRight = loadTexture("assets/scenery/castle-window-right.png"),
            castleEntranceTop = loadTexture("assets/scenery/castle-entrance-top.png"),
            castleEntranceBottom = loadTexture("assets/scenery/castle-entrance-bottom.png")
        },
        marioPalettes = [
            null,
            {
                small = loadSmallMarioSet("assets/mario-small-palette-1"),
                big = loadBigMarioSet("assets/mario-big-palette-1")
            },
            {
                small = loadSmallMarioSet("assets/mario-small-palette-2"),
                big = loadBigMarioSet("assets/mario-big-palette-2")
            },
            {
                small = loadSmallMarioSet("assets/mario-small-palette-3"),
                big = loadBigMarioSet("assets/mario-big-palette-3")
            }
        ]
    };
}

function screenRect(x, y, width, height, r, g, b, a = 1.0) {
    gfx.drawSolidRect(floor(x * PIXEL_SCALE).tofloat(), floor(y * PIXEL_SCALE).tofloat(),
                      floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
                      r, g, b, a);
}

function worldRect(gm, x, y, width, height, r, green, b, a = 1.0) {
    screenRect(x - gm.cameraX, y, width, height, r, green, b, a);
}

function screenTexture(texture, x, y, width, height) {
    gfx.drawTexturedRect(texture,
        floor(x * PIXEL_SCALE).tofloat(), floor(y * PIXEL_SCALE).tofloat(),
        floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
        1.0, 1.0, 1.0, 1.0);
}

function screenTextureTint(texture, x, y, width, height, r, g, b, a = 1.0) {
    gfx.drawTexturedRect(texture,
        floor(x * PIXEL_SCALE).tofloat(), floor(y * PIXEL_SCALE).tofloat(),
        floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
        r, g, b, a);
}

function worldTexture(gm, texture, x, y, width, height) {
    if (x + width < gm.cameraX - 16.0 || x > gm.cameraX + LOGICAL_WIDTH + 16.0) return;
    screenTexture(texture, x - gm.cameraX, y, width, height);
}

function worldTextureRotated(gm, texture, x, y, width, height, degrees) {
    if (x + width < gm.cameraX - 16.0 || x > gm.cameraX + LOGICAL_WIDTH + 16.0) return;
    gfx.drawTexturedRectRotated(texture,
        floor((x - gm.cameraX + width * 0.5) * PIXEL_SCALE).tofloat(),
        floor((y + height * 0.5) * PIXEL_SCALE).tofloat(),
        floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
        degrees, 1.0, 1.0, 1.0, 1.0);
}

function backgroundMetatileTexture(value) {
    if (value == 0x80) return assets.scenery.cloudLeft;
    if (value == 0x81) return assets.scenery.cloudMiddle;
    if (value == 0x82) return assets.scenery.cloudRight;
    if (value == 0x83) return assets.scenery.cloudBottomLeft;
    if (value == 0x84) return assets.scenery.cloudBottomMiddle;
    if (value == 0x85) return assets.scenery.cloudBottomRight;
    if (value == 0x02) return assets.scenery.bushLeft;
    if (value == 0x03) return assets.scenery.bushMiddle;
    if (value == 0x04) return assets.scenery.bushRight;
    if (value == 0x05) return assets.scenery.hillLeft;
    if (value == 0x06) return assets.scenery.hillLeftBottom;
    if (value == 0x07) return assets.scenery.hillMiddleTop;
    if (value == 0x08) return assets.scenery.hillRight;
    if (value == 0x09) return assets.scenery.hillRightBottom;
    if (value == 0x0A) return assets.scenery.hillMiddleBottom;
    return null;
}

function positiveModulo(value, divisor) {
    local result = value % divisor;
    return result < 0 ? result + divisor : result;
}

function drawBackground(g) {
    if (g.area == "underground") return;
    // SMB's renderer selects one byte for every 16-pixel column. The upper
    // nibble is the vertical start row and the lower nibble selects a
    // three-metatile vertical object. The 48-column pattern repeats every
    // three nametable pages, exactly as it does in the ROM.
    local firstColumn = floor(g.cameraX / TILE_SIZE).tointeger() - 1;
    local lastColumn = firstColumn + 19;
    local sceneryOffset = ROM_BACK_SCENERY_OFFSETS[ROM_WORLD_1_1_BACKGROUND_SCENERY - 1];

    for (local column = firstColumn; column <= lastColumn; column += 1) {
        if (column < 0) continue;
        local descriptor = ROM_BACK_SCENERY_DATA[
            sceneryOffset + positiveModulo(column, 48)
        ];
        local objectNumber = descriptor & 0x0F;
        if (objectNumber == 0) continue;

        local objectOffset = (objectNumber - 1) * 3;
        local startRow = (descriptor >> 4) + 2;
        for (local row = 0; row < 3; row += 1) {
            local metatile = ROM_BACK_SCENERY_METATILES[objectOffset + row];
            local texture = backgroundMetatileTexture(metatile);
            if (texture == null) continue;
            worldTexture(g, texture, column * TILE_SIZE,
                         (startRow + row) * TILE_SIZE, TILE_SIZE, TILE_SIZE);
        }
    }
}

function tileTexture(g, tile) {
    if (g.area == "underground" &&
        (tile == TILE_GROUND || tile == TILE_SOLID || tile == TILE_BRICK))
        return assets.tiles.undergroundBrick;
    if (tile == TILE_GROUND) return assets.tiles.ground;
    if (tile == TILE_SOLID) return assets.tiles.solid;
    if (tile == TILE_BRICK || tile == TILE_BRICK_COIN || tile == TILE_BRICK_STAR)
        return assets.tiles.brick;
    if (tile == TILE_QUESTION || tile == TILE_POWERUP_BLOCK) return assets.tiles.question;
    if (tile == TILE_USED) return assets.tiles.used;
    if (tile == TILE_PIPE_TOP_LEFT) return assets.tiles.pipeTopLeft;
    if (tile == TILE_PIPE_TOP_RIGHT) return assets.tiles.pipeTopRight;
    if (tile == TILE_PIPE_SHAFT_LEFT) return assets.tiles.pipeShaftLeft;
    if (tile == TILE_PIPE_SHAFT_RIGHT) return assets.tiles.pipeShaftRight;
    if (tile == TILE_SIDE_PIPE_TOP_END) return assets.tiles.sidePipeTopEnd;
    if (tile == TILE_SIDE_PIPE_TOP_SHAFT) return assets.tiles.sidePipeTopShaft;
    if (tile == TILE_SIDE_PIPE_TOP_JOINT) return assets.tiles.sidePipeTopJoint;
    if (tile == TILE_SIDE_PIPE_BOTTOM_END) return assets.tiles.sidePipeBottomEnd;
    if (tile == TILE_SIDE_PIPE_BOTTOM_SHAFT) return assets.tiles.sidePipeBottomShaft;
    if (tile == TILE_SIDE_PIPE_BOTTOM_JOINT) return assets.tiles.sidePipeBottomJoint;
    return null;
}

function drawTiles(g) {
    local first = floor(g.cameraX / TILE_SIZE).tointeger() - 1;
    local last = first + 19;
    if (first < 0) first = 0;
    if (last >= g.areaWidth) last = g.areaWidth - 1;

    for (local ty = 0; ty < LEVEL_HEIGHT; ty += 1) {
        for (local tx = first; tx <= last; tx += 1) {
            local tile = getTile(g, tx, ty);
            if (tile == TILE_EMPTY) continue;
            local texture = tileTexture(g, tile);
            if (texture == null) continue;
            local offsetY = 0.0;
            if (g.bump.active && g.bump.tx == tx && g.bump.ty == ty)
                offsetY = -sin((g.bump.time / 0.18) * PI) * 4.0;
            if (tile == TILE_QUESTION || tile == TILE_POWERUP_BLOCK) {
                // ColorRotation advances every eighth frame through the six
                // ROM palette entries; use the pre-rendered exact variants.
                local phase = floor(g.simTime * NES_FRAME_RATE / 8.0).tointeger() % 6;
                worldTexture(g, assets.tiles.questions[phase], tx * 16.0,
                             ty * 16.0 + offsetY, 16.0, 16.0);
            } else {
                worldTexture(g, texture, tx * 16.0, ty * 16.0 + offsetY, 16.0, 16.0);
            }
        }
    }
}

function playerPalettePhase(g) {
    local p = g.player;
    local frameCounter = floor(g.simTime * NES_FRAME_RATE).tointeger();
    if (p.transformFrames > 0 && p.transformKind == "fire")
        return (frameCounter >> 2) & 3;
    if (p.starTimer > 0.0) {
        // StarInvincibleTimer below eight interval counts slows from a
        // two-frame to an eight-frame palette cadence.
        if (p.starTimer < (8.0 * NES_INTERVAL_FRAMES * FIXED_DT))
            return (frameCounter >> 3) & 3;
        return (frameCounter >> 1) & 3;
    }
    return 0;
}

function marioTextureFromSet(g, set) {
    local p = g.player;
    if (p.big) {
        if (p.crouching)
            return p.facing > 0 ? set.crouchRight : set.crouchLeft;
        if (!p.grounded)
            return p.facing > 0 ? set.jumpRight : set.jumpLeft;
        if (p.skidding)
            return p.facing > 0 ? set.skidRight : set.skidLeft;
        if (abs(p.vx) > 8.0) {
            local bigFrame = floor(g.simTime * 10.0).tointeger() % 3;
            return p.facing > 0 ? set.walkRight[bigFrame] : set.walkLeft[bigFrame];
        }
        return p.facing > 0 ? set.standRight : set.standLeft;
    }
    if (!p.grounded) return p.facing > 0 ? set.jumpRight : set.jumpLeft;
    if (p.skidding) return p.facing > 0 ? set.skidRight : set.skidLeft;
    if (abs(p.vx) > 8.0) {
        local frame = floor(g.simTime * 10.0).tointeger() % 3;
        return p.facing > 0 ? set.walkRight[frame] : set.walkLeft[frame];
    }
    return p.facing > 0 ? set.standRight : set.standLeft;
}

function marioTexture(g) {
    local p = g.player;
    if (p.dead) return p.facing > 0 ? assets.mario.deadRight : assets.mario.deadLeft;
    local palettePhase = playerPalettePhase(g);
    if (palettePhase > 0) {
        local set = p.big ? assets.marioPalettes[palettePhase].big :
                            assets.marioPalettes[palettePhase].small;
        return marioTextureFromSet(g, set);
    }
    if (p.fire && p.throwingTimer > 0.0)
        return p.facing > 0 ? assets.marioFire.throwRight : assets.marioFire.throwLeft;
    local baseSet = p.fire ? assets.marioFire : (p.big ? assets.marioBig : assets.mario);
    return marioTextureFromSet(g, baseSet);
}

function drawPlayer(g) {
    local p = g.player;
    if (g.state == "timeBonus" || g.state == "raiseFlag" ||
        g.state == "fireworks" || g.state == "postClearDelay" ||
        g.state == "levelComplete" || g.state == "gameOver") return;
    if (p.invulnerable > 0.0 && floor(g.simTime * 14.0).tointeger() % 2 == 0) return;
    local drawY = p.big && !p.crouching ? p.y : p.y - 16.0;
    local texture = marioTexture(g);
    if (p.transformFrames > 0 && p.transformKind != "fire") {
        local frame = floor(p.transformFrames / 4).tointeger() % 2;
        if (p.transformKind == "grow" && frame == 0) {
            texture = p.facing > 0 ? assets.mario.standRight : assets.mario.standLeft;
            drawY = p.y;
        } else if (p.transformKind == "shrink" && frame == 1) {
            texture = p.facing > 0 ? assets.marioBig.standRight : assets.marioBig.standLeft;
            drawY = p.y - 16.0;
        }
    }
    worldTexture(g, texture, floor(p.x - 2.0), floor(drawY), 16.0, 32.0);
}

function drawPowerUps(g, behindTiles) {
    foreach (item in g.powerups) {
        if (!item.active || !item.visible) continue;
        if (item.emerging != behindTiles) continue;
        local texture = assets.items.mushroom;
        if (item.kind == "flower") texture = assets.items.flower;
        if (item.kind == "oneup") texture = assets.items.oneUp;
        if (item.kind == "star") texture = assets.items.star;
        worldTexture(g, texture, floor(item.x), floor(powerUpDrawY(item)), 16.0, 16.0);
    }
}

function drawLevelCoins(g) {
    foreach (coin in g.levelCoins) {
        if (!coin.active) continue;
        local phase = floor(g.simTime * NES_FRAME_RATE / 8.0).tointeger() % 6;
        worldTexture(g, assets.items.undergroundCoins[phase],
                     floor(coin.x), floor(coin.y), 16.0, 16.0);
    }
}

function drawFireballs(g) {
    foreach (fireball in g.fireballs) {
        if (!fireball.active) continue;
        if (fireball.exploding) {
            local frame = floor((6 - fireball.explosionFrames) / 2).tointeger();
            if (frame < 0) frame = 0;
            if (frame > 2) frame = 2;
            worldTexture(g, assets.items.fireballExplosions[frame],
                         floor(fireball.x - 4.0), floor(fireball.y - 4.0), 16.0, 16.0);
        } else {
            local frame = floor(g.simTime * 15.0).tointeger() % 2;
            worldTexture(g, assets.items.fireballs[frame],
                         floor(fireball.x), floor(fireball.y), 8.0, 8.0);
        }
    }
}

function drawEnemy(g, e) {
    if (!e.alive) return;
    local texture = null;
    local y = e.y;
    local height = 24.0;
    if (e.state == "flipped") {
        texture = e.kind == "koopa" ? assets.enemies.greenShell[0] : assets.enemies.goomba;
        local flippedY = e.y - (e.kind == "koopa" ? 10.0 : 8.0);
        worldTextureRotated(g, texture, floor(e.x - 1.0), floor(flippedY),
                            16.0, height, 180.0);
        return;
    } else if (e.kind == "goomba" && e.state == "defeated") {
        texture = assets.enemies.goombaDefeated;
    } else if (e.kind == "koopa" &&
               (e.state == "shell" || e.state == "shellMoving")) {
        // EnemyGfxHandler toggles both stationary and moving shell frames on
        // FrameCounter bit 3: eight frames per image.
        local shellFrame = floor(g.simTime * NES_FRAME_RATE / 8.0).tointeger() % 2;
        texture = assets.enemies.greenShell[shellFrame];
        y -= 10.0;
    } else if (e.kind == "koopa") {
        local frame = floor(g.simTime * 7.0).tointeger() % 2;
        texture = e.vx < 0.0 ? assets.enemies.koopaLeft[frame] :
                               assets.enemies.koopaRight[frame];
    } else {
        texture = assets.enemies.goomba;
    }
    worldTexture(g, texture, floor(e.x - 1.0), floor(y - (e.kind == "goomba" ? 8.0 : 0.0)), 16.0, height);
}

function drawFlag(g) {
    for (local y = 48.0; y <= 176.0; y += 16.0)
        worldTexture(g, assets.scenery.flagShaft, g.flagX, y, 16.0, 16.0);
    worldTexture(g, assets.scenery.flagBall, g.flagX, 40.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.flagpoleFlag,
                 g.flagX - 8.0, g.flagY, 16.0, 16.0);
}

function drawFireworks(g) {
    foreach (burst in g.fireworks) {
        local frame = floor((24 - burst.frames) / 8).tointeger();
        if (frame < 0) frame = 0;
        if (frame > 2) frame = 2;
        worldTexture(g, assets.items.fireballExplosions[frame],
                     burst.x, burst.y, 16.0, 16.0);
    }
}

function drawCastle(g) {
    local x = g.castleX;
    local wall = assets.scenery.castleWall;
    worldTexture(g, assets.scenery.castleTopBrick, x + 32.0, 128.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleTop, x + 16.0, 144.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleTopBrick, x + 32.0, 144.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleTop, x + 48.0, 144.0, 16.0, 16.0);
    for (local row = 0; row < 3; row += 1)
        for (local col = 0; col < 5; col += 1)
            worldTexture(g, wall, x + col * 16.0, 160.0 + row * 16.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleWindowLeft, x + 16.0, 160.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleWindowRight, x + 48.0, 160.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleEntranceTop, x + 32.0, 176.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleEntranceBottom, x + 32.0, 192.0, 16.0, 16.0);
    if (g.castleFlagVisible)
        worldTexture(g, assets.scenery.castleFlag,
                     x + 32.0, g.castleFlagY, 16.0, 16.0);
}

function drawEffects(g) {
    if (g.coinEffect.active) {
        local t = g.coinEffect.time / 0.42;
        local y = g.coinEffect.y - sin(t * PI) * 24.0;
        local frame = floor(g.simTime * 30.0).tointeger() % 4;
        worldTexture(g, assets.items.jumpCoins[frame], g.coinEffect.x, y, 8.0, 16.0);
    }
    foreach (piece in g.brickDebris) {
        if (!piece.active) continue;
        worldTexture(g, assets.items.brickFragment,
                     floor(piece.x), floor(piece.y), 8.0, 8.0);
    }
}

function drawHudGlyphs(glyphs, x, y) {
    for (local i = 0; i < glyphs.len(); i += 1)
        screenTexture(assets.hudFont[glyphs[i]], x + i * 8.0, y, 8.0, 8.0);
}

function drawHudNumber(value, digits, x, y, blankLeading = false) {
    local divisor = 1;
    for (local i = 1; i < digits; i += 1) divisor *= 10;
    local shown = !blankLeading;
    for (local i = 0; i < digits; i += 1) {
        local digit = floor(value / divisor).tointeger() % 10;
        if (digit != 0 || i == digits - 1) shown = true;
        local glyph = shown ? digit : 0x24;
        screenTexture(assets.hudFont[glyph], x + i * 8.0, y, 8.0, 8.0);
        divisor = divisor / 10;
    }
}

function drawHud(g) {
    drawHudGlyphs([0x16, 0x0A, 0x1B, 0x12, 0x18], 24.0, 8.0); // MARIO
    drawHudNumber(g.score, 6, 24.0, 16.0);
    screenTexture(assets.hudFont[0x2E], 88.0, 16.0, 8.0, 8.0);
    screenTexture(assets.hudFont[0x29], 96.0, 16.0, 8.0, 8.0);
    drawHudNumber(g.coins, 2, 104.0, 16.0);
    drawHudGlyphs([0x20, 0x18, 0x1B, 0x15, 0x0D], 144.0, 8.0); // WORLD
    drawHudGlyphs([0x01, 0x28, 0x01], 152.0, 16.0);
    drawHudGlyphs([0x1D, 0x12, 0x16, 0x0E], 200.0, 8.0); // TIME
    drawHudNumber(g.time, 3, 200.0, 16.0, true);

    if (g.state == "gameOver") {
        screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT, 0.0, 0.0, 0.0);
        drawHudGlyphs([0x10, 0x0A, 0x16, 0x0E, 0x24,
                       0x18, 0x1F, 0x0E, 0x1B], 92.0, 112.0);
    } else if (g.state == "levelComplete") {
        drawHudGlyphs([0x20, 0x18, 0x1B, 0x15, 0x0D], 88.0, 96.0);
        drawHudGlyphs([0x01, 0x28, 0x01], 112.0, 112.0);
    }
}

function renderGame(g) {
    gfx.clear();
    if (g.area == "underground")
        screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT, 0.0, 0.0, 0.0);
    drawBackground(g);
    drawLevelCoins(g);
    drawPowerUps(g, true);
    drawFireballs(g);
    drawTiles(g);
    drawPowerUps(g, false);
    if (g.area == "main") {
        drawFlag(g);
        drawCastle(g);
    }
    drawFireworks(g);
    foreach (e in g.goombas) drawEnemy(g, e);
    drawEffects(g);
    drawPlayer(g);
    drawHud(g);
}
