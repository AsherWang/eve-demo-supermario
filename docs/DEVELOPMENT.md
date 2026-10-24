# Windows 开发环境与首次验证

Worktree 并行任务可复用只读 SDK 和 Mesen 安装，用 `tools/setup_worktree.ps1`
建立独立依赖与插件输出；初始化命令、并发限制和集成流程见
[Worktree 并行开发](WORKTREE_DEVELOPMENT.md)。

支持的开发平台是 Windows x64。安装 Python 3.12+ 并将 `python` 加入 PATH；
安装 Visual Studio 2022 C++ Build Tools，勾选桌面 C++、Windows SDK 和 CMake 工具。
推荐使用 PowerShell 7。在 clone 后的项目根目录执行：

```powershell
.\tools\setup_windows.ps1
.\tools\package_windows.ps1
```

安装脚本为项目建立 `.venv/`，安装固定版本 Pillow；下载校验后的 EVEngine 和
Mesen agent 到 `.tools/`。这些目录均被忽略，不需要复制原作者的缓存。
游戏包位于 `dist/`，源码模式的启动命令见 README。

## Windows 首帧显示与发布配置

`SuperMario.exe` 以 `STARTF_USESHOWWINDOW / SW_HIDE` 启动固定版本的 EVEngine。
引擎可在原生窗口隐藏期间初始化和提交 Vulkan 帧；启动器读取 `game.log`，确认
`[startup] first present - window shows content` 后，仅显示该子进程的 `SDL_app`
游戏窗口，不显示 IME 等辅助窗口。初始化失败、present 报错、进程退出或 30 秒
超时均停止隐藏的引擎并显示错误提示，避免无窗口进程长期残留。

此方案不修改 SDK 或引擎二进制，依赖已固定 SDK 的启动标记。升级 SDK 时必须
复验。直接运行 `eve.exe run .` 会绕过启动器，因此不包含隐藏到首帧的行为。

源码保留 `hotReload = true` 和 `startupSelfTests = true`；打包脚本仅将发布包的
这两项设为 `false`，不改源码配置。完整启动检查仍在源码开发和确定性回放中执行；
即使配置关闭 `startupSelfTests`，启用 parity 回放也会强制执行。

```powershell
python tools/check_windows_startup.py --package 'C:/path/to/package' `
  --report local-parity/startup-check.json
```

检查工具记录该次启动的子进程窗口，确认首帧前没有可见游戏窗口、首帧后窗口可见。
正常关闭检查会避开 SDK 最初 45 帧的退出事件保护期，再发送标题栏关闭命令。
`--expect-failure` 可用于隔离的失败启动夹具，检查错误提示、非零退出及子进程清理；
可加 `--expected-error` 核对具体日志原因。测试会关闭它自己启动的游戏，不影响其他
游戏进程。启动耗时受机器、音频素材和驱动影响；隐藏窗口消除的是未准备好时的显示，
不代表完全消除初始化等待。

## 固定工具来源

- EVEngine v0.6.0：<https://github.com/EVEngine/EVEngine/releases/tag/v0.6.0>
  ，Windows SDK 压缩包 SHA-256：
  `8b4dccb5c86e41de4e71627576a4fdc1030b225e61024c4fa71a44c45c08d8c7`。
- Mesen agent v0.1.0：<https://github.com/atonamy/mesen-agent/releases/tag/v0.1.0>
  ，`mesen-agent-windows-x64.zip` SHA-256：
  `169a1f797fc7104d603a3cee19cbb0b62d44ed32686333eafca1b2295cd756c8`。
  这是包含无窗口 CLI 的 Mesen fork；普通 Mesen GUI 不能代替该命令行工具。
  必须将 `mesen-agent.exe` 与匹配的 `MesenCore.dll` 放在一起。

下载失败时可从以上固定 Release 手动下载，按安装脚本目录解压。重复运行安装脚本
会校验缓存压缩包，不必重复下载；它会覆盖 `.tools/` 中对应工具文件。

## 首次对照测试

```powershell
.\.venv\Scripts\python.exe tools\parity\run_suite.py `
  --rom 'roms\Super Mario Bros. (World).nes' --cases walk-right-smoke
```

成功后去掉 `--cases walk-right-smoke` 运行全部七条回归用例。
只有已经生成相应用例参考数据后才能使用 `--reuse-reference`。
报告生成于 `local-parity/reports/index.html`。首次执行不需要原作者的截图、存档或报告。

