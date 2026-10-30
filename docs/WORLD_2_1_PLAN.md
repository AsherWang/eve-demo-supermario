# World 2-1 implementation plan

Updated 2026-10-29. The main-route runtime prototype and 1-4 to 2-1 transition
are implemented. Bonus destinations and strict whole-level acceptance remain pending.

## Verified offline data

- ROM SHA-256: `f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`.
- `World2Areas[0]` selects area pointer `$28`.
- `L_GroundArea9`: CPU `$a7cd`, 101 bytes including header and terminator.
- `E_GroundArea9`: CPU `$9f51`, 43 bytes, including two three-byte area links.
- Main map: 212 columns, 13 metatile/collision rows per column. Flag column 200.
- Item inventory includes the hidden 1-UP, star, multi-coin brick and a vine
  brick at column 83 / screen row 5. The two raw links are `$fe,$2b,$20` and
  `$fe,$42,$20`; destination and return behavior still require runtime review.

Generated streams and map are in `scripts/generated/world21_data.nut` and
`scripts/generated/world21_map.nut`. Provenance and item locations are recorded
in `assets/world21/manifest.json` and `assets/world21/map-manifest.json`.
No ROM, emulator or save state is used by the game runtime.

## Rebuild

```powershell
python tools/extract_world21.py
python tools/parity/capture_world21_map.py
```

The map generator uses the verified ROM's RenderAreaGraphics callback. It
parses forward continuously, keeping the offline fixture player above terrain
after the normal entrance finishes. That fixture is for static data extraction,
not an input movie or gameplay evidence. It never changes map or parser RAM.

Checkpoint-only captures miss object continuations, including the question row
at columns 79..82. The active area is identified by its data base `$a7cf` rather
than AreaPointer: AreaPointer changes when a destination link is parsed even
while Mario remains in the main area. The final six columns beyond the scroll
lock are captured from the last checkpoint, with all six preceding columns
200..205 required to match the continuous capture before merging the tail.
The generator fails on missing columns or differing overlap, and records hashes.

## Runtime and acceptance work

- [x] Introduce explicit world/stage identity while keeping existing World 1
  loaders and regressions stable. Do not overload stage number 1 as World 1-1.
- [ ] Define a small level descriptor for map, enemy stream, item locations,
  entry, goal, checkpoint, music and palette. Keep mutable area state separate.
- [ ] Implement the 2-1 main route: enemies, pipes, group spawns, jumping green
  Paratroopas and jumpspring behavior. Reuse shared movement/collision rules.
- [ ] Implement vine growth/climbing, cloud-area return, underground-area
  return, and correct destination/return links. Do not substitute a mushroom
  for the vine reward or label inaccessible branches complete.
- [x] Connect 1-4 to 2-1 and preserve score, coins, lives and powers. Reset the
  area timer, HUD and music correctly; cover death and restart in World 2.
- [x] Extend reference/bootstrap and actual replay selection with world/stage
  fields. Existing World 1 movies retain their present meaning and hashes.
- [ ] Establish a fixed-input normal-entrance whole-route movie and separate
  branch movies; compare artifact/state/event/all images/APU/audio gates.
- [ ] Review route/branches and register evidence in the level inventory only
  after the corresponding acceptance requirements pass.

0.0.7 contains the World 1 fixes. It does not include playable World 2-1.

## Runtime verification record

The source prototype loads the verified map and enemy stream, including jumping
green Paratroopas, piranhas, a working spring and growing vine. F5 selects 2-1.
Vine climbing, cloud and underground destinations/returns remain unimplemented;
pipe entry is disabled for this stage rather than entering a World 1 bonus room.
2-2 is unavailable; R at the 2-1 settlement restarts 2-1.

- Ten simulation regression groups pass via `python tools/run_world1_regressions.py`.
  These include checkpoint/new-life reset and small/big/fire cross-world retention.
- `world-2-1-idle.json`: all 120 frames pass artifact, state, event, image,
  APU and detection-side audio gates. Reports: `local-parity/world21-runtime/reports/idle-final`.
- At commit `3d4a209`, `world-2-1-main-host-route.json`: 3116 host frames reach settlement with
  three lives and no death. The same input fails in the ROM, with deaths at
  754, 1393 and 2018. First Y difference is frame 643 and first X difference
  frame 649. Reports: `local-parity/world21-runtime/reports/main-route`.
- The earlier `world-2-1-route-candidate.json` remains failed evidence in
  `local-parity/world21-runtime/reports/route`; it is not an acceptance movie.
