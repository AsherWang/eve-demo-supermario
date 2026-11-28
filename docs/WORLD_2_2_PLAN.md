# World 2-2 开发与验证

## 2026-11-28 主分支集成更新

本关已接入主分支，正常入口整关、跨关和原生逐帧验证以 [World 2 集成记录](WORLD_2_INTEGRATION.md) 为准。下方工作树报告与待集成说明属于历史证据；严格原版六项验收仍未通过。

Updated: 2026-11-28.

## Continuous host route and water interactions

**The host now completes a fixed normal-entrance route. Strict whole-level
parity remains pending.** `tests/parity/movies/world-2-2-normal-route.json`
contains 3,436 frames. Ordinary `createGame(); startLevel(g,2,2)` supplies the
entrance; frame zero observes it unchanged. All later gameplay uses controller
masks and `simulateFixed` only. There are no player, camera, RNG, enemy, or
state edits, checkpoint starts, teleports, or invulnerability during replay.

| Milestone | Host frame |
| --- | ---: |
| Normal surface entrance | 0 |
| Water control | 294 |
| Side-pipe entry | 2377 |
| Surface exit control | 2660 |
| Flag slide | 2810 |
| Castle settlement (`levelComplete`) | 3435 |

Small Mario retains three lives, collects six coins, visits all 12 water pages
and all three whirlpools, encounters Blooper and Cheep-Cheep slots, and finishes
with 18,550 points. The movie stops at settlement; next-stage transition is
parent-owned. Segmented tests accept registered 2-3 and preserve progress and
powers. Surface-exit death is checked on a separate 2-2 game.

### Repeatable validation

- `python tools/run_world22_regressions.py --output local-parity/world22-route/regression`
  checks the unchanged 1,800-frame motion/enemy fixture, segmented flows,
  projectile/bubble regressions, and the complete route. Either failure fails
  the command.
- `python tools/run_world22_route.py --output local-parity/world22-route/whole-course`
  writes every state, ordered transitions, milestones, source hashes, and
  movie hash. Removing all A inputs was verified to fail: Mario remains at
  x=162, does not cover page 1, and does not settle. Port-two and checkpoint
  movies are rejected.
- `python tools/parity/diagnose_world22_route.py --output local-parity/world22-route/original --capture-lock D:/workspace/eve-demos/super-mario/local-parity/gpu-capture.lock --actual local-parity/world22-route/regression/whole-route/state.jsonl`
  selects the original surface area before initialization, then captures the
  entire continuous movie without further RAM writes. It writes diagnostic
  results, not an acceptance manifest or restored-state replay proof.
- `python tools/parity/capture_world22_route.py --output local-parity/world22-route/native --capture-lock D:/workspace/eve-demos/super-mario/local-parity/gpu-capture.lock`
  uses an isolated wrapper project with ordinary stage initialization and fixed
  inputs. It modifies no shared source and skips parity-origin friction/counter
  patches. It captures silently, so it cannot establish audio acceptance.
  Both capture tools require fresh output directories, atomically claim the
  shared lock, and remove only their own token in `finally`. Busy locks exit 75.

Evidence is in `local-parity/world22-route/`, including `committed-regression/`,
`world1-regressions/`, `negative-no-swim/`, and `original-final/`.
`assets/world22/route-diagnostic.json` preserves the movie hash and compact
observed results. Large raw evidence stays ignored. All 10 pre-existing
World 1/campaign simulation suites pass.

Final native evidence is `native-final/`: 3,436 PNGs and all 3,436 decoded states
exactly equal the headless replay. Screenshots were reviewed at water midcourse,
side-pipe entry, and final settlement. The zero-tolerance original frame
comparison (`committed-frame-comparison/`) fails all 3,436 frames, with zero missing
frames. `native2/` preserves an earlier wrapper omission of sky initialization;
`native3/` preserves the transient SDK Vulkan `VK_INCOMPLETE` startup failure.
Neither is substituted for the corrected successful capture.
The final reference and native captures were regenerated from the committed LF
movie bytes (SHA-256 `928ccfe2947901ba94230e2809de54f056c329690da4d972e32f2a4904fb1a34`).
Earlier CRLF-movie captures remain diagnostic history; their old byte hashes
are not relabeled as current evidence.


