import { readFileSync, mkdirSync, writeFileSync, existsSync } from 'node:fs';
import { parseEnv } from 'node:util';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const root = fileURLToPath(new URL('../', import.meta.url));
const values = {};
for (const name of ['.env', '.env.local']) {
  const file = path.join(root, name);
  if (existsSync(file)) Object.assign(values, parseEnv(readFileSync(file, 'utf8')));
}
Object.assign(values, process.env);
if (process.argv.includes('--flutter-version')) {
  process.stdout.write(values.FLUTTER_VERSION || '3.47.2');
} else {
  const override = process.argv.indexOf('--client-id');
  if (override !== -1 && process.argv[override + 1]) {
    values.GOOGLE_CLIENT_ID = process.argv[override + 1];
  }
  // Explicit allowlist: arbitrary secrets in .env never enter the browser bundle.
  const config = {
    GOOGLE_CLIENT_ID: values.GOOGLE_CLIENT_ID || '',
    SUPABASE_URL: values.SUPABASE_URL || '',
    SUPABASE_ANON_KEY: values.SUPABASE_ANON_KEY || '',
  };
  mkdirSync(path.join(root, '.dart_tool'), { recursive: true });
  writeFileSync(path.join(root, '.dart_tool/build-config.json'), JSON.stringify(config));
  if (!config.GOOGLE_CLIENT_ID) {
    console.warn('Warning: GOOGLE_CLIENT_ID is empty. Google sign-in requires configuration and a rebuild.');
  }
}