重建音频先运行 README 中的 idle reference 命令生成 `origin.mss`，随后执行素材采集。
游戏本身已经包含素材，因此普通开发不需要重新提取或采集音频。

## 乌龟与蘑菇交互回归（2026-10-25）

源码启动和 parity 回放会执行三组专项自检：

- `runKoopaBounceSelfTest`：缩壳后继续使用原始乌龟碰撞框，并保留连续接触标记；再次接触静止壳时踢壳，不重复回弹。比较原版 ROM 的连续 40 帧 Y、整数速度、两项小数状态和龟壳状态。
- `runShellDefeatSelfTest`：移动龟壳击中敌人后保留对象，展示翻转、上抛、下落，越过屏幕下边界才删除；同时检查连杀计分、音效和双壳碰撞。
- `runPowerUpGapSelfTest`：实际 1-2 第 89 列奖命砖出菇期间打碎右邻砖，蘑菇底部中心失去支撑后落下；保留完整砖面的对照及普通蘑菇检查。

1-2 出口加载共享地面敌人数据时，跳过初始屏幕右边界之前的敌人，避免楼梯末尾出现本不应生成的两个栗宝宝。

重新采集踩踏对照需要已校验的 ROM 和 1-1 起始存档：

```powershell
python tools/parity/capture_koopa_bounce.py --origin-state local-parity/reference/walk-right-smoke/origin.mss --write-fixture
```

采集脚本保存 ROM、存档与输出哈希；固定初始 RAM 的 Lua 场景位于 `tests/parity/fixtures/koopa-bounce.lua.in`。这属于专项受控场景验证，不代表 1-2 整关已验收；蘑菇和击飞生命周期自检也不是逐帧 ROM 对照。

本次合并后运行 11 条现有回归：1-1 的 8 条全部通过；1-2 的 idle、walk、route 仍仅在既有采样画面门禁失败，产物、状态、事件、APU 和音频检查通过。运行时音质门禁通过，整体套件保留失败状态，没有放宽画面阈值。Win64 构建、CTest 混音测试、打包和首帧显示/关闭检查通过。

## 自定义安装路径

原生构建与打包支持 `-Sdk <目录>`。Python 对照工具优先读取 `EVE_EXE`、
`MESEN_AGENT` 环境变量，其次使用项目 `.tools/`、PATH，最后兼容旧用户缓存位置。
顶层套件通过环境变量把相同工具设置传递给子进程，例如：

```powershell
$env:EVE_EXE = 'C:\tools\eve-sdk\win32\bin\eve.exe'
$env:MESEN_AGENT = 'C:\tools\mesen\mesen-agent.exe'
```

## 引擎源码及验证边界

迁入的 `local-reference/EVEngine-v0.6.0-audio` 在整理时工作区无改动，HEAD 为
`848301ca`。当前游戏音频实现位于已版本管理的 `native/audio/`，构建链接官方 SDK；
不需要依赖该本地引擎副本，也没有必须另行应用的未提交引擎补丁。

发布工作流检查 Win64 编译、混音单元测试和打包结构；完整 ROM 对照仍由开发者运行。
运行时可能偶发遇到 `VK_INCOMPLETE` 图形初始化失败；检查启动日志并重跑该用例。
密集逐帧管道过渡检查仍存在已知显示差异，默认七用例 PASS 不代表所有画面逐帧 1:1。

## 干净源码验证记录（2026-10-24）

用仅复制待版本管理文件的独立源码目录验证，未复制原项目的插件、编译缓存、参考数据
或 Python 环境。安装脚本校验工具压缩包并建立新的 Python 3.12 环境、安装 Pillow 后：

- Win64 插件、启动器、CTest 混音测试和游戏打包成功，游戏包内 NES 文件为零。
- 从零生成全部七用例参考数据并执行完整比较：产物、采样画面、4260 帧状态、
  事件、APU、PCM 和运行时 WAV 质量门禁均通过，套件退出码为 0。
- 从零生成 idle origin 存档，重新采集 `jump.wav`，SHA-256 与仓库素材完全一致。

这是本机独立源码目录验证，不等同于跨机器验证；本次重采验证了跳跃音效，未重采全部音频。