The 43 Python tests pass with the three motion movies restored locally to the
**exact CRLF bytes** hashed by `world22_motion.json`. A clean LF checkout
currently fails their hash assertion (42/43 pass). This pre-existing mismatch
is not hidden by accepting multiple hashes or updating the fixture manifest.
The fixture trajectories and manifests remain unchanged. Parent integration
can pin those three existing movie paths to `text eol=crlf` in root
`.gitattributes`; new route movies use normal repository LF.

### Water-specific additions

- Fireballs now check the five water enemy slots after shared projectile motion
  and terrain collision, before water enemy motion. Alternate-frame contact
  skips dead/offscreen enemies, explodes the projectile, awards 200 points once,
  and emits the existing kick sound event. Defeated swimmers use the source's
  -1 water launch speed, two-pixel lift, $0f gravity, and vertical death graphics.
  Tests cover all three enemy types, repeated hits, harmless defeated contact,
  and eventual slot cleanup. Full OAM/death trajectories are not claimed exact.
- Three bubbles share the original 32/64-frame timer and $ff/$50 fractional
  rise amounts. Reverse slot order, mouth origin, surface retirement, transform
  freeze, and area reset are covered. They read the existing random register
  without advancing it. CHR $74/palette 2 and death sprites are reproducibly
  extracted by `tools/extract_world22.py`; runtime has no ROM dependency.
- `startWorld22Water` queues `resume_music` and records `water` at actual entry
  or reload. Only the existing water-origin probe passes `recordMusic=false`
  to avoid duplicate origin music events. Parent owns water tracks, shared
  `resumeMusic`, star expiry, and removal of preview `stopMusic()`.

These changes preserve the 1,800-frame selected-motion fixture and the new
successful route. No shared runtime, audio assets/tools, release/version, or
acceptance registry is committed by this worker.

### Original diagnostics and remaining failures

Original capture contains **3,436 states and 3,436 PNGs**, from normal entrance
engine task 7 detected at bootstrap frame 66. Selected player x/y/speed/grounded
comparison reports **11,833 differences**: speed differs at frame 0 and position
at frame 1. Host entrance walks one pixel/frame; the original accelerates.
Original water control starts at **393**, host at **294**. With identical
inputs, the ROM stalls near x=1234, enters death at **2953**, loses a life at
**3189**, and ends at x=93 with two lives. It does not complete the course.
The exact short swim fixtures do not establish normal-entrance timing.

Required next work: reconcile entrance/loading timing; find a successful shared
original/host route; compare complete frames, enemy/OAM, events, APU writes and
device audio; prove restored/continuous reference agreement; validate next-stage
transition and review the branch inventory. Strict acceptance is not claimed.

For shared reference routing, import `build_world22_entrance_origin_lua` and
choose it only for 2-2 movies with `origin == "normal-entrance"`; keep
`build_world22_origin_lua(checkpoint_page)` for old swim probes. Normal native
replay must initialize with `startLevel(g,2,2)` and skip 2-1/water-probe origin
initializers. Shared `parityAdvanceOneFrame` patches frame-zero friction and
counter; the dedicated native diagnostic deliberately keeps frame zero
untouched, matching the headless route. Shared runner support needs an explicit
normal-entrance mode, not a bypass of the strict stage guard.

## 正常出入水流程（2026-11-27）

- 2-2 入口对象流与 1-2 入口相同，出口与 1-1 地面图相同；回归逐字节检查后复用已有构建器。出水选择第 11 页，淘汰出生屏幕前已跳过的敌人。
- 2-1 结算加载真正的 2-2 地面入口，自动走进管道后进入水下。第 189 列侧管允许未落地的游泳角色进入，只有碰撞框完整处于管口高度才接受；上/下方岩石不触发。
- 跨区保留大小/火力、分数、金币、生命与剩余时间。出水恢复陆地碰撞，爬楼梯、触旗及城堡结算可执行；未实现的 2-3 停在结算边界，不误载 World 1。
- 出口死亡回水下第 5 页检查点并恢复小马里奥。最后一命触发 Game Over 和音效；过场重开仍留在 2-2。
- 三种能力形态的入口、侧管、地面出口至结算、死亡与重开分段测试通过。测试在水下出口前设置了位置，**不构成连续游过整关的证据**。1800 帧原有运动基准、10 组既有模拟回归、43 项工具测试及原生混音通过。
- 实际窗口检查了入口、入水后及出水口画面，启动标题/图标/关闭检查通过。转场目前复用已有 1-2 实现，未完成原版逐帧加载/音乐时序验收；没有据此宣称 2-1 的完整六项门禁通过。

