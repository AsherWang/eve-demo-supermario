# EVEngine 音频接入改动说明

## 改动范围

本次基于 **EVEngine v0.6.0 Windows Release SDK**，没有修改 EVEngine 本体源码，
也不需要维护引擎 fork 或重新编译 `eve.exe`。改动是项目内的原生插件和游戏音频调用层：
通过引擎官方 `eve.Plugins()` 接口加载 `mario_audio.dll`，由插件自行播放 PCM。

这里的“修改源码”指新增 C++ 插件源码、替换游戏的音频接入代码，而不是给引擎
`sound` / `audio` 模块打补丁。引擎继续承担窗口、图形、输入和脚本执行。
此前准备的引擎源码检出没有产生补丁，不是此项目的构建依赖。

## 为什么调整

离线参考 WAV 与用户在游戏中听到的声音不一致，需要分别验证音源生成和播放链路。
旧链路使用历史合成 WAV，再经 `sound.newSoundDataFromFile` / `audio.newSource`
播放；新链路使用离线原版采集素材，并直接验证实际游戏提交给 Windows 的 PCM。
这不表示 EVEngine 普遍“不支持”音频，也不能仅凭这次替换认定旧模块是唯一噪声来源。

## 文件与职责

| 文件 | 改动 |
| --- | --- |
| `native/audio/NativeAudio.cpp` | 注册 `eve.NativeAudio`，管理 Windows waveOut、工作线程、缓冲区、诊断采集及关闭流程 |
| `native/audio/Mixer.h`、`Mixer.cpp` | WAV 读取、音乐/音效混音、PCM 写出与削波统计 |
| `native/audio/MixerTest.cpp`、`CMakeLists.txt` | 独立混音测试、官方插件 SDK 构建配置 |
| `config.nut` | 不再选择引擎 `sound`、`audio` 模块，保留 `gfx`、`keyboard` |
| `scripts/audio.nut` | 加载插件和素材，发送播放/停止命令，区分大小跳跃、道具出现/拾取音效 |
| `main.nut` | 保存插件实例，更新诊断状态，退出时关闭设备 |
| `scripts/simulation.nut` | 道具出现事件选择 reveal 音效，保持原有语义回放事件名称 |
| `tools/build_native_audio.ps1`、`package_windows.ps1` | 编译/测试插件，制作独立 Windows 游戏目录 |
| `tools/render_reference_audio_assets.py` | 离线运行 ROM 原版声音处理逻辑并采集音乐/音效 |
| `tools/check_native_audio.py` | 启动真实游戏并验证提交给 Windows 的音频缓冲区 |

## 播放约定与生命周期

插件使用 48 kHz、双声道、16-bit PCM；运行时素材保持原始样本，音乐和音效均为
单位增益，不额外重采样、滤波或归一化。混音溢出采取饱和处理并计数。
加载器也接受同采样率的单声道 PCM16，复制为双声道；不支持的格式直接报错。

播放线程使用 4 个 480 帧缓冲区，每个 10 ms，名义排队容量 40 ms（不是保证的
端到端延迟）。它独立于渲染线程补充音频，不在音频线程调用 Squirrel。
脚本命令与混音通过互斥锁同步。素材在开始播放前加载；退出/重载时停止线程、
等待线程退出、重置设备、解除缓冲区准备状态并关闭设备。

对外方法为 `loadClip`、`open`、`close`、`playMusic`、`playEffect`、`stopMusic`、
`stopAll`、`verify`、`status`、`beginCapture`、`finishCapture`。
`status` 提供已提交帧数、欠载次数、削波样本数和设备错误码。
插件缺失或设备出错会报告错误，不会静默回退到旧链路。

## 构建、运行和打包

前提：Windows x64、Visual Studio 2022 C++ Build Tools（含 CMake）、匹配的
EVEngine v0.6.0 Windows Release SDK。以下命令从仓库根目录执行：

```powershell
./tools/build_native_audio.ps1 -Sdk 'C:/path/to/eve-sdk/win32'
& 'C:/path/to/eve-sdk/win32/bin/eve.exe' run .

./tools/package_windows.ps1 -Sdk 'C:/path/to/eve-sdk/win32'
```

