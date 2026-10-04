// Renders the splash image and launcher-icon foreground from the app's own drawing code
// (entry/src/main/ets/components/CreatureDraw.ets), so every surface shows the same creature.
//
//   cd ~/.wisp-gym-tools && npm i @napi-rs/canvas      # once
//   NODE_PATH=~/.wisp-gym-tools/node_modules node scripts/render-creature.mjs
import { mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { createRequire } from 'node:module';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(join(process.env.NODE_PATH || join(process.env.HOME, '.wisp-gym-tools/node_modules'), 'x.js'));
const { createCanvas, loadImage } = require('@napi-rs/canvas');

// ArkTS sources -> plain .ts next to each other (same trick as tests/run.mjs)
const out = join(root, '.render-build');
rmSync(out, { recursive: true, force: true });
mkdirSync(out, { recursive: true });
const ets = join(root, 'entry/src/main/ets');
const files = readdirSync(join(ets, 'core')).filter((f) => f.endsWith('.ets')).map((f) => join(ets, 'core', f));
files.push(join(ets, 'components/CreatureDraw.ets'));
for (const f of files) {
  let code = readFileSync(f, 'utf8');
  code = code.replace(/from '\.\.\/core\/([A-Za-z]+)'/g, "from './$1.ts'").replace(/from '\.\/([A-Za-z]+)'/g, "from './$1.ts'");
  writeFileSync(join(out, f.split('/').pop().replace(/\.ets$/, '.ts')), code);
}
const { drawCreatureFit } = await import(pathToFileURL(join(out, 'CreatureDraw.ts')).href);
const { CreatureLook } = await import(pathToFileURL(join(out, 'CreatureLook.ts')).href);

function look(opts) {
  const L = new CreatureLook();
  Object.assign(L, { hue: 14, glow: 0.55, eyeOpen: 1, smile: 0.6, bob: 0, legs: 1, push: 1, pull: 1, core: 1, mood: 'curious' }, opts);
  return L;
}

function render(size, L, fill) {
  const c = createCanvas(size, size);
  const ctx = c.getContext('2d');
  ctx.save();
  ctx.translate(size * (1 - fill) / 2, size * (1 - fill) / 2);
  drawCreatureFit(ctx, L, 1, -1, size * fill, size * fill);
  ctx.restore();
  return c;
}

const media = join(root, 'entry/src/main/resources/base/media');
const appMedia = join(root, 'AppScope/resources/base/media');

// Splash (start window icon on the dark window background)
writeFileSync(join(media, 'startIcon.png'), render(256, look({ glow: 0.6 }), 0.92).toBuffer('image/png'));

// Launcher icon foreground: the safe zone is the central ~2/3, no ground glow
const fg = render(1024, look({ glow: 0, smile: 0.75 }), 0.78).toBuffer('image/png');
writeFileSync(join(media, 'foreground.png'), fg);
writeFileSync(join(appMedia, 'foreground.png'), fg);

// README icon preview: foreground on the background layer, rounded
const bg = await loadImage(readFileSync(join(media, 'background.png')));
const prev = createCanvas(512, 512);
const p = prev.getContext('2d');
p.beginPath();
p.roundRect(0, 0, 512, 512, 112);
p.clip();
p.drawImage(bg, 0, 0, 512, 512);
p.drawImage(await loadImage(fg), 0, 0, 512, 512);
writeFileSync(join(root, 'docs/app-icon.png'), prev.toBuffer('image/png'));

rmSync(out, { recursive: true, force: true });
console.log('rendered startIcon.png, foreground.png (entry + AppScope), docs/app-icon.png');