证据：`local-parity/world22-flow-20261127/`，最终回归 `regression-final2`、`existing-final`；三张 PNG 为分段显示检查。最终包首次启动遇到 SDK 的 Vulkan 扩展枚举 `VK_INCOMPLETE`，失败日志已保留；未改代码重试 `package-final-retry.json` 通过，仍记录此偶发启动限制。最新试玩包 `dist/super-mario-water-route-preview-20261127-win64/SuperMario.exe` 从地面入口开始。水下音乐、火球/气泡、完整成功路线与音画验收仍待完成，不是正式 release。


## 水下敌人实现（2026-11-27）

- 新增 `scripts/world22_enemies.nut`：按原版五槽位、区域解析时机和敌人流生成鱿鱼；保留困难模式命令的游标占位，避免后续敌人提前出现。
- 动态鱼群由地图命令启停，使用七字节随机寄存器、32 帧生成计时和八种高度去重；实现灰/红鱼水平速度与第三槽位起的竖直摆动。
- 鱿鱼追踪、收缩/展开周期、计时器和离屏清理已接入。原版精灵行绘制函数确认鱼的方向 2 要水平翻转，灰/红鱼均使用对应朝左素材。
- 水下接触造成伤害，不执行地面踩踏；增加小马里奥死亡、大马里奥变小及星星击杀回归。变身期间冻结敌人。
- 三条独立原版探针共 **1800 帧**的玩家字段和五个敌人槽位选定运动寄存器逐帧一致。基准 `tests/fixtures/world22_enemies.nut` 仅供测试，运行游戏不读取期望轨迹；新增比较器拒绝缺帧和未知敌人类型。
- 43 项 Python 测试、现有 10 组模拟回归、水下专项回归及原生混音测试通过。实际窗口已检查水下场景和鱿鱼显示；完整 OAM、死亡翻转、音频及成功整关路线尚未验收。

证据：`local-parity/world22-enemies-20261127/`。`actors1` 至 `actors5` 保留排查失败，`actors6/enemies-report.json` 的 960 帧五槽位比较零差异；最终 1800 帧固化回归位于 `regressions-final2/`。

最新试玩包：`dist/super-mario-water-enemies-preview-20261127-win64/SuperMario.exe`。直接从水下开始，仍无正常出口流程和背景音乐，不能作为 2-2 通关版本；版本维持 0.0.7，不发 release。

## 水下运行实现（2026-11-26，历史里程碑）

- `scripts/world22.nut` 消费已验证的显示/碰撞图，水体与海草不会作为固体，金币采用独立可变对象；不同加载实例互不共享收集状态。
- 按原版按下沿启动划水，保留 32 帧计时、普通/漩涡两组竖直参数、水面上限、松开 A 的重力切换和水平摩擦。水下方向切换与地面奔跑分支隔离。
- 三处漩涡来自对象流，不按录像帧号触发。每隔一帧向中心横拉，玩家绘制之后再执行一次 `$10` 重力和速度上限 1 的竖直积分；下一帧划水读取漩涡标志。
- 修正反向游到镜头左边缘时速度未清零；镜头使用绘制时保存的横坐标，避免漩涡晚于绘制修改 X 后出现 1 像素偏差。
- 水下诊断死亡按镜头第 5 页选择中途重生，小马里奥恢复、分数/金币保留；中途入口使用原版 entrance control 2 的 Y=176（小马里奥碰撞框 Y=192）。
- 新提取大小马里奥各三帧划水贴图。实际窗口已检查，可正常显示水下场景和划水动作；脚部替换/OAM、金币动画、完整音画一致性尚未验收。

### 本轮验证

三条原版独立回放（360/480/960 帧）均通过连续视频与存档回放的一致性证明。宿主共 **1800 帧**逐帧匹配以下字段：X/Y、水平/竖直速度、四个小数累积字段、落地状态、朝向/移动方向及镜头 X。覆盖间歇划水、自然下沉、落地后划水、长按/松开 A、反向游动及第一处漩涡；不包含敌人状态和逐像素对照。

