# 本轮验证记录

日期：2026-11-24。目标：Gemini-Niang 视觉原型0.1.0，非Antigravity整合版。

## 仓库

上游基线：6d7dd765ba4703ad5332e252f6420bdf1e88b3be。
GitHub账户经官方API确认KasterMist；PATCH仓库名称后返回full_name=KasterMist/gemini-Niang、fork=true、parent=T7moris/GPT-Niang。名称变化不等于代码已适配Antigravity。
本地独立目录：D:\Project\gemini-Niang。未改动mod_maker游戏目录或已安装GPT娘。

## 实际执行与结果

1. npm install --save-dev sharp gifenc omggif：退出0；审计0漏洞。锁文件已保存。
2. npm run build:character：首次遇到extract_area: bad extract area（sharp操作顺序）；修复为先materialize extend再extract，重跑退出0。
3. 构建导出2张透明源图、12张对齐PNG、12个GIF和character.json。每GIF320×320、40帧、100ms帧延迟、无限循环、disposal=2；解码像素哈希确认每个动画有至少两种真实帧。
4. 源图alpha实检：full图alpha=0像素934936，bust图737333；其余边缘有半透明值，主体主要alpha253/254，不能以聊天缩略图紫底误判文件不透明。
5. npm test：15个测试全部通过，退出0；原始输出见character-test-output.txt。涵盖运动周期/眨眼/减少动态、SHA256、PNG尺寸/alpha、GIF解码、循环/透明、24个下载路径和本地服务访问边界。
6. git diff --check：退出0（仅CRLF转LF提示）。

## 浏览器实测

本机127.0.0.1:4178。初次发现根URL导致相对模块路径错误；加入302跳转到/preview/index.html后修复，并加入服务回归测试。
实际观察“12个姿态已就绪”，全身→半身切换、招手选择、下载链接对应bust-wave、暂停→继续文字、减少动态、重载保留半身招手与减少动态、恢复默认，均通过。
实际截图：studio-verification.jpg。截图来自真实浏览器，未用生成图替代。
下载路径通过HTTP HEAD及文件解码验证；未声称测试过每个浏览器的下载对话框。

## 限制与下一步

- 这是新角色资产与本地播放器，不是完整桌面挂件安装包；上游WPF与Codex后台未更换为Antigravity。
- 新动作是绘制姿态＋整体呼吸/摇摆/弹跳，不是手臂/尾巴逐段绑定。
- 新全身动作是正面；原始侧/背三视图已保留，但侧/背独立动画未制作。
- 自动测试不替代用户对美术风格、表情与动作幅度的最终验收。
- GitHub云端CI是否启用/通过需以仓库Actions实际结果为准，本地通过不等于云端通过。

## 恢复

原版内容保存在Git历史与README-GPT-Niang.upstream.md。要撤销视觉原型提交，用git revert对应提交，不要reset --hard；本机Codex安装无需恢复，因为未修改。
