# World 2-1 implementation plan

Updated 2026-11-08. The main route, 1-4 to 2-1 transition, underground bonus
and vine/sky bonus are implemented. Checkpoint-origin branch diagnostics cover
natural entry, automatic entrance, platforms and return to the main route.
Strict normal-entrance whole-level acceptance remains pending.


## Verified offline data

- ROM SHA-256: `f61548fdf1670cffefcc4f0b7bdcdd9eaba0c226e3b74f8666071496988248de`.
- `World2Areas[0]` selects area pointer `$28`.
- `L_GroundArea9`: CPU `$a7cd`, 101 bytes including header and terminator.
- `E_GroundArea9`: CPU `$9f51`, 43 bytes, including two three-byte area links.
- Main map: 214 columns, 13 metatile/collision rows per column. Flag column 200.
  The final two verified continuation columns cover the castle-walk viewport.
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
- [x] Define a small level descriptor for map, enemy stream, item locations,
  entry, goal, checkpoint, music and palette. Keep mutable area state separate.
- [x] Implement the 2-1 main-route prototype: enemies, pipes, group spawns, jumping green
  Paratroopas and jumpspring behavior. Reuse shared movement/collision rules.
- [x] Implement vine growth/climbing, cloud-area return, underground-area
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
The underground destination/return is connected and verified by the 900-frame
checkpoint branch replay below. Vine climbing and the cloud branch are connected;
their checkpoint validation is recorded in the 2026-11-02 section.
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


### 2026-10-30：2-1 关卡配置与区域链接语义整理

- 新增独立关卡描述配置，统一主地图/碰撞数据、敌人流、初始位置、旗杆/城堡、检查点、初始时间、音乐/调色板标识及区域链接。运行时损坏砖块、敌人、槽位累积值和解析器状态继续独立保存。
- 主关卡加载和死亡检查点选择已使用该配置。链接按原版三字节命令解码：流偏移 12、第 63 列 → `$2b`；偏移 23、第 111 列 → `$42`，均仅适用于 World 2、入口页 0。列坐标代表命令解析位置，不能直接当作可进入物体坐标。
- 新增世界过滤、显式页跳转、入口页位域、独立描述表加载测试。链接仍标记为不可游玩；未接通奖励地图或修改入口禁用规则，运行时仍不读取 ROM。
- 10 组模拟回归、3 项 Python 测试通过。原生诊断回放 3116 帧状态门禁与 91 张抽样截图继续全部通过。证据：`local-parity/world21-runtime/actual/descriptor-links`、`local-parity/world21-runtime/descriptor-links/reports`。
- 下一步定位 `$2b`/`$42` 的离线目的地数据与各自返回命令，确认实际藤蔓/管道入口后接通分支并建立独立回放。关卡描述中的奖励物品清单尚未统一，因此相关总任务保留未完成；整关成功通关验收仍未完成。


### 2026-10-30：奖励区域离线数据与返回命令

- 新增 `tools/extract_world21_branches.py`，只接受已验证 ROM 哈希，从唯一指针表签名解引用目标数据，并用已知主区域地址交叉验证表布局。按命令边界读取数据，避免把操作数字节当作结束标记。
- 天空 `$2b`：区域对象 CPU `$a87a`、21 字节，敌人/链接流 `$9fa0`、9 字节；World 2 返回 `$28`、入口页 10。
- 地下 `$42`：区域对象 CPU `$ad79`、141 字节，敌人/链接流 `$a133`、45 字节；该房间有多个世界的返回命令，World 2 使用偏移 3 的命令返回 `$28`、入口页 7。
- 生成 `scripts/generated/world21_branches.nut` 与 `assets/world21/branches-manifest.json`，记录来源地址、长度、SHA-256、返回命令和 `runtime_connected=false`。这是区域数据流，不是已验证的最终 metatile 地图；运行时代码尚未加载这些流。
- 重复离线生成结果一致；3 项新增测试覆盖共享房间世界过滤、页/入口位域、指针解引用及操作数终止符边界，并纳入 release CI。原有 3 项 Python 测试、10 组模拟回归通过。没有改动游戏运行源码，未重复图形回放。
- 下一步使用离线原版解析器捕获这两个区域的 metatile/碰撞地图，确认实际进入与返回的渲染位置，再接通游戏加载和奖励分支回放。当前奖励入口仍不可进入，未发布新 release。


### 2026-10-30：奖励入口地图与碰撞数据捕获

- 新增 `tools/parity/capture_world21_branches.py`，用验证 ROM 的 `$88ae` RenderAreaGraphics 回调采集 metatile 与碰撞缓冲，按当前区域数据基址筛选。天空区域设置原版 cloud override；固定玩家在地形上方只是离线地图采集条件，不是游玩证据。
- 天空入口窗口输出 48 列，地下入口首屏输出 16 列，每列 13 行；提交 `scripts/generated/world21_branch_maps.nut` 和 `assets/world21/branch-maps-manifest.json`，记录 Lua、原始列记录、成功模拟器日志及生成数据哈希。
- 两个独立模拟器运行各完成 1400 帧，无 Lua 错误。天空观察到 86 列、地下观察到 24 列。初次要求地下 32 列时因缺少 24–31 列而拒绝输出；检查横管/管墙布局后将输出范围明确收窄为入口首屏 16 列，保留所有原始 24 列，不补造后续共享区域。没有证明共享地下整区域完整或可通关。
- `--reuse-capture` 仅在既有 Lua 与当前配置完全一致、日志含成功 1400 帧摘要且无 Lua 错误时重用采集证据。本次输出使用上述成功采集记录。
- 新增提交数据哈希、维度、地下 19 枚金币和横向出口管道几何测试。4 项分支测试、3 项既有 Python 测试、10 组模拟回归通过。运行时尚未加载该地图，未重复原生游戏回放、未发布新 release。
- 下一步接入分支贴图/碰撞与金币、区域加载和返回到第 7/10 页的流程，再连接实际管道/藤蔓入口并单独验证。奖励入口仍不可进入，整关验收未完成。


### 2026-10-31：地下金币房进出原型接通

- 第 103 列可进入管口：站稳且双脚居中时按下进入地下金币房。复用 48 帧下管、区域加载及自动落地流程；房间使用已捕获的 16×13 地图/碰撞数据、现有地下贴图和共享金币奖励逻辑。
- 右侧第 13 列横管在站地向右时进入，经过侧管与加载流程，返回主地图第 7 页（X=1848），从第 115 列出口管上升。保存主地图已破坏砖块、对象与检查点，保留能力、得分、金币和剩余时间。
- 三种能力（小/大/火力）新增完整模拟进出回归，验证 19 枚金币、一次领取只奖励一次、主地图砖块修改、能力和分数保留、返回位置与临时快照释放。10 组模拟回归、7 项 Python 测试、原生音频测试通过。
- 主路线既有诊断回放 `underground-prototype`：3116 帧状态门禁和 91 张抽样截图仍全部通过；该回放未经过新增地下分支，不能代替分支原版一致性验证。
- 打包程序预览确认地下地图、19 枚金币、砖台和横管正常绘制；图片 `local-parity/world21-runtime/underground-prototype/underground-preview.png`。直接 SDK 启动预览曾遇到 Vulkan 初始化错误，保留 `preview.log`；随后打包程序成功捕获。预览/启动检查使用进程级隐式层禁用，不修改系统设置。
- 预览包 `dist/super-mario-world21-underground-win64/SuperMario.exe`：启动、窗口标题、图标、关闭检查通过，配置已恢复正常开局。
- 天空入口仍未接通；`branchesPlayable=false` 继续代表尚未全部完成。离线采集 manifest 的 `runtime_connected=false` 是生成时状态，当前地下运行进度以本节为准。
- 下一步建立地下分支从正常入口进出、金币领取、返回状态/图像/音乐的原版对照回放，再实现藤蔓攀爬和天空区域。当前未完成分支严格验收或成功通关整关验收，未发布新 release。


### 2026-10-31：检查点分支对照与横管自然进入修复

