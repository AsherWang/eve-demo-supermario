#include "Mixer.h"
#include <array>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>

using namespace mario::audio;
void require(bool condition) { if (!condition) throw std::runtime_error("Mixer assertion failed"); }
int main(int argc, char** argv) {
    try {
        // Optional real-asset identity test: a single voice must preserve every sample.
        if (argc == 3) {
            auto clip = readWave(argv[1]);
            auto expected = clip.samples;
            Mixer mixer;
            mixer.load("reference", std::move(clip));
            mixer.play("reference", true);
            std::vector<std::int16_t> actual(expected.size());
            for (std::size_t i = 0; i < actual.size(); i += 960)
                mixer.render(std::span(actual).subspan(i, (std::min)(std::size_t(960), actual.size() - i)));
            require(actual == expected);
            require(mixer.clippedSamples() == 0);
            writeWave(argv[2], actual);
            require(readWave(argv[2]).samples == expected);
        }
        Mixer mixer;
        mixer.load("music", {{1, -1, 2, -2, 3, -3, 4, -4}});
        mixer.play("music", true);
        std::array<std::int16_t, 4> out{};
        mixer.render(out);
        require(out == std::array<std::int16_t, 4>{1, -1, 2, -2});
        mixer.load("effect", {{100, -100}});
        mixer.play("effect", false);
        mixer.render(out);
        require(out == std::array<std::int16_t, 4>{103, -103, 4, -4});
        mixer.render(out);
        require(out == std::array<std::int16_t, 4>{0, 0, 0, 0});
        mixer.play("music", true);
        mixer.play("effect", false);
        mixer.stopMusic();
        mixer.render(out);
        require(out == std::array<std::int16_t, 4>{100, -100, 0, 0});
        mixer.load("loud", {{32767, -32768}});
        mixer.play("loud", true);
        mixer.play("loud", false);
        mixer.render(out);
        require(out == std::array<std::int16_t, 4>{32767, -32768, 0, 0});
        require(mixer.clippedSamples() == 2);
        mixer.play("music", true);
        mixer.stopAll();
        mixer.render(out);
        require(out[0] == 0);
        bool rejected = false;
        try { mixer.play("missing", false); } catch (const std::runtime_error&) { rejected = true; }
        require(rejected);
        const auto fixture = std::filesystem::current_path() / "audio-mixer-fixture.wav";
        const std::array<std::int16_t, 4> extrema{32767, -32768, 0, -1};
        writeWave(fixture.string(), extrema);
        require(readWave(fixture.string()).samples == std::vector<std::int16_t>(extrema.begin(), extrema.end()));
        // Truncation must fail before a declared data chunk can be consumed.
        std::filesystem::resize_file(fixture, 46);
        rejected = false;
        try { (void)readWave(fixture.string()); } catch (const std::runtime_error&) { rejected = true; }
        require(rejected);
        writeWave(fixture.string(), extrema);
        {
            std::fstream file(fixture, std::ios::in | std::ios::out | std::ios::binary);
            file.seekp(20);
            file.put(3);  // IEEE float is not PCM16.
        }
        rejected = false;
        try { (void)readWave(fixture.string()); } catch (const std::runtime_error&) { rejected = true; }
        require(rejected);
        std::filesystem::remove(fixture);
        std::cout << "PASS: sample identity, continuity, stereo, mix, stop, EOF, clipping, invalid clip\n";
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        return 1;
    }
}
