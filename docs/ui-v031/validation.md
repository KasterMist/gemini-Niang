# v0.3.1 UI 改版与验收

日期：2026-11-25（Asia/Shanghai）。响应用户对 UI 与 GPT-Niang 不一致的反馈。

## 改法与来源

不是再画一套类似皮肤：`desktop/widget.xaml` 直接改自 `gpt-niang-usage/widget.xaml`，保留原气泡 Path、尾部圆点、两档额度排版、进度条与菜单按钮；改名并显式显示菜单按钮。`desktop/menu-resources.xaml` 提取上游 `runtime/ui-settings.ps1` 中的资源字典，保留圆角、留白、悬停、选中及子菜单模板。上游 MIT 版权与原文件均保留。

`desktop/ui.ps1` 将真实控件连接到现有 Antigravity 数据与角色帧；不加载上游 Codex 运行时，不修改 Codex。原桌面脚本保存于 git 基线 a51d9a1，原始和修改后 SHA256 见 source-hashes.json。

## 已完成交互

- 思考气泡及圆点连接、半身/正面/侧面/背面角色、可见菜单按钮和右键入口。
- 两档剩余额度数值与进度条、重置时间、刷新按钮。未知/缺失/过期/失败不伪造数据。
- 模型组菜单选择，标题标明 Gemini 或 Claude/GPT，避免把不同模型组混合计算。
- 分组主题菜单：气泡收起、刷新、台词、形态、动作、外观大小/暂停、模型组、完成提醒、跟随/位置、退出。
- 背面“耳朵轻动”标注、选中状态、偏好持久化。声音、音乐律动、语录编辑及自动更新不在本次移植范围，也不添加无效菜单。

## 验证证据

1. 本机 `npm test`：47/47 通过，原始输出为 test-output.txt。Windows 专项启动实际 WPF 进程；UI harness 使用真实控件和路由事件完成 23 个断言，清单见 ui-checks.json。
2. quota.png、menu.png、shapes.png 来自真实 WPF Visual 渲染，不是网页模型图。额度 100/69 为明确的合成测试输入，不是个人账户余额。
3. 正式安装脚本已更新本机自有配置并启动新挂件；官方 CLI `plugin list --json` 返回 gemini-niang enabled、v0.3.1。安装目录文件已逐个比对 SHA256。
4. 在真实 Antigravity 主窗口观察到新思考气泡与实际 CLI 额度；正式 runtime 显示 testMode=false、nativeVisible=true、hostAttached=true。保留用户原有全身偏好，没有强制改成半身。没有为本轮 UI 再发送模型消息，模拟完成事件仍由现有回归测试覆盖。
5. 自动化工具没有列出 PowerShell 承载的挂件为可操作窗口，因此没有冒充完成原生实鼠标菜单/拖动验收；本轮菜单点击和展开为 WPF 控件事件测试。物理多屏/DPI 也仍待测试。
6. GitHub 阶段提交：a51d9a1 保存上一版完整成果；3b4b012 提交 UI 主体。3b4b012 的 Gemini character assets Linux/Windows CI 已成功；上游遗留的 macOS/Windows 全量工作流当时仍在运行，不能据此声称全部 CI 通过。

## 本机恢复

本轮修改前的自有 config.json、preferences.json 已备份为 `%LOCALAPPDATA%\GeminiNiang\state\*.pre-ui-*.bak`；插件副本为 `plugin-backup-ui-*`。不修改 PATH、计划任务、开机启动或其他插件。

需要回退 UI 时先运行 `停用Gemini娘.cmd`，对本轮 UI 提交使用 git revert（或从 a51d9a1 导出到另一个目录），然后在对应版本运行 `安装Gemini娘.cmd`；按需恢复上面的自有偏好备份，不复制全局账号配置。停用入口也会注销本插件，重新启用需运行对应版本安装器。

## 复现命令

```powershell
npm test
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File tests/desktop-ui.test.ps1 -StateDir .test-state/ui-check -CaptureDir docs/ui-v031
git diff --check
```

上述 UI 检查仅写隔离测试目录，测试数据不覆盖实际额度与个人偏好。
