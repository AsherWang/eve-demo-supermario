#include "Mixer.h"
#pragma warning(push)
// EVEngine's installed SDK exports STL-bearing classes across its plugin ABI.
#pragma warning(disable: 4251 4100)
#include "common/Export.h"
#include "common/Module.h"
#include <simplesquirrel/simplesquirrel.hpp>
#pragma warning(pop)

#include <windows.h>
#include <mmsystem.h>

#include <array>
#include <algorithm>
#include <atomic>
#include <mutex>
#include <stdexcept>
#include <thread>

namespace eve::mario_audio {
using namespace ::mario::audio;
namespace {
constexpr unsigned bufferFrames = 480;
constexpr unsigned bufferCount = 4;
void check(MMRESULT result) {
    if (result == MMSYSERR_NOERROR) return;
    char message[MAXERRORLENGTH]{};
    waveOutGetErrorTextA(result, message, MAXERRORLENGTH);
    throw std::runtime_error(std::string("Windows audio: ") + message);
}
}

// The script owns commands; one native worker owns continuous PCM generation.
// No Squirrel or EVEngine audio calls occur on the worker. All buffers outlive
// waveOutReset/UnprepareHeader/Close, including failure and shutdown paths.
class NativeAudio : public eve::Module {
public:
    Module_REG(NativeAudio);
    NativeAudio() = default;
    ~NativeAudio() override { close(); }

