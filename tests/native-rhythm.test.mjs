import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawn } from 'node:child_process';
import { once } from 'node:events';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
for (const name of ['music-motion', 'music-throw-release', 'music-beat-clock']) {
  test(`ported ${name}: synthetic timing/physics only, no capture`, { skip: process.platform !== 'win32' }, () => {
    const out = execFileSync('powershell.exe', ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', `tests/ported-${name}.test.ps1`], { encoding: 'utf8', timeout: 30000, windowsHide: true });
    assert.match(out, /PASS/);
  });
}
test('native GUI host is a WinExe, starts an isolated WPF app and exits cleanly', { skip: process.platform !== 'win32' }, async t => {
  const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'gemini-native-')); t.after(() => fs.rm(dir, { recursive: true, force: true }));
  const state = path.join(dir, 'state with spaces'); await fs.mkdir(state);
  await fs.writeFile(path.join(state, 'preferences.json'), JSON.stringify({ followHost: false, collapsed: true }));
  const built = JSON.parse(execFileSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 'scripts/Build-DesktopHost.ps1', '-OutputDirectory', path.join(dir, 'bin')], { encoding: 'utf8', timeout: 20000, windowsHide: true }));
  const binary = await fs.readFile(built.executable), pe = binary.readUInt32LE(0x3c);
  assert.equal(binary.readUInt16LE(pe + 24 + 68), 2, 'Windows GUI subsystem, not a console');
  const child = spawn(built.executable, ['--root', process.cwd(), '--state-dir', state, '--test', '--no-refresh', '--show-taskbar', '--auto-close', '4'], { windowsHide: true });
  const exit = once(child, 'exit');
  try {
    let runtime;
    const until = Date.now() + 12000;
    while(Date.now() < until) {
      runtime = await fs.readFile(path.join(state, 'widget-runtime.json'), 'utf8').then(JSON.parse).catch(() => null);
      if(runtime) break;
      if(child.exitCode !== null) throw new Error('GUI host exited before WPF startup');
      await new Promise(r => setTimeout(r, 100));
    }
    assert.ok(runtime); assert.equal(runtime.pid, child.pid); assert.equal(runtime.testMode, true); assert.equal(runtime.systemRhythmActive, false);
    const result = await Promise.race([exit, new Promise((_, reject) => { const timer=setTimeout(() => reject(new Error('GUI shutdown timeout')), 10000); timer.unref(); })]);
    assert.equal(result[0], 0);
  } finally { if(child.exitCode === null) child.kill(); }
});
