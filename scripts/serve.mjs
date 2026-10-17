import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
const files = new Map([
  ['/', ['../web/index.html', 'text/html;charset=utf-8']],
  ['/web/style.css', ['../web/style.css', 'text/css;charset=utf-8']],
  ['/web/app.mjs', ['../web/app.mjs', 'text/javascript;charset=utf-8']],
  ['/engine.mjs', ['../_build/host/engine.mjs', 'text/javascript;charset=utf-8']],
  ...['harbor', 'observatory', 'training'].map(n => [`/examples/${n}.mstory`, [`../examples/${n}.mstory`, 'text/plain;charset=utf-8']]),
]);
export function createServer() {
  return http.createServer(async (req, res) => {
    const path = new URL(req.url, 'http://localhost').pathname;
    const entry = files.get(path);
    const headers = { 'X-Content-Type-Options': 'nosniff', 'Cache-Control': 'no-store', 'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'" };
    if (!entry || !['GET', 'HEAD'].includes(req.method)) { res.writeHead(404, headers); res.end('Not found'); return; }
    try { const bytes = await readFile(new URL(entry[0], import.meta.url)); res.writeHead(200, { ...headers, 'Content-Type': entry[1] }); res.end(req.method === 'HEAD' ? undefined : bytes); }
    catch { res.writeHead(500, headers); res.end('Build engine first: npm run build'); }
  });
}
if (process.argv[1] && fileURLToPath(import.meta.url) === resolve(process.argv[1])) {
  const port = Number(process.env.MOONSTORY_PORT ?? 4175);
  createServer().listen(port, '127.0.0.1', () => console.log(`MoonStory studio: http://127.0.0.1:${port}`));
}
