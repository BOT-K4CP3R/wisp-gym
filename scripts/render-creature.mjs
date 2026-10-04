// Renders the splash image and launcher-icon foreground from the app's own drawing code
// (entry/src/main/ets/components/CreatureDraw.ets), so every surface shows the same creature.
//
//   cd ~/.wisp-gym-tools && npm i @napi-rs/canvas      # once
//   NODE_PATH=~/.wisp-gym-tools/node_modules node scripts/render-creature.mjs
//
// --preview [out.png]: instead renders a contact sheet of every species x expression (nothing
// in the project is written). Output: [out.png], else $PREVIEW_OUT, else the dev scratchpad
// if present, else ./species-sheet.png. Cell size: $PREVIEW_CELL (default 200).
import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync, rmSync } from 'node:fs';
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

if (process.argv.includes('--preview')) {
  const i = process.argv.indexOf('--preview');
  const arg = process.argv[i + 1];
  const scratch = '/private/tmp/claude-501/-Users-kacper-hackathon-wisp-gym/76be0924-9168-4cf8-9f03-3210d137ca95/scratchpad';
  const fallback = existsSync(scratch) ? join(scratch, 'species-sheet.png') : join(process.cwd(), 'species-sheet.png');
  const dest = arg && !arg.startsWith('--') ? arg : (process.env.PREVIEW_OUT || fallback);
  const species = [['wisp', 14], ['mochi', 330], ['ember', 2], ['pip', 42], ['nova', 265], ['moss', 120]];
  const exprs = ['', 'happy', 'joy', 'surprised', 'focused', 'strain', 'love', 'sleepy', 'asleep', 'proud', 'curious'];
  const cell = Number(process.env.PREVIEW_CELL || 200);
  const padL = 90;
  const padT = 34;
  const sheet = createCanvas(padL + cell * exprs.length, padT + cell * species.length);
  const sc = sheet.getContext('2d');
  sc.fillStyle = '#151619';
  sc.fillRect(0, 0, sheet.width, sheet.height);
  sc.fillStyle = '#B9BCC8';
  sc.font = '600 15px sans-serif';
  sc.textAlign = 'center';
  exprs.forEach((e, x) => sc.fillText(e === '' ? '(mood)' : e, padL + cell * x + cell / 2, 22));
  species.forEach(([id, hue], y) => {
    sc.textAlign = 'left';
    sc.fillStyle = '#E6E7EE';
    sc.font = '700 16px sans-serif';
    sc.fillText(id, 14, padT + cell * y + cell / 2 + 5);
    exprs.forEach((e, x) => {
      const L = look({ species: id, hue, expression: e, mood: 'content', eyeOpen: 0.85, smile: 0.7 });
      sc.save();
      sc.translate(padL + cell * x + 6, padT + cell * y + 6);
      drawCreatureFit(sc, L, 1, -1, cell - 12, cell - 12);
      sc.restore();
    });
  });
  writeFileSync(dest, sheet.toBuffer('image/png'));
  rmSync(out, { recursive: true, force: true });
  console.log('preview: ' + dest);
  process.exit(0);
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
