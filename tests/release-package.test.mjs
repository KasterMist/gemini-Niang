import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtemp, readFile, writeFile, rm } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import os from 'node:os';
import path from 'node:path';

const ps = (args, timeout = 120000) => execFileSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', ...args], { encoding: 'utf8', windowsHide: true, timeout, stdio: ['ignore', 'pipe', 'pipe'] });
const hash = b => createHash('sha256').update(b).digest('hex').toUpperCase();
test('Gemini source package is immutable, reproducible, private-state-free and extractable', { skip: process.platform !== 'win32', timeout: 240000 }, async t => {
  const dir = await mkdtemp(path.join(os.tmpdir(), 'gemini-release-'));
  t.after(() => rm(dir, { recursive: true, force: true }));
  const build = () => JSON.parse(ps(['-File', 'scripts/Build-GeminiRelease.ps1', '-OutputDirectory', dir]));
  const first = build(), second = build();
  assert.equal(first.sha256, second.sha256);
  assert.equal(first.commit, execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8', windowsHide: true }).trim());
  const bytes = await readFile(first.archive);
  assert.equal(hash(bytes), first.sha256);
  const manifest = JSON.parse(await readFile(first.archive.replace(/\.zip$/, '.manifest.json'), 'utf8'));
  assert.equal(Object.keys(manifest.files).length, first.files);
  assert.equal(manifest.commit, first.commit);
  for (const name of Object.keys(manifest.files)) {
    assert.doesNotMatch(name, /(^|\/)(\.codex|\.agents|node_modules|\.test-state|dist)(\/|$)/);
    assert.notEqual(name, 'docs/ui-v040/local-runtime.json');
  }
  const packedJson = execFileSync('git', ['show', `${first.commit}:package.json`], { windowsHide: true });
  assert.equal(manifest.files['package.json'].toUpperCase(), hash(packedJson));
  // Extract and load the actual shipped app prerequisites, without launch/install/audio capture.
  const quote = s => `'${s.replaceAll("'", "''")}'`;
  const extracted = path.join(dir, 'unpacked');
  const check = ps(['-Command', `Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::ExtractToDirectory(${quote(first.archive)},${quote(extracted)}); & ${quote(path.join(extracted, 'Gemini-Niang', 'desktop', 'GeminiNiang.ps1'))} -CheckOnly`]);
  assert.equal(JSON.parse(check).ok, true);
  // Preserve a conflicting pre-existing package instead of silently replacing it.
  const conflict = Buffer.concat([bytes, Buffer.from('conflict')]);
  await writeFile(first.archive, conflict);
  assert.throws(build, /Different package already exists/);
  assert.equal(hash(await readFile(first.archive)), hash(conflict));
});

test('legacy Codex publisher is restricted to upstream, Gemini CI only uploads artifacts', async () => {
  const release = await readFile('.github/workflows/release.yml', 'utf8');
  assert.match(release, /if: github\.repository == 'T7moris\/GPT-Niang' &&/);
  const gemini = await readFile('.github/workflows/character-assets.yml', 'utf8');
  assert.match(gemini, /Build-GeminiRelease\.ps1/);
  assert.match(gemini, /gemini-windows-source/);
  assert.doesNotMatch(gemini, /contents: write|gh release create/);
});