测试基准保存在 `tests/fixtures/world22_motion.nut`，只由测试加载；运行游戏不读取录像期望值。`build_world22_motion_fixture.py` 校验电影哈希、原版独立重放证明及连续帧数后生成基准。

- `python tools/run_world22_regressions.py --output local-parity/world22-regression`：1800 帧运动及死亡/地形/对象隔离测试。
- `python tools/run_world1_regressions.py`：现有 10 组模拟回归通过。
- `python -m unittest discover -s tests/parity`：42 项测试通过。
- 原生混音测试、试玩包启动/标题/图标/关闭检查通过；包内脚本与素材逐文件匹配源文件。

证据：`local-parity/world22-runtime-20261126/`。`controls1/2`、`whirlpool1/2` 保留失败结果；`controls3`、`whirlpool3` 及最终固化回归通过。

试玩包：`dist/super-mario-water-controls-preview-20261126-win64/SuperMario.exe`。专用于水下运动试玩，正常启动工程仍从 1-1 开始。背景音乐、敌人、火球和正常入口/出口尚待接入；本包不能通关 2-2，不是正式 release。

## 已核实的数据

- ROM SHA-256：`f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`，提取器拒绝其他 ROM。
- 从原版地址表解析入口 `0x29`、水下 `0x01`、出口 `0x25`，共六条对象/敌人流。扫描只在命令边界判断终止符，避免操作数误截断。
- 世界 2 的区域顺序为 `28 29 01 27 62`。入水前仍有地面管道过场；水下出口链接选择共享地面图第 11 页。链接命令位于第 18 列，不代表出口管道就在第 18 列。
- 水下对象流：`$AE45`，123 字节；敌人流：`$A171`，42 字节。根据世界位筛选出口链接；区分普通与困难模式的鱿鱼生成。
- `HalfwayPageNybbles` 世界 2 的低半字节给出 2-2 检查点第 5 页。
- 三处漩涡按原版空洞处理程序登记：左边界/长度分别为 `(1040,96)`、`(2080,160)`、`(2496,128)`。这些数值是原版吸力区域寄存器范围，不是简单的可见空洞宽度。
- 第 80、96 列有水中鱼群生成指令，第 192 列停止生成；第 189 列、第 5 行为水管对象。运行时需执行生成指令，不能只实例化静态敌人列表。

## 地图与素材证据

`tools/parity/capture_world22_map.py` 使用原版区域解析器采集 208×13 个显示元图块及独立碰撞块。连续正向覆盖 0～199 列；尾部补采 200～207 列，194～199 六列与连续采集完全一致后才允许写出。显示水面、水体与可碰撞岩壁不能混用。

初次使用 Y=32 的地面探针被第 77 列顶部岩壁挡住，仅得到 94 列，完整性检查失败。最终探针采用 OAM Y=0 和受伤保护计时器；只改变离线玩家状态，不写地图、解析器、滚屏锁寄存器。此探针用于数据采集，不能作为正常游玩或通关证据。

水下调色板、101 种元图块以及鱿鱼/鱼基础图帧从 ROM 离线提取，文件哈希在 `assets/world22/manifest.json`。地图哈希及采集方式在 `assets/world22/map-manifest.json`。运行包不依赖 ROM 或模拟器。

本地证据目录：`local-parity/world22-foundation-20261126/`。其中 `map-above-ceiling/` 是通过的地图采集；前三个 `map*` 失败目录保留诊断，不计入验收。`water-map-review.png` 为四段拼接的整幅地形检查图。

## 游泳参考基线

`tests/parity/movies/world-2-2-swim-probe.json` 从水下可操作起点开始，360 帧包含水平输入、间歇 A 划水和松开输入。它跳过地面入口，仅用于物理诊断。

原版独立运行通过：360 帧状态和 APU 写入在存档回放/连续启动回放之间一致，13 张采样画面齐全。证据见 `swim-reference/`，索引和哈希提交在 `assets/world22/reference-manifest.json`。此结果仅证明参考采集一致，不代表宿主游泳已实现或与原版匹配。

参考回放入口现在统一由 `build_movie_origin_lua` 分派，连续视频使用同一入口。2-2 仅开放原版参考采集；`run_actual.py` 的不支持关卡检查保持有效。

## 后续执行顺序

