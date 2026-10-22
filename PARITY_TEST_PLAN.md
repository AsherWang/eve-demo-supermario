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
- [x] 建立玩家定点运动、形态、落地状态、镜头、生命、分数、金币、时间、流程任务、道具和首个栗宝宝运行槽的 SMBDIS 语义映射；七条录像共 4260 帧全部零差异。
- [x] 事件记录/比较框架已完成；七条用例的方块、金币、强化道具、跳跃、管道、死亡、踩敌、旗杆和音乐切换事件均严格通过。
- [x] 已记录逐帧 APU 寄存器及原版音频队列写入，并加入严格 PCM 与 NES 帧包络/时移报告。
- [x] 已记录参考端绝对 CPU 周期和逐帧周期边界；把复刻端 APU 值按原写入
  周期注入 Mesen 2A03，严格比较 48 kHz PCM。
- [x] 建立完整 1200 帧 1-1 自然输入录像，以及走路、首次跳跃、首次强化块和死亡/重生边界用例。
- [x] 增加两端产物契约门禁、单用例总报告和七用例套件总览。

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

## 当前基线结果（2026-10-22）

- ROM SHA-256：`f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`。
- 原版正常控制起点由 RAM 状态检测为开机后第 194 帧，不使用固定秒数或肉眼猜测。
- 七条用例的产物契约全部通过；输入、清单、截图集合、完整时间轴、事件、APU 写入与 WAV 均可复验。
- 240、300、240、700、300、1200 和 1280 帧状态报告全部通过，共 4260 帧；字段包含玩家定点状态、镜头、敌人槽、强化道具、生命、分数、金币、时间和流程任务。
- 七条用例的事件报告全部严格通过；新增第一只栗宝宝直接踩踏路线，验证反弹定点余数、21 帧敌人间隔计时器、计分显示和 OAM 消失时序；完整 1-1 的地下 9 枚场景金币、踩敌、低位和高位旗杆路径也已逐帧对齐。
- 七条用例的全部采样截图均以零容差 RGB 通过；两条完整 1-1 路线包含结算阶段连续帧采样。
- `ColorRotateOffset`、`ScrollThirtyTwo`、`AreaParserTaskNum` 与 `VRAM_Buffer_AddrCtrl` 已进入逐帧状态门禁，覆盖卷屏列更新、管道切换、地下金币擦除、死亡重载和地上/地下调色板包选择。
- 以参考第 0 帧声音 RAM 为起点、之后仅由复刻端事件和状态驱动的 APU 模型，在七条用例的全部 4260 帧中严格复现原版 `$4000-$4017` 写入顺序和值。
- 七条用例的检测侧 48 kHz、16-bit PCM 全部逐采样一致：首个差异为空、
  MAE 为 0、相关系数为 1.0。
- 产物、画面、状态、事件、APU 写入和 PCM 六项门禁全部通过。
- 周期歧义分析覆盖 2737 个有 APU 写入的非初始帧：404 种相同地址/值/顺序模板中，187 种对应多个绝对周期日程，73 种连帧内写入间距也不同；报告位于 `local-parity/reports/apu-cycle-ambiguity.json`。

PCM 检测使用“周期载体”方式：原 ROM 执行只提供真实 CPU 写入时刻，Mesen
提供 2A03 非线性混音与滤波；内存回调在写入 APU 前用复刻端模型值替换原值。
回放清单要求每次地址一一对应，缺写、额外写入和地址错位均直接失败。因此
PCM 通过不能由原 ROM 偷带寄存器值获得。

下一轮继续扩大状态机、对象槽和 PPU 边界录像覆盖，并把已经验证的 APU
写入模型接入 EVEngine 的交互运行时。检测内核只作为本地裁判，不进入游戏
或发布包；运行时当前仍使用 WAV，不能把“检测侧逐采样通过”表述为“游戏内
音频已经逐周期实现”。

初始阶段预计不会通过；报告的作用是给出首个偏差帧和证据，而不是掩盖差异。只有调色板、裁边、时间原点和场景状态都固定后，像素比较才采用零容差作为最终门禁。
