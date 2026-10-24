# World 1-2 实现与验证

沿用独立游戏规则 + ROM 数据解码 + Mesen 参考对照。ROM 不参与交互运行时。

实施顺序：

1. 从已校验 ROM 定位 UndergroundArea1、入口 GroundArea10、金币房
   UndergroundArea3 和返回地面 GroundArea6，保存原始流及地址清单。
2. 支持关卡编号、1-1 结算到 1-2、开发者直达入口；保留 1-1 回归。
3. 解码地下地形控制、砖块、金币、道具、管道和敌人；加入连续升降平台及食人花。
4. 接入入口、金币房返回、正常地面出口、屋顶和 Warp Zone。
5. Mesen 选择相同关卡并生成参考；检查地图和初始帧、运动状态、交互事件。
6. 记录验证结果及尚未对齐的项目，严格区分可玩实现与零差异门禁。

数据依据：已验证 SMB World ROM 与 SMBDIS 的 DecodeAreaData、TerrainRenderBits、
VerticalPipe、ExitPipe、MovePiranhaPlant、LargeLiftUp/Down、World1Areas。
提取工具必须可只依赖仓库中的 ROM 重建，不能依赖被忽略的参考源码目录。

## 已实现

- 正常游玩通过 1-1 后进入 1-2，也可按 F2 从入口开始。
- 地下主图 208 列、金币房 17 列，使用 Mesen 执行原版地图解析器得到的
  metatile 列；分页采集的重叠列必须一致，否则生成器报错。碰撞与初始显示
  共用这份地图，砖块被顶后切换到游戏自身状态。
- 道具砖、金币、敌人、六处食人花、四个升降平台、金币房入口和返回管道。
- 正常出口接回地面旗杆与城堡；屋顶可以绕过侧向出口进入 Warp Zone。
- 地下调色板、问号动画、板栗怪、食人花和平台图块均离线提取。
- 游戏交互运行不加载 ROM，也不嵌入模拟器。

## 重建数据

在仓库根目录执行（先按 README 安装工具与依赖）：

```powershell
python tools/extract_world12.py
python tools/parity/capture_world12_map.py
python tools/parity/capture_world12_map.py --area bonus --output local-parity/world12-bonus-map
```

纹理与原始流来源见 `assets/world12/manifest.json`；生成的三份 Squirrel 数据
在 `scripts/generated/world12_*.nut`，与源码一起保存。

## 验证结果和边界

1-1 原有七组用例、4260 帧回归通过。1-2 的 `world-1-2-idle`（240 帧）、
`world-1-2-walk`（180 帧）及 `world-1-2-route`（240 帧）已完成对照：产物、
跟踪状态、事件、APU 写入和检测侧严格 PCM 均通过。21 张抽样截图中 16 张
逐像素一致，idle 和 route 的第 0、1 帧及 walk 第 17 帧仍有显示差异。
route 只是首段落地、移动、敌人和管道的诊断路线，不是整关验证。

```powershell
python tools/parity/run_suite.py --rom 'roms/Super Mario Bros. (World).nes' --cases world-1-2-idle world-1-2-walk world-1-2-route
```

每次启动还检查主图道具位置、缺口、平台/食人花数量、金币房往返、地面出口和
屋顶绕过侧向管道。这些是逻辑检查，不等于整关输入回放零差异通过。

保留的开场状态校正来自原版 OAM 证据；未合入按测试帧、输入或渲染次数补画面的
方案，也没有放宽像素阈值或排除失败帧。尚未完成严格对齐的项目包括开场
OAM/VRAM 显示时序、第二只敌人进入视野前的下落显示；较长跳跃实验约第 131 帧
出现运动差异，该实验尚未成为正式验收路线。
入口自动行走、整关通关、升降平台乘坐、食人花交互和 Warp Zone 尚缺完整的
原版输入回放门禁，因此当前应视为可玩实现，不能宣称整个 1-2 严格 1:1。
Warp Zone 可以选择 4、3、2，但对应世界未实现，选择后停在目的地提示画面。

## 后续回归修复

- 乌龟踩踏：原来的上一帧脚底/龟头高度限制与较低的身体碰撞盒冲突。
  改为原版 `ChkForPlayerInjury` 的正向 Y 速度分支，增加大小马里奥实际碰撞到
  乌龟后缩壳、反弹且不死亡的启动检查。
- 通关音乐：进入城堡前已触发 `course_clear`，时间奖励结束时又触发一次，
  导致 PCM 播放游标清零。删除后一次；原版延长回放也仅在第 1230 帧请求一次。
- 入口管道：补上 `RenderSidewaysPipe` 第四列底部的两个 `$15` 图块，
  增加管道右侧到地面的连续性检查，并实际启动检查画面。

七组既有回归重跑通过。新增 `world-1-1-castle-fireworks` 是 1750 帧诊断回放，
沿用 high-flag 输入并延长观察窗口；该路线目前没有礼炮（时间尾数不满足条件）。
本轮修复了城堡入口碰撞、结算期自动控制、状态追踪映射、时间奖励音效和 HUD
前导零。1750 帧的产物、状态、事件、抽样画面、APU 及检测侧 PCM 六项门禁已
通过。音效使用离线原版采集素材，运行时仍有共享声道混音限制；该路线没有礼炮，
也没有全程逐帧截图，不能代替礼炮、跨关衔接或整关验收。
