# v0.3.2 交互与语录验收

日期：2026-11-25（Asia/Shanghai）。基于 6e6df55 的 v0.3.1 继续实现；未修改角色图集、Codex、PATH 或开机自启。

## 本次交付

- 复用上游 MIT `runtime/quotes.ps1` 的本地加权抽取、去重、备份与自动播放计时器；只使用 Gemini-Niang 自有三句默认文案，没有复制上游语录合集。
- 编辑器改自上游 `Open-QuoteEditor`，接入当前紫色资源样式：逐行输入、可选权重、保存、恢复内置、错误反馈、关闭。严格检查无效行，避免静默丢弃；重复文案合并权重；每句 200 字、最多 5000 条、JSON 上限 1 MB。
- 自定义文案仅在 `%LOCALAPPDATA%\GeminiNiang\state\quotes.json` 保存；不写入仓库、不调用模型、不读取聊天正文。替换和重置前生成 quotes.json.bak，损坏文件回退内置文案但不重写原件。
- 自动语录默认关闭，1/5/15 分钟可选，出现 8 秒。只在挂件可见、气泡收起、未操作时启动；隐藏、休眠、时钟回拨或忙闲切换后重新计时，避免补播和通知抢占。
- 修复定位逻辑：DragMove 的嵌套消息循环期间不再执行跟随定位；桌面拖动位置用原生像素保存、重启恢复；允许负坐标显示器，恢复到最近显示器工作区并限制越界。这里是代码与几何/原生工作区测试，不代表已完成物理多屏/DPI 验收。
- 修复暂停动画偏好未落盘、完成提醒结束后不恢复收起状态；200 字长文案按真实字体测量，缩字号以防裁切，并保留完整 tooltip。

## 实际命令与结果

命令均从仓库根目录执行。完整输出及断言清单保存在本目录。

| 命令/操作 | 实际结果 |
| --- | --- |
| 修改前 npm test | 47/47，退出 0，baseline-test-output.txt |
| 首轮服务回归 npm test | 49/50；测试脚本中的 Get-FileHash 在该 Windows PowerShell 子进程模块环境中不可用（CommandNotFoundException），不是业务保存失败。改为 .NET SHA256 后重跑 |
| 最终 npm test | 50/50，退出 0，test-output.txt |
| tests/desktop-services.test.ps1 -Case Pool | 41 个断言，退出 0，含损坏回退、无效保存、精确备份和额外副本恢复 SHA256 |
| 同脚本 -Case Scheduler | 16 个断言，退出 0，模拟时间推进，无需真实等候或发送模型消息 |
| 同脚本 -Case Placement | 10 个断言，退出 0，含实际最近显示器 API、负坐标/越界和真实 Update-Host 函数的拖动早返回分支 |
| tests/desktop-ui.test.ps1 | 34 个 WPF 控件断言，退出 0，含实际打开编辑器、触发保存/报错/关闭、选项持久化及场景恢复 |
| 官方 CLI plugin validate --strict | 验证通过（本机安装器实际执行） |
| 官方 CLI plugin list --json | gemini-niang，enabled=true，version=0.3.2 |
| 本机安装/重启 | 正式 runtime 的 version=0.3.2、testMode=false；无 widget-error.txt。观察时宿主隐藏，挂件随之隐藏，见脱敏 local-runtime.json |

最后单独执行 git diff --check；验收不只检查 UI 文案。Pool/Scheduler/Placement 断言合计 67，UI 34；它们包含在相应 Node 测试进程内，不额外冒充 101 个独立测试。

## 视觉证据与限制

quote-editor.png、custom-quote.png、menu.png、shapes.png、quota.png、long-quote.png 为真实 WPF Visual 渲染；所有文字/额度均是隔离测试输入，不是用户自定义内容或账户余额。编辑器初次截图出现的内容边缘裁切，已通过带背景的外层 Border 修正并重新渲染检查。

本轮未发送额外真实模型消息，未自动打开或修改用户聊天。此前 v0.3.0 的真实完成提醒记录继续保留；当前完成事件由真实 WPF 测试进程加模拟 Stop 覆盖。

原生实鼠标菜单/拖动、物理多屏/DPI 仍未完成完整人工验收。声音、音乐律动和自动更新不在本轮实现范围，菜单没有伪装这些功能。自动语录不能抢占持续展开的额度气泡，这是明确的交互规则，不是播放故障。

## 安装、备份与恢复

更新前复制自有 config/preferences/（若存在）quotes 文件为状态目录中的 `*.pre-v032-20261125042639.bak`；插件备份为 `plugin-backup-v032-*`。随后请求旧挂件退出，运行 Install-GeminiNiang.ps1 -StartWidget，校验同源插件目录并同步文件，逐个 SHA256 比对一致；没有清空个人偏好，没有开启自动语录。

原始文件与新文件 SHA256、上游来源哈希见 source-hashes.json。v0.3.1 的桌面原件已从 git 导出到额外测试副本并校验，未在实际安装目录做破坏性恢复。

需要回退时先运行根目录 `停用Gemini娘.cmd`，再从 6e6df55 导出到单独目录、运行该版本安装器；按需复制回 pre-v032 的自有配置/偏好。语录恢复可先备份当前文件，再从 quotes.json.bak 复制到 quotes.json。不要恢复或覆盖全局账号配置、其他插件。

## 阶段提交与 CI

第一阶段已推送 8ce625e（语录/场景/定位主体），最终验收另行提交。上个正式版本 6e6df55 的 Gemini 和上游 Windows/macOS 两个 CI 均已成功；新版本状态以对应提交的实际工作流为准。

最终代码与验收提交 3174a16 已推送；该提交的 Gemini character assets（Windows/Linux）CI 已成功，上游遗留全量工作流仍在运行。后续文档修订不改变已测试的代码。
