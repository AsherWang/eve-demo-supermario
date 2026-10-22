#pragma once

#include <cstdint>
#include <map>
#include <memory>
#include <span>
#include <string>
#include <vector>

namespace mario::audio {

constexpr unsigned sampleRate = 48000;
constexpr unsigned channels = 2;

// Immutable, interleaved signed 16-bit stereo PCM at 48 kHz.
struct Clip {
    std::vector<std::int16_t> samples;
};

// Reject unsupported formats instead of silently resampling or guessing headers.
Clip readWave(const std::string& path);
void writeWave(const std::string& path, std::span<const std::int16_t> samples);

// Owner-thread only. NativeAudio serializes calls with its render worker.
// Rendering never opens files, allocates buffers, or calls script code.
class Mixer {
public:
    void load(const std::string& name, Clip clip);
    void play(const std::string& name, bool music);
    void stopMusic();
    void stopAll();
    void render(std::span<std::int16_t> output);
    std::uint64_t clippedSamples() const { return clipped_; }

private:
    struct Voice {
        std::shared_ptr<const Clip> clip;
        std::size_t cursor = 0;
    };
    std::map<std::string, std::shared_ptr<const Clip>> clips_;
    Voice music_;
    // Original runtime restarts the same effect; fixed voices bound mixing cost.
    std::map<std::string, Voice> effects_;
    std::uint64_t clipped_ = 0;
};
}  // namespace mario::audio
