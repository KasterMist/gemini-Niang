# v0.3.0 本机安装与验收

日期：2026-11-24（Asia/Shanghai）。本轮已获得用户“允许，完成本机安装与真实联调”的明确授权。

## 实际完成

- 本机 Antigravity App 2.34、官方 CLI 1.5.16；`gemini-niang` v0.3.0 注册且 enabled，包含 usage MCP 与 completion Stop hook。
- 插件位于 `%USERPROFILE%\.gemini\config\plugins\gemini-niang`；CLI 位于 `%LOCALAPPDATA%\GeminiNiang\bin\agy.exe`；状态目录为 `%LOCALAPPDATA%\GeminiNiang\state`。
- 不更改 Codex 配置，不更改 PATH，不添加计划任务或开机自启。
- 官方 CLI `plugin install` 在本机 staging 目录 rename 返回 Access denied；自有目录创建/重命名探针可用。采用显式 `-ManualCopyFallback` 复制到本地插件目录，再由官方 `plugin enable` 启用；未改 ACL。安装器先备份既有同源插件和自有配置，拒绝覆盖不同来源插件或链接目录。

## 真实聊天链路

在 App 新建的无项目测试聊天中累计发送三条短测试消息（另有一次 CLI 冒烟测试）。第三条回复“联调完成”后，Stop 收到 `NO_TOOL_CALL`、`fullyIdle=true`，发布完成事件；正式挂件（非 TestMode）变为 happy，完成气泡可见。观察时刻为 UTC 2026-11-24T14:28:07.7785676Z，详见 [脱敏证据](v030-live-validation.json)。

实测发现当前 App 使用 `NO_TOOL_CALL` 而非文档示例 `model_stop`；现在仅接受这两个已确认的正常结束原因，并排除错误、取消和非 idle 状态。

当前 App 的 executionNum 每轮可能都是 0。为避免同一会话重复短提示被永久去重，最终代码使用允许目录内 transcript.jsonl 的大小和修改时间作为回合标记；仅 stat 元数据，不读正文。无元数据时回退到输入摘要，不保存明文，但此回退不能区分相同文本的重复输入。最终去重改动已做确定性回归测试，未额外发送第四条真实 App 消息。

## 桌面与素材

- 真实宿主最小化后隐藏、还原后重新附着和显示已验证；额度气泡可见。
- 原大头肩胸半身保持不变；新增侧面、背面图集与每视角六个动作，总计四种形态、24 PNG、24 GIF。背面眨眼按钮标为“耳朵轻动”。
- 浏览器预览的侧面招手、背面耳动和下载路径已检查；公开截图见 [背面预览](v030-back-preview.jpg)。
- 原生右键菜单、鼠标拖动尚未完整实鼠标验收，物理多屏/DPI 未验证。动画为姿态帧加整体运动，不是 Live2D。
- 真实本机截图包含个人额度，只保留在忽略的 `.test-state/`，不上传仓库。公开日志不含账号、额度值或会话 ID。

## 测试与发布

`npm test`：45/45 通过，原始输出见 [测试记录](v030-test-output.txt)。包含 PNG/GIF 解码、MCP/Stop、回合去重、Windows PowerShell 5 预检与真实 WPF 测试进程。`git diff --check` 单独执行。

上游遗留 Windows 打包脚本原先从新 README 提取旧版许可章节失败；现改从保留的 upstream README 获取，并只打包原 Codex 文件，不把 Gemini 入口混入。此 Python 打包未在本机运行（未安装 Python），由 GitHub CI 验证；CI 状态以实际工作流结果为准。

## 恢复

- 停用：运行根目录 `停用Gemini娘.cmd`，退出挂件并移除本插件，保留偏好。
- 自有状态目录中 `plugin-backup-20261124141705523` 保存安装前 v0.2 插件；`config.json.*.bak` 保存自有配置。先停用，再从备份复制回同名插件目录并 `agy plugin enable gemini-niang`，配置按需恢复。不要覆盖其他插件或全局账号设置。
- 插件备份的复制/恢复在额外副本上校验 SHA256；不以实际安装目录做破坏性恢复试验。
- 代码回退可对本次提交执行 `git revert`，或重新解压旧版归档；不会自动恢复本机部署，需要重新安装相应版本。
