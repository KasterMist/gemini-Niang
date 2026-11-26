// Local PCM analysis, not system-audio or microphone capture.
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { normalizeWave, WaveError } from './audio-import.mjs';
export const MAX_MUSIC_BYTES = 100 * 1024 * 1024;
export function analyzeMusic(bytes) {
  const track = normalizeWave(bytes, { maxBytes: MAX_MUSIC_BYTES, maxSeconds: 1200 });
  const hop = Math.max(1, Math.round(track.sampleRate * .05)), levels = [];
  for (let frame = 0; frame < track.frames; frame += hop) {
    const end = Math.min(track.frames, frame + hop); let sum = 0;
    for (let i = frame * track.channels; i < end * track.channels; i++) {
      const value = track.bytes.readInt16LE(44 + i * 2) / 32768; sum += value * value;
    }
    levels.push(Math.round(Math.min(1, 3 * Math.sqrt(sum / ((end - frame) * track.channels))) * 10000) / 10000);
  }
  return { bytes: track.bytes, metadata: { ok: true, duration: track.duration, stepSeconds: hop / track.sampleRate, levels } };
}
export function prepareMusic(source, target) {
  const fd = fs.openSync(source, 'r');
  try {
    const size = fs.fstatSync(fd).size;
    if (size > MAX_MUSIC_BYTES) throw new WaveError('too_large');
    const bytes = Buffer.alloc(size); let n = 0;
    while (n < size) { const count = fs.readSync(fd, bytes, n, size - n, null); if (!count) throw new WaveError('invalid'); n += count; }
    if (fs.fstatSync(fd).size !== size) throw new WaveError('invalid');
    const result = analyzeMusic(bytes);
    fs.writeFileSync(target, result.bytes, { flag: 'wx', mode: 0o600 });
    fs.writeFileSync(target + '.json', JSON.stringify(result.metadata), { flag: 'wx', mode: 0o600 });
    return { ok: true };
  } finally { fs.closeSync(fd); }
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    if (process.argv.length !== 4) throw new WaveError('invalid');
    prepareMusic(process.argv[2], process.argv[3]);
  } catch (error) {
    // The caller generates a unique output; never include source paths or music names.
    if (process.argv[3]) {
      try { fs.writeFileSync(process.argv[3] + '.json', JSON.stringify({ ok: false, error: error instanceof WaveError ? error.code : 'io' }), { flag: 'wx', mode: 0o600 }); } catch {}
    }
    process.exitCode = 1;
  }
}
