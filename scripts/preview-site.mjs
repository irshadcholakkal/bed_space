import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = path.resolve(fileURLToPath(new URL('../build/site/', import.meta.url)));
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript',
  '.json': 'application/json', '.css': 'text/css', '.webp': 'image/webp',
  '.png': 'image/png', '.ttf': 'font/ttf', '.woff2': 'font/woff2', '.wasm': 'application/wasm', '.svg': 'image/svg+xml' };
createServer(async (request, response) => {
  try {
    const url = new URL(request.url, 'http://127.0.0.1');
    if (url.pathname === '/app') {
      response.writeHead(308, { Location: '/app/' + url.search }); response.end(); return;
    }
    let file = path.resolve(root, '.' + decodeURIComponent(url.pathname));
    if (file !== root && !file.startsWith(root + path.sep)) throw new Error('Outside output');
    try { if ((await stat(file)).isDirectory()) file = path.join(file, 'index.html'); }
    catch (_) {
      if (url.pathname.startsWith('/app/') && !path.extname(url.pathname)) file = path.join(root, 'app/index.html');
    }
    const body = await readFile(file);
    response.writeHead(200, { 'Content-Type': mime[path.extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
    response.end(body);
  } catch (_) { response.writeHead(404); response.end('Not Found'); }
}).listen(4173, '127.0.0.1', () => console.log('Preview: http://127.0.0.1:4173'));