- 增加只适用于 2-1 的 `checkpoint_page` 回放参数（整数 0–12），同步参考引导、连续视频验证和宿主诊断起点。默认页 0 保持现有正常入口含义；检查点回放不是正常入口整关路线。
- 参考引导现在核对当前主地图数据基址 `$a7cf`，避免目标区域指针提前选择奖励区域时漏掉起点。连续视频原先遗漏检查点参数，造成存档/冷启动验证失败；现已同步，保留失败 `reference/underground-checkpoint-route`。
- 新诊断 `tests/parity/movies/world-2-1-underground-checkpoint-probe.json` 共 600 帧。参考录制 `reference/underground-checkpoint-route-v2` 的连续视频与存档恢复全部 600 帧状态、APU 写入一致；这是参考录制可靠性证明，不是宿主一致性通过。
- 宿主对照证据：`local-parity/world21-runtime/actual/underground-checkpoint-probe`、`local-parity/world21-runtime/underground-checkpoint-comparison`。状态门禁失败，31 张抽样截图有 30 张失败。原版第 68 帧死亡，宿主第 73 帧进入管道；不得将该输入序列标为成功分支验证。
- 已确认起点差异：原版在第 6 页初始区加载了 X=1656/1848 的两只食人花，而当前宿主检查点诊断只准备了主地图与敌人模板，遗漏初始化期间的可见植物。后续需补齐检查点初始区域解析/演员状态，不能仅调输入绕过初始状态不一致。
- 真实步行验证另发现地下横管出口会把 Mario 停在 X=194（右侧含边界采样 X+13），旧判断以宽度 12 要求更靠右，导致无法自然进入。现按实际碰撞边界触发；三种能力回归改为从 X=180 真正步行进入出口，覆盖此前直接摆放角色遗漏的问题。
- 10 组模拟回归、5 项分支/检查点 Python 测试及 3 项既有 Python 测试通过。未发布新包/release；地下分支严格验证、天空入口和整关成功通关验收仍未完成。


### 2026-10-31：检查点植物初始化与碰撞规则修复

- 将检查点诊断初始化集中为 `initializeWorld21CheckpointParity`，按加载阶段首个 24 列窗口给管道植物分配槽位，并执行可控起点之前的一次敌人运动。第 6 页测试验证 X=1656/Y=143/槽 0 上升，以及 X=1848/Y=176/槽 1 停止，保持帧计数和玩家起点。
- 对照 PlayerEnemyDiff 与 MovePiranhaPlant：2-1 植物近距离判断使用绝对距离低字节（272 像素按 16 处理）；碰撞框采用原版控制 9 的包含边界坐标，并只在偶数帧检查玩家碰撞。新增奇数帧跳过、偶数帧伤害回归；World 1 保留已有行为。
- 检查点回放证据 `actual/checkpoint-plant-collision`、`checkpoint-plant-collision/reports`（均相对 `local-parity/world21-runtime`）：600 帧对照仍失败，31 张截图中 23 失败。玩家相关字段首个差异由第 68 帧移至第 503 帧；不能表述为全部状态一致到 502。
- 全部字段仍包括 `enemy0.active` 第 1 帧差异、`enemy0.x` 第 64 帧差异及 `camera_x` 第 293 帧差异。检查点当前未正确跳过屏幕右边界之前的旧敌人命令，死亡加载阶段相机也需进一步核对。分支验证仍未通过，这条回放仍不是成功进入地下房的原版路线。
- 主路线基线重跑 `actual/plant-fix-main-baseline-retry`：3116 帧状态门禁、91 张抽样截图全部通过。首次启动遇到 Vulkan 初始化失败，日志保留 `actual/plant-fix-main-baseline`；对比报告在 `plant-fix-main-baseline/reports`。
- 10 组模拟回归、5 项分支 Python 测试及 3 项既有 Python 测试通过。未发布新包/release；下一步补齐检查点敌人流和相机初始化，继续修正分支诊断。天空入口及成功通关整关验收仍未完成。


### 2026-10-31：检查点敌人流与加载相机修复

- 检查点初始化按 ScreenRight（camera+255）跳过旧敌人命令，修复此前仅按 ScreenLeft 丢弃导致旧敌人提前生成的问题。
- 死亡加载第 3 帧恢复检查点相机；复活入口复用相同的植物/敌人初始化，避免下一命漏载植物及重复保留旧命令。辅助函数重命名为 `initializeWorld21Checkpoint`，由真实复活和诊断共同使用。
- 新增旧命令过滤和加载中相机恢复回归。10 组模拟回归、5 项分支 Python 测试和 3 项既有 Python 测试全部通过。
- 检查点诊断 `actual/checkpoint-stream-fix` 对原版 `reference/underground-checkpoint-route-v2`：600 帧当前状态门禁全部通过。31 张抽样截图仍有 23 张失败，含植物绘制与加载画面差异；报告 `checkpoint-stream-fix/reports`。该路线会死亡，不是成功地下分支或整关通关证据。
- 正常入口基线 `actual/checkpoint-stream-main-baseline`：3116 帧状态门禁、91 张抽样截图全部通过，报告 `checkpoint-stream-main-baseline/reports`。
- 下一步处理检查点截图差异（第 20 帧差异已定位到植物区域），并建立实际成功进入/领取金币/返回地下房的原版路线。未发布新包/release，天空入口及整关验收仍未完成。


### 2026-10-31：地下成功进出路线完整验证

- 固定输入路线从第 6 页检查点出发，等待植物周期后于 173 帧下管，247 帧开始房间入口，264 帧恢复控制；领取 8 枚金币；490 帧进入横管，676 帧开始主地图管道出口，772 帧恢复控制，900 帧结束时存活并保留 8 金币/1600 分。
- 版本化回放：`world-2-1-underground-checkpoint-route.json`（抽样）及 `world-2-1-underground-checkpoint-route-all-frames.json`（全部 900 帧截图）。检查点起点仅设置加载位置，没有修改后续玩家、碰撞或地图内存；不是正常入口整关路线。
- 修复植物双阶段绘制坐标、动画位选择、死亡运动冻结、计时器到零立即执行；下管首帧滚动及运动小数保留、整数管口采样、横管首帧加速、清场帧跳过敌人运动、换区相机清零；返回时按原版重建敌人槽而保留被破坏的地形，避免残留升起的植物。
- 全帧检查额外发现并修复金币 VRAM 擦除延迟、首入口精灵隐藏、时间 HUD 延迟，以及 OAM 背景优先级的缓冲交接。使用优先级缓冲，未通过修改角色位置去掩盖绘制差异。
- `reference/underground-all-frames` 的连续视频/存档恢复：900 帧状态与 APU 写入一致。最终宿主 `actual/underground-all-frames-v3`：900 帧当前状态门禁、900 张零容差截图、25 项语义事件时序、5407 次模型 APU 写入全部通过；最终模型写入与用于 PCM 渲染的 v1 模型文件逐字节相同。
- APU 模型从参考起点的一次声音 RAM 状态初始化，之后使用宿主事件/状态和离线 ROM 音频数据；PCM 渲染复用参考 CPU 写入周期时间表及 Mesen 2A03 硬件模型。`underground-audio/reports/audio-report.json` 中两侧 718749 个 48kHz 双声道样本帧的 PCM SHA-256 相同、误差为零。这不代表设备扬声器输出或实时 WinMM 混音逐样本一致。
- 原有诊断复验：`underground-final-main-regression` 的 3116 帧状态/91 张截图通过；`underground-final-death-regression` 对应实际目录 `actual/underground-final-death-regression-retry` 的 600 帧状态/31 张截图通过。首轮 Vulkan 窗口失败日志保留，不当作通过。
- 所有路径均相对 `local-parity/world21-runtime`；最终分支报告在 `underground-all-frames-v3/reports`。v1/v2 失败截图与状态证据保留。10 组模拟回归、8 项 Python 测试和原生混音测试通过。
- 预览包：`dist/super-mario-world21-underground-verified-win64/SuperMario.exe`，第二次窗口启动/标题/图标/关闭检查通过；首次 Vulkan 初始化失败报告保留。未发布新 release，版本仍为 0.0.7。
- 本节仅完成地下分支的检查点起点验证。天空分支、正常入口成功整关路线和 32 关严格验收仍待完成；不会登记 2-1 整关为已验收。


### 2026-11-02：藤蔓与天空奖励分支

