dofile("scripts/generated/oam_cells.nut");
if (!("oamTextureCells" in getroottable())) oamTextureCells <- {};
if (!("renderOffsetY" in getroottable())) renderOffsetY <- 0.0;

function loadTexture(path) {
    local texture = gfx.newTextureFromFile(path);
    // NES CHR pixels are discrete samples.  EVEngine textures default to
    // linear filtering, which blends neighbouring texels and shifts edge
    // coverage as the camera moves.  Point sampling preserves the PPU image.
    gfx.setTextureSampler(texture, "nearest", "none", 1.0, 0.0);
    foreach(entry in OAM_TEXTURE_CELLS) if(entry[0]==path) {
        local cells=[];
        foreach(cellPath in entry[3]) cells.append(loadTexture(cellPath));
        oamTextureCells[texture] <- {columns=entry[1],rows=entry[2],cells=cells};
        break;
    }
    return texture;
}

function screenOamTexture(texture,x,y,width,height,clipX=null,lowerRowCarry=0) {
    if (!(texture in oamTextureCells)) {
        screenTexture(texture,x,y,width,height);
        return;
    }
    local data=oamTextureCells[texture];
    if(clipX==null) clipX=x;
    for(local row=0;row<data.rows;row+=1) {
        // Hide offscreen OAM rows before byte wrapping so they cannot
        // reappear at the opposite edge of the screen.
        local oamY=floor(y).tointeger()-1+row*8+(row>0?lowerRowCarry:0);
        if(oamY<0 || oamY>=239) continue;
        for(local column=0;column<data.columns;column+=1) {
            local cellX=floor(x).tointeger()+column*8;
            local maskX=floor(clipX).tointeger()+column*8;
            // GetXOffscreenBits includes the left edge in the hidden cell:
            // an edge/object difference of zero selects mask $80.
            if(maskX<=0 || maskX>=256) continue;
            screenTexture(data.cells[row*data.columns+column],cellX,oamY+1,8,8);
        }
    }
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
        climbRight = [
            loadTexture(path + "/climb-1-right.png"),
            loadTexture(path + "/climb-2-right.png")
        ],
        climbLeft = [
            loadTexture(path + "/climb-1-left.png"),
            loadTexture(path + "/climb-2-left.png")
        ],
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
        world12 = {
            questions = [loadTexture("assets/world12/question-0.png"),loadTexture("assets/world12/question-1.png"),
                loadTexture("assets/world12/question-2.png"),loadTexture("assets/world12/question-3.png"),
                loadTexture("assets/world12/question-4.png"),loadTexture("assets/world12/question-5.png")],
            goombas = [loadTexture("assets/world12/goomba-0.png"),loadTexture("assets/world12/goomba-1.png")],
            goombaDefeated = loadTexture("assets/world12/goomba-defeated.png"),
            plants = [loadTexture("assets/world12/piranha-0.png"),loadTexture("assets/world12/piranha-1.png")],
            platform = loadTexture("assets/world12/platform.png")
        },
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
            undergroundGround = loadTexture("assets/tiles/underground-ground.png"),
            undergroundPipeShaftLeft =
                loadTexture("assets/tiles/underground-pipe-shaft-left.png"),
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
            climbRight = [
                loadTexture("assets/mario/climb-1-right.png"),
                loadTexture("assets/mario/climb-2-right.png")
            ],
            climbLeft = [
                loadTexture("assets/mario/climb-1-left.png"),
                loadTexture("assets/mario/climb-2-left.png")
            ],
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
            climbRight = [
                loadTexture("assets/mario-big/climb-1-right.png"),
                loadTexture("assets/mario-big/climb-2-right.png")
            ],
            climbLeft = [
                loadTexture("assets/mario-big/climb-1-left.png"),
                loadTexture("assets/mario-big/climb-2-left.png")
            ],
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
            climbRight = [
                loadTexture("assets/mario-fire/climb-1-right.png"),
                loadTexture("assets/mario-fire/climb-2-right.png")
            ],
            climbLeft = [
                loadTexture("assets/mario-fire/climb-1-left.png"),
                loadTexture("assets/mario-fire/climb-2-left.png")
            ],
            crouchRight = loadTexture("assets/mario-fire/crouch-right.png"),
            crouchLeft = loadTexture("assets/mario-fire/crouch-left.png"),
            skidRight = loadTexture("assets/mario-fire/skid-right.png"),
            skidLeft = loadTexture("assets/mario-fire/skid-left.png"),
            throwRight = loadTexture("assets/mario-fire/fireball-right.png"),
            throwLeft = loadTexture("assets/mario-fire/fireball-left.png")
        },
        enemies = {
            goombas = [
                loadTexture("assets/enemies/goomba-1.png"),
                loadTexture("assets/enemies/goomba-2.png")
            ],
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
            hudCoins = [
                loadTexture("assets/items/hud-coin-0.png"),
                loadTexture("assets/items/hud-coin-1.png"),
                loadTexture("assets/items/hud-coin-2.png"),
                loadTexture("assets/items/hud-coin-3.png"),
                loadTexture("assets/items/hud-coin-4.png"),
                loadTexture("assets/items/hud-coin-5.png")
            ],
            hudCoinsUnderground = [
                loadTexture("assets/items/hud-coin-underground-0.png"),
                loadTexture("assets/items/hud-coin-underground-1.png"),
                loadTexture("assets/items/hud-coin-underground-2.png"),
                loadTexture("assets/items/hud-coin-underground-3.png"),
                loadTexture("assets/items/hud-coin-underground-4.png"),
                loadTexture("assets/items/hud-coin-underground-5.png")
            ],
            hudCoinLives = loadTexture("assets/items/hud-coin-lives.png"),
            jumpCoins = [
                loadTexture("assets/items/jump-coin-0.png"),
                loadTexture("assets/items/jump-coin-1.png"),
                loadTexture("assets/items/jump-coin-2.png"),
                loadTexture("assets/items/jump-coin-3.png")
            ],
            score200 = loadTexture("assets/items/score-200.png"),
            score100 = loadTexture("assets/items/score-100.png"),
            flagScores = [
                loadTexture("assets/items/flag-score-5000.png"),
                loadTexture("assets/items/flag-score-2000.png"),
                loadTexture("assets/items/flag-score-800.png"),
                loadTexture("assets/items/flag-score-400.png"),
                loadTexture("assets/items/flag-score-100.png")
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
    assets.world12.metatiles <- {};
    foreach(column in ROM_WORLD_1_2_METATILES) foreach(meta in column) {
        if(!(meta in assets.world12.metatiles))
            assets.world12.metatiles[meta]<-loadTexture("assets/world12/metatile-"+meta+".png");
    }
    foreach(column in ROM_WORLD_1_2_BONUS_METATILES) foreach(meta in column) {
        if(!(meta in assets.world12.metatiles))
            assets.world12.metatiles[meta]<-loadTexture("assets/world12/metatile-"+meta+".png");
    }
}

function screenRect(x, y, width, height, r, g, b, a = 1.0) {
    y+=renderOffsetY;
    gfx.drawSolidRect(floor(x * PIXEL_SCALE).tofloat(), floor(y * PIXEL_SCALE).tofloat(),
                      floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
                      r, g, b, a);
}

function visualCameraX(gm) {
    return ("displayCameraX" in gm) ? gm.displayCameraX : gm.cameraX;
}

function worldRect(gm, x, y, width, height, r, green, b, a = 1.0) {
    screenRect(x - visualCameraX(gm), y, width, height, r, green, b, a);
}

function screenTexture(texture, x, y, width, height) {
    y+=renderOffsetY;
    gfx.drawTexturedRect(texture,
        floor(x * PIXEL_SCALE).tofloat(), floor(y * PIXEL_SCALE).tofloat(),
        floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
        1.0, 1.0, 1.0, 1.0);
}

function screenTextureTint(texture, x, y, width, height, r, g, b, a = 1.0) {
    y+=renderOffsetY;
    gfx.drawTexturedRect(texture,
        floor(x * PIXEL_SCALE).tofloat(), floor(y * PIXEL_SCALE).tofloat(),
        floor(width * PIXEL_SCALE).tofloat(), floor(height * PIXEL_SCALE).tofloat(),
        r, g, b, a);
}

function worldTexture(gm, texture, x, y, width, height) {
    local cameraX = visualCameraX(gm);
    if (x + width < cameraX - 16.0 || x > cameraX + LOGICAL_WIDTH + 16.0) return;
    screenTexture(texture, x - cameraX, y, width, height);
}

function worldTextureRotated(gm, texture, x, y, width, height, degrees) {
    local cameraX = visualCameraX(gm);
    if (x + width < cameraX - 16.0 || x > cameraX + LOGICAL_WIDTH + 16.0) return;
    gfx.drawTexturedRectRotated(texture,
        floor((x - cameraX + width * 0.5) * PIXEL_SCALE).tofloat(),
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
    if(isWorld21(g)) {drawWorld13Background(g);return;}
    if(g.level==3) {drawWorld13Background(g);return;}
    if(g.level==4) {drawWorld14Background(g);return;}
    if (g.area == "underground") return;
    // SMB's renderer selects one byte for every 16-pixel column. The upper
    // nibble is the vertical start row and the lower nibble selects a
    // three-metatile vertical object. The 48-column pattern repeats every
    // three nametable pages, exactly as it does in the ROM.
    local firstColumn = floor(visualCameraX(g) / TILE_SIZE).tointeger() - 1;
    local lastColumn = firstColumn + 19;
    local sceneryType=g.level==2 && g.stage=="intro"?1:ROM_WORLD_1_1_BACKGROUND_SCENERY;
    local sceneryOffset = ROM_BACK_SCENERY_OFFSETS[sceneryType - 1];

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
    if (tile == TILE_HIDDEN_COIN) return null;
    if (tile == TILE_BRICK_POWERUP || tile == TILE_BRICK_ONEUP || tile == TILE_BRICK_VINE)
        return g.area == "underground" ? assets.tiles.undergroundBrick : assets.tiles.brick;
    if (g.area == "underground" && tile == TILE_GROUND)
        return assets.tiles.undergroundGround;
    if (g.area == "underground" &&
        (tile == TILE_SOLID || tile == TILE_BRICK))
        return assets.tiles.undergroundBrick;
    if (g.area == "underground" && tile == TILE_PIPE_SHAFT_LEFT)
        return assets.tiles.undergroundPipeShaftLeft;
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
    local first = floor(visualCameraX(g) / TILE_SIZE).tointeger() - 1;
    local last = first + 19;
    if (first < 0) first = 0;
    if (last >= g.areaWidth) last = g.areaWidth - 1;

    for (local ty = 0; ty < LEVEL_HEIGHT; ty += 1) {
        for (local tx = first; tx <= last; tx += 1) {
            local tile = getTile(g, tx, ty);
            foreach (entry in g.displayTileOverrides) {
                if (entry.tx == tx && entry.ty == ty) {
                    tile = entry.tile;
                    break;
                }
            }
            if(isWorld21(g)) {
                local texture=world21TileTexture(g,tx,ty,tile);
                if(texture!=null) worldTexture(g,texture,tx*16.0,ty*16.0,16,16);
                continue;
            }
            if(g.level>=3) {
                local texture=g.level==3?world13TileTexture(g,tx,ty,tile):
                    world14TileTexture(g,tx,ty,tile);
                if(texture!=null) worldTexture(g,texture,tx*TILE_SIZE,ty*TILE_SIZE,TILE_SIZE,TILE_SIZE);
                continue;
            }
            if (tile == TILE_EMPTY) continue;
            local texture = tileTexture(g, tile);
            if(g.level==2 && (g.stage=="underground" || g.stage=="bonus") && g.world12BaseTiles.len()>0 &&
               tile==g.world12BaseTiles[tileIndex(tx,ty)] && tile!=TILE_QUESTION && tile!=TILE_POWERUP_BLOCK) {
                local meta=g.world12Metatiles[tileIndex(tx,ty)];
                if(meta in assets.world12.metatiles) texture=assets.world12.metatiles[meta];
            }
            if (texture == null) continue;
            local offsetY = 0.0;
            if (g.bump.active && g.bump.tx == tx && g.bump.ty == ty) {
                // BlockObjMT_Updater prepares these fourteen OAM offsets.
                // Use the same buffered-frame relationship as the coin object.
                // ROM traces expose two carry-dependent block trajectories.
                // A normal brick uses the full -7 apex; the opening power-up
                // block reaches a -6 apex and has the adjacent intermediate
                // values below.  Preserve both observed 14-frame sequences.
                local bumpOffsets = g.bump.tile == TILE_POWERUP_BLOCK ?
                    [-1, -3, -4, -5, -6, -6, -6, -6, -6, -5, -4, -2, -1, 1] :
                    [-1, -3, -5, -6, -6, -7, -7, -7, -6, -5, -4, -3, -1, 1];
                // The hit frame and its first following capture still show
                // the nametable metatile; block-object OAM begins at -1 on
                // the second following capture.
                if (g.bump.frame > 1) {
                    local bumpIndex = g.bump.frame - 2;
                    if (bumpIndex >= bumpOffsets.len())
                        bumpIndex = bumpOffsets.len() - 1;
                    offsetY = bumpOffsets[bumpIndex].tofloat();
                }
            }
            if (tile == TILE_QUESTION || tile == TILE_POWERUP_BLOCK) {
                // ColorRotation advances every eighth frame through the six
                // ROM palette entries; use the pre-rendered exact variants.
                local phase = g.displayColorPhase;
                local questionTextures=g.level==2 && g.area=="underground" ?
                    assets.world12.questions : assets.tiles.questions;
                worldTexture(g, questionTextures[phase], tx * 16.0,
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
    // PlayerGfxOffset is prepared with the same buffered OAM image as the
    // relative coordinates.  Do not re-decide the action from current RAM
    // flags here: on a take-off frame the visible image is still the prior
    // walking frame even though Player_State is already jumping.
    local visualFrame = p.displayAnimationFrame;
    local visualFacing = p.displayFacing;
    if (visualFrame == -5 || visualFrame == -6) {
        local climbFrame = visualFrame == -5 ? 0 : 1;
        return visualFacing > 0 ? set.climbRight[climbFrame] : set.climbLeft[climbFrame];
    }
    if (p.big) {
        if (visualFrame == -3)
            return visualFacing > 0 ? set.crouchRight : set.crouchLeft;
        if (visualFrame == -2)
            return visualFacing > 0 ? set.jumpRight : set.jumpLeft;
        if (visualFrame == -4)
            return visualFacing > 0 ? set.skidRight : set.skidLeft;
        if (visualFrame >= 0) {
            local bigFrame = visualFrame;
            return visualFacing > 0 ? set.walkRight[bigFrame] : set.walkLeft[bigFrame];
        }
        return visualFacing > 0 ? set.standRight : set.standLeft;
    }
    if (visualFrame == -2)
        return visualFacing > 0 ? set.jumpRight : set.jumpLeft;
    if (visualFrame == -4)
        return visualFacing > 0 ? set.skidRight : set.skidLeft;
    if (visualFrame >= 0) {
        local frame = visualFrame;
        return visualFacing > 0 ? set.walkRight[frame] : set.walkLeft[frame];
    }
    return visualFacing > 0 ? set.standRight : set.standLeft;
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
    if (g.state == "nextStageLoad" && g.stageLoadFrames == 165) return;
    if (parityIsEnabled() && g.parity.originPending && g.world==1 && g.level==1) return;
    if ((g.state == "timeBonus" && p.courseClearHidden) || g.state == "raiseFlag" ||
        g.state == "fireworks" || g.state == "postClearDelay" ||
        g.state == "levelComplete" || g.state == "gameOver" || g.state == "warpComplete") return;
    if (p.invulnerable > 0.0 && floor(g.simTime * 14.0).tointeger() % 2 == 0) return;
    // Player_Rel_YPos is prepared before the current movement integration;
    // OAM therefore displays the preceding world Y while RAM already holds
    // the new position (visible during the death jump in particular).
    local spriteWorldY = p.previousY;
    local drawY = p.big && !p.crouching ? spriteWorldY : spriteWorldY - 16.0;
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
    // OAM Y stores the scanline before the first visible sprite row.
    // Player_Rel_XPos is prepared alongside Player_Rel_YPos before movement
    // and scrolling.  previousX combined with the buffered display camera is
    // the same relative coordinate, without frame-dependent inset guesses.
    if (p.dead) {
        worldTexture(g, texture, floor(p.previousX), floor(drawY) + 1.0,
                     16.0, 32.0);
    } else {
        screenOamTexture(texture, floor(p.displayRelX),
                      floor(p.displayRelY) + 1.0,
                      16.0, 32.0);
    }
}

function drawPowerUps(g, behindTiles) {
    foreach (item in g.powerups) {
        if (!item.displayActive || !item.displayVisible) continue;
        if (item.displayEmerging != behindTiles) continue;
        local texture = assets.items.mushroom;
        if (item.kind == "flower") texture = assets.items.flower;
        if (item.kind == "oneup") texture = assets.items.oneUp;
        if (item.kind == "star") texture = assets.items.star;
        worldTexture(g, texture, floor(item.displayX),
                     floor(item.displayRomY + POWERUP_DRAW_Y_OFFSET), 16.0, 16.0);
    }
}

function drawLevelCoins(g) {
    foreach (coin in g.levelCoins) {
        if (!coin.active && !("visualErasePending" in coin && coin.visualErasePending)) continue;
        local phase = g.displayColorPhase;
        local texture = g.level == 3 ? assets.world13.coins[phase] :
            assets.items.undergroundCoins[phase];
        worldTexture(g, texture,
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
    if (!e.alive && e.erasedDisplayFrames <= 0) return;
    // EnemyGfxHandler suppresses the object once its origin is in the left
    // offscreen region (EnemyOffscrBitsMasked bit 2).  Letting the host clip
    // the corrected 16px texture would leak a one-pixel sliver that the NES
    // OAM writer has already hidden.
    if (e.x < g.cameraX && g.level!=3) return;
    local visualState = e.displayState;
    local levelTexture=g.level==3?world13EnemyTexture(g,e,visualState):null;
    local texture = null;
    local y = e.y;
    if(g.level==3 && e.kind=="goomba") y=e.displayY;
    local height = 24.0;
    if (visualState == "flipped") {
        texture = e.kind == "koopa" ? assets.enemies.greenShell[0] : assets.enemies.goomba;
        if(levelTexture!=null) texture=levelTexture;
        local flippedY = e.y - (e.kind == "koopa" ? 10.0 : 8.0);
        worldTextureRotated(g, texture, floor(e.x - 1.0), floor(flippedY),
                            16.0, height, 180.0);
        return;
    } else if (e.kind == "goomba" && visualState == "defeated") {
        texture = g.level == 2 && g.area == "underground" ?
            assets.world12.goombaDefeated : assets.enemies.goombaDefeated;
    } else if (e.kind == "koopa" &&
               (visualState == "shell" || visualState == "shellMoving")) {
        // The first image is the fully closed shell. The exposed-feet image
        // is a late revival warning, never the moving shell's normal frame.
        local shellFrame = visualState == "shellMoving" ? 0 : e.displayShellFrame;
        texture = assets.enemies.greenShell[shellFrame];
        if(levelTexture!=null) texture=levelTexture;
        y -= 10.0;
    } else if (e.kind == "koopa") {
        local frame = floor(g.simTime * 7.0).tointeger() % 2;
        texture = e.vx < 0.0 ? assets.enemies.koopaLeft[frame] :
                               assets.enemies.koopaRight[frame];
        if(levelTexture!=null) texture=levelTexture;
        if(isWorld21(g) && "greenJump" in e && e.greenJump)
            texture=e.vx<0?assets.world21.wingsLeft[frame]:assets.world21.wingsRight[frame];
    } else {
        // EnemyGfxHandler sees the counter from the gameplay pass that built
        // the visible OAM buffer (two counts behind this render-side value).
        // TimerControl freezes the last prepared direction after Mario dies.
        local gfxCounter = (g.nesFrameCounter + 254) & 0xFF;
        // Goombas animate by XOR-flipping their base left-facing attributes
        // when FrameCounter bit 3 is clear; the CHR image itself is unchanged.
        // The two extracted textures are those two horizontal orientations.
        local frame = g.goombaVisualFrame;
        if (!g.player.dead) {
            local counterBitSet = (gfxCounter & 0x08) != 0;
            local movingLeft = e.vx < 0.0;
            frame = counterBitSet == movingLeft ? 1 : 0;
        }
        texture = g.level == 2 && g.area == "underground" ?
            assets.world12.goombas[frame] : assets.enemies.goombas[frame];
    }
    // RelativeEnemyPosition is prepared before EnemyMovementSubs.  With the
    // host-side post-movement coordinate, left-moving Goombas need a one-pixel
    // rollback and right-moving Goombas the opposite half-step compensation.
    // This is independent of ScrollAmount (notably during pipe-exit entrance).
    // The rollback only compensates a movement pass that has already changed
    // the host coordinate.  A lethal player collision skips EnemyMovementSubs
    // and TimerControl then freezes that pre-movement OAM position, so keeping
    // the one-pixel lead during the death sequence would move the frozen
    // Goomba one pixel to the right of the ROM image.
    local goombaMotionLead = g.player.dead ? 0.0 :
        (e.state == "defeated" ? e.stompDisplayLead :
            (e.vx > 0.0 ? -1.0 : 1.0));
    local defeatedGoomba = e.kind == "goomba" && visualState == "defeated";
    // State $04 uses only the bottom OAM row ($ef).  Its stored X is the
    // unadjusted relative coordinate and the 24px extracted canvas therefore
    // starts eight pixels above the host collision top.
    local drawX = defeatedGoomba ? e.x :
        (e.kind == "goomba" ? e.x + goombaMotionLead : e.x - 1.0);
    local drawY = defeatedGoomba ? y - 8.0 :
        (e.kind == "goomba" ? y - 9.0 : y);
    if (g.level == 3) {
        if (e.kind == "koopa") {
            // RelativeEnemyPosition uses the pre-movement X and visible OAM
            // scanline Y for the red enemy slots.
            drawX += 1.0;
            drawY -= 1.0;
            if(visualState=="walking" || visualState=="falling") {
                drawY=e.displayY+1.0;
            }
        }
        if(visualState=="walking" || visualState=="falling") drawX=e.displayX;
    }
    if(g.level==3)
        screenOamTexture(texture,floor(drawX)-visualCameraX(g),floor(drawY),16.0,height,
            // Reconstruct the integer pre-movement coordinate from the
            // host's half-pixel walking phase before computing edge bits.
            floor(e.previousX+(e.vx<0.0?0.5:0.0))-visualCameraX(g));
    else worldTexture(g, texture, floor(drawX), floor(drawY), 16.0, height);
}

function drawFlag(g) {
    renderOffsetY=g.displayBackgroundYOffset;
    for (local y = 48.0; y <= 176.0; y += 16.0)
        worldTexture(g, assets.scenery.flagShaft, g.flagX, y, 16.0, 16.0);
    // The flagpole-ball metatile stores its eight visible scanlines in the
    // lower half of a 16px canvas.  FlagpoleObject places that metatile at
    // row 2, so its visible outline starts at y=40.
    worldTexture(g, assets.scenery.flagBall, g.flagX, 32.0, 16.0, 16.0);
    renderOffsetY=0.0;
    // OAM Y is the scanline immediately above a sprite.  EnemyGfxHandler
    // writes the flag at g.flagY, and the PPU exposes its first pixel at +1.
    if(g.level==3 && g.flagX-8.0-visualCameraX(g)<240.0)
        screenOamTexture(assets.scenery.flagpoleFlag,g.flagX-8.0-visualCameraX(g),
            g.displayFlagY+1.0,16.0,16.0,g.flagX-g.cameraX,
            // FlagpoleGfxHandler adds 8 then 12 to relative X for the score
            // baseline. ADC #8 for the third sprite retains that carry.
            g.flagX-8.0-visualCameraX(g)>=236.0?1:0);
    else if(g.level!=3) worldTexture(g, assets.scenery.flagpoleFlag,
                 g.flagX - 8.0, g.displayFlagY + 1.0, 16.0, 16.0);
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
    if(isWorld21(g)) {
        if(g.castleFlagVisible) worldTexture(g,assets.scenery.castleFlag,
            g.castleX+32,g.castleFlagY+1,16,16);
        return;
    }
    // World 1-3 carries its full castle in the area tilemap and has no
    // castle-object star flag. The course-clear flagpole flag is separate.
    if (g.level == 3) return;
    local x = g.castleX;
    local wall = assets.scenery.castleWall;
    // DrawStarFlag writes attribute $22: palette 2, behind opaque background.
    // Draw before the castle so the rising flag is hidden by its brickwork.
    // castleFlagY is the ROM OAM coordinate; pixels start one scanline later.
    if (g.castleFlagVisible)
        worldTexture(g, assets.scenery.castleFlag,
                     x + 32.0, g.castleFlagY + 1.0, 16.0, 16.0);
    // First five rows of CastleMetatiles ($45-$4b), consumed row-major by
    // CastleObject in World 1-1.  Keeping the ROM's metatile identities here
    // matters: several shapes look interchangeable at a glance but use
    // different CHR quadrants and palette pixels.
    for (local col = 1; col <= 3; col += 1)
        worldTexture(g, assets.scenery.castleTop,
                     x + col * 16.0, 128.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleWindowLeft,
                 x + 16.0, 144.0, 16.0, 16.0);
    worldTexture(g, wall, x + 32.0, 144.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleWindowRight,
                 x + 48.0, 144.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleTop, x, 160.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleTop, x + 64.0, 160.0, 16.0, 16.0);
    for (local col = 1; col <= 3; col += 1)
        worldTexture(g, assets.scenery.castleTopBrick,
                     x + col * 16.0, 160.0, 16.0, 16.0);
    for (local row = 1; row <= 2; row += 1)
        for (local col = 0; col < 5; col += 1)
            worldTexture(g, wall, x + col * 16.0,
                         160.0 + row * 16.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleEntranceTop, x + 32.0, 176.0, 16.0, 16.0);
    worldTexture(g, assets.scenery.castleEntranceBottom, x + 32.0, 192.0, 16.0, 16.0);
}

function coinEffectDrawY(effect) {
    if (effect.displayPhase == "coin") {
        // Visible-top displacements from CoinBlock's spawn origin, including
        // the OAM/PPU scanline relationship. The reference block was at Y=144
        // (spawn Y=128); absolute captured screen coordinates must not be
        // reused for blocks on other rows. CoinBlock derives Y from the block
        // and ProcJumpCoin applies the same gravity regardless of that row.
        local offsets = [
            -5, -10, -15, -19, -22, -26, -29, -32,
            -34, -36, -38, -40, -41, -42, -43, -43,
            -43, -43, -42, -41, -40, -38, -36, -34,
            -32, -29, -26, -22, -19, -15, -10
        ];
        local index = effect.frame - 2;
        if (index < 0) index = 0;
        if (index >= offsets.len()) index = offsets.len() - 1;
        return effect.y + offsets[index] + effect.spawnCarryYOffset;
    }
    // DrawFloateyNumber_Coin retains the coin's Y, then raises the number.
    local scoreIndex = effect.scoreFrame;
    if (scoreIndex < 0) scoreIndex = 0;
    return effect.y - 5.0 - floor(scoreIndex / 2.0);
}

function drawCoinEffect(g, effect) {
    if (effect.active) {
        if (effect.displayPhase == "coin") {
            // The misc object is initialized in RAM before its two OAM sprites
            // reach the visible DMA page.
            if (effect.frame <= 2) return;
            // JCoinGfxHandler selects $60-$63 directly from
            // (FrameCounter >> 1) & 3.  The visible DMA page is three counter
            // values behind the render-side counter at this capture point.
            local visibleCounter = (g.nesFrameCounter + 254) & 0xFF;
            local tileFrame = (visibleCounter >> 1) & 3;
            worldTexture(g, assets.items.jumpCoins[tileFrame],
                         effect.x,
                         coinEffectDrawY(effect), 8.0, 16.0);
        } else {
            worldTexture(g, assets.items.score200,
                         effect.displayX,
                         coinEffectDrawY(effect), 16.0, 8.0);
        }
    }
}

function drawEffects(g) {
    foreach (effect in g.archivedCoinEffects) drawCoinEffect(g, effect);
    drawCoinEffect(g, g.coinEffect);
    foreach (piece in g.brickDebris) {
        if (!piece.active) continue;
        worldTexture(g, assets.items.brickFragment,
                     floor(piece.x), floor(piece.y), 8.0, 8.0);
    }
    foreach (score in g.floatingScores) {
        if (score.age <= 0) continue;
        local texture = score.control == 1 ? assets.items.score100 :
                        (score.control == 2 ? assets.items.score200 :
                         (score.control == 3 ? assets.items.flagScores[3] : null));
        if (texture != null)
            // FloateyNumbersRoutine stores the baseline coordinate, subtracts
            // eight for OAM, and PPU sprite Y adds one visible scanline.
            screenTexture(texture, score.x,
                score.displayY-(score.displayY<24.0?8.0:7.0),16.0,8.0);
    }
    // FlagpoleScore becomes visible after the same two-stage OAM handoff as
    // the other enemy-object sprites.  It is composed before Mario, whose
    // lower OAM index masks the overlapping digits while he changes sides.
    if (g.flagScoreAge >= 1 && g.flagScoreIndex >= 0 && g.flagScoreIndex < 5)
        worldTexture(g, assets.items.flagScores[g.flagScoreIndex],
                     g.flagX + 12.0, g.displayFlagScoreY + 1.0, 16.0, 8.0);
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
    drawHudGlyphs([0x16, 0x0A, 0x1B, 0x12, 0x18], 24.0, 16.0); // MARIO
    drawHudNumber(g.displayScore, 6, 24.0, 24.0);
    local colorPhase = g.displayColorPhase;
    local hudCoinSet = g.area == "underground" ?
        assets.items.hudCoinsUnderground :
        (g.area == "castle" ? world14Assets.hudCoins : assets.items.hudCoins);
    screenTexture(hudCoinSet[colorPhase], 88.0, 24.0, 8.0, 8.0);
    screenTexture(assets.hudFont[0x29], 96.0, 24.0, 8.0, 8.0);
    drawHudNumber(g.displayCoins, 2, 104.0, 24.0);
    drawHudGlyphs([0x20, 0x18, 0x1B, 0x15, 0x0D], 144.0, 16.0); // WORLD
    drawHudGlyphs([g.world, 0x28, g.level], 152.0, 24.0);
    drawHudGlyphs([0x1D, 0x12, 0x16, 0x0E], 200.0, 16.0); // TIME
    if (!(parityIsEnabled() && g.parity.originPending) &&
        g.state != "nextStageLoad" && g.stageLoadFrames != 166 &&
        g.state != "areaExitEntrance")
        drawHudNumber(g.displayTime, 3, 208.0, 24.0,
            !(g.state == "timeBonus" || g.state == "raiseFlag" ||
              g.state == "fireworks" || g.state == "postClearDelay" ||
              g.state == "levelComplete"));

    if (g.state == "gameOver") {
        screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT, 0.0, 0.0, 0.0);
        drawHudGlyphs([0x10, 0x0A, 0x16, 0x0E, 0x24,
                       0x18, 0x1F, 0x0E, 0x1B], 92.0, 112.0);
    } else if (g.state == "levelComplete" && g.level != 3) {
        drawHudGlyphs([0x20, 0x18, 0x1B, 0x15, 0x0D], 88.0, 96.0);
        drawHudGlyphs([g.world, 0x28, g.level], 112.0, 112.0);
    } else if (g.state == "warpComplete") {
        drawHudGlyphs([0x20,0x18,0x1b,0x15,0x0d],88,96);
        drawHudGlyphs([g.warpWorld,0x28,1],112,112);
    }
}

function drawIntermediateLives(g) {
    screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT, 0.0, 0.0, 0.0);
    drawHudGlyphs([0x16, 0x0A, 0x1B, 0x12, 0x18], 24.0, 16.0);
    drawHudNumber(g.score, 6, 24.0, 24.0);
    screenTexture(assets.items.hudCoinLives, 88.0, 24.0, 8.0, 8.0);
    screenTexture(assets.hudFont[0x29], 96.0, 24.0, 8.0, 8.0);
    drawHudNumber(g.coins, 2, 104.0, 24.0);
    drawHudGlyphs([0x20, 0x18, 0x1B, 0x15, 0x0D], 144.0, 16.0);
    drawHudGlyphs([g.world, 0x28, g.level], 152.0, 24.0);
    drawHudGlyphs([0x1D, 0x12, 0x16, 0x0E], 200.0, 16.0);

    drawHudGlyphs([0x20, 0x18, 0x1B, 0x15, 0x0D, 0x24,
                  g.world, 0x28, g.level], 88.0, 80.0);
    if (!(g.state == "nextStageLoad" && g.stageLoadFrames >= 148))
        screenTexture(assets.mario.standRight, 96.0, 89.0, 16.0, 32.0);
    screenTexture(assets.hudFont[0x29], 120.0, 112.0, 8.0, 8.0);
    screenTexture(assets.hudFont[g.lives], 144.0, 112.0, 8.0, 8.0);
}

// saveFramePng reads the last presented frame, so the parity capture observes
// the preceding draw.  Advance the blanking windows accordingly; otherwise the
// staged area spawn leaks onto the screen as a one-frame teleport.
function areaTransitionOverlay(g) {
    if (g.state == "areaReload") {
        if (g.areaReloadTarget == "underground") {
            if (g.areaReloadFrames <= 3)
                return "sky";
            if (g.areaReloadFrames >= 4 && g.areaReloadFrames <= 25)
                return "black";
        } else {
            if (g.areaReloadFrames <= 22)
                return "black";
            if (g.areaReloadFrames >= 23 && g.areaReloadFrames <= 25)
                return "sky";
        }
        return null;
    }
    return null;
}

function renderGame(g) {
    gfx.clear();
    renderOffsetY=0.0;
    if (g.state == "nextStageLoad" && g.stageLoadFrames == 0 &&
        "loadingRenderCameraX" in g) {
        // The first loader pass keeps the completed World 1-3 nametable on
        // screen while LevelNumber has already advanced.
        local savedLevel = g.level;
        local savedState = g.state;
        local savedCameraX = g.cameraX;
        local savedDisplayCameraX = g.displayCameraX;
        local savedDead = g.player.dead;
        g.level = 3;
        g.state = "postClearDelay";
        g.cameraX = g.loadingRenderCameraX;
        g.displayCameraX = g.loadingRenderCameraX;
        g.player.dead = true;
        renderGame(g);
        g.player.dead = savedDead;
        g.displayCameraX = savedDisplayCameraX;
        g.cameraX = savedCameraX;
        g.state = savedState;
        g.level = savedLevel;
        return;
    }
    local world12EntryFrames=g.world12PipeMode=="side"?160:48;
    if (g.level == 2 && g.state == "world12Pipe" &&
        g.world12TransitionFrames > world12EntryFrames &&
        g.world12TransitionFrames < world12EntryFrames+27) {
        screenRect(0,0,LOGICAL_WIDTH,LOGICAL_HEIGHT,0,0,0);
        return;
    }
    local transitionOverlay = areaTransitionOverlay(g);
    if (transitionOverlay != null) {
        if (transitionOverlay == "black")
            screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT, 0.0, 0.0, 0.0);
        else
            screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT,
                       146.0 / 255.0, 144.0 / 255.0, 1.0);
        return;
    }
    if (g.state == "deathReload") {
        // Screen disable first exposes the previous sky backdrop, then the
        // intermediate lives nametable.  The final twelve-count disable wait
        // exposes its black universal background before area rendering resumes.
        if (g.deathReloadFrames <= 8) {
            screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT,
                       146.0 / 255.0, 144.0 / 255.0, 1.0);
        } else if (g.deathReloadFrames >= 149) {
            screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT,
                       0.0, 0.0, 0.0);
        } else {
            drawIntermediateLives(g);
        }
        return;
    }
    if (g.state == "nextStageLoad" && g.stageLoadFrames < 165) {
        if (g.stageLoadFrames <= 3) {
            screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT,
                       146.0 / 255.0, 144.0 / 255.0, 1.0);
        } else if (g.stageLoadFrames <= 8 || g.stageLoadFrames >= 149) {
            screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT,
                       0.0, 0.0, 0.0);
        } else {
            drawIntermediateLives(g);
        }
        return;
    }
    if (g.area == "underground" || g.area == "castle")
        screenRect(0.0, 0.0, LOGICAL_WIDTH, LOGICAL_HEIGHT, 0.0, 0.0, 0.0);
    renderOffsetY=g.displayBackgroundYOffset;
    drawBackground(g);
    drawLevelCoins(g);
    renderOffsetY=0.0;
    drawPowerUps(g, true);
    drawFireballs(g);
    if (g.level == 2) drawWorld12Actors(g, true);
    if (g.level == 3) drawWorld13Actors(g, true);
    if (g.level == 4) drawWorld14Actors(g, true);
    if(isWorld21(g)) drawWorld21Actors(g,true);
    // Pipe/entrance movement sets OAM priority bit 5 for Mario.  Draw him
    // before the background metatiles so non-transparent pipe/ground pixels
    // occlude the sprite exactly as the PPU does.
    local playerBehindBackground = g.state == "pipeDown" ||
        g.state == "pipeSide" || g.state == "areaExitEntrance" ||
        (g.level == 2 && g.state == "world12Pipe");
    local playerHidden = g.state == "areaReload";
    if (playerBehindBackground && !playerHidden) drawPlayer(g);
    renderOffsetY=g.displayBackgroundYOffset;
    drawTiles(g);
    renderOffsetY=0.0;
    drawPowerUps(g, false);
    if (g.area == "main") {
        if (!(g.level == 2 && g.stage == "intro")) drawFlag(g);
        drawCastle(g);
    }
    drawFireworks(g);
    local hudBeforeSprites=g.state!="gameOver" && g.state!="warpComplete" &&
        g.state!="levelComplete";
    if(hudBeforeSprites) {
        renderOffsetY=g.displayBackgroundYOffset;
        drawHud(g);
        renderOffsetY=0.0;
    }
    // Lower OAM indexes win sprite-over-sprite priority on the PPU.  Draw
    // higher enemy slots first so slot 0 is composited last by the host.
    for (local slot = 5; slot >= 0; slot -= 1)
        foreach (e in g.goombas)
            if (e.slot == slot || (!e.alive &&
                e.erasedDisplayFrames > 0 && e.erasedSlot == slot))
                drawEnemy(g, e);
    drawEffects(g);
    if (g.level == 2) drawWorld12Actors(g, false);
    if (g.level == 3) drawWorld13Actors(g, false);
    if (g.level == 4) drawWorld14Actors(g, false);
    if(isWorld21(g)) drawWorld21Actors(g,false);
    if (!playerBehindBackground && !playerHidden) drawPlayer(g);
    if(!hudBeforeSprites) drawHud(g);
}
