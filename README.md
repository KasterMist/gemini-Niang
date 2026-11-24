# Gemini-Niang（Gemini 娘）

基于 [T7moris/GPT-Niang](https://github.com/T7moris/GPT-Niang) 的非官方社区 Fork。

**当前交付：Gemini 娘视觉与动画原型 v0.1.0。** 依据用户提供的三视图，制作透明半身/全身素材、六种姿态、循环 GIF 与动作选择。

> 尚未完成 Antigravity 运行集成。原有 `安装GPT娘.cmd` 等脚本仍是上游 Codex 安装器，不是 Gemini 娘安装器。本轮不修改本机已安装的 GPT 娘，也不读取账号或额度。

| 半身 · 招手 | 全身 · 待机 |
| --- | --- |
| ![半身招手](assets/characters/gemini/gif/bust-wave.gif) | ![全身待机](assets/characters/gemini/gif/full-idle.gif) |

## 预览与动作选择

需要 Node.js 20+。在仓库目录运行：

```sh
npm ci
npm run preview
```

打开 `http://127.0.0.1:4178/`（仅监听本机）。可切换全身/半身、待机/眨眼/招手/开心/思考/困倦，暂停、调速度/大小/背景，开启减少动态，下载当前PNG/GIF。浏览器保存形态与偏好。

## 动画规格

**AI绘制姿态图集＋程序运动**，不是Live2D或完整连续逐帧骨骼动画。待机切换睁闭眼帧；招手是招手姿态整体轻摇，不宣称手掌独立运动。

- 源图集2张：1536×1024 RGBA、3×2网格。
- PNG12张：512×512、水平对齐、柔和透明边缘。
- GIF12个：320×320、10fps、4秒/40帧、无限循环、单比特透明。
- 全身动画为**正面**；三视图原件保留作设计依据，未制作侧面/背面独立动作套装。

## 文件与验证

- `assets/reference/gemini-turnaround.png`：原始三视图。
- `assets/characters/gemini/`：图集、PNG、GIF、character.json和素材声明。
- `preview/`：角色播放器和动作选择。
- `scripts/build-character.mjs`：分帧、对齐与GIF构建。
- `docs/visual-production-plan.md`：实施计划。
- `docs/asset-provenance.md`：来源与提示词。
- `docs/visual-validation.md`：验收记录及限制。

```sh
npm test
npm run build:character
```

构建使用仓库图集，不调用图像服务。正式界面推荐PNG帧，GIF因色数/透明度限制会损失细节。

## 上游与许可

保留上游历史、MIT版权与素材声明。[上游原始README](README-GPT-Niang.upstream.md)保存原安装与功能说明，不代表已适配Antigravity。

新角色参考由用户提供，来源见[生成记录](docs/asset-provenance.md)；第三方角色、商标与参考图商业权利需另行确认，代码MIT不自动覆盖所有图像，详见[素材声明](assets/characters/gemini/NOTICE.md)。本项目非Google或OpenAI官方产品。
