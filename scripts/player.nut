// Player runtime state. Movement remains in simulation.nut during incremental migration.
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
