import { execFile } from 'node:child_process';
import { access } from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { stateDir, readJson } from './state.mjs';
export const USAGE_ARGS = Object.freeze(['-p', '/usage', '--output-format', 'json']);
const fail = (errorCode, message) => ({ ok: false, source: 'antigravity-cli', errorCode, message, groups: [], observedAt: new Date().toISOString() });
const label = (s, fallback) => typeof s === 'string' && s.length <= 160 ? s.replace(/[\x00-\x1f]/g, '') : fallback;
export function parseUsage(value) {
  if (!value || value.status !== 'SUCCESS' || value.command?.name !== 'usage' || value.num_turns !== 0) return fail('INVALID_RESPONSE', 'CLI未返回只读usage结果；已拒绝将模型回复当成额度。');
  const groups = value.command.data?.groups;
  if (!Array.isArray(groups) || groups.length > 32) return fail('INVALID_RESPONSE', '额度分组格式无法识别，请检查CLI版本。');
  try {
    const clean = groups.map(g => {
      if (!Array.isArray(g.buckets) || g.buckets.length > 32) throw new Error();
      return { name: label(g.name, '模型组'), buckets: g.buckets.map(b => {
        if (typeof b.remaining_fraction !== 'number' || !Number.isFinite(b.remaining_fraction) || b.remaining_fraction < 0 || b.remaining_fraction > 1) throw new Error();
        const ms = typeof b.reset_time === 'string' ? Date.parse(b.reset_time) : NaN;
        return { id: label(b.id, ''), label: label(b.name, '额度'), window: label(b.window, ''), remaining: Math.round(b.remaining_fraction * 1000) / 10,
          // Epoch is an unknown reset, NOT a real reset in 1970.
          resetsAt: Number.isFinite(ms) && ms > 0 ? new Date(ms).toISOString() : null };
      }) };
    });
    return { ok: true, source: 'antigravity-cli', groups: clean, observedAt: new Date().toISOString(), modelTurns: 0 };
  } catch { return fail('INVALID_RESPONSE', '额度字段无效，未显示旧余额或推算值。'); }
}
export async function resolveCli(env = process.env) {
  const config = await readJson(path.join(stateDir(env), 'config.json'), {});
  // Configuration is an executable path, never a shell command/argument string.
  if (env.GEMINI_NIANG_AGY || config.agyPath) return env.GEMINI_NIANG_AGY || config.agyPath;
  if (process.platform === 'win32') {
    const p = path.join(env.LOCALAPPDATA || '', 'agy/bin/agy.exe');
    try { await access(p); return p; } catch {}
  } else {
    const p = path.join(os.homedir(), '.local/bin/agy');
    try { await access(p); return p; } catch {}
  }
  return process.platform === 'win32' ? 'agy.exe' : 'agy';
}
export async function queryUsage({ cli, timeoutMs = 30000, runner = execFile, env = process.env } = {}) {
  cli ||= await resolveCli(env);
  return new Promise(resolve => {
    runner(cli, [...USAGE_ARGS], { timeout: timeoutMs, maxBuffer: 1024 * 1024, windowsHide: true, shell: false, env }, (error, stdout = '') => {
      // Never persist/forward stdout or stderr on failures: they can contain account details.
      if (error) return resolve(fail(error.code === 'ENOENT' ? 'CLI_NOT_FOUND' : error.killed ? 'TIMEOUT' : 'CLI_FAILED',
        error.code === 'ENOENT' ? '未找到Antigravity CLI，请配置agyPath。' : error.killed ? '额度查询超时，可稍后刷新。' : 'CLI查询失败，请在终端检查登录与网络。'));
      try { resolve(parseUsage(JSON.parse(stdout.replace(/^\uFEFF/, '')))); }
      catch { resolve(fail('INVALID_JSON', 'CLI输出不是额度JSON，未调用模型解释。')); }
    });
  });
}