- 接入主图第 83 列藤蔓砖块、薄藤蔓接触范围、上/下爬、侧换边及跳离、自动爬升切区；天空入口等待藤蔓生长后自动爬入并侧移释放。按原版两次 SetupVine 写入的合并结果生长到 96 像素，原生声音只播放一次。
- 天空静态地图重新完整采集 86 列，包含 41 枚金币；第 62 列开始无云层地面。原版大云平台使用 48×8、CHR $75、精灵调色板 2，首次站上后以每帧 1 像素向右移动。
- 云区终点命令在解析器提前 22 列处理时锁定相机到 X=992；滚动量按真实位移归零。平台右移时采用玩家 X+13 的原版包含边界，修复提前失去支撑和移出平台后仍被承载。
- 云区掉落在屏幕以下先停止滚动/计时，到原版高字节深度门槛后返回主图第 10 页，从顶端正常下落；不扣命，保留金币、分数、强化和主图地形改动。返回入口按 Y>=48 交还控制，恢复首帧加速度。
- 完整路线包含第 4 页检查点后的真实固定按键接近、跳管、顶出藤蔓、跳到上层、爬藤、进入天空、乘云、离开云和返回；没有在路线途中重写模拟器玩家、碰撞或地图内存。第 5 页直接起点缺少原版跨页物体延续，因此未用它替代成功路线。
- 修复全帧检查发现的同组后续敌人当帧运动、藤蔓双缓冲高度、交错 8×8 精灵、边界裁切、砖块弹起的 OAM/背景优先级、天空入口马里奥背景优先级，以及 sprite 0 对 HUD 重叠像素的遮挡。
- 三种形态的分支往返、侧换边释放、云平台首乘/持续承载/边缘脱离及地形/强化保留均纳入十组模拟回归。新增快速状态诊断工具 `tools/parity/run_world21_simulation.py`，明确不代替实际窗口画面或设备音频验收。
- 最终全帧证据：`reference/sky-cloud-all-frames` 的连续视频/存档回放 2400 帧状态和 APU 写入一致；`actual/sky-cloud-all-frames-v4` 对应 `sky-cloud-all-frames-v4/reports` 的 2400 帧选定状态字段、2400 张零容差截图、16 项事件和 19219 次模型 APU 写入全部通过，无缺帧。v1/v2/v3 失败证据保留，最终没有放宽比较阈值。
- `sky-cloud-all-frames-v4/audio/reports/audio-report.json`：1916776 个 48kHz 双声道 PCM 样本帧逐样本一致（SHA-256 `88e02e0f774cc7f00ef38dd60733791b86ca7cba54e84e90df210bb45e9f2e85`）。同样属于参考周期时间表及 Mesen 2A03 模型上的音频验证，不代表实时原生混音/扬声器逐样本一致。另一条 2000 帧云层地面掉落路线也通过状态、事件、15779 次模型 APU 写入和模型 PCM；没有据此声称其全部画面已验收。
- 共享代码复验：`sky-final-underground/reports` 的地下 900 帧选定状态、900 张全帧画面、事件和 5407 次模型 APU 写入均通过，模型写入与已验证地下 PCM 的版本完全相同；`sky-final-main-regression/reports` 的 3116 帧死亡/标题返回/新游戏状态及 91 张抽样截图通过。
- 十组模拟回归、六项分支/资源 Python 测试、三项既有 Python 测试及原生混音单元测试通过。构建包 `dist/super-mario-world21-sky-verified-win64/SuperMario.exe`；`sky-cloud-all-frames-v4/package-startup.json` 的标题、大小图标、首帧显示及正常关闭检查通过。
- 所有证据目录均相对 `local-parity/world21-runtime`。本节完成天空分支的检查点起点验证，下一项为正常入口成功整关路线；2-1 仍未登记为整关严格验收通过。版本保持 0.0.7，未发布新 release。


### 2026-11-07：长按踩踏、敌人 OAM 与死亡重载收敛

- 长按 A 的跳跃到达顶点后永久切换为下落重力；随后踩踏改变垂直速度时不再错误恢复起跳重力。乌龟 40 帧 ROM 回弹自检同时覆盖松开和持续按住 A。
- 2-1 敌人互撞使用整数碰撞边界及龟壳原始高度；被踩栗宝宝失去支撑后继续下落，保留原状态字节和对象槽小数位置。绿龟转向、动画、龟壳绘制位置及屏幕边缘裁切采用 OAM 分块素材。
- OAM 提取器只采集实际龟壳帧，排除 `green-shell-*-inspect.png` 检查图；生成结果重复执行字节一致。新增 36 张运行时精灵切片，未纳入检查图的 192 张冗余切片。
- 死亡重载第 3 帧清理区域音乐队列并实际发出静音，同时隐藏时间 HUD。显示流程按 ScreenRoutines、ResetSpritesAndScreenTimer 和 NMI/OAM 交接分开处理旧场景、天空色清屏、黑屏、续命页及重新入场；续命页末帧提前清除角色精灵，重新入场首帧隐藏角色。
- 新增 `world-2-1-held-jump-stomp-probe.json` 与 `world-2-1-held-jump-stomp-probe-all-frames.json`。正常入口起点、1601 帧固定输入，覆盖长按踩踏、敌人落下及两次死亡重生；这是一条诊断，未成功通关。
- 地下检查点分支 900 帧、天空检查点分支 2400 帧再次通过选定状态、全部零容差画面、事件、模型 APU、模型 PCM 和产物契约检查。证据：`local-parity/current-validation-20261107/{underground-all-frames,sky-cloud-all-frames}/reports`。这轮分支回放先于随后仅针对死亡画面的修正，未扩大为任意路径或设备音频验证。
- 旧通关候选的 3210 帧模拟诊断与最新参考解码器对照后，选定玩家/镜头/进度字段一致；原版与宿主均在 936、1884、2440 帧死亡。剩余字段差异从 `enemy0.x` 第 637 帧（583 对 582）和 `powerup.state_raw` / `powerup.y` 第 1434 帧开始；没有因参考生命下溢解码错误继续报告 256 命。证据：`local-parity/current-validation-20261107/route-candidate-simulation/reports`，它没有渲染或音频验收。
- 本机根目录直接回放的热重载扫描耗时约 24 秒，回放未在默认超时内完成；日志保留在 `current-validation-20261107/held-jump-stomp-all-frames/actual`。后续使用隔离源码副本，仅关闭热重载，保留 parity 强制启动自检；实际窗口回放串行执行。另保留 `current-validation-20261107/main-route/actual-isolated` 中本轮中间版本的绘制参数类型错误；最终版将颜色零值改为浮点数后重新验证。

最终踩踏诊断：1601 帧选定状态、28 项语义事件、8804 次模型 APU 写入、模型 PCM 和产物契约通过；全帧画面由本轮修正前的 30 帧失败降至 10 帧，零缺帧，阈值仍为零。剩余帧为 354 / 375 / 376 / 379 / 473 / 474 / 1153 / 1154 / 1588 / 1589，涉及转向、死亡瞬间的 OAM/玩家图像及起跳显示缓冲，仍保留失败。新录像统一为 Git 规定的 LF，按提交文件哈希重新采集参考和预览包实际窗口；两侧各 1601 张重采 PNG 与换行统一前逐文件相同。最终报告：`local-parity/committed-validation-20261107/reports/world-2-1-held-jump-stomp-probe-all-frames`。

预览包：`dist/super-mario-world21-stomp-preview-20261107-win64/SuperMario.exe`。原生构建/混音测试及首帧显示、窗口标题、大小图标、正常关闭检查通过，启动报告在 `local-parity/committed-validation-20261107/package-startup.json`。最终窗口回放首轮 Vulkan 初始化失败保留在该目录的 `actual/world-2-1-held-jump-stomp-probe-all-frames-startup-failure`；重试仅对该进程禁用隐式 Vulkan 层，未修改系统设置。

快速及共享代码回归：10 组模拟回归、23 项 Python 测试和原生混音 CTest 通过；World 1 七条既有 ROM 回放共 4260 帧状态、各自指定的采样画面、事件、APU、PCM 和产物门禁全部通过。前六条报告在 `local-parity/final-validation-20261107/w1`，高旗杆重试报告在 `local-parity/verified-validation-20261107/w1/world-1-1-high-flag`；首轮 Vulkan 初始化失败日志保留在前一目录。

本轮补跑主线诊断的全帧及音频门禁：3116 帧选定状态通过，3116 张画面中 58 张失败；事件缺少第 2649 帧标题初始化静音，模型 APU 从第 2647 帧开始不一致。虽然 PCM 文件相同，重放清单存在 467 次地址不匹配和 942 次缺少参考写入，产物门禁正确失败，不能将 PCM 一致当作模型音频通过。证据：`local-parity/final-validation-20261107/main-route/reports`。它补充了旧 91 张抽样截图和状态记录，不能据旧记录推断全帧/音频通过。

后续顺序：先收敛剩余敌人/玩家显示缓冲差异、正常入口敌人 X 和道具出现/运动时序，以及标题静音事件和 APU 模型，再建立真正成功的正常入口路线，补齐 2-2 及跨关衔接。仍不登记 2-1 为整关完成，发布版本保持 0.0.7。

