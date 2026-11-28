# World 2 集成与整关验证

更新：2026-11-28。2-2、2-3、2-4 已由三个 `gpt-6-astra` 子代理分关开发，再在主分支集成、修复并复验。本记录区分正常游玩验证与原版严格验收。

## 交付与当前状态

- 新包：`dist/super-mario-world2-integration-20261128-win64/SuperMario.exe`。保留整个目录，不能单独移动 EXE。
- 本包默认从 2-2 正常地面入口开始，可连续进入 2-3、2-4。源码默认仍从 1-1 开始。
- 3-1 尚未实现，2-4 救人后保留完成画面，R 可重开本关。
- 版本仍为 0.0.7。本次提交并推送代码，不新建版本标签或 GitHub release。
- **三关正常游玩整关验证已通过；原版严格六项验收尚未全部通过。** 正式 32 关登记不变。

## 最终集成验证

| 关卡 | 正常入口固定按键 | 原生完整 PNG / 状态 | 结果 |
|---|---:|---:|---|
| 2-2 | 3436 帧 | 3436 / 3436 | 入口→水下 12 页、三处漩涡→出水→旗杆结算→2-3；三条命，无死亡 |
| 2-3 | 2243 帧 | 2243 / 2243 | 桥梁/飞鱼→旗杆结算→2-4；三条命，无死亡 |
| 2-4 | 1812 帧 | 1812 / 1812 | 城堡机关→斧头/断桥→救人→完成画面；三条命，无死亡 |

三关共 **7491 帧**，无缺图、坏图或脚本错误。原生回放与独立无窗口回放的关卡、状态、生命和玩家坐标逐帧一致；Y 按原生状态输出的 OAM 无符号字节格式转换，X 保留原始小数，不增加误差容限。另抽看水下、桥梁、库巴、救人画面，结尾文字与人物位置正常。

这些检查证明游戏自身两条执行路径一致，**不是**与原版 PNG、APU 或 PCM 逐帧完全一致的证明。原生整关采集使用正常入口，不套用原版存档起点修正。

另有 `world-2-campaign-gameplay.json`：**7495 帧**从 2-2 正常入口连续通到 2-4 完成画面，保留三条命，无死亡、无状态补丁。它复用已验证的输入，在进入城堡后空按键等待 33 帧，以适应跨关继承的机关相位；从新游戏重新回放通过。连续路线目前验证的是模拟执行，未重复采集全部连续画面。

补充检查：

- 2-2：1800 帧原版选定运动寄存器、接触、检查点、火球/敌人及整关回归通过。
- 2-3：2727 组运动寄存器对、18 组生成数据、接触/检查点回归通过。
- 2-4：机关、平台、库巴及结束流程自检和正常入口路线通过。
- World 2：三种能力跨关保留进度；死亡恢复小马里奥；2-3 第七页检查点、2-4 无检查点；结尾 R 重开通过。
- World 1 现有十组模拟回归通过；Python 工具测试 62 项通过。
- 水下普通及加速音乐各比较前三秒 **144000 个采样帧**，waveOut 提交 PCM 与资源精确一致，零欠载、零削波、零错误。静态音乐检查不代表整关音频时序通过。
- 交付包脚本/素材逐文件匹配源文件，关闭自动回放、热重载和启动自测。

结构化结果与哈希：`tests/parity/world2_gameplay_evidence.json`。本地全部原始产物：`local-parity/world2-integration-20261128/`。图像、日志等大文件不提交 Git。

## 本轮修复与失败记录