- `world-1-4-to-world-2-1.json`: 2800 actual frames, no death, three lives,
  enters World 2-1 at frame 2496 and finishes in playing state with score 11150.
  Capture: `local-parity/world21-runtime/actual/world-transition`.

## Collision follow-up (2026-10-29)

The first player-position divergence was caused by a false Koopa stomp at frame
642, not by free-flight gravity. The host fed a fractional enemy X into an
integer ROM bounding box, extending the trailing collision edge by half a pixel.
Collision boxes now use integer origins and inclusive ROM edges. Goomba and
Mario edge contact also retains the inclusive final pixel. Regression cases
cover Koopa integer/half-pixel phases, adjacent hit/miss positions, and Goomba
vertical edge contact versus a one-pixel gap.

The 760-frame actual-window capture is retained in
`local-parity/world21-runtime/actual/collision-inclusive`; its unchanged-input
prefix comparison is `local-parity/world21-runtime/collision-fix/verification.json`.
There is no stomp event at 642. The next speed differences are at 754 and the
next X/Y differences at 755. Ten simulation groups pass. Four before/after
World 1 simulation replays (first stomp, death lifecycle, 1-1 TAS and 1-3 route)
have identical state records for all 3976 simulated frames; these checks do not
include rendered images or device audio. Their report is
`local-parity/world21-runtime/collision-fix/world1-before-after.json`.

At commit `930ff87`, the same-input diagnostic retains matching player X/Y through frame 754;
the next position divergence is 755. This is only a position-prefix check,
not a pass of the complete semantic state or image gates. At this point the
host has a different enemy population: piranhas do not reserve the ROM's five
enemy slots, and delayed group members are retried instead of consuming the
group command when slots are exhausted. These are the next parser/actor tasks.
The earlier 3116-frame no-death result belongs to the old commit and must not
be interpreted as verification of the corrected collision code.

## Actor-slot follow-up (2026-10-29)

Pipe parser column tasks now allocate piranhas from the same five slots as
walkers. A plant is skipped when its column is parsed with a full buffer;
it is not spawned later when capacity becomes available. A full-buffer enemy
group command waits, but once its first member spawns the command is consumed
and members beyond capacity are discarded. A slot erased at the end of its
enemy pass becomes available to the walker parser on the following frame.
These changes are currently scoped to World 2-1; World 1 behavior is preserved.

Ten simulation groups pass, including plant/walker slot exclusion, skipped
plants, full and partial group allocation, and deferred reuse of erased slots.
The 900-frame actual-window replay uses the unchanged first 900 inputs of
`world-2-1-main-host-route.json`. Player X/Y, raw X/Y speeds, vertical force
and accumulator, state and grounded flag all match the existing ROM reference
for all 900 frames. Both runs enter death from the Goomba at frame 754.
Capture: `local-parity/world21-runtime/actual/slot-prefix`; comparison:
`local-parity/world21-runtime/slots-fix/verification.json`.

At commit `148a9a3`, the complete 3116-input simulation probe first differs in Y at frame 961 and
X at 963, during death/reload. The host uses a fixed 208-frame death duration;
the ROM gates life loss on player depth and death-music completion. Full
reload parity, actor image parity and whole-route acceptance remain pending.
The 900-frame result is a player-state prefix, not a six-gate whole-level pass.

## Death/reload follow-up (2026-10-29)

World 2-1 now ends enemy-death animation when both conditions from PlayerControl
hold: the 180-frame death track has ended and the sprite origin reaches the
ROM's Y-high-byte $04 depth. The old unconditional 208-frame delay remains
unchanged in World 1. The later correction below supersedes the initial timer
rewind used by this implementation.

The World 2 reload now clears the area on its initialization pass, resets
powers while retaining score/coins/lives/checkpoint, and computes the lives-screen
wait from ScreenTimer=7 and the shared 21-frame interval divider. It rebuilds
the area, restores music, then exposes entrance and normal-control passes in
order. A/B input history is cleared by entrance control, and the first moving
frame uses the shared entrance friction profile. Holding jump through the
lives screen can therefore jump immediately on the first controllable frame.

Regression covers six divider phases at start/checkpoint 6, retained stats,
small new-life form and the two independent death-completion conditions.
At commit `7813aeb`, the complete-input simulation matches player X/Y through frame 1393;
the next position difference is 1394, at the second enemy-death interaction.
This remains a failed whole-route diagnostic, not an accepted level.

