# 项目目录结构

`super-mario/` 是项目根目录，构建与打包不再依赖相邻的 `builds/` 或 `_private/`。

| 目录 | 内容 | Git 管理 |
| --- | --- | --- |
| `scripts/` | 游戏规则、渲染、音频调度及 ROM 数据 | 是 |
| `assets/` | 运行时素材与音频 | 是 |
| `native/audio/` | 原生音频插件和 Windows 启动器源码 | 是 |
| `roms/` | 用户提供的 ROM 及校验说明 | 是 |
| `tools/` | 构建、打包、提取和对照工具 | 是 |
| `tests/` | 确定性的输入用例 | 是 |
| `docs/` | 实现说明和发布记录 | 是 |
| `build/native-audio/` | 当前原生插件编译缓存，可重新生成 | 否 |
| `.tools/` | 校验后安装的 EVEngine SDK 与 Mesen agent | 否 |
| `.venv/` | 项目 Python 环境 | 否 |
| `native/bin/` | 构建生成的插件和启动器 | 否 |
| `dist/` | 新生成的 Windows 独立游戏目录 | 否 |
| `local-parity/` | 本机模拟器参考、截图及对照报告 | 否 |
| `local-reference/` | 原 `_private/`：参考反汇编、原始提取素材、引擎研究副本 | 否 |
| `build-archive/` | 原相邻 `builds/` 中的历史游戏包、验证目录及旧编译缓存 | 否 |

`local-reference/` 和 `build-archive/` 保留本机研究历史，不是运行或重新构建游戏的必需依赖。

## 玩家与关卡数据

`scripts/player.nut` 定义 `createPlayer()`，创建每个玩家独立的可变状态；
移动和碰撞行为当前仍在 `scripts/simulation.nut`，后续依靠回放逐步迁移。

`scripts/level_data.nut` 的 `LEVEL_DATA` 注册支持的世界/关卡和加载函数。
`scripts/levels.nut` 的 `startLevel()` 先查询定义，确认支持后再重建游戏状态，
保留分数、金币、生命及允许保留的强化状态，然后调用对应加载函数。
扩展复用现有机制的关卡入口时，在注册表添加定义即可。

当前注册表仅统一关卡入口。地图、实体、音乐和管道目标仍由各关构建函数及
`scripts/generated/` 数据提供；尚未形成覆盖全部区域配置的 `LevelData`。
可变图块、敌人和区域保存状态仍存于游戏对象，尚未单独抽出 `LevelState`。
共享注册表不存放这些可变状态，避免重进关卡时复用旧对象。

此次提取在 HEAD 源码副本中独立验证，未混入工作区中的其他未提交玩法改动。
Player 构造函数主体提取前后逐字一致；源码启动检查、1-1 行走回放通过。
高旗杆用例的画面、状态、事件及音频检查通过，但参考 manifest 的录像哈希
与当前录像不符，产物校验失败，不能计为完整门禁通过。
1-2 静止回放仍有原有画面差异，但本次重构前后 240 帧状态、事件及全部
采集 PNG 字节一致，状态与音频对照通过。此结果仅证明本次组织调整保持行为，
不代表所有关卡的完整验收。
旧 CMake 缓存含有迁移前的绝对路径，保留作历史记录；重新编译使用新的 `build/native-audio/`。
历史日志和报告也可能保留原绝对路径；新的报告由工具重新生成。

从项目根目录构建：

```powershell
.\tools\build_native_audio.ps1
.\tools\package_windows.ps1
```

第一个命令生成 `native/bin/`；第二个命令生成 `dist/super-mario-<时间>-win64/`，
双击其中的 `SuperMario.exe` 启动。也可以通过 `-Output` 指定其他打包目录。

开发环境仍需安装 Visual Studio 2022 C++ Build Tools、EVEngine v0.6.0 SDK；
运行 `tools/setup_windows.ps1` 将 SDK 安装到项目 `.tools/`，也可以通过构建脚本的
`-Sdk` 参数指定安装位置。首次安装和验证步骤见 `docs/DEVELOPMENT.md`。
运行对照工具还需要 Python 和 Mesen agent；这些是外部开发工具，不在游戏发布包内。

Windows 游戏包仅复制脚本、运行时素材、引擎和本机插件；不包含 `roms/`、参考资料、
测试报告、编译缓存或历史构建。GitHub 自动生成的源码归档与 Windows 游戏包是不同产物。
