import { mkdir, writeFile, link, unlink, readdir, stat } from 'node:fs/promises';
import { createHash, randomUUID } from 'node:crypto';
import path from 'node:path';
import { stateDir } from './state.mjs';
export function completionEvent(input, now = Date.now()) {
  if (!input || input.fullyIdle !== true || input.terminationReason !== 'model_stop' || input.error) return null;
  if (typeof input.conversationId !== 'string' || !input.conversationId || input.conversationId.length > 200 || !Number.isSafeInteger(input.executionNum) || input.executionNum < 0) return null;
  const id = createHash('sha256').update(`${input.conversationId}\0${input.executionNum}`).digest('hex');
  // No user prompts, transcript paths, workspace paths or raw conversation IDs.
  return { id, type: 'completed', at: new Date(now).toISOString() };
}
export async function publishCompletion(input, dir = stateDir()) {
  const event = completionEvent(input);
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