Final actual-window capture:
`local-parity/world21-runtime/actual/death-reload-final`, with selected-field
comparison in `local-parity/world21-runtime/death-fix/final-verification.json`.
All 1200 frames match player X/Y, raw speeds, vertical force/dummy, horizontal
acceleration/position fractions, state and grounded flag, plus world, level,
lives, time, camera, frame counter and engine loading phase. Milestones are
death at 754, lose-life dispatch at 960, decrement at 961, area initialization
at 963, entrance at 1131, normal control at 1132 and held-button jump at 1133.
The final run captures five screenshots; the preceding run retains all 1200
images, with the remaining horizontal-fraction correction recorded separately.
Neither run establishes complete image/audio or whole-level acceptance.

## Second-life contact follow-up (2026-10-29)

ChkForPlayerInjury skips its height-based exception for enemy IDs below $07.
Ordinary Koopas therefore injure an ascending Mario; only the flying variants
use that high-position stomp rule. The shared handler now distinguishes these
cases. Regression covers upward contact for small/big Mario against ordinary
and winged Koopas, alongside the existing descending stomp tests.

The reference origin RAM has IntervalTimerControl ($077f) = $01, not $00.
Correcting this fixture removes the need to rewind timers on death. Normal
frame timers now complete the collision frame before the death freeze begins,
which also fixes the second lives-screen wait without a special frame offset.

The complete-input simulation aligns all three death contacts (754, 1393,
2018), the first two life losses and both restarts. Player X/Y stay equal until
the ROM returns to its title flow at 2648, but a semantic difference remains
at Game Over (2227): the host uses a bounded game-over state while the ROM
enters mode 3 and later returns to title. The old reference extractor also
reports 256 lives for the ROM's $ff underflow byte; that requires a separate
normalization correction with raw data preserved. This is still failed
whole-route evidence; matching frozen coordinates does not establish gameplay
equivalence after Game Over.

Four before/after World 1 simulation routes retain identical state records
for all 3976 frames (`second-life-fix/world1-before-after.json` under the local
World 2-1 evidence directory). Image/audio and whole-route acceptance remain pending.

The actual-window diagnostic is
`local-parity/world21-runtime/actual/second-life-prefix` (2230 frames, eight
screenshots). Its `second-life-fix/verification.json` report retains the failed
Game Over comparisons: lives and engine phase first differ at 2227. Selected
player position, raw speeds, movement fractions, state/grounded, time, world,
level, camera and frame counter match throughout the capture; all selected
fields match through 2226. Death events are exactly 754, 1393 and 2018. This
diagnostic does not pass full-scene image/audio gates or reach the level goal.

## Game Over follow-up (2026-10-29)

The reference decoder now maps NumberOfLives=$ff to zero visible lives and
also exports `lives_raw` to retain the original byte. Other values remain
the ROM's stored count plus one, including counts above 127. Old failed
reference state files are preserved; the same raw RAM trace is decoded afresh
to `local-parity/world21-runtime/gameover-fix/reference-state.jsonl`.

World 2-1 Game Over now exposes setup/screen/display phases, queues its music
on setup rather than the preceding lose-life pass, and counts the $12 screen
timer using the 21-frame divider after the remaining death master-timer freeze.
Its rendering preserves the scene during the initial handoff, then blacks out,
then displays the HUD without time digits and GAME OVER at nametable $220b.
Regression covers the music request, timer expiry, zero-life terminal state
and a clean three-life R retry. Reference sentinel tests run in release CI.

Actual replay capture now also rejects EVEngine `frame error:` / `Run failed:`
logs even if the engine produces every requested frame. Failure logs and
artifacts remain on disk. A first failed Game Over rendering probe is kept in
`actual/gameover-prefix`; it exposed an invalid integer color argument rather
than a successful screenshot run. Unit checks cover completed captures with a
render fault and healthy audio status containing `error=0`.

At commit `64614d7`, the terminal screen still waits for R. Automatic title return
is not implemented in that version. In its complete-input simulation the first engine-mode
difference is now 2646, where the ROM leaves Game Over for its title flow;
the first visible-lives difference is 2647. This is retained as failed evidence.

