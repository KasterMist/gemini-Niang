import sharp from 'sharp';
import gifenc from 'gifenc';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { ACTIONS, motionAt } from '../preview/motion.mjs';
const { GIFEncoder, quantize, applyPalette } = gifenc;
const root = fileURLToPath(new URL('../', import.meta.url));
const out = path.join(root, 'assets/characters/gemini');
await mkdir(path.join(out, 'png'), { recursive: true });
await mkdir(path.join(out, 'gif'), { recursive: true });
const viewArg = process.argv.find(a => a.startsWith('--view='))?.slice(7);
if (viewArg && !['full', 'bust'].includes(viewArg)) throw new Error('Use --view=full or --view=bust');
const views = viewArg ? [viewArg] : ['full', 'bust'];
const manifest = viewArg
  ? JSON.parse(await readFile(path.join(out, 'character.json'), 'utf8'))
  : { id: 'gemini-niang', animationType: 'pose-atlas-with-procedural-motion', cycleSeconds: 4, cellSize: 512, gif: { width: 320, height: 320, frames: 40, fps: 10, loop: true }, actions: ACTIONS, views: {}, sourceSha256: {} };
manifest.version = '0.1.1';
for (const view of views) {
  const source = await readFile(path.join(out, `${view}-atlas.png`));
  manifest.sourceSha256[view] = createHash('sha256').update(source).digest('hex');
  const meta = await sharp(source).metadata();
  if (meta.width !== 1536 || meta.height !== 1024 || !meta.hasAlpha) throw new Error(`${view}: invalid atlas`);
  const buffers = [], registrations = [];
  for (const action of ACTIONS) {
    const cell = await sharp(source).extract({ left: (action.cell % 3) * 512, top: Math.floor(action.cell / 3) * 512, width: 512, height: 512 }).png().toBuffer();
    const { data, info } = await sharp(cell).raw().toBuffer({ resolveWithObject: true });
    let min = 512, max = -1;
    for (let y = 0; y < 512; y++) for (let x = 0; x < 512; x++) if (data[(y * 512 + x) * info.channels + 3] > 32) { min = Math.min(min, x); max = Math.max(max, x); }
    if (max < min) throw new Error(`Empty cell ${view}/${action.id}`);
    // Registration-only export: never repaint or synthesize character pixels.
    const shiftX = Math.round(256 - (min + max) / 2);
    const margin = 64;
    if (Math.abs(shiftX) > margin) throw new Error('Registration exceeds safe margin');
    const padded = await sharp(cell).extend({ top: 0, bottom: 0, left: margin, right: margin, background: '#00000000' }).png().toBuffer();
    const normalized = await sharp(padded).extract({ left: margin - shiftX, top: 0, width: 512, height: 512 }).png().toBuffer();
    buffers.push(normalized); registrations.push({ action: action.id, shiftX });
    await writeFile(path.join(out, 'png', `${view}-${action.id}.png`), normalized);
  }
  manifest.views[view] = { atlas: `${view}-atlas.png`, registrations, png: `png/${view}-{action}.png`, gif: `gif/${view}-{action}.gif` };
  const samples = [];
  for (const b of buffers) {
    const pixels = await sharp(b).resize(192, 192).raw().toBuffer();
    for (let i = 0; i < pixels.length; i += 4) if (pixels[i + 3] >= 128) samples.push(pixels[i], pixels[i + 1], pixels[i + 2], 255);
  }
  const colors = quantize(Uint8Array.from(samples), 255, { format: 'rgb565' });
  const palette = [[0, 0, 0], ...colors];
  for (const action of ACTIONS) {
    const gif = GIFEncoder();
    for (let frame = 0; frame < 40; frame++) {
      const m = motionAt(action.id, frame / 10);
      const image = buffers[m.cell].toString('base64');
      const deg = m.angle * 180 / Math.PI;
      const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512"><g transform="translate(${256 + m.x} ${478 + m.y}) rotate(${deg}) scale(.92 ${.92 * m.scaleY})"><image href="data:image/png;base64,${image}" x="-256" y="-478" width="512" height="512"/></g></svg>`;
      const pixels = await sharp(Buffer.from(svg)).resize(320, 320).ensureAlpha().raw().toBuffer();
      const index = applyPalette(pixels, colors, 'rgb565');
      for (let i = 0; i < index.length; i++) index[i] = pixels[i * 4 + 3] < 128 ? 0 : index[i] + 1;
      gif.writeFrame(index, 320, 320, { palette, transparent: true, transparentIndex: 0, delay: 100, repeat: 0, dispose: 2 });
    }
    gif.finish();
    const bytes = gif.bytes();
    await writeFile(path.join(out, 'gif', `${view}-${action.id}.gif`), bytes);
    console.log(`${view}-${action.id}: ${bytes.length} bytes, 40 frames`);
  }
}
await writeFile(path.join(out, 'character.json'), JSON.stringify(manifest, null, 2) + '\n');
console.log(`Wrote ${views.length * 6} registered PNGs, ${views.length * 6} animated GIFs and character.json.`);
