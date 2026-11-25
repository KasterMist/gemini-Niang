import { test } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
test('root redirects and all browser assets/downloads are served', async t => {
  const port = 20000 + Math.floor(Math.random() * 20000);
  const child = spawn(process.execPath, ['scripts/preview-server.mjs'], { cwd: new URL('../', import.meta.url), env: { ...process.env, PORT: String(port) }, windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  t.after(() => child.kill());
  await Promise.race([once(child.stdout, 'data'), once(child, 'exit').then(() => { throw new Error('Server exited before ready'); }), new Promise((_, reject) => { const timer = setTimeout(() => reject(new Error('Server startup timeout')), 5000); timer.unref(); })]);
  const root = `http://127.0.0.1:${port}`;
  const r = await fetch(root); assert.equal(r.status, 200); assert.match(r.url, /preview\/index.html$/);
  assert.match(await r.text(), /Gemini 娘/);
  for (const url of ['/preview/studio.mjs', '/preview/studio.css', '/preview/motion.mjs', '/assets/characters/gemini/character.json']) assert.equal((await fetch(root + url)).status, 200);
  for (const view of ['full', 'bust', 'side', 'back']) for (const action of ['idle', 'blink', 'wave', 'happy', 'think', 'sleep']) for (const ext of ['png', 'gif']) {
    const media = await fetch(`${root}/assets/characters/gemini/${ext}/${view}-${action}.${ext}`, { method: 'HEAD' });
    assert.equal(media.status, 200); assert.equal(media.headers.get('content-type'), `image/${ext}`);
  }
  assert.equal((await fetch(root + '/.git/config')).status, 403);
  assert.equal((await fetch(root + '/package.json', { method: 'POST' })).status, 405);
});