The final actual-window diagnostic is `actual/gameover-verified` under
`local-parity/world21-runtime`, with 2650 state frames and 11 screenshots.
Selected state fields agree through 2645; the title-return failure is preserved
in `gameover-fix/verified-report.json`. Eight selected images match at zero
pixel tolerance, including the black loading screen and stable GAME OVER page.
Three handoff images (2227, 2228, 2230) still fail and are not excluded from the
report. Stable-page correctness does not imply whole-scene or timing acceptance.
The corrected capture has no runtime errors; earlier failed probes remain saved.

## Single-player title and new game (2026-10-29)

Game Over expiry now returns to a title loader and a single-player menu.
Enter/Start starts a fresh World 1-1 game with three lives, small Mario,
zero score/coins and no checkpoint, retaining the best score for this process.
R on the title also starts a new game; R before the Game Over wait finishes
remains the development retry shortcut for the current stage.

`tools/extract_title.py` verifies the ROM hash and decodes the CHR $1ec0 VRAM
packet into `assets/title/overlay.png` and `scripts/generated/title_data.nut`.
The original logo, copyright, menu and mushroom cursor are reused; the runtime
uses only generated files. The title's temporary $0300..$0439 copy and subsequent
buffer clear are modeled for the inactive-player accumulator aliases.

The new-game loader preserves entrance state until its initialization pass,
waits on ScreenTimer and the shared interval divider, then restores music and
the first-control friction profile. Regression covers automatic title return,
fresh stats/powers/checkpoint and best-score retention. Versioned diagnostic
movies are `world-2-1-title-return.json` and `world-2-1-title-new-game.json`.
The new-game reference has a continuous-video proof for all 3116 states and APU
writes from the normal World 2-1 origin through title Start and movement in 1-1.

Final actual capture: `local-parity/world21-runtime/actual/title-new-game-verified`.
All 3116 frames match the 18 selected player/progress/engine fields recorded in
`title-fix/verified-report.json`. The original title packet briefly aliases
movement fractions during loading; these bytes are cleared on the next buffer
task, not carried into gameplay. Stable title frames 2690/2749, lives screen
2800 and sampled 1-1 frames 2950/3115 match at zero pixel tolerance.

At commit `7111cf8`, the full state gate FAILS on raw size/palette/VRAM fields in the title
loader and pre-existing enemy fields (first enemy-state mismatch at 129).
The full selected-image report compares 91 images: 73 pass, 18 fail. Large
Game Over handoff backdrop errors are fixed; frames 2227/2228 each retain 370
enemy pixels of difference. Other failed loading images remain in
`title-fix/reports/state-report.html` and `title-fix/reports/report.html`.
These are diagnostics, not a complete World 2-1 route or six-gate acceptance.
The first concurrent capture had black image output despite valid state logs;
the final native replay was run serially and retained that earlier failed probe.

This is the single-player return flow for World 2-1. Initial launch still enters
the existing 1-1 game. Two-player selection, the idle demo and A+Start continue
are not implemented; the original title artwork still contains its two-player
label. Whole-route and branch acceptance remain pending.

## Walker and title-state follow-up (2026-10-29)

World 2-1 Goombas now use the existing integer ROM ground-walker/falling
routine instead of floating-point gravity. A missing bottom-middle support
probe changes the enemy to falling before movement; the $3d force accumulator
then advances its Y bytes. A golden twelve-frame regression checks the first
airborne sequence from the normal-entry ROM trace. World 1 movement is unchanged.

Title initialization now clears palette/scroll/parser state on the memory-clear
pass. The inactive raw Size byte is retained separately from logical player
powers until PrimaryGameSetup initializes it. Title and new-game screen tasks
queue their initial palette, twelve area-column buffers, area palette and CHR
title packet, and consume the previous VRAM selection before the next task.
The first controllable new-game pass also advances the shared palette cycle.

The simulation state probe retains all 3116 player/progress frames and removes
the earlier raw-size, palette, VRAM and first falling-state failures. Its state
gate still FAILS on enemy activation and X (first mismatch 406/407).
Evidence: `local-parity/world21-runtime/walker-fix/simulation-report`.
The camera-admission experiment saved as `group-probe.jsonl` was not retained
in runtime code: it moved a spawn discrepancy later without establishing the
underlying stream-parser rule. Existing failed probes remain visible.

The serial actual-window replay is `actual/walker-title-fix` under the same
local evidence directory. Its 3116-frame state comparison confirms only two
failed fields: enemy activation at 406 and X at 407; all other fields in the
current state gate pass. Reports are in `walker-fix/reports`. The 91 selected
images still have 18 failures (no full-frame or audio acceptance claim).
Ten simulation groups pass, including the new falling trajectory regression.

