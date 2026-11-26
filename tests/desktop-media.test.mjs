import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync, spawnSync } from 'node:child_process';
import { normalizeWave, WaveError } from '../desktop/audio-import.mjs';
import { analyzeMusic, prepareMusic, MAX_MUSIC_BYTES } from '../desktop/music-import.mjs';
function wav(seconds = .2, level = .2) {
  const rate = 8000, frames = Math.round(seconds * rate), b = Buffer.alloc(44 + frames * 2);
  b.write('RIFF'); b.writeUInt32LE(b.length - 8, 4); b.write('WAVEfmt ', 8); b.writeUInt32LE(16, 16);
  b.writeUInt16LE(1, 20); b.writeUInt16LE(1, 22); b.writeUInt32LE(rate, 24); b.writeUInt32LE(rate * 2, 28);
  b.writeUInt16LE(2, 32); b.writeUInt16LE(16, 34); b.write('data', 36); b.writeUInt32LE(frames * 2, 40);
  for (let i = 0; i < frames; i++) b.writeInt16LE(Math.round(32767 * level * Math.sin(2 * Math.PI * 400 * i / rate)), 44 + i * 2);
  return b;
}
async function temp(t) { const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'gemini-media-')); t.after(() => fs.rm(dir, { recursive: true, force: true })); return dir; }
test('click WAV normalization preserves source and enforces bounded PCM format', () => {
  const source = wav(), saved = Buffer.from(source), r = normalizeWave(source);
  assert.equal(r.duration, .2); assert.equal(r.channels, 1); assert.deepEqual(source, saved);
  const bad = Buffer.from(source); bad.writeUInt16LE(99, 20);
  for (const b of [bad, source.subarray(0, 40), Buffer.alloc(12)]) assert.throws(() => normalizeWave(b), WaveError);
  assert.throws(() => normalizeWave(wav(5.01)), e => e.code === 'too_long');
});
test('music envelope follows actual PCM energy, silence remains still', () => {
  const silent = analyzeMusic(wav(.2, 0)); assert.ok(silent.metadata.levels.every(x => x === 0));
  const quiet = analyzeMusic(wav(.2, .1)), loud = analyzeMusic(wav(.2, .3));
  assert.equal(quiet.metadata.stepSeconds, .05); assert.equal(quiet.metadata.levels.length, 4);
  assert.ok(loud.metadata.levels[0] > quiet.metadata.levels[0] * 2.9);
  assert.ok(loud.metadata.levels.every(x => x >= 0 && x <= 1));
  assert.equal(analyzeMusic(wav(6)).metadata.duration, 6);
});
test('encoded output caps and malformed RIFF lengths are rejected', () => {
  const b = wav(.1); assert.throws(() => normalizeWave(b, { maxBytes: 32 }), e => e.code === 'too_large');
  assert.throws(() => normalizeWave(b, { maxSeconds: .01 }), e => e.code === 'too_long');
  b.writeUInt32LE(0xffffffff, 40); assert.throws(() => analyzeMusic(b), WaveError);
});
test('music importer owns unique outputs and never rewrites the selected source', async t => {
  const dir = await temp(t), source = path.join(dir, 'source.wav'), target = path.join(dir, 'out.wav'), b = wav();
  await fs.writeFile(source, b); prepareMusic(source, target);
  assert.deepEqual(await fs.readFile(source), b); assert.equal(JSON.parse(await fs.readFile(target + '.json')).ok, true);
  assert.throws(() => prepareMusic(source, target)); assert.deepEqual(await fs.readFile(target), b);
});
test('oversized source is rejected from file metadata with sanitized error output', async t => {
  const dir = await temp(t), source = path.join(dir, 'private-name.wav'), target = path.join(dir, 'out.wav');
  const handle = await fs.open(source, 'w'); await handle.truncate(MAX_MUSIC_BYTES + 1); await handle.close();
  const r = spawnSync(process.execPath, ['desktop/music-import.mjs', source, target], { encoding: 'utf8', windowsHide: true });
  assert.equal(r.status, 1); assert.equal(r.stderr, '');
  const text = await fs.readFile(target + '.json', 'utf8'); assert.equal(JSON.parse(text).error, 'too_large'); assert.equal(text.includes(source), false);
});
test('Windows media controller, PCM queue and actual muted WPF playback', { skip: process.platform !== 'win32' }, async t => {
  const dir = await temp(t); await fs.writeFile(path.join(dir, 'track.wav'), wav(5));
  const out = execFileSync('powershell.exe', ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', 'tests/desktop-media.test.ps1', '-StateDir', dir], { windowsHide: true, encoding: 'utf8', timeout: 30000 });
  assert.match(out, /Media checks passed/);
  const r = JSON.parse((await fs.readFile(path.join(dir, 'media-checks.json'), 'utf8')).replace(/^\uFEFF/, ''));
  assert.equal(r.ok, true); assert.ok(r.checks.length >= 20);
});
