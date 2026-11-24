# Antigravity 适配实施计划 v0.2.0

## 目标与边界
在已完成的Gemini形象基础上实现独立Windows桌面挂件、Antigravity窗口跟随、官方只读额度适配、Stop hook完成通知与MCP工具。开发/测试使用独立状态目录，不覆盖Codex的GPT娘，不默默安装全局插件、改登录或开机启动。

## 执行顺序
1. 核查官方CLI/usage真实返回结构、插件清单与Stop字段；本地工具下载仅进入gitignore的.test-state，不修改PATH或全局应用。
2. Node额度provider：固定只读命令、超时/大小限制、严格字段解析、无凭据/聊天保存，失败不可显示假余额。
3. 轻量事件桥：仅接受model_stop且fullyIdle=true的Stop，去重与有界存储，不保存lastUserInput/transcriptPath/error全文；永不强制继续模型。
4. Windows WPF挂件：复用12PNG和动作，形态/动作菜单、拖动/缩放、窗口模式/桌面模式、额度气泡、完成提醒；独立命名、状态与进程生命周期。
5. 打包Antigravity本地插件（MCP + Stop hook）和显式安装/卸载入口，默认不注册开机启动；配置改写前备份。
6. Node单元/进程测试 + PowerShell语法/CheckOnly + 额外测试状态下真实WPF验证。真实账户额度/真实Stop若需登录或激活插件，明确标记未实测，不用fixture代替实测。
7. 更新README与验收记录，提交推送用户Fork。

## 官方来源（2026-11-24复查）
https://antigravity.google/docs/getting-started?tab=cli
https://antigravity.google/docs/cli/commands/usage/
https://antigravity.google/docs/build-plugins/
https://antigravity.google/docs/hooks
