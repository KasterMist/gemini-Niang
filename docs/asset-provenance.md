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
