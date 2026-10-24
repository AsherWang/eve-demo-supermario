function runKoopaBounceSelfTest() {
    local g=createGame(),p=g.player,e=makeEnemyAt(128.0,12,"koopa");
    g.goombas=[e];e.awake=true;e.slot=0;g.nesFrameCounter=0;
    p.x=128;p.y=180;p.grounded=false;p.entranceFalling=false;
    p.nesYSpeed=3;p.nesYMoveForce=254;p.nesYDummy=0;
    p.fallForce=112;p.jumpOriginY=192;
    foreach(expected in KOOPA_BOUNCE_TRACE) {
        simulateFixed(g,FIXED_DT);
        requireSelfTest(p.y-16==expected[0] && p.nesYSpeed==expected[1] &&
                        p.nesYMoveForce==expected[2] && p.nesYDummy==expected[3],
                        "koopa rebound must preserve the ROM 40-frame fixed-point trajectory");
        local expectedState=(expected[4]&128)!=0?"shellMoving":"shell";
        requireSelfTest(e.state==expectedState,
                        "recontact must kick a stationary shell at the ROM frame without another bounce");
        requireSelfTest(!p.dead,"the same continuous shell contact must not injure Mario twice");
    }
}
