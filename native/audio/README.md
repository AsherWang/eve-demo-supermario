# Windows native audio

The game loads `native/bin/mario_audio.dll` through EVEngine's official
`eve.Plugins()` API. EVEngine v0.6.0 itself is unchanged. Its audio and sound
modules are no longer selected in `config.nut`.

`NativeAudio.cpp` owns a Windows waveOut device and four 10 ms buffers. A native
worker fills those buffers independently of rendering. `Mixer.cpp` is the single
PCM mixer used by playback and the sample-identity test. Music and effects use
unity gain, preserve the stereo PCM16 samples, and saturate rather than wrap on
overflow. Counters expose underruns, clipping and device errors. Commands and
rendering share a mutex; file loading occurs before playback. Shutdown joins the
worker, resets the device, unprepares the buffers, then closes the handle.

Build the DLL against the matching **Release Windows SDK**:

```powershell
./tools/build_native_audio.ps1
```

Build output stays outside the project in `../builds/super-mario-native-audio`.
The generated DLL is copied into the ignored `native/bin` directory. The build
uses the official SDK import library, MSVC's Release CRT, and Windows `winmm`.
It does not download or compile another engine or emulator.

The executable is still named `eve.exe` because the SDK import library binds
the plugin to that host name. Package the game as a loose directory using
`tools/package_windows.ps1`; a fused single EXE cannot load this external DLL
and loose WAV files without a separate extraction/loading implementation.

## What has and has not been verified

`audio_mixer_test` verifies sample continuity across buffer boundaries, stereo,
music/effect mixing, stop/restart, EOF, saturation, WAV round trips, unsupported
formats and truncated files.

`tools/check_native_audio.py` launches the actual game with a temporary diagnostic
configuration. It captures the **same PCM buffers submitted to Windows** and
compares them byte for byte with a reference, allowing only startup queue delay.
It also requires zero underruns, clipping and device errors. With
`--use-game-assets`, the game's normal overworld clip is tested; without it, the
reference WAV is substituted to isolate playback from asset generation.

```powershell
python tools/check_native_audio.py `
  --reference dist/smb-world-1-1-opening-idle-10s-original.wav `
  --use-game-assets
```

This boundary excludes Windows enhancements, system volume, resampling by the
device, DAC and speakers. It is not a physical loopback recording.

## Asset provenance and remaining parity work

`tools/render_reference_audio_assets.py` uses the local ROM and Mesen **offline**
to run the original sound handler and capture PCM. Queue addresses and values,
ROM/emulator/state hashes, sample counts and file hashes are recorded in
`assets/audio/oracle-audio-manifest.json`. No synthesized note durations,
hand-tuned sweeps, gain normalization or filters are applied afterward.

The opening uses the normal controllable-game state. Long music captures freeze
the gameplay timer after frame 700 to prevent hurry/death; this changes later
CPU execution timing, so the complete long clip is not a cycle-exact gameplay
trace. The initial 10 seconds can be compared against the unmodified idle oracle.
Other clips start from a settled silent state and inject one original sound
queue request. Each manifest entry records the timer-freeze policy used for its
capture (earlier captures froze it from the beginning). Small/large jump and powerup appearance/collection have distinct
clips and runtime dispatch.

This backend currently mixes **isolated pre-rendered clips**. It does not run
6502/PPU/APU code, does not emulate NES channel stealing, and cannot reproduce
the nonlinear APU mixer interactions between simultaneous music and SFX.
The next strict-parity step is to port the already tested sound state machine
and feed a real-time 2A03 synthesizer into this playback worker. A PCM playback
test passing does not mean that work is complete.
