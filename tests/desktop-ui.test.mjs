import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, readFile, rm } from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import { execFileSync } from 'node:child_process';

test('upstream bubble and menu templates retain attribution and real visual controls', async () => {
  const xaml = await readFile('desktop/widget.xaml', 'utf8');
  const menu = await readFile('desktop/menu-resources.xaml', 'utf8');
  for (const name of ['BubbleShape', 'ShortBar', 'WeekBar', 'TailNear', 'MenuButton']) assert.ok(xaml.includes(`x:Name="${name}"`));
  assert.match(xaml, /T7moris/); assert.match(menu, /T7moris/);
  assert.match(menu, /PART_Popup/); assert.match(menu, /IsHighlighted/);
});

test('Windows WPF themed UI scenes, menus and preference actions', { skip: process.platform !== 'win32' }, async t => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'gemini-ui-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const out = execFileSync('powershell.exe', ['-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-File', 'tests/desktop-ui.test.ps1', '-StateDir', dir], { encoding: 'utf8', windowsHide: true, timeout: 20000 });
  assert.match(out, /UI checks passed/);
  const result = JSON.parse(await readFile(path.join(dir, 'ui-validation.json'), 'utf8'));
  assert.equal(result.ok, true); assert.ok(result.checks.length >= 19);
});
