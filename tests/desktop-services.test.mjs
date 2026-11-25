import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

for (const name of ['Pool', 'Scheduler', 'Placement']) {
  test(`Windows desktop ${name}: persistence, safety and deterministic regressions`, { skip: process.platform !== 'win32' }, async t => {
    const dir = await mkdtemp(path.join(os.tmpdir(), 'gemini-services-'));
    t.after(() => rm(dir, { recursive: true, force: true }));
    const out = execFileSync('powershell.exe', ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', 'tests/desktop-services.test.ps1', '-StateDir', dir, '-Case', name], { encoding: 'utf8', windowsHide: true, timeout: 20000 });
    assert.match(out, /checks passed/);
    const result = JSON.parse((await readFile(path.join(dir, `${name}-result.json`), 'utf8')).replace(/^\uFEFF/, ''));
    assert.equal(result.ok, true); assert.ok(result.checks.length >= 9);
  });
}
