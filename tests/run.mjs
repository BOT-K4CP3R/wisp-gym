// Runs the pure core logic (entry/src/main/ets/core) on plain Node.
// ArkTS files are copied to .test-build as .ts with import paths rewritten, then the
// node:test files in tests/*.test.mts are executed with Node's built-in TS stripping.
import { cpSync, mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = join(root, 'entry/src/main/ets/core');
const out = join(root, '.test-build/core');
rmSync(join(root, '.test-build'), { recursive: true, force: true });
mkdirSync(out, { recursive: true });
for (const f of readdirSync(src)) {
  if (!f.endsWith('.ets')) continue;
  let code = readFileSync(join(src, f), 'utf8');
  code = code.replace(/from '\.\/([A-Za-z]+)'/g, "from './$1.ts'");
  writeFileSync(join(out, f.replace(/\.ets$/, '.ts')), code);
}
const tests = readdirSync(join(root, 'tests')).filter((f) => f.endsWith('.test.mts')).map((f) => join(root, 'tests', f));
const r = spawnSync(process.execPath, ['--test', ...tests], { stdio: 'inherit', cwd: root });
process.exit(r.status ?? 1);