    void loadClip(const std::string& clipName, const std::string& path) {
        auto clip = readWave(path);
        std::lock_guard lock(mutex_);
        mixer_.load(clipName, std::move(clip));
    }
    void playMusic(const std::string& clipName) {
        verify();
        std::lock_guard lock(mutex_);
        mixer_.play(clipName, true);
    }
    void playEffect(const std::string& clipName) {
        verify();
        std::lock_guard lock(mutex_);
        mixer_.play(clipName, false);
    }
    void stopMusic() {
        std::lock_guard lock(mutex_);
        mixer_.stopMusic();
    }
    void stopAll() {
        std::lock_guard lock(mutex_);
        mixer_.stopAll();
    }
    void open() {
        if (device_) { verify(); return; }
        event_ = CreateEventW(nullptr, FALSE, FALSE, nullptr);
        if (!event_) throw std::runtime_error("Cannot create Windows audio event");
        try {
            WAVEFORMATEX format{};
            format.wFormatTag = WAVE_FORMAT_PCM;
            format.nChannels = channels;
            format.nSamplesPerSec = sampleRate;
            format.wBitsPerSample = 16;
            format.nBlockAlign = channels * 2;
            format.nAvgBytesPerSec = sampleRate * format.nBlockAlign;
            check(waveOutOpen(&device_, WAVE_MAPPER, &format,
                              reinterpret_cast<DWORD_PTR>(event_), 0, CALLBACK_EVENT));
            for (unsigned i = 0; i < bufferCount; ++i) {
                headers_[i] = {};
                headers_[i].lpData = reinterpret_cast<char*>(buffers_[i].data());
                headers_[i].dwBufferLength = sizeof(buffers_[i]);
                check(waveOutPrepareHeader(device_, &headers_[i], sizeof(WAVEHDR)));
                ++prepared_;
            }
            error_ = MMSYSERR_NOERROR;
            submitted_ = 0;
            underruns_ = 0;
            running_ = true;
            worker_ = std::thread([this] { run(); });
        } catch (...) { close(); throw; }
    }
    void close() {
        running_ = false;
        if (event_) SetEvent(event_);
        if (worker_.joinable()) worker_.join();
        if (device_) {
            waveOutReset(device_);
            for (unsigned i = 0; i < prepared_; ++i)
                waveOutUnprepareHeader(device_, &headers_[i], sizeof(WAVEHDR));
            waveOutClose(device_);
            device_ = nullptr;
        }
        prepared_ = 0;
        if (event_) { CloseHandle(event_); event_ = nullptr; }
    }
    void verify() const {
        check(error_.load());
        if (!running_) throw std::runtime_error("Native audio is not open");
    }
    std::string status() {
        std::lock_guard lock(mutex_);
        return "backend=winmm-pcm rate=48000 channels=2 buffer_ms=40 submitted_frames=" +
            std::to_string(submitted_.load()) + " underruns=" + std::to_string(underruns_.load()) +
            " clipped_samples=" + std::to_string(mixer_.clippedSamples()) +
            " error=" + std::to_string(error_.load());
    }
    // Captures exactly the PCM handed to waveOut, before Windows device mixing.
    // Allocation occurs only here on the script thread; bounded to 60 seconds.
    void beginCapture(int seconds) {
        if (seconds < 1 || seconds > 60) throw std::runtime_error("Capture duration must be 1..60 s");
        std::vector<std::int16_t> buffer(static_cast<std::size_t>(seconds) * sampleRate * channels);
        std::lock_guard lock(mutex_);
        capture_ = std::move(buffer);
        captured_ = 0;
    }
    void finishCapture(const std::string& path) {
        std::vector<std::int16_t> buffer;
        {
            std::lock_guard lock(mutex_);
            capture_.resize(captured_);
            buffer.swap(capture_);
            captured_ = 0;
        }
        writeWave(path, buffer);
    }

private:
    void run() noexcept {
        bool started = false;
        while (running_) {
            unsigned available = 0;
            for (const auto& header : headers_)
                if (!(header.dwFlags & WHDR_INQUEUE)) ++available;
            if (started && available == bufferCount) ++underruns_;
            for (unsigned i = 0; i < bufferCount && running_; ++i) {
                if (headers_[i].dwFlags & WHDR_INQUEUE) continue;
                {
                    std::lock_guard lock(mutex_);
                    mixer_.render(buffers_[i]);
                    const auto count = (std::min)(buffers_[i].size(), capture_.size() - captured_);
                    std::copy_n(buffers_[i].begin(), count, capture_.begin() + captured_);
                    captured_ += count;
                }
                const auto result = waveOutWrite(device_, &headers_[i], sizeof(WAVEHDR));
                if (result != MMSYSERR_NOERROR) { error_ = result; running_ = false; break; }
                submitted_ += bufferFrames;
            }
            started = true;
            WaitForSingleObject(event_, 10);
        }
    }
    Mixer mixer_;
    std::mutex mutex_;
    HWAVEOUT device_ = nullptr;
    HANDLE event_ = nullptr;
    std::thread worker_;
    std::atomic<bool> running_{false};
    std::atomic<MMRESULT> error_{MMSYSERR_NOERROR};
    std::atomic<std::uint64_t> submitted_{0}, underruns_{0};
    std::array<WAVEHDR, bufferCount> headers_{};
    std::array<std::array<std::int16_t, bufferFrames * channels>, bufferCount> buffers_{};
    unsigned prepared_ = 0;
    std::vector<std::int16_t> capture_;
    std::size_t captured_ = 0;
};

Module_IMPL(NativeAudio, new NativeAudio());
void NativeAudio::expose(ssq::Table& table) {
    auto cls = table.addClass(name, NativeAudio::create, false);
    expose(cls);
}
void NativeAudio::expose(ssq::Class& cls) {
    cls.addFunc("loadClip", &NativeAudio::loadClip);
    cls.addFunc("open", &NativeAudio::open);
    cls.addFunc("close", &NativeAudio::close);
    cls.addFunc("playMusic", &NativeAudio::playMusic);
    cls.addFunc("playEffect", &NativeAudio::playEffect);
    cls.addFunc("stopMusic", &NativeAudio::stopMusic);
    cls.addFunc("stopAll", &NativeAudio::stopAll);
    cls.addFunc("verify", &NativeAudio::verify);
    cls.addFunc("status", &NativeAudio::status);
    cls.addFunc("beginCapture", &NativeAudio::beginCapture);
    cls.addFunc("finishCapture", &NativeAudio::finishCapture);
}
}  // namespace eve::mario_audio

EVE_PLUGIN_EXPORT int eve_plugin_init() { return 0; }
