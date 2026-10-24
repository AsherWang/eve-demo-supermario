# Worktree 并行开发

每条开发任务使用独立 worktree 和 `codex/` 分支；主目录统一集成和发布。隔离目录不能消除公共规则的合并冲突，也不能代替合并后的整关验证。

## 初始化

先在工具源目录运行 `tools/setup_windows.ps1` 安装已固定版本的 SDK 和 Mesen，然后在新 worktree 根目录执行：

```powershell
./tools/setup_worktree.ps1 -SharedTools 'D:/workspace/eve-demos/super-mario/.tools'
```

共享路径是本机示例，其他机器应传入实际位置。脚本读取共享工具、设置当前 PowerShell 的 `EVE_EXE` / `MESEN_AGENT`，在本 worktree 创建 Python 环境并编译插件。新终端需要重新运行；依赖和插件已准备时可加 `-SkipPython -SkipBuild`。不复制其他工作区的 CMake 缓存、虚拟环境、运行插件或正在写入的报告。

对照测试使用本 worktree 的 `.venv/Scripts/python.exe`。首次参考从 ROM 重建；若复制已有参考，必须确认 ROM、录像、工具和参考生成逻辑一致，复制到本地后使用，禁止多个任务写同一份参考或报告。SDK 与工具升级单独进行，不在并行任务运行时覆盖共享安装。

```powershell
./.venv/Scripts/python.exe tools/parity/run_suite.py --rom 'roms/Super Mario Bros. (World).nes'
./tools/package_windows.ps1 -Sdk 'D:/workspace/eve-demos/super-mario/.tools/evengine/eve-sdk/win32'
```

## 并发约定

- 一个 worktree 同时只运行一个游戏回放、源码游戏实例或打包任务。`run_actual.py` 会临时改写 `scripts/generated/parity_movie.nut`，其他启动和打包可能读取到临时回放。
- 不同 worktree 的 `build/`、`native/bin/`、`local-parity/`、`dist/` 保持独立；禁止把这些输出指向共享目录。
- 跨 worktree 并行回放先做小规模验证；图形初始化失败或机器资源不足时降低并发。真实设备音频验证串行进行。
- 初期按 1-1 结算、1-2 专用显示与回放、验证工具与验收清单拆分。修改公共运动或加载接口时先协调，避免同时重构公共脚本。
- 每个任务提交独立结果，记录修改文件、源码提交、测试命令、通过范围和剩余失败。未经整关验证的关卡保持开发中。
- 审查通过后才集成。测试专用代码可以设置经过核对的比较起点和记录证据；玩法与显示修复应来自通用运行时规则，不能按录像帧号、用例名或输入掩码直接补画像素以换取通过。
- 工具测试的成功样本必须符合实际产物生成器的格式；同时覆盖缺失、过期和失败证据。只使用自定义的理想样本，不能证明工具能验收真实回放。
- 按依赖顺序逐项集成，合并后重跑受影响路线及已有基线，发布按 Roadmap 重跑所有已完成关卡的整关和分支验证。
- 确认提交已集成且本地证据已保留后，再归档不再使用的托管 worktree。忽略的参考数据与报告不随普通 Git 提交保存。

此流程不依赖自动初始化触发；每次开始任务都检查工具路径、插件、回放关闭状态和输出位置。
