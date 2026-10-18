function loadAudio() {
    if (soundSources != null) return;
    soundSources = {};
    local names = [
        "jump", "coin", "bump", "break", "powerup", "oneup", "stomp",
        "kick", "fireball", "pipe", "death", "flag", "course_clear",
        "game_over", "blast", "overworld_intro", "overworld", "star"
    ];
    foreach (name in names) {
        local data = sound.newSoundDataFromFile("assets/audio/" + name + ".wav");
        local source = audio.newSource(data);
        source.setRelative(true);
        local isMusic = name == "overworld_intro" || name == "overworld" ||
                        name == "star" || name == "death" ||
                        name == "course_clear" || name == "game_over";
        source.setVolume(isMusic ? 0.42 : 0.58);
        soundSources[name] <- source;
    }
    soundSources.overworld.setLooping(true);
    soundSources.star.setLooping(true);
    soundSources.overworld_intro.play();
    musicState = "ground_intro";
}

function emitSound(g, name) {
    g.soundEvents.append(name);
    parityRecordEvent(g, "audio", name);
}

function playSound(name) {
    if (soundSources == null || !(name in soundSources)) return;
    local source = soundSources[name];
    source.stop();
    source.play();
}

function stopMusic() {
    if (soundSources == null) return;
    soundSources.overworld_intro.stop();
    soundSources.overworld.stop();
    soundSources.star.stop();
    musicState = "stopped";
}

function resumeMusic(useStarMusic = false) {
    if (soundSources == null) return;
    if (useStarMusic) {
        soundSources.overworld_intro.stop();
        soundSources.overworld.stop();
        if (!soundSources.star.isPlaying()) soundSources.star.play();
        musicState = "star";
    } else {
        soundSources.star.stop();
        soundSources.overworld.stop();
        soundSources.overworld_intro.stop();
        soundSources.overworld_intro.play();
        musicState = "ground_intro";
    }
}

function startStarMusic() {
    if (soundSources == null) return;
    soundSources.overworld_intro.stop();
    soundSources.overworld.stop();
    soundSources.star.stop();
    soundSources.star.play();
    musicState = "star";
}

function updateMusic() {
    if (soundSources == null || musicState != "ground_intro") return;
    if (soundSources.overworld_intro.isPlaying()) return;
    soundSources.overworld.stop();
    soundSources.overworld.play();
    musicState = "ground_loop";
}

function flushSoundEvents(g) {
    foreach (name in g.soundEvents) {
        if (name == "silence_music") {
            stopMusic();
            continue;
        }
        if (name == "resume_music") {
            resumeMusic(g.player.starMusicActive);
            continue;
        }
        if (name == "star_music") {
            startStarMusic();
            continue;
        }
        if (name == "death" || name == "flag" || name == "course_clear" ||
            name == "game_over" || name == "pipe") stopMusic();
        playSound(name);
    }
    g.soundEvents.clear();
}
