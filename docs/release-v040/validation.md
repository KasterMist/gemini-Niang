# v0.4.0 后续：发布工程与抛掷验收尝试

日期：2026-11-27（Asia/Shanghai）。起点 bcae2c6。保持桌面/插件版本 0.4.0：本次不改运行时功能，不重装插件，不新增自启或自动更新。

## 真实鼠标抛掷尝试

- 命令：`powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/Preview-Rhythm.ps1`，退出 0，独立 GUI 启动。
- 隔离 preview-rhythm 运行记录显示 `testMode=true`、`rhythmSynthetic=true`、`soundOn=false`、`capturesSystemAudio=false`，系统播放捕获工作线程未创建。
- 使用 Computer Use 枚举并选择唯一 Gemini GUI；捕获返回全屏舞台 screenshot-0 和角色相关窗口 screenshot-1。
- 对最新角色截图执行 drag：从 (220,330) 到 (325,230)，返回 **`Error: unknown screenshotId screenshot-1`**。没有重试猜测坐标或通过其他输入注入绕过工具边界。
- 已发送 Escape 和 Alt+F4，后续进程查询确认该预览 PID 不再存在；预览 runtime 文件已清除。
- **结果：真实鼠标抛掷仍未通过验收**。合成物理回归不是实鼠标成功证据。未保存/发布带用户桌面背景的截图。未打开真实系统播放监听、未使用麦克风、未发送模型测试消息；物理双屏仍待具备硬件时验证。

## 发布工程改动

原 `.github/workflows/release.yml` 读取的是上游 gpt-niang-usage 版本，发布 Codex/GPT 安装包；不能作为 Gemini 发布器。保留上游源码与测试，仅将 publish 限定到 `T7moris/GPT-Niang`，避免 Fork 误发布该产品。Gemini Windows CI 新增自己的打包步骤并上传 artifact，**不自动创建 Release**。

`scripts/Build-GeminiRelease.ps1` 从指定 Git commit（默认 HEAD）的不可变 blob 创建源码 ZIP，而非打包工作区。核对 Gemini 包与插件身份/版本、24 张角色 PNG、宿主与启动/退出/预览入口；排除 `.codex`、`.agents` 和旧本机 runtime 证据；拒绝常见私人状态、生成文件和不安全路径。逐项校验解压字节的 Git blob SHA1，再输出 ZIP SHA256 与逐文件 SHA256 清单。同名不同内容包拒绝覆盖。

ZIP 保留上游源代码用于溯源，不是纯运行时安装包或已编译 EXE；用户应使用 Gemini 安装入口。README 同时修正了本地 WAV 模式与系统播放模式混写的说明。

## 实际测试与修复

- `node --test tests/release-package.test.mjs`：2/2，退出 0；重复打包、manifest 对应 Git blob、排除规则、解压后 `GeminiNiang.ps1 -CheckOnly`、不同同名包保留、工作流发布边界均通过。
- `npm test`：63/63，退出 0；原始输出见 `test-output.txt`。包含已有不采集音频的原生合成集成测试。
- 首次执行中文脚本名不匹配：Windows PowerShell 5.1 将无 BOM UTF-8 脚本误读为本地编码；新增 PS1 保存为 UTF-8 BOM 后修复。
- 首次 Node 子进程测试 `Get-FileHash` 不可用；改用 .NET 流式 SHA256，解压测试也使用 .NET ZipFile，不依赖该环境下缺失的模块命令。没有安装 Python 或修改系统模块路径。
- 功能提交 `e18600483347b2d9446f48c826d01187118d97a4` 提交后再次执行 `npm test`：63/63、退出0，最终原始输出已更新至 `test-output.txt`。最终包逐文件核对成功；见 `build-record.json`。
- GitHub [Gemini CI](https://github.com/KasterMist/gemini-Niang/actions/runs/46010194264) 对上述提交完成且成功，Windows/Linux job 均成功；Windows 的打包与 artifact 上传步骤成功，`gemini-windows-source` artifact 已存在。此结论不代表保留的上游 macOS 工作流已通过。

## 最终本地产物

- 路径：`D:\Project\gemini-Niang-release-e186004\gemini-niang-v0.4.0-windows-source.zip`
- 51,715,369 字节；422 个文件；源码提交 e186004。
- SHA256：`8ADA8B69CA283524E99F3ED9043F70D8301C53EC98D3F3501D4B24DF48EF8346`。
- 同目录 `.sha256.txt` 与 `.manifest.json` 已重新打开核对。上述压缩包包含功能提交时的文档；之后的证据补充提交不改运行时代码。可复现指同一 Git/压缩工具链，不保证不同 Git/zlib 版本产生相同压缩字节。

## 原始版本与恢复

原始三份修改文件从 bcae2c6 导出到本机 `.test-state/release-baseline-bcae2c6/` 额外副本，重新读取字节核对；SHA256 见 `baseline-hashes.json`。本次未修改已安装的 v0.4.0、账户设置、个人语录或音效。

需要撤回时，对本轮功能提交执行 `git revert <提交号>`，而不是 reset --hard；发布包位于独立输出目录，不覆盖之前的 `D:\Project\gemini-Niang-v0.4.0.zip`。不需要恢复生产偏好，也不需要卸载其他插件。