重建任一用例时，可以先构建一个隔离 Windows 包，再分别生成参考和实际产物；启用 parity 会强制运行启动自检，即使包配置关闭常规启动自检。以下命令生成新的参考，不依赖本机旧报告：

```powershell
./tools/package_windows.ps1 -Output dist/parity-check
$case = 'world-2-1-held-jump-stomp-probe-all-frames'
$movie = "tests/parity/movies/$case.json"
$rom = 'roms/Super Mario Bros. (World).nes'
python tools/parity/run_reference.py --rom $rom --movie $movie --output "local-parity/recheck/reference/$case"
python tools/parity/run_actual.py --movie $movie --project dist/parity-check --timeout 600 --output "local-parity/recheck/actual/$case"
python tools/parity/run_case.py --rom $rom --movie $movie --artifacts local-parity/recheck --skip-runs
```

`run_case.py` 会保留失败门禁；上述踩踏诊断存在已知画面差异，不能预期整体退出码为零。模型音频仍由宿主事件/状态生成寄存器值，PCM 使用原版周期时间表及 Mesen 2A03，不代表实际扬声器输出逐样本一致。


### 2026-11-08：标题音频与 OAM 逐帧对照收敛

本轮解决上一节保留的标题音频及两条正常入口诊断画面差异。以下均为诊断或奖励分支证据，不是成功通关整关验收。

| 回放 | 起点与覆盖 | 状态帧数 | 零容差画面 | 六项门禁 |
| --- | --- | ---: | ---: | --- |
| `world-2-1-held-jump-stomp-probe-all-frames` | 正常入口、长按踩踏、两次死亡重生 | 1601 | 1601 / 1601 | 全部通过 |
| `world-2-1-main-host-route` | 正常入口、三次死亡、Game Over、返回标题 | 3116 | 3116 / 3116 | 全部通过 |
| `world-2-1-underground-checkpoint-route-all-frames` | 第 6 页检查点进入地下、领取金币、返回 | 900 | 900 / 900 | 全部通过 |
| `world-2-1-sky-cloud-platform-route-all-frames` | 第 4 页检查点顶藤、爬入天空、乘云、返回 | 2400 | 2400 / 2400 | 全部通过 |
| `world-2-1-title-new-game` | 正常入口至标题，再开始新游戏 | 3116 | 91 / 91（采样） | 全部通过 |

前两条最终报告在 `local-parity/accepted-parity-20261108/{held-jump-stomp-all-frames,main-route}/reports`；后三条在 `local-parity/parity-final-20261108/{underground-all-frames,sky-cloud-all-frames,title-new-game}/reports`。合计 11133 帧选定状态、8108 张指定画面；不把最后一条的采样检查称为全帧画面验收。

- 标题音频：按原版 `SoundEngine` 的 `OperMode` 分支，在标题模式只写 `$4015=0`，不消费声音队列或推进音乐；SoundEngine 观察本帧游戏逻辑执行前的模式。独立处理 `InitializeGame` 清零页/声音 RAM 及两次无 SoundEngine 的初始化阶段，不从后续参考 RAM 重新播种模型。新增标题初始化、新游戏区域初始化的静音请求，并从原版模式切换独立解码 `new_game` 事件。
- 原版周期载体上的主线 APU 流 15118 次、新游戏 APU 流 16787 次完整匹配；PCM 与产物门禁通过，注入清单没有 `address_mismatch` 或 `missing_reference_write`。这消除了上一节“PCM 一样但注入失败”的假充分证据。音频验证边界仍是宿主模型寄存器值加原版周期时间表/Mesen 2A03，不是设备扬声器录音或独立实时周期调度验证。
- 精灵缓冲：方向、动画、位置、死亡图像及新对象的图形可见性分别按 OAM 准备页交接。敌人槽刚分配时不提前画旧坐标；同组后续槽仍保留原版当帧处理规则。死亡会停止运动，但仍重建敌人图形页，并区分致死碰撞之前/之后处理的槽位。
- `FloateyNumbersRoutine` 会复用被踩乌龟的头部 OAM 行；分数出现时隐藏被覆盖的旧行。实现 `$58/$48/$38` 三相精灵分配轮换，按实际 OAM 地址处理重叠优先级，换区及恢复主图时清零轮换相位；地下/天空共 3300 帧相位追踪与原版一致。
- 新增 `scripts/oam.nut`：对主图已经分块的玩家、普通敌人及植物精灵逐扫描线按 OAM 地址选择前八个单元，透明图块也占名额。仅对真实溢出的像素行缓存 8×8 裁切纹理，视口外像素交给 GPU 裁切；使用官方 SDK 的 ImageData/Texture API，不修改引擎或添加切片文件。其他专属演员保留现有路径，不宣称完整 PPU 或溢出标志行为模拟。
- 普通绿龟离开平台后改用既有 ROM 整数重力/位置累加器；保留跳跃绿龟独立路径，按各自 ROM 原点落地。2-1 重生时清除动画计时器设定，修复落地后两个走路图像。World 1-3 的 `world-1-3-route` 在本轮前后全部 1840 帧导出模拟状态逐字节相同，报告在 `local-parity/visual-fix/world13-preservation`；这不代表该路线画面或整关验收。
- 29 项 Python 测试、10 组模拟回归通过；OAM 自检覆盖第九个精灵、局部扫描线遮挡及视口边界。新增六项标题/APU 测试无需 ROM，并纳入 Windows 发布工作流。

保留失败证据：`parity-finish-20261107` 记录中间版本的主线 25 帧差异；`parity-final-20261108` 保留首次最终复验中的底部一行像素问题，以及从 2651 帧起重复旧 Game Over 图像的一次主线采集异常。补充原生渲染状态诊断和完整重录后通过，未修改输入、阈值或删去失败帧。Vulkan 初始化失败日志另保留；重试仅对进程禁用隐式层。

旧 `world-2-1-route-candidate` 的 3210 帧快速模拟仍存在第 637 帧 `enemy0.x` 和第 1434 帧起道具状态/运动差异，证据在 `local-parity/accepted-parity-20261108/route-candidate/reports`。下一步先修这条正常入口候选，再建立存活至旗杆/结算和下一关的成功路线。World 2-2、跨关衔接和正式逐关验收仍未完成；版本保持 0.0.7，未发布新 release。


最终共享回归：World 1 七条既有回放共 4260 帧状态及各自指定画面、事件、APU、PCM、产物契约全部通过。前五条报告位于 `local-parity/world1-final-20261108`，TAS 与高旗杆重试报告位于 `local-parity/world1-final-retry-20261108`；TAS 首轮 Vulkan 初始化失败保留。没有将这七条回放的采样画面称为全帧检查。

本轮预览包为 `dist/super-mario-world21-parity-preview-20261108-win64/SuperMario.exe`；原生构建/混音 CTest、窗口首帧显示、标题、大小图标、正常关闭检查通过。启动证据为 `local-parity/accepted-parity-20261108/package-startup.json`。源码默认启动 1-1，F5 进入 2-1；这不是新的正式发布版本。

## Normal-entry candidate state follow-up (2026-11-08)

旧 `world-2-1-route-candidate` 本轮已通过全部 3210 帧选定状态字段；没有改输入、放宽容差或改状态解码来隐藏差异。参考状态使用当前解码器重新读取旧 RAM 轨迹，消除旧文件对生命 `$ff` 的历史下溢解释。快速报告：`local-parity/route-fix-20261108/candidate-final/reports`。

- 第 637 帧敌人转向偏差来自逐槽执行顺序：较低槽已经完成移动，较高槽随后用本帧保存的碰撞盒将双方转向。2-1 改为在各对象自己的处理过程中碰撞，低槽保留本次运动；World 1 继续使用原路径。
- 第 892 帧起新板栗的半像素偏差来自前任乌龟被踩时抹去了水平小数。2-1 保留槽位的独立运动余量，停止的整数坐标仍由导出和绘制取整；槽位复用后接续余量。
- 蘑菇冒出按全局 `FrameCounter & 3`，不从生成瞬间另起四帧计数。普通蘑菇和 1UP 接入整数位置、重力小数、状态 d6、落地和移动后墙面检测；保留落地位置小数，并在屏幕左侧 72 像素边界外回收。撞砖弹起会初始化整数垂直速度并保留受击状态位。星星与花保留各自运动路径，未据此宣称全部道具严格验收。
- 增加逐槽相撞、全局生成相位及撞砖蘑菇上升自检。10 组模拟回归与 29 项 Python 测试通过。报告：`local-parity/route-fix-20261108/simulation-bump`。

