# ROM 参考对照测试计划

目标：NES 内核仅作为本地参考裁判，不进入 EVEngine 游戏和发布包。指定 ROM 与复刻版接收同一段比较期输入，测试工具自动找出首个画面、状态、事件或声音偏差。

## 架构

```text
movie.json
  ├─> Mesen 2 headless core + local ROM -> local-parity/reference/<case>
  └─> EVEngine deterministic mode      -> local-parity/actual/<case>
                                             |
                                      comparator/report.html
```

ROM、Mesen home、截图、WAV、RAM、状态和报告均位于 `local-parity/`，该目录被忽略且不得打入发布包。

## 执行顺序

- [x] 定义版本化输入录像格式，区分原版启动期和双方比较期。
- [x] 安装并校验无窗口 Mesen 参考工具；固定工具二进制哈希写入每次参考清单。
- [x] 实现参考运行器：ROM 哈希门禁、固定输入、逐帧/检查点截图、WAV、最终 RAM 和状态。
- [x] 实现 EVEngine 确定性模式：每次只推进一个 60.0988 Hz 逻辑帧，抓帧成功后才允许下一帧。
- [x] 实现 256×240 归一化、逐像素比较、差异图和 JSON/HTML 报告。
- [x] 找到 SHA-256 完全一致的本机 ROM 副本，跑通第一条真实双端测试并生成失败报告。
- [x] 用 SMBDIS RAM 状态自动检测正常玩家控制，保存 origin state 后再执行比较期输入。
- [x] 建立玩家定点运动、形态、落地状态、镜头、生命、分数、金币、时间、流程任务和首个栗宝宝运行槽的 SMBDIS 语义映射；四条录像共 2440 帧全部零差异。
- [x] 事件记录/比较框架已完成；四条用例的方块、金币、跳跃、管道、死亡、踩敌、旗杆和音乐切换事件均严格通过。
- [x] 已记录逐帧 APU 寄存器及原版音频队列写入，并加入严格 PCM 与 NES 帧包络/时移报告。
- [x] 建立完整 1200 帧 1-1 自然输入录像，以及走路、首次跳跃和死亡/重生边界用例。
- [x] 增加两端产物契约门禁、单用例总报告和四用例套件总览。

## 当前命令

```powershell
python tools\parity\run_case.py `
  --rom 'C:\path\to\Super Mario Bros. (World).nes' `
  --movie tests\parity\movies\walk-right-smoke.json

# 以下是 run_case.py 内部的可单独执行阶段：
python tools\parity\run_reference.py `
  --rom 'C:\path\to\超级玛丽.nes' `
  --movie tests\parity\movies\walk-right-smoke.json `
  --output local-parity\reference\walk-right-smoke

python tools\parity\run_actual.py `
  --movie tests\parity\movies\walk-right-smoke.json `
  --output local-parity\actual\walk-right-smoke

python tools\parity\compare_frames.py `
  --reference local-parity\reference\walk-right-smoke\frames `
  --actual local-parity\actual\walk-right-smoke\frames `
  --output local-parity\reports\walk-right-smoke

python tools\parity\extract_reference_state.py `
  --input local-parity\reference\walk-right-smoke\ram-trace.jsonl `
  --output local-parity\reference\walk-right-smoke\state.jsonl

python tools\parity\compare_states.py `
  --reference local-parity\reference\walk-right-smoke\state.jsonl `
  --actual local-parity\actual\walk-right-smoke\state.jsonl `
  --output local-parity\reports\walk-right-smoke

python tools\parity\extract_reference_events.py `
  --queues local-parity\reference\walk-right-smoke\audio-queues.jsonl `
  --ram-trace local-parity\reference\walk-right-smoke\ram-trace.jsonl `
  --output local-parity\reference\walk-right-smoke\events-semantic.jsonl

python tools\parity\compare_events.py `
  --reference local-parity\reference\walk-right-smoke\events-semantic.jsonl `
  --actual local-parity\actual\walk-right-smoke\events.jsonl `
  --output local-parity\reports\walk-right-smoke

# 运行全部用例；--reuse-reference 只重放 EVEngine，--skip-runs 只重建报告
python tools\parity\run_suite.py `
  --rom 'C:\path\to\Super Mario Bros. (World).nes' `
  --reuse-reference
```

产物字段与合法性约束见 [`PARITY_ARTIFACT_SPEC.md`](PARITY_ARTIFACT_SPEC.md)。

## 当前基线结果（2026-10-19）

- ROM SHA-256：`f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`。
- 原版正常控制起点由 RAM 状态检测为开机后第 194 帧，不使用固定秒数或肉眼猜测。
- 四条用例的产物契约全部通过；输入、清单、截图集合、完整时间轴、事件与 WAV 均可复验。
- 240、300、700 和 1200 帧状态报告全部通过，共 2440 帧；字段包含玩家定点状态、镜头、敌人槽、生命、分数、金币、时间和流程任务。
- 四条用例的事件报告全部严格通过；完整 1-1 的地下 9 枚场景金币、踩敌和低位旗杆/静音路径均已逐帧对齐。
- 零容差 RGB 仍失败；完整用例第 0 帧为 59,438/61,440 个像素不同，画面色彩/渲染链尚未对齐。
- 严格 PCM 仍失败；完整用例当前最佳 NES 帧包络偏移为 -1 帧、相关系数约 0.490。
- 因此严格总套件保持失败；这表示测试闭环有效并正在暴露真实剩余差异，而不是测试系统未运行。

下一轮按报告驱动：先统一 NES 调色板、PPU 背景/OAM 组合与裁边，使 RGB 首差异可局部定位；再以参考 APU 写入日志移植 SFX handler 和声道抢占，收敛 PCM 差异。

初始阶段预计不会通过；报告的作用是给出首个偏差帧和证据，而不是掩盖差异。只有调色板、裁边、时间原点和场景状态都固定后，像素比较才采用零容差作为最终门禁。
