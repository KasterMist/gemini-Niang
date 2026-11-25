# 角色来源与生成记录

2026-11-24；使用Codex内置ImageGen，未使用API/CLI回退。

## 来源

用户参考图：assets/reference/gemini-turnaround.png。
原件SHA256：FD472EB36B6ACBC18D7552291C32F02ECEC38C7C2B7A93072BA42768EE902466。
最终图集SHA256记录于assets/characters/gemini/character.json。参考用于身份与服装一致性，不构成新增商业许可声明。

## 实际生成提示词规格（摘要）

### 全身
Use case stylized-concept. The three-view image is CHARACTER IDENTITY REFERENCE. Transparent 1536x1024 RGBA, strict equal 3x2 grid, six isolated FRONT VIEW FULL BODY sprites. Same registration/proportions, head top/feet bottom, ears and tail visible. Preserve lavender cat ears/ahoge, twin buns, blue-lavender long hair with pink gradient ends, viewer-left red eye/viewer-right gold eye, gold four-point star on viewer-right, purple starry outfit with white frills, same legwarmers/shoes. Row-major: neutral smile open eyes; identical neutral pose closed-eye blink; one raised open hand greeting; delighted closed-eye smile both small fists at chest; thoughtful one finger at cheek; sleepy hands clasped. No props, effects, text, grid, borders, ground or shadow.

### 全身定向透明修订
Use case background-extraction. Edit target six-cell sprite sheet. Remove all purple/black gradient backdrop and gaps inside hair/arms/legs. Real alpha=0 empty areas, no simulated checker/glow/shadow. Keep all six characters, 1536x1024 dimensions, strict3x2 layout, colors/poses/details unchanged. Only transparent background.

工具缩略图看似紫底，但文件实查有真实alpha=0；未用缩略图观感作为透明度验收依据。

### 半身
Image1 identity reference, Image2 full-body atlas as art-style reference. HALF BODY companion atlas 1536x1024 RGBA, six512x512 cells in3x2. Same front-facing character framed ear tips to waist, no legs/shoes, full ears/hair/hands inside each cell, consistent proportions. Preserve blue-violet/pink hair, twin buns, cat ears, red viewer-left/gold viewer-right eyes, right-side gold star, violet starry outfit white frills. Row-major: calm open-eye; same closed-eye blink; raised open hand greeting; happy closed-eye both fists; finger at cheek thinking; sleeping hands clasped. No text/grid/borders/glow/objects/ground; genuine alpha0 background.

## 程序导出

build-character.mjs按512px网格分帧，通过可见alpha边界水平对齐，使用motionAt的变换合成40帧GIF。只做导出、对齐、缩放与动画编码，不以程序替代形象绘制。PNG保留alpha；GIF为256色、单比特透明。

动图中的呼吸/摇摆为整体变换，非手臂/尾巴独立骨骼运动。

## 半身 v0.1.1 更新
原半身生成规格为历史记录；当前采用大头肩胸近景版。新参考、提示词规格、原始SHA256及验证见 [半身修订记录](bust-v011-revision.md)。

## v0.3.0 侧面与背面

使用同一用户三视图及已确认画风作为参考，通过 Codex 内置 ImageGen 生成两张真实透明 1536×1024、3×2 图集。未调用外部付费 API。

- 侧面规格：一致左朝向全身、可见金色眼睛、双丸子猫耳、蓝紫粉渐变长发、紫色星纹服装、尾巴，六姿态依次为待机、闭眼、招手、开心、思考、困倦。第一轮出现多余手臂，经 ImageGen 定向修订后才采用最终图集。
- 背面规格：始终背朝观察者，不显示脸或眼睛；保持后发、猫耳、服装后部和尾巴；第二格使用耳朵轻动代替眨眼，其余为对应背向动作姿态。
- 导出命令：`node scripts/build-character.mjs --view=side`、`node scripts/build-character.mjs --view=back`。不覆盖已确认半身或正面图。
- 动画仍是姿态帧与整体轻摆/呼吸变换，不是逐肢体骨骼绑定。最终 atlas 和各帧 SHA256 保存在 character.json。
