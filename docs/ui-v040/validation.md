# v0.4.0 最后开发项与验收边界

日期：2026-11-26（Asia/Shanghai）。基线 2abab61；主体提交 fb05502；主功能提交 6e16de9；最小化停止保护与最终测试提交 a8414e4。目标仍为用户的 Gemini-Niang/Antigravity，不改 Codex，不增自启。

## 已补齐的开发项

1. **系统播放监听**：移植上游 MIT music-audio.cs，使用默认多媒体 eRender 设备的 WASAPI shared-mode loopback；控制器选择默认设备模式，不枚举/自动选择音乐进程。采样只在 C# 工作线程内处理，派生节拍快照交给 WPF，不把原始音频写盘、上传或传给 PowerShell。没有麦克风入口。
2. **摆锤与舞台**：移植上游 music-visual.cs 的重力、边界反弹、按拍压缩、抓取/抛掷、音箱、灯光。未给新角色硬套上游龙娘专用眼镜；保留用户确认的四种形态。
3. **开关与生命周期**：默认关闭，不持久化“开启监听”。菜单启动前再次确认；隐藏/最小化挂件、暂停动画、改变形态/大小/跟随模式、退出会停止；恢复不会偷偷重开。Esc（焦点在挂件）可安全停止。自动语录不抢占系统律动。
4. **独立 GUI 宿主**：Host.cs 为 Windows GUI 子系统 EXE，STA 运行进程内 PowerShell/WPF，不是控制台或把终端改个名字。显式 Per-Monitor V2 manifest 与 .NET DPI switch；本机从源码编译，缓存源/二进制哈希校验。新安装入口会先请求旧挂件退出并等待，不强杀其他进程。状态目录大小写变体不再启动第二实例。
5. **安全预览**：根目录“预览摆锤（不监听）.cmd”使用隔离 preview-rhythm 状态和 SyntheticRhythmTest，构造器传 captureSystem=false；无监听线程、无额度调用，强制静音、约120秒自动关闭。普通生产入口不带此参数，且合成启动参数禁止脱离 TestMode 使用。

用户本轮选择只实现功能、不实际开启监听：本轮没有启用真实 WASAPI 采集，没有播放用于监听联调的测试音，不把合成节拍说成真实系统音乐。

## 本次实际测试

| 验证 | 实际结果 |
| --- | --- |
| npm test | 61/61、退出0，完整原始输出 test-output.txt |
| 上游物理回归移植 | 8427 个采样点；100/150/200%比例 ×30/60/144fps；按拍压缩/回弹、交互暂停，motion-checks.json |
| 快速抛掷回归 | 36个组合、5–60ms释放延迟、动量保留与刻意停留清动量，throw-checks.json |
| 节拍时钟回归 | 90/120/170 BPM、离拍干扰、音量变化、静音/鼓点停止与换速重新锁定，beat-clock-checks.json；纯合成数值输入 |
| WPF 控件专项 | 50个断言，含合成源不创建采集工作线程、停止恢复原变换、隐藏停止、语录不抢占，ui-checks.json |
| 原生宿主集成 | PE Subsystem=2（GUI）、隔离目录启动、真实 HWND PerMonitorV2=true、大小写路径单实例、正常退出码0 |
| 原生合成渲染集成 | 实际渲染回调PerMonitorV2=true，多组角色可见区域在物理工作区内，capturesSystemAudio=false；独立进程退出后无舞台遗留 |
| 额外四组实际帧 | synthetic-frame-checks.json；不是凭界面提示判断成功 |
| 安全预览入口 | preview-checks.json：合成、静音模式，无采集工作线程，正式 preferences SHA256前后一致 |
| 正式本机部署 | 注册enabled v0.4.0，插件复制后逐文件SHA256一致；GUI原生进程 v0.4.0、非TestMode、PerMonitorV2=true、系统律动关闭，local-runtime.json |

61项是 Node 测试条目；上面的采样点/断言包含在对应条目内，不额外冒充独立测试数量。本机实际仅枚举到一个显示器，物理3840×2160、150%，工作区3840×2088；display-topology.json。

### DPI 复核与更正

最初从非DPI感知 PowerShell 查询到2560×1440，这是150%下的逻辑尺寸，不是物理分辨率。一度将它与原生物理窗口坐标比较而怀疑越界；切换明确PerMonitorV2上下文复核后，确认实际物理尺寸为3840×2160。因此不能把早先的怀疑当作已证实的软件越界缺陷。

保留的改进是显式 scoped DPI context（调用完恢复原上下文）与物理可见区域集成断言：避免今后混合HwndSource的回调坐标再被误用。不修改Windows显示缩放设置。100/200%与负坐标/多屏边界为回归模拟，不是物理双屏实测。

## 实鼠标/原生交互证据

native-validation.json 与 native-menu.png（真实弹出菜单截图，裁去透明边缘以免发布桌面背景）。实际执行并观察到：

- 点击菜单按钮、角色右键、展开形象子菜单并选择背面。
- 普通桌面拖动：原生坐标由150/150变为300/225，偏好落盘；重启 v0.4.0 恢复300/225。
- 合成摆锤舞台实际可见；Esc停止后灯光和音箱消失、普通气泡/角色布局恢复；关闭原生窗口后进程/舞台结束。

移动摆锤的实鼠标抛掷**没有计入通过**：自动化工具对相关HwndSource捕获的 screenshotId/输入边界报错，部分输入未被接受。抛掷算法和输入状态机已由上述回归覆盖，但不能据此伪称完成全部实鼠标抛掷验收。真实系统音频未测是用户明确约束；物理双屏未测是本机只有一个活动显示器。

## 失败与恢复

- 原生编译最初混用了 Add-Type CompilerParameters 与 ReferencedAssemblies 参数，改成在同一 CompilerParameters 对象配置输出/引用后编译成功。
- 首个宿主正常关闭时错误地把 HadErrors 当成非空 Error[0]，导致索引异常；改为检查 InvocationStateInfo 的实际失败状态。原始本机错误日志已保留为 pre-v040 备份；新宿主启动/正常退出回归通过。
- 单独加载媒体控制器时缺少停止系统律动函数，改为在媒体模块显式导入控制器。
- 移植测试用 ScriptBlock.Create 导致PSScriptRoot为空，改为按文件路径dot-source；随后全部通过。
- 菜单子项越出主窗口范围时，改用真实弹出菜单的捕获区域完成点选；移动舞台的输入限制未伪装成通过。

## 恢复与交付

SHA256见 source-hashes.json。原版本桌面/启动脚本从2abab61导出到额外副本并核对，未在实际安装目录做破坏性回滚。旧配置/偏好/个人语录/音效配置（存在时）保留在 `%LOCALAPPDATA%\GeminiNiang\state\*.pre-v040-20261126153254.bak`，插件备份为 plugin-backup-v040-*。旧的宿主诊断日志另行保留，没有删除用户内容。

回退：先运行“停用Gemini娘.cmd”，再从2abab61或v0.3.3归档导出到单独目录，运行对应安装器；按需恢复上述自有偏好。不要恢复/覆盖全局账号设置或其他插件。新GUI缓存位于本机GeminiNiang/bin，源代码可重建；不是系统服务、计划任务或开机自启。

## GitHub CI

fb05502 的 Gemini Windows/Linux CI 已成功，保留的上游 Windows 测试/打包也成功。上游macOS任务未获得托管runner而取消，注释为“job was not acquired by Runner”和“capacity constraints”；这是实际runner容量信息，不声称全工作流成功，也未为此改写上游macOS代码。最终提交的CI以对应run为准。