省略 `-Sdk` 时脚本使用本机用户目录下的 EVEngine SDK 缓存路径，见脚本默认参数。
默认编译目录为仓库外的 `../builds/super-mario-native-audio`；插件复制到已忽略的
`native/bin/mario_audio.dll`，同时生成 GUI 启动器 `native/bin/SuperMario.exe`。构建脚本会执行 CTest。

打包输出为仓库外 `../builds/super-mario-native-audio-<时间>-win64`，双击其中的
`SuperMario.exe`（或 `Play.cmd`）启动。启动器不会显示控制台；EVEngine 宿主位于
`runtime/eve.exe`，其输出写入 `game.log`。默认包包含 SDK 运行库、游戏脚本、素材和插件，不包含 ROM。
不要改名 `eve.exe`：SDK 导入库绑定该宿主名称。当前采用松散目录包，不支持直接
融合成单 EXE；外部 DLL/WAV 如需单文件分发还需另做解包和加载设计。

源码、测试、构建脚本和运行素材进入 Git；DLL、编译目录、ROM、模拟器存档、
本地报告及诊断 WAV 不提交。克隆后需要先构建插件。

## 对照证据与复测

2026-10-22，源码启动和独立 Windows 包均完成开场静止 10 秒验证：

- 对比 480,000 个双声道样本帧，提交的 PCM 与原版参考逐样本一致。
- 本次测得启动偏移为 0 帧，欠载、削波、设备错误均为 0。
- 参考 PCM SHA-256：`3055990253f227f674862c8cbd9261b687a87677a122635ada720dc6a90d4b73`。
- 混音单元测试通过；`walk-right-smoke`、`first-goomba-jump`、
  `first-powerup-mushroom` 三条回归通过。

复测命令（参考 WAV 需本地准备，不随仓库分发）：

```powershell
python tools/check_native_audio.py `
  --reference dist/smb-world-1-1-opening-idle-10s-original.wav `
  --use-game-assets
```

默认结果写入 `local-parity/native-audio-runtime/report.json`。省略
`--use-game-assets` 会替换开场音源为参考 WAV，仅隔离验证播放链路；保留该参数才会
验证当前游戏素材。使用 `--project` 和 `--eve` 可指定打包目录及其中的宿主。
测试只容许启动队列偏移，不修改音量或波形以提高匹配率。

证据边界是 **提交给 waveOut 的 PCM**，不是声卡回录，不覆盖 Windows 音效增强、
系统音量、设备重采样、DAC 或扬声器。开场测试通过不代表所有交互组合都逐周期一致。

## 素材来源及尚未完成的工作

当前音频由本地 ROM + Mesen 离线采集，采集请求、哈希、帧数和计时器冻结策略记录在
`assets/audio/oracle-audio-manifest.json`。运行游戏不依赖模拟器，不执行 ROM。
`generate_audio.py`、`render_smb_rom_music.py` 及旧 `rom-music-manifest.json`
保留为历史合成实验，不是当前运行素材的权威生成流程。

长音乐采集冻结游戏计时器以避免加速/死亡；当前地上音乐在第 700 帧之后冻结，
保证最初 10 秒仍能与未修改的静止参考比较。其他采集的策略以各条 manifest 为准。
冻结可能影响后续 CPU 时序，不能称整条长音轨为完整游戏的逐周期记录。

目前仍是独立预录片段混音，**没有**实现实时 NES 声道抢占、音乐/音效的非线性 APU
混音交互，也没有通用实时 APU PCM 输入接口。严格对齐的后续工作应移植已验证的
声音状态机和实时 2A03 合成器，接入该播放线程，再以交互轨迹逐样本验证。
不能用调整播放速度、滤波或主观听感代替这部分验证。

更详细的插件实现说明见 [native/audio/README.md](../native/audio/README.md)，
整体精确复刻边界见 [ORIGINAL_PARITY_CHECKLIST.md](../ORIGINAL_PARITY_CHECKLIST.md)。
