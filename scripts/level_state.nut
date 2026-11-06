// Fresh mutable area storage. Existing gameplay keeps its flat g.* API while
// ownership moves out of map decoding. Each call owns new arrays.
function createAreaState() {
    return {
        tiles=array(LEVEL_WIDTH*LEVEL_HEIGHT,TILE_EMPTY),
        goombas=[], powerups=[], fireballs=[], brickDebris=[], levelCoins=[],
        brickCoinTimer=0.0, brickCoinStarted=false
    };
}

function clearAreaObjects(g) {
    local fresh=createAreaState();
    foreach(key,value in fresh) g[key]=value;
}

function runAreaStateSelfTest() {
    local first=createGame(),second=createGame();
    local player=first.player;
    first.score=12345;first.coins=7;first.lives=2;first.cameraX=256.0;
    first.savedMain={tiles=clone first.tiles};
    local saved=first.savedMain;
    local otherTile=second.tiles[0];
    first.tiles[0]=TILE_USED;
    first.powerups.append({active=true});
    first.brickCoinTimer=10.0;first.brickCoinStarted=true;
    clearAreaObjects(first);
    requireSelfTest(first.tiles[0]==TILE_EMPTY && first.powerups.len()==0 &&
        first.brickCoinTimer==0.0 && !first.brickCoinStarted,
        "area reset must discard changed tiles, spawned objects and block timers");
    requireSelfTest(first.player==player && first.score==12345 && first.coins==7 &&
        first.lives==2 && first.cameraX==256.0 && first.savedMain==saved,
        "area reset must retain player, progress, camera and saved return area");
    first.tiles[0]=TILE_USED;first.powerups.append({active=true});
    requireSelfTest(second.tiles[0]==otherTile && second.powerups.len()==0,
        "different area instances must not share mutable tile/entity arrays");
    print("Area state self-test passed.\n");
}