Next: resolve enemy stream admission/placement and remaining presentation gates,
then complete branch destinations
and record same-input full-route six-gate acceptance. Opening gates and host
playability do not mark the level complete in the 32-level inventory.


## Data validation record

Repeated captures generated the same map SHA-256:
`5d48f7e51e7ebe0256d7baafdbbce65196ed418d4ae4c27851fa3b7f8ba3cbb2`.
Both metatile and collision arrays contain 212 complete 13-row columns.
Columns 79..82 retain the question-block continuation, and column 200 contains
the expected flagpole metatiles. The extraction tool rejects a wrong ROM hash
before writing outputs. Local validation is saved in
`local-parity/world21-data-check.json`; individual parser captures and tail
agreement are retained in `local-parity/world21-map-final`.


### 2026-10-29：敌人流的地图解析任务门控

- 对照 `EnemiesAndLoopsCore` 确认：空槽在 `AreaParserTaskNum & 7 == 7` 时不解析敌人流；已有敌人继续更新。2-1 现已遵守此规则，没有修改摄像机边界或回放输入。
- 新增回归覆盖任务 7 暂停生成、已有敌人继续移动、任务 6 恢复整组生成。
- 原生窗口回放 `world-2-1-title-new-game.json` 共 3116 帧，无缺帧。状态门禁仅剩 `enemy0.x`：首次差异第 709 帧（原版 1115、当前 1114），共 232 帧；此前第 406/407 帧的激活/位置差异已消除。玩家、进度及其他当前门禁字段保持一致。
- 91 张截图中 73 通过、18 失败；10 组模拟回归和 3 项参考状态/运行错误检测测试通过。此回放包含死亡、Game Over、标题及重新开局，不能替代成功通关验收。
- 证据：`local-parity/world21-runtime/actual/parser-task-fix`、`local-parity/world21-runtime/parser-task-fix/native-reports`。下一步追查第 709 帧空槽复用/组内更新顺序，并继续清理图像差异；奖励区域连接及整关验收仍未完成。


### 2026-10-30：保留复用敌人槽的横向小数状态

- 原版 RAM 显示第 708 帧新板栗复用槽 1 时保留 `$0402` 的 `$80` 横向累积值；原实现重置该值，导致第 709 帧开始提前一像素。现按槽保存横向运动小数，分配新敌人时继承，初始化区域时清零。
- 新增槽位继承与区域初始化清零回归。10 组模拟回归、3 项 Python 测试、原生音频测试全部通过。
- 原生 `world-2-1-title-new-game.json` 回放 3116 帧，当前全部状态门禁通过、无缺帧。91 张截图仍为 73 通过、18 失败；状态门禁通过仅限当前覆盖字段，不能替代整关成功通关、全图像和设备音频验收。
- 证据：`local-parity/world21-runtime/actual/slot-fraction-fix` 和 `local-parity/world21-runtime/slot-fraction-fix/native-reports`。预览包：`dist/super-mario-world21-slot-fix-win64/SuperMario.exe`，启动、标题、大小图标及关闭检查通过。没有发布新 release，版本仍为 0.0.7。
- 下一步处理剩余截图差异，继续接通 2-1 奖励区域和返回路线，并补成功通关的整关验证。


### 2026-10-30：剩余截图差异定位与图形验证阻塞

- 对 `slot-fraction-fix` 的 91 张截图逐项检查：失败集中在 2220–2228、2236、2671–2676、2751、2918，共 18 张。当前状态门禁仍为 3116 帧通过。
- 已目视确认 2671、2674 原版仍为纯天空背景色，当前实现提前绘制关卡或菜单；2918 原版为纯天空背景色，当前实现仍为黑屏。应继续核对关闭 PPU 绘制期间的背景色及重新启用绘制时机，不能只调整状态机时间。
- 绘制候选保存在 `local-parity/world21-runtime/title-blanking-investigation/candidate.patch`，未合入运行源码。连续三次原生验证均在 SDL 创建窗口时因 `vkEnumerateInstanceExtensionProperties returned VK_INCOMPLETE(5)` 失败，尚未进入脚本游戏循环；不是截图门禁通过，也未产生新的完整状态证据。
- 失败日志分别保留在 `actual/title-blanking-fix`、`actual/title-blanking-fix-retry`、`actual/title-blanking-fix-third`（均相对 `local-parity/world21-runtime`）。候选代码的 10 组无窗口模拟回归通过，但不能证明绘制正确。
- 下一步先恢复原生图形捕获，再验证候选并核对逐帧空白/精灵显示阶段；未确认前保持已验证运行代码，不发布新包或 release。


