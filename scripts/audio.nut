function loadAudio() {
    if (nativeAudio != null) {
        nativeAudio.stopAll();
        nativeAudio.close();
    }
    local root = eve.Filesystem().getSource();
    local plugins = eve.Plugins();
    if (!plugins.load(root + "/native/bin/mario_audio.dll"))
        throw "Native audio plugin failed to load. Run tools/build_native_audio.ps1.";
    nativeAudio = eve.NativeAudio();
    local names = [
        "jump", "jump_big", "coin", "bump", "break", "powerup", "powerup_reveal",
        "oneup", "stomp", "kick", "fireball", "pipe", "death", "flag",
        "course_clear", "game_over", "blast", "overworld", "star", "underground",
        "hurry", "overworld_fast", "underground_fast", "star_fast", "timer_tick"
    ];
    foreach (name in names)
        nativeAudio.loadClip(name, root + "/assets/audio/" + name + ".wav");
    // Optional diagnostic input uses the identical runtime mixer/device path.
    if ("audioReferenceClip" in config)
        nativeAudio.loadClip("overworld", config.audioReferenceClip);
    nativeAudioCaptureTime = 0.0;
    hurryMusicTime = 0.0;
    if ("audioCaptureSeconds" in config && config.audioCaptureSeconds > 0)
        nativeAudio.beginCapture(config.audioCaptureSeconds);
    nativeAudio.open();
    nativeAudio.playMusic("overworld");
    musicState = "ground";
    print("NATIVE_AUDIO " + nativeAudio.status() + "\n");
}

function emitSound(g, name, variant = null) {
    local clip = name;
    if (name == "jump" && g.player.big) clip = "jump_big";
    if (name == "powerup" && variant == "reveal") clip = "powerup_reveal";
    g.soundEvents.append(clip);
    // Keep semantic replay events stable; the audio variant only selects PCM.
    parityRecordEvent(g, "audio", name);
}

function playSound(name) {
    if (nativeAudio == null) return;
    if (name == "death" || name == "course_clear" || name == "game_over")
        nativeAudio.playMusic(name);
    else
        nativeAudio.playEffect(name);
}

function stopMusic() {
    hurryMusicTime = 0.0;
    if (nativeAudio == null) return;
    nativeAudio.stopMusic();
    musicState = "stopped";
}

function resumeMusic(useStarMusic = false) {
    hurryMusicTime = 0.0;
    if (nativeAudio == null) return;
    local name = useStarMusic ? "star" :
        ((game != null && game.area == "underground") ? "underground" : "overworld");
    if (game != null && game.hurryActive) name += "_fast";
    nativeAudio.playMusic(name);
    musicState = useStarMusic ? "star" : "ground";
}

function startStarMusic() {
    resumeMusic(true);
}

function updateMusic(dt = 0.0) {
    if (nativeAudio == null) return;
    nativeAudio.verify();
    if (hurryMusicTime > 0.0) {
        hurryMusicTime -= dt;
        if (hurryMusicTime <= 0.0) resumeMusic(game.player.starMusicActive);
    }
    if ("audioCaptureSeconds" in config && config.audioCaptureSeconds > 0 &&
        nativeAudioCaptureTime >= 0.0) {
        nativeAudioCaptureTime += dt;
        if (nativeAudioCaptureTime >= config.audioCaptureSeconds + 0.2) {
            nativeAudio.finishCapture(config.audioCapturePath);
            print("NATIVE_AUDIO_CAPTURE " + nativeAudio.status() + "\n");
            nativeAudioCaptureTime = -1.0;
        }
    }
}

function flushSoundEvents(g) {
    foreach (name in g.soundEvents) {
        if (name == "hurry") {
            if (nativeAudio != null) nativeAudio.playMusic("hurry");
            hurryMusicTime = HURRY_WARNING_FRAMES / NES_FRAME_RATE;
            musicState = "hurry";
            continue;
        }
        if (name == "silence_music") { stopMusic(); continue; }
        if (name == "resume_music") { resumeMusic(g.player.starMusicActive); continue; }
        if (name == "star_music") { startStarMusic(); continue; }
        if (name == "death" || name == "flag" || name == "course_clear" ||
            name == "game_over" || name == "pipe") stopMusic();
        playSound(name);
    }
    g.soundEvents.clear();
}