该候选仍在 936 / 1884 / 2440 帧死亡，不能作为成功通关路线或整关完成证据。输入文件保持 Git 版本原字节；旧参考的 CRLF 哈希另行保留，不覆盖成当前 LF 哈希。

实际窗口重采：按当前 LF 录像文件重新生成参考，连续录像证明全部 3210 帧 RAM 与 APU 写入一致；宿主选定状态、49 项语义事件、18255 次模型 APU 写入、模型 PCM 与产物契约通过。零容差逐帧画面中 242 / 3210 张失败、零缺帧，首帧为 570（29 像素）；大量后续差异位于死亡后的敌人图像，仍保留。报告：`local-parity/route-fix-20261108/runtime-final/route/reports`。首次产物检查缺少新参考的派生语义事件文件，补生成后通过，原检查保留为 `artifact-before-derived-events.json`。没有据状态通过宣称画面或整关通过。

### Successful ROM route and next remake divergence

新增 `tests/parity/movies/world-2-1-normal-clear.json`，2398 帧、67 段固定输入，正常小马里奥入口、无检查点。原版全程三条命，第 1753 帧触旗，第 2397 帧 StageNumber 变为 2；录像结束于这次切换的首帧，不声称覆盖完整 2-2 入场。路线通过空中减速落在长坑前、压缩弹簧后再次按跳跃取得高弹力；搜索只读取状态并输入按键，不改游戏 RAM。自适应搜索器不进入游戏运行时。

固定输入随后由标准 `run_reference.py` 独立重放，连续录像的 2398 帧状态及 APU 写入一致；与搜索日志的 X、含高位页的 Y、生命、世界/关卡和子程序逐帧全部相同。证据：`local-parity/route-fix-20261108/normal-clear/fixed-input-proof.json` 及 `reference-lf/continuous-video/proof.json`。比较 Y 时直接从原始 RAM 计算 `Player_Y_Position + (Player_Y_HighPos - 1) * 256`，避免搜索日志有符号高度与已有语义解码低字节表示混用；未修改公共状态解码器。

修正落地转向前，宿主在该固定输入的快速模拟中，首个玩家运动差异为第 404 帧垂直速度：原版 -4，宿主 +4；随后第 405 帧 Y 不同。该漏踩交互的修正见下段。宿主后续死亡，旗杆、结算和 2-2 转场均未验收。报告：`local-parity/route-fix-20261108/normal-clear/simulation/reports`。新录像是可复现的成功原版路线，不登记为宿主完成关卡。

标准完整用例入口新增 `--actual-timeout`，默认仍为 120 秒；全帧窗口截图可显式设置 600 秒。旧候选首次实际采集在 120 秒截止时仅取得 2767 帧，失败保留于 `candidate-runtime-fresh/actual`，随后隔离重采完整 3210 帧；没有删减截图或提高差异阈值。

```powershell
python tools/parity/run_case.py --rom 'roms/Super Mario Bros. (World).nes' --movie tests/parity/movies/world-2-1-normal-clear.json --artifacts local-parity/normal-clear-recheck --actual-timeout 600
```

该命令预期保留当前宿主差异并返回失败，不能以原版路线成功推断宿主验收通过。World 2-2、跨关实现及正式逐关完成登记仍待推进；发布版本保持 0.0.7。

后续定位及修正：普通乌龟从平台落地时，原版会在恢复行走前面向玩家；宿主保持旧方向，导致第 392 帧起该乌龟位置不同、第 404 帧漏踩。2-1 现补齐落地方向选择，保留浮点水平速度，跳跃敌人和 World 1 路径不变；增加落地后朝玩家移动的自检。新成功路线的选定状态首差推迟到第 581 帧：跳跃初速度原版 -5、宿主 -4，Y 原版 171、宿主 172。报告：`local-parity/route-fix-20261108/normal-clear/landing-final/reports`；原始 404 帧失败仍保留在 `normal-clear/simulation`。

本轮实际窗口复验中，1601 帧踩踏诊断（`actual-regression/held-jump-stomp-all-frames`）、3116 帧主诊断（`actual-regression-retry/main-route`）、900 帧地下、2400 帧天空及 3116 帧/91 张采样画面的新游戏诊断（后三项位于 `runtime-final`）全部通过六项门禁。以上路径均以 `local-parity/route-fix-20261108` 为根。主诊断及地下诊断各有一次 Vulkan 初始化失败，分别保留在 `actual-regression/main-route`、`actual-regression-retry/underground-all-frames`；未覆盖失败日志。

最终落地方向修正另做上述五条诊断和旧候选的模拟前后对照，范围是全部导出 JSON 字段，不是只看玩家 X/Y；结果见 `landing-preservation/summary.json`。这与实际窗口重采是两项独立证据，不能将模拟对照称为重新采集画面。

最终落地修正前后六条诊断合计 14343 帧导出状态全部相同。最终 Win64 预览包：`dist/super-mario-world21-route-final-preview-20261108-win64/SuperMario.exe`；原生构建、混音 CTest、首帧可见性、标题/图标及正常关闭检查通过，报告 `local-parity/route-fix-20261108/package-startup.json`。最终 10 组模拟自检通过，含本轮新增落地方向、碰撞顺序、全局生成相位与撞砖上升场景。

新增成功录像按 Git 规定统一为 LF 后，以最终提交字节哈希重新生成完整参考，位于 `normal-clear/reference-lf`。与首轮 CRLF 采集相比，2398 帧完整导出状态、APU 写入和全部 2398 张 PNG 逐字节相同；`fixed-input-proof.json` 核对输入文件与 Git 暂存字节一致，并记录最终哈希。两次原始 RAM 轨迹在栈页 `$0160-$01ec` 范围内的 141 个地址存在差异，没有将导出状态一致称为全部 RAM 字节一致；差异原样保留。首轮 CRLF 参考及证明保留在 `normal-clear/reference` 和 `fixed-input-proof-crlf.json`。宿主第 581 帧失败已按 LF 参考再次比较确认。


## Normal-entry settlement state alignment (2026-11-08)

`world-2-1-normal-clear` 的输入及 LF 哈希保持不变。本轮宿主按该输入保住三条命，触旗、走入城堡并完成时间结算。实际窗口完整 2398 帧状态对照中，帧 0..2396 的全部选定字段一致；只在 2397 帧（原版开始切换 2-2）留下 `level`（2 / 1）与 `oper_mode_task`（0 / 3）差异。没有截掉末帧或把完整门禁标为通过。

本轮修正：

- `beginNesJump` 使用上次运动更新保存的 `Player_XSpeedAbsolute`，不使用被背景碰撞刚清零的 X 速度；这解决第 581 帧撞墙后起跳的 -5 / -4 差异。共享改动以既有 World 1 回放对照验证。
- 2-1 星星改用 `$1c` 整数重力、位置小数、落地反弹与运动后侧面检测，解决 619 帧起的 Y 差异；藤蔓初始化复用槽 5，立即使原星星失效，解决 713 帧的活跃状态差异。
- 弹簧在落地当帧就移动玩家两像素；压缩期间保持 X/Y 位置积分余量，正常速度计算继续，但不进行普通移动或起跳。原水平移动子程序提前返回时 A 寄存器中的弹簧阶段仍被滚动器消费，现将该值传给滚动过程；不把玩家位置冻结误当作镜头也冻结。
- 压缩后重新按 A 得到 -12 发射速度，发射保留 Y dummy 与原有下落力，不重复发出普通跳跃声音；首次离开发射器的运动状态使用 falling 路径。死亡会冻结弹簧机械过程。
- 槽 5 的 Y 小数余量从星星、藤蔓保留至旗帜，旗帜位移按 `ADC #$ff` 的进位推进，修复触旗到结束页的一帧偏差。旗杆元图块 `$24/$25` 使用非实体碰撞映射，避免马里奥被旗杆轴错误托住；末段滚动由城堡碰撞和 ScrollLock 结束，不提前按离线提取图宽裁断。

实际窗口报告位于 `local-parity/jump-fix-20261108/runtime/normal-clear/reports`：

| 门禁 | 结果 |
| --- | --- |
| 状态 | 2398 帧，只有末帧的关卡/加载阶段两字段失败 |
| 全帧画面 | 2398 张、零缺帧、零容差；1208 张失败，首帧 101（120 像素） |
| 语义事件 | 音效/结算时序一致；仅少末帧的 2-2 初始化静音事件 |
| 模型 APU | 15625 次写入一致 |
| 模型 PCM | 通过，沿用原版周期载体/Mesen 边界，不代表独立设备采样录音 |
| 产物契约 | 通过，无运行错误 |

