import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, readdir, rm, writeFile } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { spawn, execFileSync } from 'node:child_process';
import { once } from 'node:events';
import { parseUsage, queryUsage, USAGE_ARGS } from '../antigravity/scripts/usage.mjs';
import { completionEvent, publishCompletion } from '../antigravity/scripts/events.mjs';
import { atomicJson, readJson } from '../antigravity/scripts/state.mjs';
const fixture = () => ({ status: 'SUCCESS', num_turns: 0, conversation_id: 'DO-NOT-STORE', response: 'DO-NOT-STORE', command: { name: 'usage', data: { groups: [{ name: 'Gemini Models', buckets: [{ id: 'gemini-weekly', name: 'Weekly Limit Remaining', window: 'weekly', remaining_fraction: .79556, reset_time: '2026-12-01T01:45:58Z' }, { id: 'gemini-5h', window: '5h', remaining_fraction: 1, reset_time: '1970-01-01T00:00:00Z' }] }] } } });
const hook = () => ({ conversationId: 'conversation-private', executionNum: 7, terminationReason: 'model_stop', fullyIdle: true, lastUserInput: 'DO-NOT-STORE', transcriptPath: 'DO-NOT-STORE' });
async function temp(t) { const dir = await mkdtemp(path.join(os.tmpdir(), 'gemini-niang-test-')); t.after(() => rm(dir, { recursive: true, force: true })); return dir; }
function runNode(file, input = '', env = {}) {
  return new Promise((resolve, reject) => {
    const p = spawn(process.execPath, [file], { env: { ...process.env, ...env }, windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    let out = '', err = ''; p.stdout.on('data', x => out += x); p.stderr.on('data', x => err += x);
    const timer = setTimeout(() => { p.kill(); reject(new Error('Child timeout')); }, 8000);
    p.on('error', reject); p.on('close', code => { clearTimeout(timer); resolve({ code, out, err }); }); p.stdin.end(input);
  });
}
test('real CLI 1.5 response shape maps fractions, reset epoch and drops private fields', () => {
  const r = parseUsage(fixture()); assert.equal(r.ok, true); assert.equal(r.groups[0].buckets[0].remaining, 79.6); assert.equal(r.groups[0].buckets[1].resetsAt, null);
  assert.equal(JSON.stringify(r).includes('DO-NOT-STORE'), false); assert.equal(r.modelTurns, 0);
});
test('reject model-generated answers, nonzero turns and unknown response shapes', () => {
  for (const mutate of [x => x.num_turns = 1, x => delete x.num_turns, x => x.command.name = 'chat', x => x.status = 'ERROR', x => x.command.data.groups = {}]) {
    const f = fixture(); mutate(f); assert.equal(parseUsage(f).ok, false);
  }
});
test('reject invalid fractions without silently clamping', () => {
  for (const n of [-1, 1.1, NaN, '0.5', null]) { const f = fixture(); f.command.data.groups[0].buckets[0].remaining_fraction = n; assert.equal(parseUsage(f).ok, false); }
});
test('zero quota and absent reset are valid, empty groups do not invent quotas', () => {
  const f = fixture(); f.command.data.groups[0].buckets[0].remaining_fraction = 0; delete f.command.data.groups[0].buckets[0].reset_time;
  const r = parseUsage(f); assert.equal(r.groups[0].buckets[0].remaining, 0); assert.equal(r.groups[0].buckets[0].resetsAt, null);
  f.command.data.groups = []; assert.deepEqual(parseUsage(f).groups, []);
});
test('provider only spawns fixed read-only usage args with no shell', async () => {
  const r = await queryUsage({ cli: 'path with spaces/agy', runner: (cli, args, options, cb) => {
    assert.equal(cli, 'path with spaces/agy'); assert.deepEqual(args, USAGE_ARGS); assert.equal(options.shell, false); assert.equal(options.windowsHide, true); cb(null, JSON.stringify(fixture()));
  } }); assert.equal(r.ok, true);
});
test('provider failure modes discard possible secrets from CLI output', async () => {
  for (const [error, expected] of [[{ code: 'ENOENT' }, 'CLI_NOT_FOUND'], [{ killed: true }, 'TIMEOUT'], [{ code: 1 }, 'CLI_FAILED']]) {
    const r = await queryUsage({ cli: 'agy', runner: (_c, _a, _o, cb) => cb(error, 'secret-token', 'private-email') });
    assert.equal(r.errorCode, expected); assert.equal(JSON.stringify(r).includes('secret-token'), false); assert.deepEqual(r.groups, []);
  }
  assert.equal((await queryUsage({ cli: 'agy', runner: (_c, _a, _o, cb) => cb(null, 'not-json') })).errorCode, 'INVALID_JSON');
});
test('actual missing executable is a clean unavailable state', async () => {
  const r = await queryUsage({ cli: path.join(os.tmpdir(), 'nonexistent-gemini-test-cli') }); assert.equal(r.errorCode, 'CLI_NOT_FOUND');
});
test('Stop completion requires final successful idle, not every model invocation', () => {
  assert.ok(completionEvent(hook()));
  for (const change of [{ fullyIdle: false }, { fullyIdle: undefined }, { terminationReason: 'error' }, { terminationReason: 'max_steps_exceeded' }, { terminationReason: 'cancelled' }, { error: 'failure' }, { executionNum: -1 }, { conversationId: '' }]) assert.equal(completionEvent({ ...hook(), ...change }), null);
  assert.equal(JSON.stringify(completionEvent(hook())).includes('DO-NOT-STORE'), false);
});
test('completion events atomically deduplicate concurrent hooks and retain only sanitized payload', async t => {
  const dir = await temp(t); const results = await Promise.all([publishCompletion(hook(), dir), publishCompletion(hook(), dir)]);
  assert.equal(results.filter(Boolean).length, 1);
  const files = await readdir(path.join(dir, 'events')); assert.equal(files.length, 1);
  const data = await readFile(path.join(dir, 'events', files[0]), 'utf8'); assert.equal(data.includes('DO-NOT-STORE'), false); assert.equal(data.includes('conversation-private'), false);
});
test('completion spool is bounded to 128 event files', async t => {
  const dir = await temp(t); for (let i = 0; i < 132; i++) await publishCompletion({ ...hook(), executionNum: i }, dir);
  assert.equal((await readdir(path.join(dir, 'events'))).length, 128);
});
test('hook process always returns empty JSON and does not force agent continuation', async t => {
  const dir = await temp(t);
  for (const input of ['malformed', JSON.stringify(hook()), JSON.stringify({ ...hook(), fullyIdle: false })]) {
    const r = await runNode('antigravity/scripts/stop-hook.mjs', input, { GEMINI_NIANG_STATE_DIR: dir }); assert.equal(r.code, 0); assert.deepEqual(JSON.parse(r.out), {}); assert.equal(r.err, '');
  }
  assert.equal((await readdir(path.join(dir, 'events'))).length, 1);
});
test('atomic state updates replace files on Windows and preserve valid JSON', async t => {
  const dir = await temp(t), file = path.join(dir, 'usage.json');
  await atomicJson(file, { value: 1 }); await atomicJson(file, { value: 2 }); assert.deepEqual(await readJson(file), { value: 2 });
});
test('MCP process handshake, list and unavailable-CLI tool call', async t => {
  const dir = await temp(t);
  const input = [{ jsonrpc: '2.0', id: 1, method: 'initialize', params: { protocolVersion: '2024-11-05' } }, { jsonrpc: '2.0', method: 'notifications/initialized' }, { jsonrpc: '2.0', id: 2, method: 'tools/list' }, { jsonrpc: '2.0', id: 3, method: 'tools/call', params: { name: 'get_antigravity_usage', arguments: {} } }].map(JSON.stringify).join('\n') + '\n';
  const r = await runNode('antigravity/scripts/mcp.mjs', input, { GEMINI_NIANG_STATE_DIR: dir, GEMINI_NIANG_AGY: path.join(dir, 'missing') });
  assert.equal(r.code, 0); assert.equal(r.err, ''); const messages = r.out.trim().split('\n').map(JSON.parse);
  assert.equal(messages.length, 3); assert.equal(messages.find(m => m.id === 2).result.tools[0].name, 'get_antigravity_usage');
  const result = messages.find(m => m.id === 3).result; assert.equal(result.isError, true); assert.equal(JSON.parse(result.content[0].text).errorCode, 'CLI_NOT_FOUND');
});
test('plugin configuration is self-contained, uses correct hook shape, no credential declaration', async () => {
  const manifest = JSON.parse(await readFile('antigravity/plugin.json', 'utf8')); assert.equal(manifest.name, 'gemini-niang');
  const config = JSON.parse(await readFile('antigravity/mcp_config.json', 'utf8')); assert.deepEqual(config.mcpServers.usage.args, ['${PLUGIN_ROOT}/scripts/mcp.mjs']);
  const hooks = JSON.parse(await readFile('antigravity/hooks.json', 'utf8')); assert.equal(hooks['gemini-niang-completion'].Stop[0].command, 'node ./scripts/stop-hook.mjs');
});
test('Windows PowerShell 5 syntax and native preflight', { skip: process.platform !== 'win32' }, () => {
  const output = execFileSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'desktop/GeminiNiang.ps1', '-CheckOnly'], { encoding: 'utf8', windowsHide: true });
  assert.equal(JSON.parse(output).ok, true);
});
test('Windows WPF process loads real assets and reacts to a simulated Stop hook', { skip: process.platform !== 'win32', timeout: 20000 }, async t => {
  const dir = await temp(t);
  await atomicJson(path.join(dir, 'preferences.json'), { view: 'bust', action: 'idle', size: 180, followHost: false });
  await atomicJson(path.join(dir, 'usage.json'), { ...parseUsage(fixture()), source: 'test-fixture' });
  const child = spawn('powershell.exe', ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', 'desktop/GeminiNiang.ps1', '-StateDir', dir, '-NoRefresh', '-TestMode', '-AutoCloseSeconds', '12'], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  let errors = ''; child.stderr.on('data', x => errors += x);
  const until = async predicate => {
    const end = Date.now() + 8000;
    while (Date.now() < end) { const state = await readJson(path.join(dir, 'widget-runtime.json')); if (state && predicate(state)) return state; if (child.exitCode !== null) throw new Error(`WPF exited: ${child.exitCode}; ${errors}`); await new Promise(r => setTimeout(r, 100)); }
    throw new Error(`WPF state timeout; ${errors}; ${await readFile(path.join(dir, 'widget-error.txt'), 'utf8').catch(() => '')}`);
  };
  try {
    const state = await until(s => s.pid === child.pid); assert.equal(state.view, 'bust'); assert.ok(state.handle > 0); assert.equal(state.testMode, true);
    const result = await runNode('antigravity/scripts/stop-hook.mjs', JSON.stringify(hook()), { GEMINI_NIANG_STATE_DIR: dir }); assert.equal(result.code, 0);
    const completed = await until(s => s.noticeActive); assert.equal(completed.action, 'happy'); assert.equal(completed.bubbleVisible, true);
    const widgetError = await readFile(path.join(dir, 'widget-error.txt'), 'utf8').catch(e => { if (e.code === 'ENOENT') return ''; throw e; });
    assert.equal(widgetError, ''); assert.equal(errors, '');
  } finally { if (child.exitCode === null && child.signalCode === null) { const exited = once(child, 'exit'); child.kill(); await exited; } }
});
test('Windows launch scripts use UTF-8 BOM and plugin registration is opt-in', { skip: process.platform !== 'win32' }, async () => {
  assert.equal((await readFile('scripts/Install-GeminiNiang.ps1')).subarray(0, 3).toString('hex'), 'efbbbf');
  assert.match(await readFile('scripts/Install-GeminiNiang.ps1', 'utf8'), /if\(\$RegisterPlugin\)/);
  assert.equal((await readFile('desktop/GeminiNiang.ps1')).subarray(0, 3).toString('hex'), 'efbbbf');
});
