# v0.3.3 声音与本地 WAV 音乐律动验收

日期：2026-11-26（Asia/Shanghai）。基线为 e21b468（v0.3.2）。本轮不修改角色形象，不触碰 Codex，不增加自启。

## 实现范围与来源

- desktop/audio.ps1、audio-import.mjs 改自上游对应 MIT 模块，保留来源与版权，复用 PCM 校验、音量缩放、独立工作线程和有界播放队列、自定义音效导入/备份逻辑。类型前缀改为 Gemini，避免同进程旧类型冲突。
- 内置 80/100 ms 提示音由 scripts/build-sounds.mjs 本地生成（24 kHz、16-bit mono），没有复制角色语音、商业音乐或第三方录音；许可见 desktop/assets/NOTICE.md。重新生成后 SHA256 一致。
- 点击音效默认关闭，音效与音乐音量独立，默认 35%。可导入 ≤5 秒、≤10 MiB 的 WAV，验证/预载后才提交偏好；导入失败保留旧配置与原始文件。
- 音乐采用显式选择的本地未压缩 PCM/Float WAV，≤20 分钟，输入和归一化输出均限 100 MiB。独立 Node 子进程归一化并计算约 50 ms 窗口 RMS 能量；WPF MediaPlayer 的实际 Position 驱动变换，不是按固定时间伪装节拍。
- 这是本地文件能量律动，不是上游 WASAPI 系统声音监听和摆锤物理效果的完整移植；不支持读取 Spotify/浏览器正在播放的声音，暂不支持 MP3/AAC。不创建录音设备，不开启麦克风或系统录音。
- 支持音乐暂停、手动继续、停止及独立音量。宿主隐藏后暂停，恢复时不自动响起，重启也不自动播放；暂停动画只冻结角色律动，不暂停用户主动开启的音乐。完成提醒期间保留开心动作优先级。
- 只清理自己生成的 GUID 音乐缓存，不删除所选原始文件。自定义文件/文件名不写公开运行日志，不上传 GitHub。隐藏/播放/编辑等状态也会阻止自动语录抢占。

## 实际验证

| 项目 | 结果/证据 |
| --- | --- |
| 修改前 npm test | 50/50，退出 0，baseline-test-output.txt |
| 最终 npm test | 56/56，退出 0，test-output.txt |
| 音频专项 | 31 个本机断言，media-checks.json，mutedPlaybackBackendAvailable=true |
| 真实 WPF 静音播放 | 实际 MediaOpened、Position 推进超过 0.02 秒、按时间查询非零能量；隐藏暂停、恢复不自动播放、手动继续/暂停均通过。测试音量强制 0，没有假称已人工听音 |
| 点击 PCM/队列 | 校验原始短音、零音量采样、导入事务；队列使用注入的 native-call stand-in 验证 play/stop 与线程退出，不等于扬声器听感测试 |
| UI | 41 个 WPF 控件断言，含声音开关、两套独立音量、停止状态禁用暂停、主题子菜单打开，ui-checks.json |
| Node 文件/解析测试 | 静音 RMS 为 0、不同音量 RMS 跟随比例；损坏 RIFF、时间/体积上限、超大稀疏文件按元数据拒绝、既有输出不覆盖、源文件不改写 |
| 素材重建 | node scripts/build-sounds.mjs 前后两张 WAV 的 SHA256 相同 |
| 本机更新 | 初次更新 CLI 1.5.17、最终重启 CLI 1.5.18 的严格插件校验均通过；plugin list 显示 gemini-niang enabled、v0.3.3，复制后逐文件 SHA256 一致 |
| 正式运行 | version=0.3.3、testMode=false、soundOn=false、audioReady=true、musicMode=stopped，local-runtime.json；无 widget-error.txt |

上述专项断言包含在相应 Node 测试内，不能与 56 项相加冒充更多独立测试。音频后端在其他机器若不可用，测试会验证明确错误状态；本机专项记录明确为实际静音后端可用。audioReady 只表示 PCM 预载就绪，不代表所有输出设备都已人工听过。

本机观察时 Antigravity 宿主隐藏，挂件也隐藏。安装没有主动打开用户聊天或选取个人音乐，没有再发送模型测试消息。原生实鼠标菜单/拖动和物理多屏/DPI 尚未完成完整人工验收；本轮不以控件事件测试冒充这些实测。

## 失败与修复记录

1. 首次新专项测试为 55/56；Windows PowerShell 5 不解析测试里的简写 Func 泛型。改成 System.Func[System.IntPtr,System.UInt32,System.Boolean] 后继续。
2. 随后真实静音播放器已经打开且时钟推进，但“时间轴读取能量”断言失败。定位为 PowerShell 选择 Math.Min/Max 的整数重载，将小数 RMS 取整。改成 0.0/1.0，并增加 0.25 能量应产生 -3 位移的回归断言；最终 56/56。
3. 最初复用的音效转换上限只限制输入，新模块额外限制归一化输出，防止 8-bit 转成 16-bit 后突破体积上限。

## 工件与截图

sound-menu.png、music-menu.png、menu.png 等均为真实 WPF Visual 渲染。额度和语录仍为隔离合成测试输入，不是个人余额或私人文本。音乐菜单未加载曲目时显示“未播放”，不会伪造正在播放截图。

原件/最终文件及上游来源 SHA256 见 source-hashes.json；原桌面代码从 e21b468 导出到额外副本并核对。上游录音素材未作为新角色默认音效复制。

## 本机备份与恢复

更新前的自有 config/preferences/audio-preferences（存在时）复制为状态目录中的 `*.pre-v033-20261126130426.bak`；插件完整副本为 `plugin-backup-v033-*`。随后请求旧挂件退出、运行自有安装器并启动新挂件。未开启音效或音乐，没有修改 PATH、账号设置、计划任务及 Codex。

需要停用时运行根目录 `停用Gemini娘.cmd`。需要回退时先停用，从 e21b468 导出至单独目录后运行该版本安装器，按需恢复上面的自有偏好备份。自定义音效的 audio-preferences.json.bak 和 sounds 文件一起保留，不要把个人文件提交到仓库。不要覆盖其他插件或全局登录配置。

## 分阶段提交与 CI

主体已提交并推送 50ba4f6；最终 UI/部署/验收另行提交。最新 GitHub 工作流以相应提交的实际状态为准，不以本地通过替代云端结果。

最终代码/验收提交 4b568f2 已推送，本机再次重启确认正式 v0.3.3、音效关闭、音乐停止。两个观察时点的 CLI 自报版本不同，本轮未手动替换 CLI。50ba4f6 的 Gemini Windows/Linux CI 已成功；4b568f2 的同一工作流仍在运行，上游遗留工作流排队中。
