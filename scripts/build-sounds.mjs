// Original synthetic UI tones, generated without third-party recordings (MIT).
import fs from 'node:fs';
for (const [name, hz, seconds] of [['press', 880, .08], ['release', 1174.66, .1]]) {
  const rate = 24000, frames = Math.round(rate * seconds), bytes = Buffer.alloc(44 + frames * 2);
  bytes.write('RIFF'); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8);
  bytes.writeUInt32LE(16, 16); bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22);
  bytes.writeUInt32LE(rate, 24); bytes.writeUInt32LE(rate * 2, 28); bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34);
  bytes.write('data', 36); bytes.writeUInt32LE(frames * 2, 40);
  for (let i = 0; i < frames; i++) {
    const envelope = Math.sin(Math.PI * i / (frames - 1)) ** 2;
    bytes.writeInt16LE(Math.round(32767 * .18 * envelope * Math.sin(2 * Math.PI * hz * i / rate)), 44 + i * 2);
  }
  fs.mkdirSync(new URL('../desktop/assets/', import.meta.url), { recursive: true });
  fs.writeFileSync(new URL(`../desktop/assets/${name}.wav`, import.meta.url), bytes);
}
