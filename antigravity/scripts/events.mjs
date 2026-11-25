import { mkdir, writeFile, link, unlink, readdir, stat } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import path from 'node:path';
import os from 'node:os';
import { stateDir } from './state.mjs';
export function completionEvent(input, now = Date.now(), turnMarker = '') {
  // Public docs use model_stop; App 2.34/CLI 1.5.16 actually emit NO_TOOL_CALL
  // for a successful final reply. Only these verified normal endings qualify.
  if (!input || input.fullyIdle !== true || !['model_stop', 'NO_TOOL_CALL'].includes(input.terminationReason) || input.error) return null;
  if (typeof input.conversationId !== 'string' || !input.conversationId || input.conversationId.length > 200 || !Number.isSafeInteger(input.executionNum) || input.executionNum < 0) return null;
  const fallback = typeof input.lastUserInput === 'string' ? createHash('sha256').update(input.lastUserInput).digest('hex') : '';
  const id = createHash('sha256').update(`${input.conversationId}\0${input.executionNum}\0${turnMarker || fallback}`).digest('hex');
  // No user prompts, transcript paths, workspace paths or raw conversation IDs.
  return { id, type: 'completed', at: new Date(now).toISOString() };
}
export async function transcriptMarker(input, roots = ['antigravity', 'antigravity-cli', 'antigravity-ide'].map(n => path.join(os.homedir(), '.gemini', n, 'brain'))) {
  if (typeof input?.transcriptPath !== 'string' || input.transcriptPath.length > 4096 || !path.isAbsolute(input.transcriptPath)) return '';
  const target = path.resolve(input.transcriptPath);
  // Never stat arbitrary paths or network shares supplied on stdin. Only the
  // documented local conversation-log location is eligible. No file is read.
  if (!roots.some(root => {
    const relative = path.relative(root, target);
    return !relative.split(/[/\\]/).includes('..') && /^[^/\\]+[/\\]\.system_generated[/\\]logs[/\\]transcript\.jsonl$/.test(relative);
  })) return '';
  try { const info = await stat(target, { bigint: true }); return info.isFile() ? `${info.size}:${info.mtimeNs}` : ''; } catch { return ''; }
}
export async function publishCompletion(input, dir = stateDir(), options = {}) {
  if (!completionEvent(input)) return false;
  const event = completionEvent(input, Date.now(), await transcriptMarker(input, options.transcriptRoots));
  if (!event) return false;
  const folder = path.join(dir, 'events');
  await mkdir(folder, { recursive: true, mode: 0o700 });
  const tmp = path.join(folder, `${randomUUID()}.tmp`);
  await writeFile(tmp, JSON.stringify(event) + '\n', { mode: 0o600 });
  let published = false;
  try { await link(tmp, path.join(folder, event.id + '.json')); published = true; }
  catch (e) { if (e.code !== 'EEXIST') throw e; }
  finally { await unlink(tmp); }
  const files = (await readdir(folder)).filter(f => /^[a-f0-9]{64}\.json$/.test(f));
  if (files.length > 128) {
    const stats = (await Promise.all(files.map(async f => {
      try { return { f, time: (await stat(path.join(folder, f))).mtimeMs }; }
      catch (e) { if (e.code === 'ENOENT') return null; throw e; }
    }))).filter(Boolean);
    stats.sort((a, b) => b.time - a.time);
    for (const item of stats.slice(128)) await unlink(path.join(folder, item.f)).catch(() => {});
  }
  return published;
}
