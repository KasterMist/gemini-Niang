import http from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
const root = fileURLToPath(new URL('../', import.meta.url));
const port = Number(process.env.PORT || 4178);
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.png': 'image/png', '.gif': 'image/gif', '.md': 'text/plain; charset=utf-8' };
const server = http.createServer(async (req, res) => {
  try {
    if (req.method !== 'GET' && req.method !== 'HEAD') { res.writeHead(405).end(); return; }
    const pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (pathname === '/') { res.writeHead(302, { Location: '/preview/index.html' }).end(); return; }
    const relative = pathname === '/' ? 'preview/index.html' : pathname.replace(/^\/+/, '');
    if (!/^(preview\/|assets\/(characters\/gemini\/|reference\/)|docs\/)/.test(relative)) { res.writeHead(403).end('Forbidden'); return; }
    const file = path.resolve(root, relative);
    if (!file.startsWith(root) || !types[path.extname(file)]) { res.writeHead(403).end('Forbidden'); return; }
    const data = await readFile(file), info = await stat(file);
    res.writeHead(200, { 'Content-Type': types[path.extname(file)], 'Content-Length': info.size, 'Cache-Control': 'no-cache', 'X-Content-Type-Options': 'nosniff' });
    res.end(req.method === 'HEAD' ? undefined : data);
  } catch { res.writeHead(404).end('Not found'); }
});
server.listen(port, '127.0.0.1', () => console.log(`Gemini 娘工作室: http://127.0.0.1:${port}/`));
