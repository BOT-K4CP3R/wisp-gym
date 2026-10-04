import { CreatureLook } from '../core/CreatureLook';

// The creature, drawn with smooth curves and soft shading on a 2D canvas. Pure drawing code
// with no system APIs, shared by the in-app CreatureCanvas, the home-screen widgets (ArkTS
// cards support Canvas) and scripts/render-creature.mjs, which renders the splash and icon.
// The scene is authored in a SCENE_W x SCENE_H box; callers scale it. Colours use #RRGGBB /
// rgba(): hsl() strings render nothing on this runtime.
//
// Layout: species features (ears, horns, tail, crest, antenna, sprout) wrap a shared plush
// body; the face is described by a Face (eyes / brows / mouth / extras) resolved either from
// the explicit expression or, when that is '', from mood / eyeOpen / smile / happyEyes.
// Product rule: no face may read as sad or angry.

export const SCENE_W = 340;
export const SCENE_H = 320;

const INK = '#1D1A3A';
const MOUTH_IN = '#7A2342';
const TONGUE = '#FF7FA3';
const EYE_Y = 98;
const MOUTH_Y = 121;

export function hslToHex(h: number, s: number, l: number): string {
  const sat = s / 100;
  const lig = l / 100;
  const k = (n: number): number => (n + h / 30) % 12;
  const a = sat * Math.min(lig, 1 - lig);
  const f = (n: number): number => lig - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  const hex = (x: number): string => {
    const v = Math.round(255 * x).toString(16);
    return v.length === 1 ? '0' + v : v;
  };
  return '#' + hex(f(0)) + hex(f(8)) + hex(f(4));
}

function hexToRgb(hex: string): string {
  const r = parseInt(hex.substring(1, 3), 16);
  const g = parseInt(hex.substring(3, 5), 16);
  const b = parseInt(hex.substring(5, 7), 16);
  return r + ', ' + g + ', ' + b;
}

function hue(h: number): number {
  return ((h % 360) + 360) % 360;
}

class Palette {
  hue: number = 0;
  base: string = '#000000';
  light: string = '#000000';
  mid: string = '#000000';
  dark: string = '#000000';
  deeper: string = '#000000';
  glowRgb: string = '0, 0, 0';
}

function paletteFor(h: number): Palette {
  const p = new Palette();
  p.hue = h;
  p.base = hslToHex(h, 72, 62);
  p.light = hslToHex(hue(h + 10), 86, 80);
  p.mid = hslToHex(h, 76, 68);
  p.dark = hslToHex(hue(h - 10), 62, 42);
  p.deeper = hslToHex(hue(h - 10), 60, 34);
  p.glowRgb = hexToRgb(hslToHex(h, 90, 66));
  return p;
}

// What the face shows this frame.
class Face {
  eyes: string = 'open';   // open | happy | closed | half | narrow | round | squeeze | heart
  open: number = 1;        // eye openness for 'open'
  pupil: number = 1;       // pupil scale
  gazeX: number = 0;
  gazeY: number = 0;
  brows: string = 'none';  // none | raised | determined
  mouth: string = 'smile'; // smile | grin | bigGrin | o | flat | grit
  smile: number = 0.5;     // curve depth for 'smile'
  mouthW: number = 1;      // width scale for 'smile'
  blush: number = 0.42;
  sweat: boolean = false;
  zzz: number = 0;         // 0 none, 1 one small z, 2 two z's
  sparkle: boolean = false;
}

function faceFor(L: CreatureLook, t: number, poking: boolean): Face {
  const f = new Face();
  const blink = (t % 4.4) > 4.22 ? 0.1 : 1;
  f.gazeX = Math.sin(t * 0.7) * 2.2;
  const ex = L.expression;
  if (ex === '') {
    // derived from the mood fields (the original behaviour)
    f.open = Math.min(L.eyeOpen, blink);
    f.eyes = (L.happyEyes || poking) ? 'happy' : (f.open > 0.28 ? 'open' : 'closed');
    f.mouth = (L.smile > 0.9 || poking) ? 'grin' : 'smile';
    f.smile = L.smile;
    f.zzz = ((L.mood === 'resting' || L.mood === 'sleepy') && !poking) ? 2 : 0;
    return f;
  }
  f.open = blink;
  if (ex === 'happy') {
    f.smile = 0.9;
    f.mouthW = 1.1;
    f.blush = 0.5;
  } else if (ex === 'joy') {
    f.eyes = 'happy';
    f.mouth = 'bigGrin';
    f.blush = 0.6;
  } else if (ex === 'curious') {
    f.pupil = 1.22;
    f.gazeY = -3.5;
    f.gazeX = 2.5 + Math.sin(t * 0.9) * 1.2;
    f.brows = 'raised';
    f.smile = 0.45;
    f.mouthW = 0.7;
  } else if (ex === 'sleepy') {
    f.eyes = 'half';
    f.smile = 0.35;
    f.mouthW = 0.8;
    f.zzz = 1;
  } else if (ex === 'asleep') {
    f.eyes = 'closed';
    f.smile = 0.3;
    f.mouthW = 0.7;
    f.zzz = 2;
  } else if (ex === 'surprised') {
    f.eyes = 'round';
    f.brows = 'raised';
    f.mouth = 'o';
  } else if (ex === 'focused') {
    f.eyes = 'narrow';
    f.brows = 'determined';
    f.mouth = 'flat';
    f.gazeX = 0;
  } else if (ex === 'strain') {
    f.eyes = 'squeeze';
    f.mouth = 'grit';
    f.sweat = true;
    f.blush = 0.6;
  } else if (ex === 'love') {
    f.eyes = 'heart';
    f.mouth = 'grin';
    f.blush = 0.65;
  } else if (ex === 'proud') {
    f.eyes = 'happy';
    f.smile = 1.05;
    f.mouthW = 1.35;
    f.sparkle = true;
    f.blush = 0.5;
  } else {
    // neutral
    f.smile = 0.45;
  }
  if (f.open < 0.28 && (f.eyes === 'open' || f.eyes === 'round' || f.eyes === 'narrow' || f.eyes === 'half')) {
    f.eyes = 'closed';
  }
  if (poking) {
    f.eyes = 'happy';
    if (f.mouth !== 'bigGrin') {
      f.mouth = 'grin';
    }
    f.zzz = 0;
    f.sweat = false;
  }
  return f;
}