完整摘要仍为失败。下一步从 101 帧显示差异开始定位，并补齐关卡尾部显示、2-2 实现及跨关初始化；不以这次状态对齐登记整关验收。旧候选的 242 帧画面失败也保持原记录。

自检增加撞墙后保留跑速的起跳、星星首步小数重力、藤蔓覆盖道具槽、弹簧首帧位移/冻结/晚按 A/发射余量、旗帜槽位进位场景。29 项 Python 测试和 10 组模拟自检通过。World 1 七条既有 1-1 回放加 1-3 路线共 6100 帧导出模拟状态在修正前后完全相同，证据 `local-parity/jump-fix-20261108/world1-preservation`；这不是新采集的画面或音频验收。World 2-1 旧六条诊断的最终导出状态对照记录在 `preservation-final`。

最终 Win64 预览包为 `dist/super-mario-world21-clear-preview-20261108-win64/SuperMario.exe`。原生构建、混音 CTest、首帧显示、标题/图标与正常关闭检查通过；启动证据：`local-parity/jump-fix-20261108/package-startup.json`。版本仍为 0.0.7，未发布新 release。


## Brick-bump and castle-tail image follow-up (2026-11-08)

本轮保持 `world-2-1-normal-clear` 的输入、2398 帧时长及零容差。完整实际重采的失败画面由 1208 / 2398 降为 834 / 2398、零缺帧，最早失败从 101 推迟到 441。状态和语义事件文件与上一轮实际采集逐字节相同；仍只有末帧的 2-2 关卡/加载切换和静音事件失败，整关门禁保持失败。完整报告：`local-parity/pixel-fix-20261108/full-stride/reports`。

- 2-1 的专属元图块绘制分支原先绕过普通砖块弹起位移。现接入既有 14 帧、两种进位轨迹，保留藤蔓砖已有处理。130 帧正常入口短回放全部画面零差异，报告 `probe1/summary-prefix.json`；它只是同输入前缀检查，不另作整关验收。
- 正常结算镜头会显示到地图第 213 列，而旧离线数据只保存 0..211。生成器宽度改为 214 后重新从已校验 ROM 的连续解析器补采，尾部仍要求 200..205 六列与前向解析一致。原有 212 列元图块和碰撞数据全部相同，只增加 212、213 两列；证据 `map214/manifest.json` 与 `map214/prefix-proof.json`。当前生成数据及素材清单均更新，早期章节中的 212 列记录保留为历史。
- 宽度扩展暴露了原先用 World 1 逻辑宽度兼任数组行跨度的边界。增加 `TILE_STRIDE=214` 作为扁平地图存储跨度，World 1 的 `LEVEL_WIDTH=212` 保持不变；所有使用该跨度的区域/元图块数组一致扩容。新增跨行不别名和尾列地面自检。初次扩展时的 3180 索引越界由模拟回归捕获，失败记录保留在 `regressions`；当时未产出画面的窗口采集已停止并保留在 `full`，修正后在 `full-stride` 独立重采。

本轮没有重新生成模型音频：先验证新旧完整 `state.jsonl`、`events.jsonl` 逐字节相同，再复用上轮 APU、PCM 和混音清单，并重新执行 APU/PCM/产物比较。三个门禁均通过；复用证据为 `full-stride/audio-reuse-proof.json`，不能将其称为新的设备录音。状态/事件的旧末帧失败没有被音频复用掩盖。

29 项 Python 测试、10 组模拟自检通过。World 1 八条路线共 6100 帧、2-1 六条既有诊断共 14343 帧导出状态在本轮前后完全相同，分别见 `world1-preservation`、`world21-preservation`。共享存储改变后，额外重采 1-1 蘑菇用例，300 帧状态及该用例指定的采样画面通过原版对照，见 `world1-powerup-reports`；未把采样称为全帧画面。

剩余首帧 441 涉及金币砖、金币/分数图像与 HUD 更新；后续继续从该帧定位。正常成功路线仍有 834 帧显示失败，World 2-2 尚未实现，正式逐关完成登记不变。以上路径均以 `local-parity/pixel-fix-20261108` 为根。

最终预览包：`dist/super-mario-world21-pixel-preview-20261108-win64/SuperMario.exe`。原生构建/混音 CTest 与窗口首帧、标题/图标、正常关闭检查通过，启动报告 `local-parity/pixel-fix-20261108/package-startup.json`；包内脚本逐字节匹配工作区，回放默认禁用，不包含 ROM 或存档。上述 1-1 补验实际比较 93 张指定采样图像，均为零差异。


## Coin-block HUD and OAM priority follow-up (2026-11-08)

同一条 2398 帧正常入口成功路线的画面失败从 834 降至 821、零缺帧；最早失败从 441 推迟到 468，剩余该帧的 3 个白色像素位于屏幕右侧浮动分数字样。逐帧差异像素数相对上一轮均未增加，也没有新增失败帧。完整报告：`local-parity/coin-fix-20261108/full/normal-clear/reports`。

第 441 帧实际包含多项独立偏差，本轮修正如下：

- 2-1 问号金币砖及星星砖的替换元图块在下一张准备图像生效；跳出金币允许在该路径的首张 OAM 图像显示。金币砖奖励立即排入分数/金币的 HUD 队列，保留普通拾取金币的既有时序及 VRAM 缓冲选择策略；一百金币归零与加命后的队列值有独立自检。
- `Block_Objects` 使用两个交替的 OAM 区域（默认 `$d8/$e8`）。现记录交替槽位，并通过已有的三相精灵轮换计算实际地址。浮动分数复用所属敌人的 OAM 单元；砖块地址较小时，仅在砖块非透明像素覆盖的范围内遮住分数字样，修正 442..450 的周期性重叠差异。这一处理覆盖弹起砖与浮动分数的组合，其他对象组合继续按各自现有路径验证。
- 使用公开 ImageData/Texture API 缓存必要的透明遮罩变体，生成前克隆加载的图像数据，避免修改缓存的源图像并使后续位置变体累计丢字。同样保护已有的扫描线裁切变体；没有修改原 PNG 或 SDK。
- 星星砖的弹起位移使用已捕获的强化砖进位轨迹，修正 555..564 的一像素高度偏差。第 553 帧仍保留 7 个像素差异，没有调整阈值。

570 帧针对性短诊断只采集 61 张指定画面；最终 `probe4` 中仅 553 帧的 7 像素失败。`probe1` 的首张 425 异常和遮罩累计丢字、`probe2/3` 的中间编译失败均原样保留，最终完整回放继续比较全部 0..2397 帧，不靠跳过采样帧建立通过证据。

实际窗口完整复验：

| 用例 | 状态/图像结果 | 其它门禁 |
| --- | --- | --- |
| 正常入口 2398 帧 | 821 张画面失败；选定状态仍只在末帧缺少 2-2 关卡/加载切换 | 仅少末帧静音事件；APU/PCM/产物通过 |
| 长按踩踏 1601 帧 | 全状态与全部 1601 张画面通过 | 六项通过 |
| 主诊断 3116 帧 | 全状态与全部 3116 张画面通过 | 六项通过 |

这些用例的新旧 `state.jsonl` 与 `events.jsonl` 逐字节相同，模型音频在此守卫下复用并重检，证据见各用例的 `audio-reuse-proof.json`。本轮不把复用称为重新录制的音频。三个用例报告分别在 `full/normal-clear`、`full/held-stomp`、`full/main-route`。

29 项 Python 测试、10 组模拟自检通过，增加交替砖槽位、三相 OAM 地址和 HUD 奖励队列检查。World 1 八条路线共 6100 帧、2-1 六条诊断共 14343 帧导出模拟状态在本轮前后全部相同，分别位于 `world1-preservation` 与 `world21-preservation`。所有路径均以 `local-parity/coin-fix-20261108` 为根。

后续继续定位 468 帧浮动分数的右侧像素及其它剩余显示差异；2-2 和末帧静音初始化尚未实现，正常成功路线仍未通过全部门禁，逐关验收状态不变。

最终预览包：`dist/super-mario-world21-hud-preview-20261108-win64/SuperMario.exe`。原生构建、混音 CTest、窗口首帧、标题/图标与正常关闭检查通过，启动证据 `local-parity/coin-fix-20261108/package-startup.json`；脚本与工作区逐字节一致，默认禁用回放，包内无 ROM/存档。版本仍为 0.0.7，未发布新 release。