### 2026-10-30：恢复图形回放并修复标题空白绘制阶段

- 对回放子进程设置 `VK_LOADER_LAYERS_DISABLE=~implicit~` 后窗口初始化恢复，基线 3116 帧状态门禁通过。系统注册了 Steam/OBS 隐式层；证据仅支持禁用隐式层能够绕过本次问题，尚未确定具体故障层。没有修改系统环境或注册表。
- PowerShell 可复现命令：先 `$env:VK_LOADER_LAYERS_DISABLE='~implicit~'`，再执行 `python tools/parity/run_actual.py` 的正常参数；设置仅在该 shell 及子进程生效。
- 标题 CHR 复制及初始化阶段保持纯天空背景色，延后玩家精灵显示；新游戏加载在区域调色板已上传而绘制尚未启用时使用天空背景色。未改变模拟状态时序。
- 验证证据：`local-parity/world21-runtime/actual/title-blanking-candidate-pass`、`local-parity/world21-runtime/title-blanking-fix/reports`。3116 帧状态门禁通过，91 张截图中 80 通过、11 失败（此前 18 失败）。2671–2676 和 2918 的差异消除。
- 剩余截图：2220–2228（294/370 像素）、2236（944 像素）、2751（19 像素）。下一步核对 Game Over 交接期间残留精灵、HUD 出现阶段及 Start 瞬间的精灵状态。
- 10 组模拟回归和 3 项 Python 测试通过；未发布新 release，也没有把这次诊断回放作为成功通关整关验收。


### 2026-10-30：Game Over HUD 与 Start 分数显示交接

- Game Over HUD/文本延后一帧显示，匹配仍处于空白屏的原版帧。Start 清零游戏分数时保留已排队显示的旧分数，直到后续 HUD 更新，避免最终标题帧提前清零。
- 原生回放使用进程级 `VK_LOADER_LAYERS_DISABLE=~implicit~`。证据：`local-parity/world21-runtime/actual/gameover-hud-fix` 和 `local-parity/world21-runtime/gameover-hud-fix/reports`。
- 3116 帧状态门禁通过；91 张截图中 82 通过、9 失败（此前 11 失败）。2236 的 944 像素差异和 2751 的 19 像素差异均消除。
- 剩余仅为 2220–2228 的乌龟绘制区域：前五帧每帧 294 像素、后四帧每帧 370 像素。应继续核对死亡冻结期间敌人图形帧及 OAM 坐标，不调整已通过的游戏状态来掩盖图像问题。
- 10 组模拟回归、3 项 Python 测试全部通过。未发布新 release；当前证据仍是死亡/标题/重新开局诊断，成功通关整关验收尚未完成。


### 2026-10-30：死亡冻结乌龟绘制修复，标题诊断门禁通过

- 对照 EnemyGfxHandler：TimerControl 禁止切换备用 CHR 帧。2-1 死亡期间乌龟固定基础动画帧，修复原先仍按 simTime 切换的贴图。
- 2-1 普通行走/下落乌龟使用缓冲的 OAM 原点与可见扫描线 Y+1；死亡冻结后使用停止移动的当前 X，避免第二只乌龟保留旧的移动前一像素偏差。
- 原生 `world-2-1-title-new-game.json` 诊断回放：3116 帧当前状态门禁通过；91 张抽样截图全部逐像素一致，零容差、无缺帧。不是 3116 帧全截图验证，不是成功通关整关验收。
- 证据：`local-parity/world21-runtime/actual/koopa-freeze-fix`、`local-parity/world21-runtime/koopa-freeze-fix/reports`。首轮仍有 145 像素差异的证据另存 `koopa-oam-fix`，未覆盖。
- 10 组模拟回归、3 项 Python 测试、原生音频测试及预览包启动/标题/图标/关闭检查全部通过。图形测试使用进程级禁用 Vulkan 隐式层的既有绕过方式。
- 新预览包：`dist/super-mario-world21-title-verified-win64/SuperMario.exe`。未发布新 release，版本保持 0.0.7。
- 下一步转回 2-1 奖励区域连接、返回路径和成功通关路线，补充正常行进阶段的图像覆盖；该诊断门禁通过不代表整个 2-1 或全部关卡已验收。