// Draws the scene scaled and centred into a cw x ch canvas. t = seconds (idle motion),
// pokeP = 0..1 progress of the tap reaction (outside that range: no reaction).
export function drawCreatureFit(c: CanvasRenderingContext2D, L: CreatureLook, t: number, pokeP: number,
  cw: number, ch: number): void {
  const s = Math.min(cw / SCENE_W, ch / SCENE_H);
  c.save();
  c.translate((cw - SCENE_W * s) / 2, (ch - SCENE_H * s) / 2);
  c.scale(s, s);
  drawCreature(c, L, t, pokeP);
  c.restore();
}

export function drawCreature(c: CanvasRenderingContext2D, L: CreatureLook, t: number, pokeP: number): void {
  const cx = SCENE_W / 2;
  const p = paletteFor(L.hue);
  const sp = L.species;

  const poking = pokeP >= 0 && pokeP < 1;
  const hop = poking ? -Math.sin(Math.PI * pokeP) * 30 : 0;
  const bob = Math.sin(t * 2.1) * 5 * L.bob + hop;
  const breathe = 1 + Math.sin(t * 1.5) * 0.012 * (0.4 + L.bob);
  const face = faceFor(L, t, poking);

  // ambient glow behind the creature
  const g = c.createRadialGradient(cx, 170, 20, cx, 170, 170);
  g.addColorStop(0, 'rgba(' + p.glowRgb + ', ' + (0.06 + L.glow * 0.16).toFixed(2) + ')');
  g.addColorStop(1, 'rgba(' + p.glowRgb + ', 0)');
  c.fillStyle = g;
  c.beginPath();
  c.arc(cx, 170, 170, 0, Math.PI * 2);
  c.fill();

  // ground shadow (shrinks when the creature bobs up)
  c.fillStyle = 'rgba(0, 0, 0, 0.30)';
  c.beginPath();
  c.ellipse(cx, 296, Math.max(50, 96 + bob * 1.2), Math.max(7, 13 + bob * 0.2), 0, 0, Math.PI * 2);
  c.fill();

  c.save();
  c.translate(0, bob);

  // one shared gradient for head + torso so they read as a single soft body
  const bodyGrad = c.createRadialGradient(cx - 40, 110, 8, cx - 10, 150, 215);
  bodyGrad.addColorStop(0, p.light);
  bodyGrad.addColorStop(0.35, p.mid);
  bodyGrad.addColorStop(0.75, p.base);
  bodyGrad.addColorStop(1, p.dark);

  // features behind the body
  if (sp === 'ember') {
    drawEmberTail(c, p, cx, t);
  } else if (sp === 'mochi') {
    drawMochiEars(c, p, cx, t);
  }

  drawFeet(c, p, cx, L);
  if (sp === 'pip') {
    drawWings(c, p, cx, L, t);
  } else {
    drawArms(c, p, cx, L, t);
  }
  drawTorso(c, bodyGrad, cx, L, breathe);

  // head
  c.fillStyle = bodyGrad;
  c.beginPath();
  c.ellipse(cx, 100, 66, 58, 0, 0, Math.PI * 2);
  c.fill();

  // features on top of the head
  if (sp === 'ember') {
    drawEmberHorns(c, p, cx);
  } else if (sp === 'pip') {
    drawPipCrest(c, p, cx, t);
  } else if (sp === 'nova') {
    drawNovaAntenna(c, p, cx, t, L.glow);
  } else if (sp === 'moss') {
    drawMossSpeckles(c, p, cx);
    drawMossSprout(c, p, cx, t);
  } else if (sp !== 'mochi') {
    drawWispTuft(c, p, cx, t);
  }

  // cheeks
  c.fillStyle = 'rgba(255, 110, 150, ' + face.blush.toFixed(2) + ')';
  c.beginPath();
  c.ellipse(cx - 42, 122, 12, 7.5, 0, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.ellipse(cx + 42, 122, 12, 7.5, 0, 0, Math.PI * 2);
  c.fill();
  if (sp === 'nova') {
    drawFreckles(c, p, cx);
  }

  drawEyes(c, face, cx, bodyGrad);
  drawBrows(c, face, cx);
  if (sp === 'pip') {
    drawBeak(c, p, cx, face);
  } else {
    drawMouth(c, face, cx);
  }
  drawFaceExtras(c, face, cx, t);

  // heart floating up after a tap
  if (poking) {
    drawHeart(c, cx + 64, 30 - pokeP * 46, 9 + pokeP * 4, 'rgba(255, 138, 91, ' + (1 - pokeP).toFixed(2) + ')');
  }

  // sparkles when thriving or proud
  if (L.mood === 'thriving' || L.mood === 'proud') {
    for (let i = 0; i < 3; i++) {
      const a = 0.35 + 0.65 * Math.abs(Math.sin(t * 1.8 + i * 1.7));
      const sx = [cx - 118, cx + 112, cx + 84][i];
      const sy = [90, 72, 214][i];
      drawSparkle(c, sx, sy, 7 + i * 1.5, 'rgba(255, 244, 190, ' + a.toFixed(2) + ')');
    }
  }
  c.restore();
}

// ---- body ----------------------------------------------------------------------------------

function drawFeet(c: CanvasRenderingContext2D, p: Palette, cx: number, L: CreatureLook): void {
  const fw = 31 * L.legs;
  const fh = 21 * L.legs;
  c.fillStyle = p.deeper;
  c.beginPath();
  c.ellipse(cx - 44, 281, fw, fh, -0.12, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.ellipse(cx + 44, 281, fw, fh, 0.12, 0, Math.PI * 2);
  c.fill();
  c.fillStyle = 'rgba(255, 255, 255, 0.14)';
  c.beginPath();
  c.ellipse(cx - 48, 275, fw * 0.55, fh * 0.35, -0.12, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.ellipse(cx + 40, 275, fw * 0.55, fh * 0.35, 0.12, 0, Math.PI * 2);
  c.fill();
}

// arms (flippers) behind the torso: size follows the "pull" level, shoulders follow "push"
function drawArms(c: CanvasRenderingContext2D, p: Palette, cx: number, L: CreatureLook, t: number): void {
  const armX = 74 * L.push;
  const armRx = 17 * L.pull;
  const armRy = 44 * L.pull;
  const wave = Math.sin(t * 2.1) * 0.1 * L.bob;
  c.fillStyle = p.dark;
  c.beginPath();
  c.ellipse(cx - armX, 176, armRx, armRy, 0.42 + wave, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.ellipse(cx + armX, 176, armRx, armRy, -0.42 - wave, 0, Math.PI * 2);
  c.fill();
  c.fillStyle = 'rgba(255, 255, 255, 0.12)';
  c.beginPath();
  c.ellipse(cx - armX - 4, 168, armRx * 0.4, armRy * 0.55, 0.42 + wave, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.ellipse(cx + armX - 4, 168, armRx * 0.4, armRy * 0.55, -0.42 - wave, 0, Math.PI * 2);
  c.fill();
}

// torso: pear-shaped, widens with the "core" level, shoulders with "push"; belly patch on top
function drawTorso(c: CanvasRenderingContext2D, bodyGrad: CanvasGradient, cx: number, L: CreatureLook,
  breathe: number): void {
  const tw = 88 * L.core * breathe;
  const sw = 58 * L.push;
  c.fillStyle = bodyGrad;
  c.beginPath();
  c.moveTo(cx, 112);
  c.bezierCurveTo(cx + sw, 112, cx + tw * 1.05, 158, cx + tw, 212);
  c.bezierCurveTo(cx + tw * 0.96, 262, cx + 52, 290, cx, 290);
  c.bezierCurveTo(cx - 52, 290, cx - tw * 0.96, 262, cx - tw, 212);
  c.bezierCurveTo(cx - tw * 1.05, 158, cx - sw, 112, cx, 112);
  c.closePath();
  c.fill();

  const bg = c.createRadialGradient(cx, 214, 4, cx, 214, 54 * L.core);
  bg.addColorStop(0, 'rgba(255, 255, 255, 0.62)');
  bg.addColorStop(1, 'rgba(255, 255, 255, 0.14)');
  c.fillStyle = bg;
  c.beginPath();
  c.ellipse(cx, 216, 41 * L.core, 49 * L.core, 0, 0, Math.PI * 2);
  c.fill();
}

// ---- species features ----------------------------------------------------------------------

// wisp: glowing flame tuft, swaying gently
function drawWispTuft(c: CanvasRenderingContext2D, p: Palette, cx: number, t: number): void {
  c.save();
  c.translate(cx, 50);
  c.rotate(Math.sin(t * 1.7) * 0.09);
  const tg = c.createLinearGradient(0, -44, 0, 6);
  tg.addColorStop(0, hslToHex(hue(p.hue + 40), 95, 82));
  tg.addColorStop(1, p.mid);
  c.fillStyle = tg;
  c.beginPath();
  c.moveTo(-11, 6);
  c.bezierCurveTo(-26, -12, -4, -22, 3, -46);
  c.bezierCurveTo(8, -26, 28, -14, 11, 6);
  c.closePath();
  c.fill();
  c.restore();
}

// mochi: two long soft bunny ears behind the head, one slightly floppier
function drawMochiEars(c: CanvasRenderingContext2D, p: Palette, cx: number, t: number): void {
  const inner = hslToHex(hue(p.hue + 8), 90, 86);
  const sway = Math.sin(t * 1.6) * 0.05;
  for (let side = -1; side <= 1; side += 2) {
    c.save();
    c.translate(cx + side * 30, 66);
    c.rotate(side * (side < 0 ? 0.3 : 0.42) + sway);
    c.fillStyle = p.mid;
    c.beginPath();
    c.moveTo(-13, 6);
    c.bezierCurveTo(-26, -34, -16, -74, 0, -74);
    c.bezierCurveTo(16, -74, 26, -34, 13, 6);
    c.closePath();
    c.fill();
    c.fillStyle = inner;
    c.beginPath();
    c.moveTo(-6, 0);
    c.bezierCurveTo(-14, -30, -9, -62, 0, -62);
    c.bezierCurveTo(9, -62, 14, -30, 6, 0);
    c.closePath();
    c.fill();
    c.restore();
  }
}

// ember: two small curved horns
function drawEmberHorns(c: CanvasRenderingContext2D, p: Palette, cx: number): void {
  const horn = hslToHex(hue(p.hue + 32), 80, 90);
  const shade = hslToHex(hue(p.hue + 20), 55, 72);
  for (let side = -1; side <= 1; side += 2) {
    const bx = cx + side * 30;
    c.fillStyle = horn;
    c.beginPath();
    c.moveTo(bx - 12, 58);
    c.quadraticCurveTo(bx - side * 3, 32, bx + side * 12, 17);
    c.quadraticCurveTo(bx + side * 10, 40, bx + 12, 58);
    c.closePath();
    c.fill();
    c.fillStyle = shade;
    c.beginPath();
    c.ellipse(bx + side * 1, 56, 11, 4, side * 0.2, 0, Math.PI * 2);
    c.fill();
  }
}

// ember: a little curled tail with a flickering flame tip
function drawEmberTail(c: CanvasRenderingContext2D, p: Palette, cx: number, t: number): void {
  const sway = Math.sin(t * 2.4) * 4;
  c.strokeStyle = p.dark;
  c.lineWidth = 11;
  c.lineCap = 'round';
  c.beginPath();
  c.moveTo(cx + 50, 266);
  c.quadraticCurveTo(cx + 122, 282, cx + 116 + sway * 0.4, 226);
  c.stroke();
  const fx = cx + 116 + sway * 0.4;
  const fy = 222;
  c.save();
  c.translate(fx, fy);
  c.rotate(Math.sin(t * 3.1) * 0.12);
  c.fillStyle = hslToHex(hue(p.hue + 22), 96, 58);
  c.beginPath();
  c.moveTo(-12, 4);
  c.bezierCurveTo(-18, -12, -4, -16, 1, -34);
  c.bezierCurveTo(6, -18, 20, -10, 12, 4);
  c.quadraticCurveTo(0, 12, -12, 4);
  c.closePath();
  c.fill();
  c.fillStyle = hslToHex(hue(p.hue + 48), 100, 80);
  c.beginPath();
  c.moveTo(-6, 3);
  c.bezierCurveTo(-9, -6, -1, -10, 1, -20);
  c.bezierCurveTo(4, -10, 10, -6, 6, 3);
  c.quadraticCurveTo(0, 7, -6, 3);
  c.closePath();
  c.fill();
  c.restore();
}

// pip: a fan of three crest feathers
function drawPipCrest(c: CanvasRenderingContext2D, p: Palette, cx: number, t: number): void {
  const col = hslToHex(hue(p.hue - 16), 88, 56);
  const sway = Math.sin(t * 1.9) * 0.06;
  const angles: number[] = [-0.42, 0, 0.42];
  const lens: number[] = [24, 32, 24];
  for (let i = 0; i < 3; i++) {
    c.save();
    c.translate(cx + (i - 1) * 6, 48);
    c.rotate(angles[i] + sway);
    const len = lens[i];
    c.fillStyle = col;
    c.beginPath();
    c.moveTo(-6, 4);
    c.bezierCurveTo(-10, -len * 0.5, -3, -len, 2, -len);
    c.bezierCurveTo(6, -len * 0.7, 8, -len * 0.3, 6, 4);
    c.closePath();
    c.fill();
    c.restore();
  }
}

// pip: wing-shaped arms with scalloped feather tips
function drawWings(c: CanvasRenderingContext2D, p: Palette, cx: number, L: CreatureLook, t: number): void {
  const armX = 74 * L.push;
  const rx = 19 * L.pull;
  const ry = 44 * L.pull;
  const wave = Math.sin(t * 2.1) * 0.14 * L.bob;
  for (let side = -1; side <= 1; side += 2) {
    c.save();
    c.translate(cx + side * armX, 172);
    c.rotate(-side * (0.5 + wave));
    c.fillStyle = p.dark;
    c.beginPath();
    c.moveTo(0, -ry);
    c.bezierCurveTo(rx * 1.3, -ry, rx * 1.2, ry * 0.4, rx, ry * 0.72);
    c.quadraticCurveTo(rx * 0.75, ry * 1.02, rx * 0.33, ry * 0.8);
    c.quadraticCurveTo(0, ry * 1.12, -rx * 0.33, ry * 0.8);
    c.quadraticCurveTo(-rx * 0.75, ry * 1.02, -rx, ry * 0.72);
    c.bezierCurveTo(-rx * 1.2, ry * 0.4, -rx * 1.3, -ry, 0, -ry);
    c.closePath();
    c.fill();
    c.fillStyle = 'rgba(255, 255, 255, 0.13)';
    c.beginPath();
    c.ellipse(-rx * 0.25, -ry * 0.15, rx * 0.4, ry * 0.5, 0, 0, Math.PI * 2);
    c.fill();
    c.restore();
  }
}

// pip: a small beak in place of the mouth; opens for open-mouthed faces
function drawBeak(c: CanvasRenderingContext2D, p: Palette, cx: number, f: Face): void {
  const top = hslToHex(hue(p.hue - 18), 95, 60);
  const low = hslToHex(hue(p.hue - 24), 85, 50);
  const opened = f.mouth === 'grin' || f.mouth === 'bigGrin' || f.mouth === 'o' || f.mouth === 'grit';
  const y = 114;
  if (opened) {
    const gap = f.mouth === 'bigGrin' ? 9 : (f.mouth === 'grit' ? 3 : 6);
    c.fillStyle = MOUTH_IN;
    c.beginPath();
    c.ellipse(cx, y + 6 + gap * 0.5, 9, 4 + gap * 0.6, 0, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = low;
    c.beginPath();
    c.moveTo(cx - 10, y + 5 + gap);
    c.quadraticCurveTo(cx, y + 9 + gap, cx + 10, y + 5 + gap);
    c.quadraticCurveTo(cx + 2, y + 15 + gap, cx, y + 15 + gap);
    c.quadraticCurveTo(cx - 2, y + 15 + gap, cx - 10, y + 5 + gap);
    c.closePath();
    c.fill();
  } else {
    c.fillStyle = low;
    c.beginPath();
    c.moveTo(cx - 11, y + 4);
    c.quadraticCurveTo(cx, y + 8, cx + 11, y + 4);
    c.quadraticCurveTo(cx + 2, y + 14, cx, y + 14);
    c.quadraticCurveTo(cx - 2, y + 14, cx - 11, y + 4);
    c.closePath();
    c.fill();
  }
  c.fillStyle = top;
  c.beginPath();
  c.moveTo(cx - 13, y + 4);
  c.quadraticCurveTo(cx - 4, y - 7, cx, y - 7);
  c.quadraticCurveTo(cx + 4, y - 7, cx + 13, y + 4);
  c.quadraticCurveTo(cx, y + 9, cx - 13, y + 4);
  c.closePath();
  c.fill();
  c.fillStyle = 'rgba(255, 255, 255, 0.45)';
  c.beginPath();
  c.ellipse(cx - 3, y - 2, 4, 1.8, -0.3, 0, Math.PI * 2);
  c.fill();
}

// nova: a springy antenna topped with a glowing star
function drawNovaAntenna(c: CanvasRenderingContext2D, p: Palette, cx: number, t: number, glow: number): void {
  const sway = Math.sin(t * 1.8) * 4;
  const tx = cx + 20 + sway;
  const ty = 12;
  c.strokeStyle = p.dark;
  c.lineWidth = 4;
  c.lineCap = 'round';
  c.beginPath();
  c.moveTo(cx + 4, 46);
  c.quadraticCurveTo(cx + 2, 24, tx, ty + 6);
  c.stroke();
  const halo = c.createRadialGradient(tx, ty, 4, tx, ty, 24);
  halo.addColorStop(0, 'rgba(255, 240, 170, ' + (0.35 + glow * 0.4).toFixed(2) + ')');
  halo.addColorStop(1, 'rgba(255, 240, 170, 0)');
  c.fillStyle = halo;
  c.beginPath();
  c.arc(tx, ty, 24, 0, Math.PI * 2);
  c.fill();
  c.save();
  c.translate(tx, ty);
  c.rotate(Math.sin(t * 1.2) * 0.2);
  c.fillStyle = '#FFE98A';
  c.beginPath();
  for (let i = 0; i < 10; i++) {
    const r = i % 2 === 0 ? 13 : 5.6;
    const a = -Math.PI / 2 + i * Math.PI / 5;
    if (i === 0) {
      c.moveTo(Math.cos(a) * r, Math.sin(a) * r);
    } else {
      c.lineTo(Math.cos(a) * r, Math.sin(a) * r);
    }
  }
  c.closePath();
  c.fill();
  c.fillStyle = '#FFFBE6';
  c.beginPath();
  c.arc(-1.5, -1.5, 3, 0, Math.PI * 2);
  c.fill();
  c.restore();
}

// nova: freckles across the cheeks
function drawFreckles(c: CanvasRenderingContext2D, p: Palette, cx: number): void {
  c.fillStyle = 'rgba(' + hexToRgb(p.deeper) + ', 0.6)';
  const dx: number[] = [-6, 1, 7];
  const dy: number[] = [-2, 3, -3];
  for (let side = -1; side <= 1; side += 2) {
    for (let i = 0; i < 3; i++) {
      c.beginPath();
      c.arc(cx + side * (42 + dx[i]), 120 + dy[i], 1.9, 0, Math.PI * 2);
      c.fill();
    }
  }
}

// moss: a two-leaf sprout on top of the head
function drawMossSprout(c: CanvasRenderingContext2D, p: Palette, cx: number, t: number): void {
  const leaf = hslToHex(hue(p.hue - 28), 70, 46);
  const leaf2 = hslToHex(hue(p.hue - 20), 66, 56);
  const vein = hslToHex(hue(p.hue - 30), 80, 78);
  c.save();
  c.translate(cx, 46);
  c.rotate(Math.sin(t * 1.5) * 0.08);
  c.strokeStyle = p.deeper;
  c.lineWidth = 4;
  c.lineCap = 'round';
  c.beginPath();
  c.moveTo(0, 4);
  c.quadraticCurveTo(-3, -10, 2, -18);
  c.stroke();
  for (let side = -1; side <= 1; side += 2) {
    c.save();
    c.translate(2, -18);
    c.rotate(side * 1.0 - 0.08);
    const len: number = side < 0 ? 32 : 36;
    c.fillStyle = side < 0 ? leaf2 : leaf;
    c.beginPath();
    c.moveTo(0, 0);
    c.bezierCurveTo(-15, -len * 0.3, -9, -len * 0.85, 0, -len);
    c.bezierCurveTo(9, -len * 0.85, 15, -len * 0.3, 0, 0);
    c.closePath();
    c.fill();
    c.strokeStyle = vein;
    c.lineWidth = 1.6;
    c.beginPath();
    c.moveTo(0, -2);
    c.lineTo(0, -len * 0.78);
    c.stroke();
    c.restore();
  }
  c.restore();
}

// moss: soft mossy speckles on head and body
function drawMossSpeckles(c: CanvasRenderingContext2D, p: Palette, cx: number): void {
  const xs: number[] = [-44, 40, -22, 50, -64, 66, 58, -54, 30];
  const ys: number[] = [70, 66, 54, 92, 196, 226, 178, 250, 262];
  const rs: number[] = [5, 4, 3.2, 3, 6, 5, 3.5, 4, 3];
  c.fillStyle = 'rgba(' + hexToRgb(hslToHex(hue(p.hue + 15), 50, 34)) + ', 0.32)';
  for (let i = 0; i < xs.length; i++) {
    c.beginPath();
    c.arc(cx + xs[i], ys[i], rs[i], 0, Math.PI * 2);
    c.fill();
  }
  c.fillStyle = 'rgba(' + hexToRgb(hslToHex(hue(p.hue - 25), 80, 80)) + ', 0.45)';
  for (let i = 0; i < xs.length; i += 2) {
    c.beginPath();
    c.arc(cx + xs[i] + 2.5, ys[i] + 5, rs[i] * 0.5, 0, Math.PI * 2);
    c.fill();
  }
}

// ---- face ----------------------------------------------------------------------------------

function drawEyes(c: CanvasRenderingContext2D, f: Face, cx: number, bodyGrad: CanvasGradient): void {
  for (let side = -1; side <= 1; side += 2) {
    const ex = cx + side * 25;
    if (f.eyes === 'happy') {
      inkStroke(c, 4);
      c.beginPath();
      c.moveTo(ex - 11, EYE_Y + 4);
      c.quadraticCurveTo(ex, EYE_Y - 10, ex + 11, EYE_Y + 4);
      c.stroke();
    } else if (f.eyes === 'closed') {
      inkStroke(c, 3.6);
      c.beginPath();
      c.moveTo(ex - 11, EYE_Y + 1);
      c.quadraticCurveTo(ex, EYE_Y + 8, ex + 11, EYE_Y + 1);
      c.stroke();
    } else if (f.eyes === 'squeeze') {
      inkStroke(c, 4);
      c.lineJoin = 'round';
      c.beginPath();
      c.moveTo(ex + side * 9, EYE_Y - 8);
      c.lineTo(ex - side * 8, EYE_Y);
      c.lineTo(ex + side * 9, EYE_Y + 8);
      c.stroke();
    } else if (f.eyes === 'heart') {
      drawHeart(c, ex, EYE_Y + 1, 12.5, '#FF4F7B');
      c.fillStyle = 'rgba(255, 255, 255, 0.85)';
      c.beginPath();
      c.ellipse(ex - 6, EYE_Y - 4, 3, 2, -0.6, 0, Math.PI * 2);
      c.fill();
    } else if (f.eyes === 'round') {
      c.fillStyle = '#FFFFFF';
      c.beginPath();
      c.arc(ex, EYE_Y - 1, 16, 0, Math.PI * 2);
      c.fill();
      c.fillStyle = INK;
      c.beginPath();
      c.arc(ex, EYE_Y, 7, 0, Math.PI * 2);
      c.fill();
      c.fillStyle = '#FFFFFF';
      c.beginPath();
      c.arc(ex - 2.4, EYE_Y - 2.6, 2.4, 0, Math.PI * 2);
      c.fill();
    } else if (f.eyes === 'narrow') {
      drawOpenEye(c, f, ex, 1);
      drawLid(c, bodyGrad, ex, EYE_Y - 8, 0);
    } else if (f.eyes === 'half') {
      drawHalfEye(c, ex);
    } else {
      drawOpenEye(c, f, ex, f.open);
    }
  }
}

function drawOpenEye(c: CanvasRenderingContext2D, f: Face, ex: number, open: number): void {
  const eh = 17 * open;
  const px = ex + f.gazeX;
  const py = EYE_Y + 2 + f.gazeY;
  c.fillStyle = '#FFFFFF';
  c.beginPath();
  c.ellipse(ex, EYE_Y, 15.5, eh, 0, 0, Math.PI * 2);
  c.fill();
  c.fillStyle = INK;
  c.beginPath();
  c.ellipse(px, py, 10 * f.pupil, Math.min(12 * f.pupil, eh * 0.78), 0, 0, Math.PI * 2);
  c.fill();
  c.fillStyle = '#FFFFFF';
  c.beginPath();
  c.arc(px - 3.5 * f.pupil, py - 5, 3.4 * f.pupil, 0, Math.PI * 2);
  c.fill();
  c.beginPath();
  c.arc(px + 3.5, py + 4, 1.7, 0, Math.PI * 2);
  c.fill();
}

// sleepy: heavy level lid with only the lower half of the eye showing
function drawHalfEye(c: CanvasRenderingContext2D, ex: number): void {
  const y = EYE_Y + 1;
  c.fillStyle = '#FFFFFF';
  c.beginPath();
  c.ellipse(ex, y, 14.5, 11, 0, 0, Math.PI);
  c.closePath();
  c.fill();
  c.fillStyle = INK;
  c.beginPath();
  c.ellipse(ex, y, 9, 8.5, 0, 0, Math.PI);
  c.closePath();
  c.fill();
  c.fillStyle = '#FFFFFF';
  c.beginPath();
  c.arc(ex - 3, y + 3.2, 1.9, 0, Math.PI * 2);
  c.fill();
  inkStroke(c, 3.6);
  c.beginPath();
  c.moveTo(ex - 15.5, y);
  c.quadraticCurveTo(ex, y - 1.5, ex + 15.5, y);
  c.stroke();
}

// Covers the top of an eye with skin (the body gradient lines up exactly) and draws the lid
// edge; droop bends the edge (negative = arched up in the middle).
function drawLid(c: CanvasRenderingContext2D, bodyGrad: CanvasGradient, ex: number, lidY: number,
  droop: number): void {
  c.fillStyle = bodyGrad;
  c.beginPath();
  c.moveTo(ex - 19, lidY);
  c.quadraticCurveTo(ex, lidY + droop * 2, ex + 19, lidY);
  c.lineTo(ex + 19, EYE_Y - 20);
  c.lineTo(ex - 19, EYE_Y - 20);
  c.closePath();
  c.fill();
  const dy = lidY - EYE_Y;
  const hw = 15.5 * Math.sqrt(Math.max(0, 1 - (dy * dy) / (17 * 17))) + 0.5;
  inkStroke(c, 3.4);
  c.beginPath();
  c.moveTo(ex - hw, lidY);
  c.quadraticCurveTo(ex, lidY + droop * 2, ex + hw, lidY);
  c.stroke();
}

function drawBrows(c: CanvasRenderingContext2D, f: Face, cx: number): void {
  if (f.brows === 'none') {
    return;
  }
  c.strokeStyle = 'rgba(29, 26, 58, 0.8)';
  c.lineWidth = 3.4;
  c.lineCap = 'round';
  for (let side = -1; side <= 1; side += 2) {
    const ex = cx + side * 25;
    c.beginPath();
    if (f.brows === 'raised') {
      c.moveTo(ex - 9, EYE_Y - 24);
      c.quadraticCurveTo(ex, EYE_Y - 31, ex + 9, EYE_Y - 24);
    } else {
      // determined: short, level and gently arched (never tilted into a frown)
      c.moveTo(ex - 10, EYE_Y - 20);
      c.quadraticCurveTo(ex, EYE_Y - 23, ex + 10, EYE_Y - 20);
    }
    c.stroke();
  }
}

function drawMouth(c: CanvasRenderingContext2D, f: Face, cx: number): void {
  const y = MOUTH_Y;
  if (f.mouth === 'grin') {
    c.fillStyle = MOUTH_IN;
    c.beginPath();
    c.moveTo(cx - 14, y);
    c.quadraticCurveTo(cx, y + 24, cx + 14, y);
    c.quadraticCurveTo(cx, y + 3, cx - 14, y);
    c.closePath();
    c.fill();
    c.fillStyle = TONGUE;
    c.beginPath();
    c.ellipse(cx, y + 9, 6, 3.6, 0, 0, Math.PI * 2);
    c.fill();
  } else if (f.mouth === 'bigGrin') {
    c.fillStyle = MOUTH_IN;
    c.beginPath();
    c.moveTo(cx - 19, y - 2);
    c.bezierCurveTo(cx - 17, y + 26, cx + 17, y + 26, cx + 19, y - 2);
    c.quadraticCurveTo(cx, y + 3, cx - 19, y - 2);
    c.closePath();
    c.fill();
    c.fillStyle = TONGUE;
    c.beginPath();
    c.ellipse(cx, y + 13, 9, 5, 0, 0, Math.PI * 2);
    c.fill();
  } else if (f.mouth === 'o') {
    c.fillStyle = MOUTH_IN;
    c.beginPath();
    c.ellipse(cx, y + 5, 6.5, 8, 0, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = TONGUE;
    c.beginPath();
    c.ellipse(cx, y + 9, 3.6, 2.4, 0, 0, Math.PI * 2);
    c.fill();
  } else if (f.mouth === 'flat') {
    inkStroke(c, 3.4);
    c.beginPath();
    c.moveTo(cx - 8, y + 2);
    c.quadraticCurveTo(cx, y + 5, cx + 8, y + 2);
    c.stroke();
  } else if (f.mouth === 'grit') {
    // effortful toothy grin: corners up, so it reads as pushing hard, not as anger
    c.fillStyle = '#FFFFFF';
    c.beginPath();
    c.moveTo(cx - 16, y - 2);
    c.quadraticCurveTo(cx, y + 3, cx + 16, y - 2);
    c.quadraticCurveTo(cx + 14, y + 13, cx, y + 13);
    c.quadraticCurveTo(cx - 14, y + 13, cx - 16, y - 2);
    c.closePath();
    c.fill();
    inkStroke(c, 2.6);
    c.lineJoin = 'round';
    c.stroke();
    c.lineWidth = 1.8;
    c.beginPath();
    c.moveTo(cx - 14, y + 5);
    c.quadraticCurveTo(cx, y + 8, cx + 14, y + 5);
    c.moveTo(cx - 6, y + 1);
    c.lineTo(cx - 6, y + 12);
    c.moveTo(cx + 6, y + 1);
    c.lineTo(cx + 6, y + 12);
    c.stroke();
  } else {
    const w = 11 * f.mouthW;
    inkStroke(c, 3.4);
    c.beginPath();
    c.moveTo(cx - w, y);
    c.quadraticCurveTo(cx, y + 15 * f.smile, cx + w, y);
    c.stroke();
  }
}

function drawFaceExtras(c: CanvasRenderingContext2D, f: Face, cx: number, t: number): void {
  if (f.sweat) {
    const sx = cx + 60;
    const sy = 62 + (t * 18) % 10;
    c.fillStyle = '#A8DBFF';
    c.beginPath();
    c.moveTo(sx, sy - 13);
    c.bezierCurveTo(sx + 3, sy - 6, sx + 8, sy - 2, sx + 8, sy + 3);
    c.bezierCurveTo(sx + 8, sy + 8, sx + 4, sy + 11, sx, sy + 11);
    c.bezierCurveTo(sx - 4, sy + 11, sx - 8, sy + 8, sx - 8, sy + 3);
    c.bezierCurveTo(sx - 8, sy - 2, sx - 3, sy - 6, sx, sy - 13);
    c.closePath();
    c.fill();
    c.fillStyle = 'rgba(255, 255, 255, 0.85)';
    c.beginPath();
    c.ellipse(sx - 3, sy + 3, 1.8, 3, 0.3, 0, Math.PI * 2);
    c.fill();
  }
  if (f.sparkle) {
    const a = 0.65 + 0.35 * Math.abs(Math.sin(t * 2.2));
    drawSparkle(c, cx + 74, 56, 11, 'rgba(255, 244, 190, ' + a.toFixed(2) + ')');
    drawSparkle(c, cx + 92, 82, 6, 'rgba(255, 244, 190, ' + (a * 0.8).toFixed(2) + ')');
  }
  if (f.zzz > 0) {
    c.fillStyle = 'rgba(244, 245, 255, 0.9)';
    c.font = '700 24px sans-serif';
    c.fillText('z', cx + 70, 56 + Math.sin(t * 1.5) * 4);
    if (f.zzz > 1) {
      c.font = '700 17px sans-serif';
      c.fillText('z', cx + 92, 36 + Math.sin(t * 1.5 + 1) * 4);
    }
  }
}

// ---- shared primitives ---------------------------------------------------------------------

function inkStroke(c: CanvasRenderingContext2D, w: number): void {
  c.strokeStyle = INK;
  c.lineWidth = w;
  c.lineCap = 'round';
}

function drawHeart(c: CanvasRenderingContext2D, hx: number, hy: number, hs: number, fill: string): void {
  c.fillStyle = fill;
  c.beginPath();
  c.moveTo(hx, hy + hs * 0.9);
  c.bezierCurveTo(hx - hs * 1.6, hy - hs * 0.2, hx - hs * 0.7, hy - hs * 1.3, hx, hy - hs * 0.45);
  c.bezierCurveTo(hx + hs * 0.7, hy - hs * 1.3, hx + hs * 1.6, hy - hs * 0.2, hx, hy + hs * 0.9);
  c.closePath();
  c.fill();
}

function drawSparkle(c: CanvasRenderingContext2D, sx: number, sy: number, r: number, fill: string): void {
  c.fillStyle = fill;
  c.beginPath();
  c.moveTo(sx, sy - r);
  c.quadraticCurveTo(sx, sy, sx + r, sy);
  c.quadraticCurveTo(sx, sy, sx, sy + r);
  c.quadraticCurveTo(sx, sy, sx - r, sy);
  c.quadraticCurveTo(sx, sy, sx, sy - r);
  c.closePath();
  c.fill();
}
