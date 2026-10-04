// Renders transparent PNGs of every creature/expression used in the promo from the app's own
// drawing code (entry/src/main/ets/components/CreatureDraw.ets), like scripts/render-creature.mjs.
//   NODE_PATH=~/.wisp-gym-tools/node_modules node scripts/creatures.mjs
import { mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '../../..');
const require = createRequire(join(process.env.NODE_PATH || join(process.env.HOME, '.wisp-gym-tools/node_modules'), 'x.js'));
const { createCanvas } = require('@napi-rs/canvas');

const build = join(here, '../.render-build');
rmSync(build, { recursive: true, force: true });
mkdirSync(build, { recursive: true });
const ets = join(root, 'entry/src/main/ets');
const files = readdirSync(join(ets, 'core')).filter((f) => f.endsWith('.ets')).map((f) => join(ets, 'core', f));
files.push(join(ets, 'components/CreatureDraw.ets'));
for (const f of files) {
  let code = readFileSync(f, 'utf8');
  code = code.replace(/from '\.\.\/core\/([A-Za-z]+)'/g, "from './$1.ts'").replace(/from '\.\/([A-Za-z]+)'/g, "from './$1.ts'");
  writeFileSync(join(build, f.split('/').pop().replace(/\.ets$/, '.ts')), code);
}
const { drawCreatureFit } = await import(pathToFileURL(join(build, 'CreatureDraw.ts')).href);
const { CreatureLook } = await import(pathToFileURL(join(build, 'CreatureLook.ts')).href);

const SPECIES = [['wisp', 22], ['mochi', 330], ['ember', 2], ['pip', 42], ['nova', 265], ['moss', 120]];
const EXPR = ['happy', 'joy', 'focused', 'strain', 'proud', 'sleepy', 'love', 'surprised'];
const out = join(here, '../public/creatures');
mkdirSync(out, { recursive: true });
const size = 900;
for (const [sp, hue] of SPECIES) {
  for (const ex of EXPR) {
    const L = new CreatureLook();
    Object.assign(L, { hue, glow: 0.6, eyeOpen: 1, smile: 0.7, bob: 0, legs: 1, push: 1, pull: 1, core: 1, mood: 'thriving', species: sp, expression: ex });
    const c = createCanvas(size, size);
    const ctx = c.getContext('2d');
    drawCreatureFit(ctx, L, 1, -1, size, size);
    writeFileSync(join(out, `${sp}-${ex}.png`), c.toBuffer('image/png'));
  }
}
rmSync(build, { recursive: true, force: true });
console.log('rendered', SPECIES.length * EXPR.length, 'creatures to', out);