## Floating-score OAM row reuse (2026-11-09)

完整正常入口路线保持原有 2398 帧输入、零像素容差及零缺帧。失败画面由 821 降至 808，首个失败由 468 推迟至 517（46 像素）；修复 468、470、471、473、474、476、477、479、480、482、483、485、486 共 13 帧，所有帧的差异像素数均未增加。完整报告 `local-parity/score-row-fix-20261108/full/normal-clear/reports`，逐帧前后证明 `image-change-proof.json`。

上一节把第 468 帧的三个白像素归因于浮动分数，现更正：它们属于右侧乌龟的翅膀。浮动分数复用被踩敌人的前两个 OAM 单元，原宿主却仍把被替换的透明头部计入原位置的八精灵扫描线预算，错误裁去翅膀。现在让分数按所属敌人的实际轮换地址登记两个单元，同时移除敌人被覆盖的第一行；中间透明行仍保留并占用扫描线预算，不能连带删除。分数的左右单元分别应用扫描线遮罩，并与原有弹起砖块像素遮挡合并，源素材保持不变。

针对性前缀回放比较 146 张画面，仅 517 和 553 两张仍有既有差异；这是采样诊断，完整验收仍比较全部 2398 帧。`probe1` 的 Vulkan 启动失败保留，`probe2` 为成功采集。所有路径以 `local-parity/score-row-fix-20261108` 为根。

正常路线的完整状态/事件文件与修正前逐字节相同，选定状态仍匹配至第 2396 帧；末帧缺少 2-2 关卡/加载切换及静音事件，完整门禁仍失败。模型 APU/PCM/产物门禁通过：音频仅在新旧状态和事件逐字节相同后复用并重检，见各用例 `audio-reuse-proof.json`；并非新设备录音。World 2-2 尚未实现，32 关完成登记不变。下一步从第 517 帧浮动分数字样的显示差异继续定位。

29 项 Python 测试和 10 组模拟回归通过；本轮修改仅涉及渲染，没有把模拟回归称为画面验收。


Win64 预览包：`dist/super-mario-world21-oam-preview-20261108-win64/SuperMario.exe`。原生构建与混音 CTest 通过；首次启动因 Vulkan `VK_INCOMPLETE` 失败，原日志保存在 `package-startup-failed.log`，重试通过首帧显示（1593 ms）、标题/图标及正常关闭，见 `package-startup-retry.json`。包内脚本与工作区逐字节一致，回放默认禁用，不包含 ROM/存档；版本仍为 0.0.7，未发布新 release。


旧路线实际窗口复采没有回归：长按踩踏 1601 帧和主诊断 3116 帧全部指定状态、全帧图像均通过；状态/事件与修正前逐字节一致。两条路线的六项门禁全部通过；在同一音频复用守卫下复检事件、APU、PCM 和产物，报告在 `full/held-stomp`、`full/main-route`。


## Coin-number final prepared image (2026-11-09)

正常入口成功路线仍使用同一份 2398 帧固定按键及零容差。完整采集的画面失败从 808 降至 807、零缺帧；第 517 帧的 46 个缺失像素已归零，最早剩余差异为第 553 帧的 7 像素，逐帧差异像素数均未增加。报告 `full/normal-clear/reports`，前后逐帧证明 `full/normal-clear/image-change-proof.json`。本节所有证据路径均以 `local-parity/coin-tail-fix-20261109` 为根。

第 517 帧是金币砖产生的“200”，并非敌人踩踏分数。原版 RAM 第 515 帧的 Misc_State 为 47，OAM 仍含该数字；第 516 帧对象清除，准备好的图像经两帧 DMA/捕获延迟仍出现在第 517 帧。宿主原先在停用对象时直接隐藏了这张图像。现增加独立的 `displayActive`，在更新前保存显示有效性；2-1 的主金币效果及已归档旧效果均完成最后一次显示交接后再退场。对象 active/计时器、槽位占用、奖励和输入不变，World 1 保持既有绘制路径。

新增自检覆盖主效果到期后只保留一次显示、下一次更新清除，以及新旧金币效果同时存在时旧分数的最后图像和归档回收。33 项 Python 测试和 10 组模拟回归通过。初次自检使用了不存在的辅助函数名，失败记录在 `regressions`；修正为既有 `startJumpingCoin` 后通过，最终见 `regressions-verified`。

`probe1` 的 146 张指定采样画面只剩第 553 帧失败。针对 553 帧尝试保留弹起砖首帧的静止底图，`probe2` 扩展比较 187 张采样后发现它新增了 441 帧差异，也未消除 553 帧，故该尝试已撤回，原始证据保留。最终完整采集使用撤回后的源码，未扩大容差或跳过失败帧。

正常路线新旧完整状态/事件文件逐字节相同，选定状态仍匹配至第 2396 帧；最后一帧缺少 2-2 关卡/加载切换及静音事件，完整门禁仍失败。模型 APU/PCM 在该逐字节守卫下复用并重检，证据 `audio-reuse-proof.json`；不是本轮新设备录音。World 2-2 与跨关衔接仍未实现，逐关完成登记不变。

Win64 预览包 `dist/super-mario-world21-coin-tail-preview-20261109-win64/SuperMario.exe` 的原生构建、混音 CTest、首帧显示（2391 ms）、标题/图标与正常关闭通过，见 `package-startup.json`。包内脚本与工作区逐字节相同，回放默认禁用，不含 ROM/存档；版本仍为 0.0.7，未发布新 release。


旧路线完整窗口复验：长按踩踏 1601 帧及主诊断 3116 帧的全状态、全帧图像、事件、APU、PCM、产物六项门禁均通过，报告分别为 `full/held-stomp` 与 `full/main-route`；状态/事件亦与修正前逐字节相同。

顺带优化画面比较器：将 RGB 最大差、绝对误差及差异图着色的逐像素 Python 循环改为 PIL 的精确整数直方图/查找表处理。新增 4 项测试对照旧循环，覆盖各颜色通道、阈值边界、相同图像、固定随机整帧及差异图全部像素。对本轮正常路线重新比较全部 2398 帧，JSON 报告及按默认上限生成的 40 张差异 PNG 与旧算法产物逐字节相同，证据 `comparator-equivalence.json` 与 `comparator-final-recheck`，零容差和门禁语义不变。30 次 256×240 内存统计微基准约快 10.4 倍（旧统计 0.578 s，新比较含哈希 0.055 s）；此基准不含 PNG I/O 和窗口采集，不代表端到端提速，见 `comparator-benchmark.json`。


## Block background erase and VRAM scheduling (2026-11-09)

同一条正常入口成功路线保持原有 2398 帧固定按键与零容差，完整画面失败由 807 降至 806、零缺帧。第 553 帧的 7 像素归零，最早剩余差异推迟至第 574 帧（12 像素），逐帧差异像素数均未增加。报告 `full/normal-clear/reports`，前后逐帧证明 `full/normal-clear/image-change-proof.json`。本节证据路径均以 `local-parity/block-erase-fix-20261109` 为根。

根因是弹起砖块的 OAM 图像与原位置的背景擦除被合并处理。原版 RAM 第 551 帧的主 VRAM 缓冲已有 `$214a/$216a` 两组空白图块写入，但地图列解析选择了第二缓冲（地址控制值 6），该背景擦除延后。现让块对象首步排入 `backgroundErasePending`，在 NMI 消费主缓冲时才清除；等待期间，原背景元图块在原位置绘制，移动精灵按原有位移单独绘制。新块对象会重置请求，藤蔓保留自己的显示路径。没有补固定坐标像素或改变原 PNG。

自检覆盖首步排队、连续两次第二缓冲占用后仍保留请求、主缓冲恢复后擦除，以及新对象不继承旧请求。33 项 Python 测试、10 组模拟回归与原生混音 CTest 通过。`probe3` 在同输入 610 帧前缀中比较 227 张指定采样图像，第 553 帧修复且无新增退化；它不替代完整 2398 帧比较。初始 `probe1` 的 Vulkan `VK_INCOMPLETE` 启动失败及 `probe2` 的中间试验保留；早期扩展前缀在 569 帧后缺少延续输入，最终 `prefix610-fixed.json` 已从原始通关输入重新裁切，正式完整比较始终使用未修改的原始 movie。

