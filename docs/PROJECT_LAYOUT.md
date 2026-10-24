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
