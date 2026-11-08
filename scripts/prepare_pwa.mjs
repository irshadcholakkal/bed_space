import { readdir, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../build/web/', import.meta.url));
async function list(directory, prefix = '') {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = await Promise.all(entries.map(async (entry) => {
    const relative = prefix + entry.name;
    return entry.isDirectory() ? list(path.join(directory, entry.name), relative + '/') : [relative];
  }));
  return files.flat();
}
const files = (await list(root)).filter((file) =>
  !['pwa-sw.js', 'pwa-precache.json', 'flutter_service_worker.js'].includes(file) &&
  !file.endsWith('.map')).sort();
for (const required of ['index.html', 'manifest.json', 'flutter_bootstrap.js',
  'main.dart.js', 'sqlite3.wasm', 'sqflite_sw.js']) {
  if (!files.includes(required)) throw new Error(`Missing PWA file: ${required}`);
}
const hash = createHash('sha256');
for (const file of files) {
  hash.update(file);
  hash.update(await readFile(path.join(root, file)));
}
const source = await readFile(new URL('../web/pwa-sw.js', import.meta.url), 'utf8');
hash.update(source);
const version = hash.digest('hex').slice(0, 16);
await writeFile(path.join(root, 'pwa-precache.json'), JSON.stringify({ version, files }));
await writeFile(path.join(root, 'pwa-sw.js'), source.replace('__PWA_VERSION__', version));
console.log(`PWA ready: ${files.length} offline app files, version ${version}`);
