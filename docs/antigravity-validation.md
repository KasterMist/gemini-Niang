# Antigravity 适配 v0.2.0 验收记录

日期：2026-11-24。此记录区分真实接口、实际进程、模拟事件与尚未验证的交互，不将单元测试等同于最终桌面体验。

## 本轮已完成

- 新建自包含 `antigravity/` 本地插件：官方 manifest、stdio MCP、Stop hook、独立 Node 内置库后端；无 Codex 注册依赖。
- 新建 `desktop/` Windows WPF 挂件：12PNG动画、半身/全身菜单、六动作、拖动/大小/暂停、额度气泡、窗口/桌面模式、完成事件临时开心动作。
- 窗口识别要求当前会话内的 Antigravity 进程且可执行路径精确匹配；只观察可见、非最小化主窗口。物理像素移动不回写WPF尺寸。
- 显式安装/停用脚本；默认无开机启动/计划任务，无Codex修改。正常安装由用户运行新入口后才注册全局插件。

## 实际命令与结果

1. 从官方文档指定的 `https://antigravity.google/cli/install.ps1` 阅读安装路径与 manifest 源；未执行全局安装脚本。
2. 下载官方 CLI manifest 与1.5.16二进制到gitignore的 `.test-state/tools`。SHA512与官方manifest一致：`058a85911c40a0beba24d0ae4e3227ea5060388060d4746aa6b48722ff43516c16fbffe6d30e31e2c266d5b47495a7886f072cc4e0143b26eb3cd9a007578c83`。未改PATH。
3. `agy.exe --version` 返回1.5.16，退出0。
4. `agy.exe -p /usage --output-format json` 真实执行，退出0；返回SUCCESS、command.name=usage、num_turns=0，2个模型组、各2个额度桶，字段为remaining_fraction/reset_time。App已登录状态下本机可读取，不需要新增登录。未公开或保存账户标识、令牌、原始响应正文。
5. `node antigravity/scripts/refresh.mjs` 使用独立测试状态目录与上述CLI，退出0，实际写入净化后的usage.json。1970时间转换为null。
6. stdio向 `node antigravity/scripts/mcp.mjs` 发送initialize与get_antigravity_usage工具调用：退出0，成功返回真实分组额度，isError=false、modelTurns=0。
7. `agy.exe plugin validate --strict ./antigravity` 退出0，官方校验通过：1 hook、1 MCP server。原始校验输出见antigravity-plugin-validation.txt。当前全局 `agy plugin list --json` 为[]，本轮没有安装正式插件。
8. `powershell.exe -File desktop/GeminiNiang.ps1 -CheckOnly` 退出0：12素材可用、宿主路径存在；当时宿主处于不可见/最小化状态，host=null，不冒认其他进程。
9. 真实WPF进程使用临时目录、TestMode、NoRefresh启动；加载PNG、生成本机窗口句柄、输出运行状态。向Stop处理器发送**模拟事件**后，进程状态变为action=happy、noticeActive=true、bubbleVisible=true，进程测试通过。不声称这是一条真实聊天回调。
10. `Install-GeminiNiang.ps1 -CheckOnly` 与不带RegisterPlugin的隔离配置验证退出0。额外副本中放入自定义配置键，重跑后仍保留；备份SHA256与原件相同，复制备份恢复后SHA256再次相同。
11. `npm test` 32项全通过，退出0；原始输出见antigravity-test-output.txt。包含实际PowerShell5/WPF子进程验证、Node后端、负向错误、Stop去重/128项上限、MCP握手、素材与动画回归。

## 已发现并修复的问题

- Windows PowerShell5将无BOM的中文脚本按旧编码读取，产生语法错误：Windows入口改用UTF-8 BOM，增加BOM/实际PS5执行验证。
- PowerShell5向File.Replace传null备份路径时转换为空字符串导致非法路径：改为显式本地备份文件，实际重复写入与恢复验证通过。
- 额度接口不是Codex格式：基于实际command.data.groups[].buckets[]实现严格解析，不凭模型回答推算额度。

## 尚未完成/不能宣称通过

- 交互桌面当前未能完成CUA窗口/截图验收（包括最小化窗口、输入几何不可用和前台进程不可读），没有生成或伪造桌面成功截图。
- 形态/动作菜单的实际鼠标操作、拖动手感、宿主移动/遮挡/恢复及物理多屏/DPI仍待交互实测；WPF进程测试不能替代这些验收。
- 未注册正式Antigravity插件，故真实聊天触发Stop→桌面整条链路仍待安装后验证；本轮没有为测试发起模型对话。
- 侧面/背面独立动作、精细手臂/头发/尾巴绑定未制作。
- 小尺寸宿主窗口、非默认安装目录、远程机器和各套餐都未全覆盖。非默认宿主路径需启动时显式传HostExecutablePath。
- GitHub CI状态需以Actions实际结果为准，不能以本地测试代替。

## 安装/恢复

程序与状态均独立于原GPT娘。双击安装Gemini娘.cmd会执行明确的下载/插件安装动作，本轮没有替用户执行该全局步骤。
停用Gemini娘.cmd请求挂件退出并移除gemini-niang插件，保留偏好；无计划任务需要删除。配置旧版本在config.json.<时间>.bak；关闭挂件后可复制该备份回config.json。代码可git revert本次提交恢复，不使用reset --hard。

## 官方依据

- https://antigravity.google/docs/getting-started?tab=cli
- https://antigravity.google/docs/cli/commands/usage/
- https://antigravity.google/docs/build-plugins/
- https://antigravity.google/docs/hooks
