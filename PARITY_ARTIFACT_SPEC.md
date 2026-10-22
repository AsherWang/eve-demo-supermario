# ROM 对照产物规范

本规范定义本地 NES 参考执行器与 EVEngine 复刻端之间的确定性接口。所有产物写入被 Git 忽略的 `local-parity/`；ROM、模拟器状态和 ROM 派生追踪不得进入发布包。

## 1. 输入录像：`smb-parity-movie-v1`

录像文件位于 `tests/parity/movies/*.json`，包含：

- `name`：稳定用例名，同时是产物目录名。
- `frames`：比较期逻辑帧数，必须大于零。
- `reference_bootstrap`：仅供原版进入正常控制状态；不属于比较时间轴。
- `inputs`：比较期内闭区间输入段；同一帧的按钮按位合并。
- `capture_frames`：需要输出 256×240 画面的检查点，必须包含最后一帧。

按钮位采用 NES 顺序：A、B、Select、Start、Up、Down、Left、Right。`tools/parity/common.py` 是格式校验与输入展开的实现。

## 2. 两端共同清单：`smb-parity-artifact-v1`

`reference/<case>/manifest.json` 与 `actual/<case>/manifest.json` 必须共同声明：

- `producer`；
- `movie` 与 `movie_sha256`；
- `comparison_frames`；
- 生成时间和端侧统计。

参考端额外记录 ROM SHA-256、Mesen 工具 SHA-256、RAM 检测出的比较原点和运行摘要。当前授权基线 ROM SHA-256 为 `f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`。

## 3. 参考端产物

目录：`local-parity/reference/<case>/`

- `frames/frame-NNNNNN.png`：Mesen 的检查点画面。
- `ram-trace.jsonl`：每个比较帧一行、完整 2 KiB 内部 RAM。
- `apu-writes.jsonl`：每帧 `$4000-$4017` 写入、帧内顺序、绝对 CPU 周期、
  master clock 和帧内 CPU 周期。
- `frame-timing.jsonl`：每个比较帧的 CPU/master clock 起止点和 CPU 周期数。
- `audio-queues.jsonl`：每帧 `$00fa-$00ff` 音频队列写入。
- `audio.wav`：参考模拟器 48 kHz、16-bit PCM 输出。
- `state.jsonl`：由 SMBDIS 地址映射生成的规范化语义状态。
- `events-semantic.jsonl`：由原版音频队列和 RAM 转换的语义事件。
- `origin.mss`、`origin-state.json`、最终 RAM/状态与诊断日志：只用于本地复现。

## 4. EVEngine 端产物

目录：`local-parity/actual/<case>/`

- `frames/frame-NNNNNN.png`：EVEngine 检查点画面。
- `state.jsonl`：每个比较帧一行，使用与参考端同义的字段；除玩家、对象、
  HUD 与流程状态外，还包含调色板轮换和 Area Parser/VRAM buffer 调度状态。
- `events.jsonl`：事件帧、帧内序号、类型和名称。
- `audio.wav`：检测专用的逐周期比较音频。Mesen/原 ROM 仅提供 CPU 周期写入
  时刻与 2A03 硬件响应；写入的寄存器值全部由复刻端 APU 模型提供。
- `audio.manifest.json`：声明周期来源、寄存器值来源、输入/输出哈希、WAV
  格式及回放状态计数。
- `apu-audio-replay.jsonl`：逐次记录原版写入、复刻端期望写入、实际注入值
  和状态；任何缺写、额外写入或地址错位都会使产物契约失败。
- `apu-writes.jsonl`：以参考第 0 帧声音 RAM 为起点、由复刻端事件驱动的
  `$4000-$4017` 写入模型；`$4014/$4016` 不属于音频比较范围。
- `manifest.json` 与运行日志。

确定性模式以一个 NTSC 逻辑帧为推进单位；当前帧的状态和所需截图写完后才推进下一帧。运行器结束时必须把 `scripts/generated/parity_movie.nut` 恢复为禁用状态。

## 5. 契约门禁

`validate_artifacts.py` 在执行比较前强制验证：

- 两端清单来自同一个录像哈希和帧数；
- 截图编号与 `capture_frames` 完全相等，无遗漏和额外旧文件；
- 参考 RAM 与实际状态时间轴为 `0..frames-1`，无缺帧、越界或重复；
- 参考帧周期时间轴连续，APU 写入包含有效的周期时间戳；
- 事件帧和帧内序号合法；
- 两端 WAV 可读、非空且为 16-bit PCM；
- 检测侧 PCM 清单哈希有效，且回放状态只能是数量完全匹配的 `injected`。

契约失败与“内容不一致”是不同问题：契约失败表示测试证据无效；内容不一致表示证据有效且确实检测到复刻偏差。

## 6. 比较报告

每个用例在 `local-parity/reports/<case>/` 生成：

- `artifact-report.*`：产物契约；
- `report.*` 与 `diff/`：256×240 RGB 像素比较和差异图；
- `state-report.*`：规范化字段逐帧比较；
- `event-report.*`：事件次数与发生帧比较；
- `audio-report.*`：严格 PCM、采样误差和 NES 帧包络偏移；
- `apu-report.*`：逐帧严格写入流、帧末寄存器状态和按声道归类的差异；
- `summary.json` 与 `index.html`：单用例总览。

`run_suite.py` 汇总所有用例到 `local-parity/reports/index.html`。严格结果只有在契约、画面、状态、事件、APU 写入和音频六项全部通过时才通过；不允许用已知差异清单把失败改写成成功。