1. 补水下火球和气泡、敌人死亡翻转/OAM；鱿鱼、鱼群及基础接触伤害已实现，继续覆盖不同随机状态和后半关交互。
2. 分段入口/出口、跨关及死亡流程已接通；补原版逐帧转场时序和连续通关路线，重新验证 2-1 末帧。
3. 接入水下音乐、加速音乐；完善划水脚部替换、金币动画及 OAM 延迟，逐帧对照画面与事件。
4. 建立正常入口到出口的成功固定按键整关路线，补死亡、检查点、出口和跨关分支；重新运行 2-1 末帧和完整六项验收。地图探针、采样图和 1800 帧局部运动测试均不能替代整关验证。

版本仍为 0.0.7，32 关正式验收登记保持未完成。


## Source task parity progress, 2026-11-28

Strict acceptance remains pending. Source task lifecycle now passes all 394
independently recorded entrance frames. The old 1800-frame selected movement and
enemy fixture and water fire-input interaction checks still pass.

Full continuous original capture: `local-parity/world22-strict/candidate4-original`
(3446 PNGs/RAM states). Input `candidate4.json` SHA256:
`938108a18f09b7e9247320d82eeba2f835e5e98dd7462208a58c83a46df3a17a`.
Latest host comparison: `candidate4-scroll-fixed2` in the same evidence directory.
Both sides reach the castle alive with three lives, three coins and final score
18300. The movie ends during fireworks before next-stage transition, so it is not
an acceptance route. Failed earlier planner candidates are not successful evidence.

All 3446 selected player motion, camera, time, lives and coin observations match.
3498 reported differences remain: counter serializer offset on3446 frames,
zero-facing serializer on48 loader frames, four one-frame delays in firework score.
This selected diagnostic does not establish full state/actor/image/event/APU/audio
parity. No reference substitutions or relaxed thresholds were used.

### Parent integration contract

`initializeWorld22Parity(g)` calls ordinary startLevel and executes the first
source automatic entrance pass; only origin RNG is seeded. Use solely for strict
normal-entrance observations, never PARITY_NORMAL_ENTRY ordinary input replay.
Frame0: x40, canonical y176, xs1, xf48, xm16, counter25, interval2, time401,
facing/moving1, engine7, operation3. No reference fixture enters runtime.

Required shared edits, intentionally not made by this stage worker:

1. At start of updateWorld12Transition:
   `if(isWorld22(g)) return updateWorld22Transition(g);`
2. In main strict World2 stage2 normal-entrance initialization:
   `initializeWorld22Parity(game);` guarded against PARITY_NORMAL_ENTRY.
3. In parityAdvanceOneFrame frame0 observation, skip generic friction flag and
   counter increment for this initializer, which already represents observed RAM.
4. In parityStateJson, when World22 transition state exists, emit actual counter
   without subtracting1; preserve facing0; use transition operTask/engineTask while
   phase is not done. Its playerYHigh records cleared loader RAM. Keep legacy
   water-only probe serializer behavior intact.
5. After completedTask assignment in updateVramAreaParserScheduler call:
   `if(isWorld22Water(g)) parseWorld22AreaColumn(g,completedTask);`
   At start of updateCamera when water and g.world22.scrollLocked:
   `g.displayCameraX=g.cameraX;g.previousScrollAmount=0;return;`
   This reads real row-$0d $46/$47 objects, not a coordinate cap.
6. Background side-pipe opening must require p.grounded; remove airborne-water
   alternative. Source checks Player_State0. Stage helper uses the real +13 sample.
7. Death branch source music/Y-high condition must cover isWorld22Water as well
   as World21. Legacy208-frame fallback loses life3162 vs original3189 on old input.
8. Shared fireworks award500 one frame late:3347 vs3346, then32-frame intervals.
   Final totals agree. Correct source lifetime/award ordering, never frame patches.

Host diagnostic --local-transition-hook installs items1/5 as temporary harness
wrappers. Shared files are unchanged. Stage capture tools use portable GPU lock.
Source exit fixes: side-pipe delay$34, no engine2 reload; grounded collision clears
vertical force before whirlpool integration; loader camera and exit rise match.

Old three water probe movie provenance requires CRLF bytes. Exact local CRLF
restoration passes8 data tests; original fixture hashes were not changed. Parent
must resolve shared attributes portability. The old playable movie is preserved
as historical evidence; source-timing route replacement is still under validation.
