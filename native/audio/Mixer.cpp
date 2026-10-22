#include "Mixer.h"

#include <algorithm>
#include <array>
#include <fstream>
#include <limits>
#include <stdexcept>

namespace mario::audio {
namespace {
std::uint32_t u32(const unsigned char* p) {
    return p[0] | (std::uint32_t(p[1]) << 8) | (std::uint32_t(p[2]) << 16) |
           (std::uint32_t(p[3]) << 24);
}
unsigned u16(const unsigned char* p) { return p[0] | (unsigned(p[1]) << 8); }
void put(std::ostream& out, std::uint32_t value, int bytes) {
    for (int i = 0; i < bytes; ++i) out.put(static_cast<char>((value >> (8 * i)) & 255));
}
void read(std::istream& in, unsigned char* bytes, std::size_t count) {
    if (!in.read(reinterpret_cast<char*>(bytes), static_cast<std::streamsize>(count)))
        throw std::runtime_error("Truncated WAV");
}
}

Clip readWave(const std::string& path) {
    std::ifstream in(path, std::ios::binary);
    std::array<unsigned char, 12> header{};
    read(in, header.data(), header.size());
    if (u32(header.data()) != 0x46464952 || u32(header.data() + 8) != 0x45564157)
        throw std::runtime_error("Expected RIFF/WAVE: " + path);
    unsigned sourceChannels = 0;
    bool formatSeen = false;
    while (in.peek() != std::char_traits<char>::eof()) {
        std::array<unsigned char, 8> chunk{};
        read(in, chunk.data(), chunk.size());
        auto size = u32(chunk.data() + 4);
        if (u32(chunk.data()) == 0x20746d66) {
            if (size < 16) throw std::runtime_error("Invalid WAV format chunk");
            std::array<unsigned char, 16> fmt{};
            read(in, fmt.data(), fmt.size());
            sourceChannels = u16(fmt.data() + 2);
            if (u16(fmt.data()) != 1 || (sourceChannels != 1 && sourceChannels != 2) ||
                u32(fmt.data() + 4) != sampleRate || u16(fmt.data() + 14) != 16 ||
                u16(fmt.data() + 12) != sourceChannels * 2 ||
                u32(fmt.data() + 8) != sampleRate * sourceChannels * 2)
                throw std::runtime_error("WAV must be 48 kHz PCM16 mono/stereo: " + path);
            formatSeen = true;
            in.seekg(static_cast<std::streamoff>(size - 16 + (size & 1)), std::ios::cur);
        } else if (u32(chunk.data()) == 0x61746164) {
            if (!formatSeen || size == 0 || size % (sourceChannels * 2) != 0 ||
                size > sampleRate * channels * 2 * 1800)
                throw std::runtime_error("Invalid or oversized WAV PCM chunk");
            // Validate file extent before allocating from an untrusted chunk size.
            auto start = in.tellg();
            in.seekg(0, std::ios::end);
            if (in.tellg() - start < size) throw std::runtime_error("Truncated WAV PCM");
            in.seekg(start);
            std::vector<unsigned char> bytes(size);
            read(in, bytes.data(), size);
            Clip result;
            result.samples.reserve(size / sourceChannels);
            for (std::size_t i = 0; i < size; i += 2) {
                auto sample = static_cast<std::int16_t>(u16(bytes.data() + i));
                result.samples.push_back(sample);
                if (sourceChannels == 1) result.samples.push_back(sample);
            }
            return result;
        } else {
            in.seekg(static_cast<std::streamoff>(size) + (size & 1), std::ios::cur);
        }
        if (!in) throw std::runtime_error("Invalid WAV chunk extent");
    }
    throw std::runtime_error("WAV has no PCM data: " + path);
}

void writeWave(const std::string& path, std::span<const std::int16_t> samples) {
    if (samples.size() % channels != 0 || samples.size() > (UINT32_MAX - 36) / 2)
        throw std::runtime_error("Invalid WAV output length");
    std::ofstream out(path, std::ios::binary);
    const auto bytes = static_cast<std::uint32_t>(samples.size() * 2);
    out.write("RIFF", 4); put(out, bytes + 36, 4); out.write("WAVEfmt ", 8);
    put(out, 16, 4); put(out, 1, 2); put(out, channels, 2); put(out, sampleRate, 4);
    put(out, sampleRate * channels * 2, 4); put(out, channels * 2, 2); put(out, 16, 2);
    out.write("data", 4); put(out, bytes, 4);
    for (auto sample : samples) put(out, static_cast<std::uint16_t>(sample), 2);
    if (!out) throw std::runtime_error("Cannot write WAV: " + path);
}

void Mixer::load(const std::string& name, Clip clip) {
    if (name.empty() || clip.samples.empty() || clip.samples.size() % channels != 0)
        throw std::runtime_error("Invalid clip");
    clips_[name] = std::make_shared<const Clip>(std::move(clip));
    effects_.try_emplace(name);
}
void Mixer::play(const std::string& name, bool music) {
    auto found = clips_.find(name);
    if (found == clips_.end()) throw std::runtime_error("Unknown audio clip: " + name);
    auto& voice = music ? music_ : effects_.at(name);
    voice = {found->second, 0};
}
void Mixer::stopMusic() { music_ = {}; }
void Mixer::stopAll() {
    stopMusic();
    for (auto& [name, voice] : effects_) { (void)name; voice = {}; }
}
void Mixer::render(std::span<std::int16_t> output) {
    if (output.size() % channels != 0) throw std::runtime_error("Partial PCM frame");
    for (auto& sample : output) {
        std::int64_t mixed = 0;
        auto add = [&](Voice& voice) {
            if (voice.clip && voice.cursor < voice.clip->samples.size())
                mixed += voice.clip->samples[voice.cursor++];
        };
        add(music_);
        for (auto& [name, voice] : effects_) { (void)name; add(voice); }
        if (mixed > 32767 || mixed < -32768) ++clipped_;
        sample = static_cast<std::int16_t>(std::clamp<std::int64_t>(mixed, -32768, 32767));
    }
}
}  // namespace mario::audio
