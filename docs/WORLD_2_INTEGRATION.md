# World 2 集成与整关验证

更新：2026-11-28。2-2、2-3、2-4 的剩余原版一致性问题已修复，三关严格整关六项门禁全部通过。验证的是登记的完整固定输入路线，不代表所有可能操作均已逐帧验证。

## 当前结果

| 关卡 | 严格整关电影 | 全帧数 | 六项门禁 | 出口及后续 |
|---|---|---:|---|---|
| 2-2 | `world-2-2-strict-clear` | 3800 | 全通过 | 地面入口→水下→侧管→地面旗杆/烟花→3597 帧进入 2-3，3763 帧恢复控制 |
| 2-3 | `world-2-3-strict-clear` | 2132 | 全通过 | 桥梁/飞鱼→旗杆/结算→2103 帧进入 2-4 加载 |
| 2-4 | `world-2-4-original-clear` | 2800 | 全通过 | 城堡→斧头/断桥/库巴→救人/文字→1807 帧进入 3-1，1974 帧恢复控制 |

共 **8732 帧**。图像门禁为逐像素零容差，无缺帧、无差异；产物完整性、选定状态字段、语义事件、APU 写入和 PCM 音频门禁全部通过。APU/PCM 使用现有严格管线，根据宿主事件/状态重建音频并对照原版；不把它表述为整关声卡输出采集。

`tests/parity/level_acceptance.json` 已登记三关的路线与分支审核。2-2 的入水/出水是主线路径，无可选奖励房或跳关；2-3、2-4 无可选区域分支。正式清单当前 **3/32 关完成，29 关待验收**，可玩状态与严格验收继续分开。

本地总报告：

- `local-parity/reports/world-2-2-strict-clear/index.html`
- `local-parity/reports/world-2-3-strict-clear/index.html`
- `local-parity/reports/world-2-4-original-clear/index.html`

本轮原始证据：`local-parity/world2-strict-20261128/`，最终目录 `final22`、`final23-current`、`final24`。失败迭代保留。每次原生采集使用独立运行时快照，三份快照的源码已与交付源码核对一致。图像、ROM、日志等大文件不提交 Git；新检出缺少本地产物时，验收工具应报告证据缺失。

## 修复内容

- 2-2：原版入口任务、加载与恢复控制时序；地面入口地图；水下背景/金币/HUD 配色；游泳踢腿与落地动画；气泡初始化、溢出、位置缓冲及精灵遮挡；进出管道时敌人更新和人物优先级；出口食人花；金币擦除、旗杆裁切、城堡旗与烟花计分显示时序。
- 2-3：末尾加载、状态与音频完成对齐；本轮共享修改后重跑全部 2132 帧及六项门禁。
- 2-4：火焰棒边缘、平台和库巴的 OAM 顺序；库巴前后半身与槽位垂直小数继承；跳跃火焰回收；砖块回弹/回位；斧头配色、断桥和画面切换；救人文字、镜头及结束计时。
- 为 2-4 整关出口补齐真实 3-1 地图、夜景/雪景入口和跨世界加载。**3-1 仅作为下一关入口依赖，不算完整关卡完成**；其敌人、奖励区域及整关路线仍待开发验收。

## 正常游玩与回归

`world-2-campaign-gameplay.json` 从新游戏的 2-2 正常入口出发，**7722 帧**连续通过 2-2→2-3→2-4→3-1 正常控制，全程三条命、无死亡。只回放控制器输入，不修改位置、敌人、能力、随机数或无敌状态。此项是独立模拟游玩回归，不冒充原版音画门禁。

2-2 独立正常路线 3406 帧通过，覆盖水下 12 页、全部三处漩涡、敌人、金币、出口和结算；1800 帧运动/接触/能力回归通过。2-4 正常入口 1812 帧通过，含城堡自检和 3-1 加载。World 1 十组既有回归、World 2 三种能力跨关及死亡检查点回归、71 项 Python 测试、原生音频混音测试通过。

早期 `world2-integration-20261128` 的 7495 帧电影和旧完成画面属于历史基线；当前连续路线与终点已替换为上面的 7722 帧版本。未调整严格电影、参考图像或比较容差来消除失败。

## 新版程序

`dist/super-mario-world2-strict-20261128-win64/SuperMario.exe`

默认从 **2-2 正常地面入口**开始，保留整个目录运行。源码默认仍从 1-1 开始。交付包关闭自动回放、热重载和启动自测；2452 个脚本/素材文件逐一匹配源码；实际启动窗口标题正确、进程正常响应并可正常关闭。版本保持 **0.0.7**，本次提交推送，不另建版本标签或 GitHub release。

## 复验

```powershell
python -m unittest discover -s tests/parity
python tools/run_world22_regressions.py --output local-parity/recheck22
python tools/run_world23_regressions.py --output local-parity/recheck23
python tools/parity/run_world24_simulation.py --movie tests/parity/movies/world-2-4-host-route.json --output local-parity/recheck24 --require-clear --self-test --normal-start
python tools/parity/run_world2_campaign.py --movie tests/parity/movies/world-2-campaign-gameplay.json --output local-parity/recheck-campaign
python tools/parity/level_acceptance.py --format markdown
```

重新严格采集：对三条严格电影分别运行 `tools/parity/run_case.py --rom <本地原版ROM> --movie <电影路径> --artifacts <新的产物根目录> --actual-timeout 600`。三个图形任务串行，工具持有共享 GPU 锁。保留失败目录，Vulkan 启动错误重试到新目录。

## 后续

1. 按同一六项标准补齐 1-1～2-1 的正式整关证据，不以历史局部通过计作整关完成。
2. 推进 3-1 的完整敌人/奖励分支和成功整关路线，再继续后续关卡。
3. 所有 32 关都必须有正常入口至出口、必要分支、全帧音画及状态证据；不降低门禁。
