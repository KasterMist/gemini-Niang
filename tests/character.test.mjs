import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import sharp from 'sharp';
import omggif from 'omggif';
import { ACTIONS, motionAt } from '../preview/motion.mjs';
const { GifReader } = omggif;
const base = new URL('../assets/characters/gemini/', import.meta.url);
test('six actions, deterministic finite periodic motion, reduced-motion support', () => {
  assert.equal(ACTIONS.length, 6); assert.equal(new Set(ACTIONS.map(a => a.id)).size, 6);
  for (const a of ACTIONS) {
    for (let t = 0; t < 4; t += .05) {
      const m = motionAt(a.id, t);
      for (const n of Object.values(m)) assert.ok(Number.isFinite(n));
      assert.ok(m.cell >= 0 && m.cell < 6);
      assert.ok(Math.abs(m.angle) <= .03 && m.y >= -21);
    }
    assert.deepEqual(motionAt(a.id, 0), motionAt(a.id, 4));
    assert.deepEqual(motionAt(a.id, 1, true), { cell: a.cell, x: 0, y: 0, angle: 0, scaleY: 1 });
  }
  assert.equal(motionAt('idle', 2.8).cell, 1); assert.equal(motionAt('idle', 3).cell, 0);
  assert.throws(() => motionAt('missing', 0), RangeError);
  assert.throws(() => motionAt('idle', NaN), TypeError);
});
test('atlases and manifest retain real alpha and source hashes', async () => {
  const manifest = JSON.parse(await readFile(new URL('character.json', base), 'utf8'));
  for (const view of ['full', 'bust', 'side', 'back']) {
    const source = await readFile(new URL(`${view}-atlas.png`, base));
    assert.equal(createHash('sha256').update(source).digest('hex'), manifest.sourceSha256[view]);
    const { data, info } = await sharp(source).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
    assert.equal(info.width, 1536); assert.equal(info.height, 1024);
    let transparent = 0, visible = 0;
    for (let i = 3; i < data.length; i += 4) { transparent += data[i] === 0; visible += data[i] >= 240; }
    assert.ok(transparent > info.width * info.height * .1 && visible > 200000);
  }
});
for (const view of ['full', 'bust', 'side', 'back']) for (const a of ACTIONS) {
  test(`${view}/${a.id}: PNG and genuine looping multi-frame GIF`, async () => {
    const png = await sharp(await readFile(new URL(`png/${view}-${a.id}.png`, base))).metadata();
    assert.equal(png.width, 512); assert.equal(png.height, 512); assert.equal(png.hasAlpha, true);
    const bytes = await readFile(new URL(`gif/${view}-${a.id}.gif`, base));
    const gif = new GifReader(bytes);
    assert.equal(gif.width, 320); assert.equal(gif.height, 320); assert.equal(gif.numFrames(), 40); assert.equal(gif.loopCount(), 0);
    const hashes = new Set();
    for (let i = 0; i < gif.numFrames(); i++) {
      const frame = gif.frameInfo(i); assert.equal(frame.delay, 10); assert.equal(frame.transparent_index, 0); assert.equal(frame.disposal, 2);
      const pixels = Buffer.alloc(320 * 320 * 4); gif.decodeAndBlitFrameRGBA(i, pixels);
      assert.equal(pixels[3], 0);
      hashes.add(createHash('sha256').update(pixels).digest('hex'));
    }
    assert.ok(hashes.size >= 2, 'GIF must contain actual visible changes, not copies of one frame');
  });
}
