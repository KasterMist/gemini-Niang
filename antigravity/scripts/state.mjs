import os from 'node:os';
import path from 'node:path';
import { mkdir, writeFile, rename, readFile } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
export function stateDir(env = process.env) {
  return path.resolve(env.GEMINI_NIANG_STATE_DIR || (process.platform === 'win32'
    ? path.join(env.LOCALAPPDATA || path.join(os.homedir(), 'AppData/Local'), 'GeminiNiang/state')
    : path.join(os.homedir(), '.local/state/gemini-niang')));
}
export async function readJson(file, fallback = null) {
  try { return JSON.parse((await readFile(file, 'utf8')).replace(/^\uFEFF/, '')); } catch { return fallback; }
}
export async function atomicJson(file, value) {
  await mkdir(path.dirname(file), { recursive: true, mode: 0o700 });
  const tmp = file + `.${randomUUID()}.tmp`;
  await writeFile(tmp, JSON.stringify(value) + '\n', { mode: 0o600 });
  await rename(tmp, file);
}