完整正常路线新旧 `state.jsonl`、`events.jsonl` 逐字节相同。选定状态仍匹配至第 2396 帧；末帧仍缺少 2-2 关卡/加载切换与静音事件，整关门禁保持失败。模型 APU/PCM/产物通过，在状态及事件逐字节一致的守卫下复用上一轮音频并重检，见 `audio-reuse-proof.json`，不是新设备录音。World 2-2 与跨关衔接仍未实现，正式逐关完成登记不变。

后续从第 574 帧开始检查星星颜色轮换：宿主使用固定星星素材，参考 OAM 的调色板属性随帧计数变化；本轮仅记录该线索，没有把它计作已修复。


旧路线实际窗口全帧复验：踩踏 1601 帧及主诊断 3116 帧的六项门禁全部通过，零画面差异、零缺帧；新旧状态/事件逐字节相同，模型音频仍按上述守卫复用。主诊断首次窗口启动因 Vulkan `VK_INCOMPLETE` 失败，日志保留在 `full/main-route/actual`；成功采集为 `actual-retry-1`，报告仍在 `full/main-route/reports`。

最终 Win64 预览包：`dist/super-mario-world21-block-erase-preview-20261109-win64/SuperMario.exe`。原生构建/混音 CTest、首帧显示（1562 ms）、标题/图标及正常关闭通过，见 `package-startup.json`；包内脚本逐字节匹配工作区，回放默认禁用，无 ROM/存档。版本仍为 0.0.7，未发布新 release。


## Star palette handoff and HUD priority (2026-11-09)

同一条 2398 帧正常入口成功路线保持原始按键、零容差与零缺帧。最终完整窗口采集的画面失败由 806 降至 708，修复 98 帧，逐帧差异像素数均未增加，最早剩余差异由 574 推迟至 693（146 像素）。最终报告 `full-priority/normal-clear/reports`，前后逐帧证明 `full-priority/normal-clear/image-change-proof.json`。本节所有证据路径以 `local-parity/star-palette-fix-20261109` 为根。

原版 `DrawPowerUp` 对星星的上下两排精灵都使用 `(FrameCounter >> 1) & 3`，每两帧切换调色板；宿主此前固定使用 palette 2 的橙色 PNG。扩展已有离线提取器，从已校验 ROM 的同一组 CHR `$8d/$e4` 导出四种星星颜色，清单记录图块、调色板字节与各 PNG 哈希。四种透明轮廓完全相同，palette 2 与原 `assets/items/star.png` 全部像素相同；25 个提取文件重跑后哈希稳定，见 `asset-proof.json`。

颜色属性需要与精灵图像一起交接。新增道具的 prepared/display 调色板状态，避免直接使用本次更新后的计数器造成提前一帧。自检覆盖完整两帧颜色周期，以及 255→0 回绕时上一张准备图像仍使用旧颜色的交接。World 1 的星星继续使用原绘制路径。

星星跳到屏幕顶部时，原绘制顺序又使后画的 HUD 背景盖住已露出的星星；第 647 帧首先只损失 1 个像素。现将 2-1 已完成露出的星星放到 HUD 之后、其它精灵之前绘制，露出过程中仍走砖块背后的原路径。只改颜色的中间完整结果为 731 张失败，加入此顺序修正后为 708，两个阶段证据分别保存在 `full` 与 `full-priority`。

前缀诊断比较 213 张指定采样图像：`probe1` 暴露颜色提前一帧，`probe2` 加入显示缓冲后修复 75 张，`probe4` 加入 HUD 优先级后修复 98 张且无新增退化；`probe3` 的 Vulkan `VK_INCOMPLETE` 启动失败保留。最终采集仍比较原始 movie 的全部 2398 帧，采样不代替整关门禁。

最终正常路线的完整状态与事件文件和修正前逐字节相同，选定状态仍匹配至第 2396 帧；末帧缺少 2-2 关卡/加载切换及静音事件，完整门禁仍失败。APU/PCM/产物通过，音频仅在状态/事件逐字节相同的守卫下复用并重检，见 `audio-reuse-proof.json`，不是新设备录音。World 2-2 和跨关衔接尚未实现，正式逐关完成登记不变。下一步从第 693 帧剩余显示差异继续定位。

33 项 Python 测试、10 组模拟回归与原生混音 CTest 通过；最终模拟结果见 `regressions-final`。


最终源码的旧路线实际窗口全帧复验：长按踩踏 1601 帧及主诊断 3116 帧全部通过状态、画面、事件、APU、PCM、产物六项门禁，零图像差异、零缺帧。最终报告在 `full-priority/held-stomp` 与 `full-priority/main-route`，新旧状态/事件逐字节相同。中间只改颜色的 `full` 采集中，两条旧路线各一次 Vulkan 初始化失败后在 `actual-retry-1` 成功；最终 `full-priority` 均直接成功。

最终 Win64 预览包：`dist/super-mario-world21-star-preview-20261109-win64/SuperMario.exe`。原生构建/混音 CTest、首帧显示（1516 ms）、窗口可见（1625 ms）、标题/图标及正常关闭检查通过，见 `package-startup.json`。脚本和四种星星 PNG 与工作区逐字节相同，回放默认禁用，包内不含 ROM/存档；版本仍为 0.0.7，未发布新 release。


## Block-slot vertical fractions (2026-11-09)

原始正常入口成功 movie 保持 2398 帧固定输入、零容差与零缺帧。完整窗口重采的画面失败由 708 降至 690，修复 18 帧，逐帧差异像素数均未增加；最早剩余差异由 693 推迟至 705（256 像素）。报告 `full/normal-clear/reports`，逐帧前后证明 `full/normal-clear/image-change-proof.json`。本节证据以 `local-parity/slot-fix-20261109` 为根。

第 693 帧的偏差属于被撞砖块，并非新的敌人。原版 `BumpBlock` 重置速度为 -2、速度小数为 0，但保留两个块对象各自的 `YMF_Dummy`（RAM `$041f/$0420`）。普通砖和强化砖的两条旧固定轨迹，其实分别对应初始位置小数 0 和 112；按砖块类型选择只是之前场景中的巧合。现按原版整数算法逐步累加位置小数及 `$50` 重力，14 次物理更新与显示交接分别保留，槽位复用继承自己的位置小数。藤蔓砖的移动图像也使用同一计算，保留其独立的精灵遮挡路径。

新增回归验证两个槽位初次使用各自从零开始、槽 0 再利用时继承 112 的完整显示轨迹，以及两槽完成后的独立余量 224/112。33 项 Python 测试、10 组模拟回归与原生混音 CTest 通过，最终模拟报告 `regressions-verified`。早期将余量放在会随奖励区域重建的 world21 状态中，`regressions-initial` 捕获了缺失索引；现将其归属到块对象自身。相应的 `probe1` 启动未完成、未产出画面，已停止并保留日志，不作成功证据。

同输入 900 帧前缀比较 388 张指定采样画面：修正归属后的 `probe2` 对齐 6 帧，藤蔓砖也接入后 `probe3` 对齐 18 帧，两次均无新增退化。它们仅用于定位，正式比较仍覆盖全部 2398 帧。

完整正常路线的新旧状态/事件文件逐字节相同，选定状态仍匹配至第 2396 帧；末帧缺少 2-2 关卡/加载切换和静音事件，整关门禁仍失败。模型 APU/PCM/产物通过；音频在新旧状态和事件逐字节一致的守卫下复用并重检，见 `audio-reuse-proof.json`，不是本轮新设备录音。World 2-2 与跨关衔接仍未实现，逐关完成登记不变。

下一步从第 705 帧的背景恢复排队时序继续定位；该帧宿主已显示静止砖块，原版该位置仍为空白。后续还有星星离开屏幕左侧的裁切差异，均未在本轮计作已修复。


原版位置/速度小数的关键帧样本保存在 `reference-fractions.json`，直接读取既有完整 RAM 轨迹，不是另造输入。旧路线实际窗口全帧复验：踩踏 1601 帧及主诊断 3116 帧的状态、画面、事件、APU、PCM、产物六项门禁均通过，零图像差异、零缺帧，新旧状态/事件逐字节相同。踩踏首次窗口因 Vulkan `VK_INCOMPLETE` 失败，日志保留在 `full/held-stomp/actual`；成功采集为 `actual-retry-1`。主诊断直接在 `full/main-route/actual` 成功。

最终 Win64 预览包：`dist/super-mario-world21-block-motion-preview-20261109-win64/SuperMario.exe`。原生构建/混音 CTest、首帧显示（1703 ms）、标题/图标与正常关闭通过，见 `package-startup.json`；包内脚本与工作区逐字节相同，回放默认禁用，没有 ROM/存档。版本仍为 0.0.7，未发布新 release。
