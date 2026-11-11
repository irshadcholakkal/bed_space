import { cp, mkdir, readFile, rm, stat, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const target = path.resolve(root, 'build/site');
// Only replace this generated output directory, never source or user data.
if (path.dirname(target) !== path.resolve(root, 'build')) throw new Error('Invalid output path');
const flutter = path.join(root, 'build/web');
const landing = path.join(root, 'landing/out');
const appHtml = await readFile(path.join(flutter, 'index.html'), 'utf8');
if (!appHtml.includes('<base href="/app/">')) {
  throw new Error('Build Flutter with --base-href /app/ before assembling the site.');
}
await stat(path.join(landing, 'index.html'));
await rm(target, { recursive: true, force: true });
await mkdir(target, { recursive: true });
await cp(landing, target, { recursive: true });
await cp(flutter, path.join(target, 'app'), { recursive: true });
await writeFile(path.join(target, '_headers'), `/*
  Cache-Control: public, max-age=0, must-revalidate
  X-Content-Type-Options: nosniff

/_next/static/*
  Cache-Control: public, max-age=31536000, immutable

/app/pwa-sw.js
  Service-Worker-Allowed: /app/

/pwa-sw.js
  Service-Worker-Allowed: /
  Cache-Control: no-store

/app/*.wasm
  Content-Type: application/wasm

/app/manifest.json
  Content-Type: application/manifest+json
`);
console.log('Site ready: Next.js landing at /; Flutter workspace at /app/.');