1. 接通 2-3/2-4 加载、绘制、更新、死亡重载和跨关分派；地图存储步长扩大到 244，避免桥梁尾端被截断。
2. 限制 World 1 专用初始化/角色分派的适用关卡，避免污染 World 2 回放和游玩。
3. 实际渲染发现 2-2 管道黑屏过场传入整数颜色，而 gfx 接口要求浮点数：在 `screenRect` 统一转换。失败采集 `final22-native` 保留；修复后 `final22-native-fixed` 全关通过。
4. 2-2 原有路线第 0 帧是尚未推进的观测帧，不能直接当作普通控制输入。新增明确标注来源的 `world-2-2-gameplay-clear.json`，转换输入索引并从正常入口重放；保留旧路线及失败 `final22-gameplay`。
5. 2-4 去掉不属于原版城堡结尾的时间换分。正常入口电影必须使用 `--normal-start`；混用存档入口的失败保留在 `final24-mechanics`。
6. 原生核对器曾错误取整 X，产生 27 个半像素假差异；改为比较两边原始 X。旧失败报告保留，最终报告为 `final22-native-check-canonical.json`。
7. Vulkan SDK 偶发启动返回 `VK_INCOMPLETE`，未进入游戏；保留 `water-native`、`final24-native` 失败，独立重试目录完成验证，没有忽略运行错误。
8. 启动器在继承隐藏窗口标记时，首次 `ShowWindow` 被 Windows 的启动参数覆盖。增加明确的再次显示，重建后隐藏方式启动也出现正确标题且进程响应正常；普通启动已验证。首轮隐藏方式复验碰到同一 SDK Vulkan 启动错误，失败日志保留，重试通过。
9. 三条旧 2-2 运动电影的基线哈希依赖 CRLF；`.gitattributes` 对其显式固定换行，已验证 Git 检出后的文件哈希。没有修改原版期望值来掩盖失败。

## 可复现命令

在仓库根目录运行，三个原生图形采集串行执行；工具使用共享 GPU 锁。

```powershell
python tools/run_world22_regressions.py --output local-parity/recheck22
python tools/run_world23_regressions.py --output local-parity/recheck23
python tools/parity/run_world24_simulation.py --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/recheck24 --require-clear --self-test --normal-start
python tools/parity/run_gameplay_route.py --movie tests/parity/movies/world-2-2-gameplay-clear.json --output local-parity/gameplay22
python tools/parity/run_gameplay_route.py --movie tests/parity/movies/world-2-3-normal-clear.json --output local-parity/gameplay23
python tools/parity/run_gameplay_route.py --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/gameplay24
python tools/parity/run_world2_campaign.py --movie tests/parity/movies/world-2-campaign-gameplay.json --output local-parity/campaign
python -m unittest discover -s tests/parity
```

原生采集用 `tools/parity/run_world2_actual.py --movie <movie> --project <包目录> --output <新目录> --timeout 240`。电影必须标记 `runtime_origin=normal-entrance`，并把 `capture_frames` 设为完整帧范围；不得改变 inputs。随后用 `verify_gameplay_capture.py --gameplay <无窗口结果> --actual <原生结果> --output <报告>` 核对。历史源电影的部分采样设置不等同于全帧采集。

## 剩余工作

1. 2-2：宿主普通入口到水下控制约 294 帧，原版约 393 帧；同一输入在原版失败。先修转场及控制起点，再重建统一成功整关对照。水下局部 1800 帧匹配不能替代此项。
2. 2-3：原版成功路线独立成立；原版起点的飞鱼 10660 个槽位快照精确匹配，但末尾 2102 帧后的切关及死亡重载、完整音画仍待收敛。
3. 2-4：原版成功路线独立成立，宿主相同原版起点路线也能通关，但斧头/断桥有一帧差异；1243 帧后胜利行走、独立镜头和消息计时不一致，APU 从约 593 帧起有差异。3-1 仍缺失。
4. 继续保留失败证据，补全部入口/分支/出口及六项门禁，不以本次可玩交付替代严格验收。

## Strict verification update — 2026-11-28

World2-3: `world-2-3-strict-clear` (2132 frames) passes all six gates with zero
pixel mismatches. Reviewed original entrance, bridge/fish route, flag1563,
settlement2102 and transition to2-4 at2103. Inventory reports complete locally.
Reports: `local-parity/reports/world-2-3-strict-clear/index.html`.

World2-2/2-4 remain pending. Worker usage limits stopped all three agents; their
committed work and unfinished diffs are retained in the worktrees. Main continues
integration; historical playable campaign results are not current strict proof.
