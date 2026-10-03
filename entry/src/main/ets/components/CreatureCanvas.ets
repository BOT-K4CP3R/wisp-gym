import { hilog } from '@kit.PerformanceAnalysisKit';
import { CreatureLook } from '../core/CreatureLook';
import { AppModel, hslToHex } from '../app/AppModel';
import { LookHolder } from './LookHolder';

function hexToRgb(hex: string): string {
  const r = parseInt(hex.substring(1, 3), 16);
  const g = parseInt(hex.substring(3, 5), 16);
  const b = parseInt(hex.substring(5, 7), 16);
  return r + ', ' + g + ', ' + b;
}

// Procedural plush creature drawn with smooth curves and soft shading on a Canvas.
// Every proportion, the colour and the mood come from CreatureLook, i.e. from the user's
// real training state. Colours use #RRGGBB / rgba(): hsl() strings render nothing on this
// runtime.
@Component
export struct CreatureCanvas {
  holder: LookHolder = new LookHolder();
  @Prop label: string = '';
  @Prop canvasHeight: number = 300;
  @Prop tappable: boolean = false;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private startedAt: number = Date.now();
  private w: number = 340;
  private h: number = 320;
  private cw: number = 340;
  private ch: number = 320;
  private cur: CreatureLook = new CreatureLook();

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (!this.holder.active) {
        return; // hidden page: skip the frame entirely
      }
      try {
        this.draw();
      } catch (e) {
        hilog.error(0x00F0, 'WispCanvas', 'draw failed: %{public}s', JSON.stringify(e));
      }
    }, 40);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  // Morphs the drawn look towards the target so mood and size changes animate smoothly.
  private follow(): void {
    const T = this.holder.look;
    const C = this.cur;
    if (this.holder.snap) {
      this.holder.snap = false;
      C.legs = T.legs; C.push = T.push; C.pull = T.pull; C.core = T.core;
      C.hue = T.hue; C.glow = T.glow; C.eyeOpen = T.eyeOpen; C.smile = T.smile; C.bob = T.bob;
    } else {
      const k = 0.1;
      C.legs += (T.legs - C.legs) * k;
      C.push += (T.push - C.push) * k;
      C.pull += (T.pull - C.pull) * k;
      C.core += (T.core - C.core) * k;
      C.hue += (T.hue - C.hue) * k;
      C.glow += (T.glow - C.glow) * k;
      C.eyeOpen += (T.eyeOpen - C.eyeOpen) * k;
      C.smile += (T.smile - C.smile) * k;
      C.bob += (T.bob - C.bob) * k;
    }
    C.mood = T.mood;
    C.happyEyes = T.happyEyes;
  }

  // The scene is authored in a 340x320 box and scaled to whatever size the component gets.
  private draw(): void {
    const c = this.ctx;
    // The context knows its real size; onAreaChange is not delivered reliably everywhere.
    if (c.width > 0 && c.height > 0) {
      this.cw = c.width;
      this.ch = c.height;
    }
    c.clearRect(0, 0, this.cw, this.ch);
    const s = Math.min(this.cw / this.w, this.ch / this.h);
    c.save();
    c.translate((this.cw - this.w * s) / 2, (this.ch - this.h * s) / 2);
    c.scale(s, s);
    this.follow();
    this.drawScene(c, this.cur, (Date.now() - this.startedAt) / 1000);
    c.restore();
  }

  private drawScene(c: CanvasRenderingContext2D, L: CreatureLook, t: number): void {
    const cx = this.w / 2;

    const base = hslToHex(L.hue, 72, 62);
    const light = hslToHex((L.hue + 10) % 360, 86, 80);
    const mid = hslToHex(L.hue, 76, 68);
    const dark = hslToHex((L.hue + 350) % 360, 62, 42);
    const deeper = hslToHex((L.hue + 350) % 360, 60, 34);
    const glowRgb = hexToRgb(hslToHex(L.hue, 90, 66));

    const pokeP = (Date.now() - this.holder.pokedAt) / 900;
    const poking = pokeP >= 0 && pokeP < 1;
    const hop = poking ? -Math.sin(Math.PI * pokeP) * 30 : 0;
    const bob = Math.sin(t * 2.1) * 5 * L.bob + hop;
    const breathe = 1 + Math.sin(t * 1.5) * 0.012 * (0.4 + L.bob);
    const blinkPhase = t % 4.4;
    const blink = blinkPhase > 4.22 ? 0.1 : 1;

    // ambient glow behind the creature
    const g = c.createRadialGradient(cx, 170, 20, cx, 170, 170);
    g.addColorStop(0, 'rgba(' + glowRgb + ', ' + (0.06 + L.glow * 0.16).toFixed(2) + ')');
    g.addColorStop(1, 'rgba(' + glowRgb + ', 0)');
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
    bodyGrad.addColorStop(0, light);
    bodyGrad.addColorStop(0.35, mid);
    bodyGrad.addColorStop(0.75, base);
    bodyGrad.addColorStop(1, dark);

    // feet
    const fw = 31 * L.legs;
    const fh = 21 * L.legs;
    c.fillStyle = deeper;
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

    // arms (flippers) behind the torso: size follows the "pull" level, shoulders follow "push"
    const armX = 74 * L.push;
    const armRx = 17 * L.pull;
    const armRy = 44 * L.pull;
    const wave = Math.sin(t * 2.1) * 0.1 * L.bob;
    c.fillStyle = dark;
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

    // torso: pear-shaped, widens with the "core" level, shoulders with "push"
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

    // belly patch
    const bg = c.createRadialGradient(cx, 214, 4, cx, 214, 54 * L.core);
    bg.addColorStop(0, 'rgba(255, 255, 255, 0.62)');
    bg.addColorStop(1, 'rgba(255, 255, 255, 0.14)');
    c.fillStyle = bg;
    c.beginPath();
    c.ellipse(cx, 216, 41 * L.core, 49 * L.core, 0, 0, Math.PI * 2);
    c.fill();

    // head
    c.fillStyle = bodyGrad;
    c.beginPath();
    c.ellipse(cx, 100, 66, 58, 0, 0, Math.PI * 2);
    c.fill();

    // glowing tuft (the "wisp"), swaying gently; brightness follows recovery
    c.save();
    c.translate(cx, 50);
    c.rotate(Math.sin(t * 1.7) * 0.09);
    const tg = c.createLinearGradient(0, -44, 0, 6);
    tg.addColorStop(0, hslToHex((L.hue + 40) % 360, 95, 82));
    tg.addColorStop(1, mid);
    c.fillStyle = tg;
    c.beginPath();
    c.moveTo(-11, 6);
    c.bezierCurveTo(-26, -12, -4, -22, 3, -46);
    c.bezierCurveTo(8, -26, 28, -14, 11, 6);
    c.closePath();
    c.fill();
    c.restore();

    // cheeks
    c.fillStyle = 'rgba(255, 110, 150, 0.42)';
    c.beginPath();
    c.ellipse(cx - 42, 122, 12, 7.5, 0, 0, Math.PI * 2);
    c.fill();
    c.beginPath();
    c.ellipse(cx + 42, 122, 12, 7.5, 0, 0, Math.PI * 2);
    c.fill();

    // eyes
    const open = Math.min(L.eyeOpen, blink);
    const gaze = Math.sin(t * 0.7) * 2.2;
    for (let side = -1; side <= 1; side += 2) {
      const ex = cx + side * 25;
      if (L.happyEyes || poking) {
        // joyful closed eyes: upturned arcs
        c.strokeStyle = '#1D1A3A';
        c.lineWidth = 4;
        c.lineCap = 'round';
        c.beginPath();
        c.moveTo(ex - 11, 102);
        c.quadraticCurveTo(ex, 88, ex + 11, 102);
        c.stroke();
      } else if (open > 0.28) {
        const eh = 17 * open;
        c.fillStyle = '#FFFFFF';
        c.beginPath();
        c.ellipse(ex, 98, 15.5, eh, 0, 0, Math.PI * 2);
        c.fill();
        c.fillStyle = '#1D1A3A';
        c.beginPath();
        c.ellipse(ex + gaze, 100, 10, Math.min(12, eh * 0.78), 0, 0, Math.PI * 2);
        c.fill();
        c.fillStyle = '#FFFFFF';
        c.beginPath();
        c.arc(ex + gaze - 3.5, 95, 3.4, 0, Math.PI * 2);
        c.fill();
        c.beginPath();
        c.arc(ex + gaze + 3.5, 104, 1.7, 0, Math.PI * 2);
        c.fill();
      } else {
        // closed eye: a soft downward arc
        c.strokeStyle = '#1D1A3A';
        c.lineWidth = 3.6;
        c.lineCap = 'round';
        c.beginPath();
        c.moveTo(ex - 11, 99);
        c.quadraticCurveTo(ex, 106, ex + 11, 99);
        c.stroke();
      }
    }

    // mouth: always a smile; opens up when thriving
    c.strokeStyle = '#1D1A3A';
    c.lineWidth = 3.4;
    c.lineCap = 'round';
    if (L.smile > 0.9 || poking) {
      c.fillStyle = '#7A2342';
      c.beginPath();
      c.moveTo(cx - 14, 121);
      c.quadraticCurveTo(cx, 121 + 24, cx + 14, 121);
      c.quadraticCurveTo(cx, 124, cx - 14, 121);
      c.closePath();
      c.fill();
      c.fillStyle = '#FF7FA3';
      c.beginPath();
      c.ellipse(cx, 130, 6, 3.6, 0, 0, Math.PI * 2);
      c.fill();
    } else {
      c.beginPath();
      c.moveTo(cx - 11, 121);
      c.quadraticCurveTo(cx, 121 + 15 * L.smile, cx + 11, 121);
      c.stroke();
    }

    // heart floating up after a tap
    if (poking) {
      const hy = 30 - pokeP * 46;
      const hx = cx + 64;
      const hs = 9 + pokeP * 4;
      c.fillStyle = 'rgba(255, 138, 91, ' + (1 - pokeP).toFixed(2) + ')';
      c.beginPath();
      c.moveTo(hx, hy + hs * 0.9);
      c.bezierCurveTo(hx - hs * 1.6, hy - hs * 0.2, hx - hs * 0.7, hy - hs * 1.3, hx, hy - hs * 0.45);
      c.bezierCurveTo(hx + hs * 0.7, hy - hs * 1.3, hx + hs * 1.6, hy - hs * 0.2, hx, hy + hs * 0.9);
      c.closePath();
      c.fill();
    }

    // sparkles when thriving or proud
    if (L.mood === 'thriving' || L.mood === 'proud') {
      for (let i = 0; i < 3; i++) {
        const a = 0.35 + 0.65 * Math.abs(Math.sin(t * 1.8 + i * 1.7));
        const sx = [cx - 118, cx + 112, cx + 84][i];
        const sy = [90, 72, 214][i];
        const r = 7 + i * 1.5;
        c.fillStyle = 'rgba(255, 244, 190, ' + a.toFixed(2) + ')';
        c.beginPath();
        c.moveTo(sx, sy - r);
        c.quadraticCurveTo(sx, sy, sx + r, sy);
        c.quadraticCurveTo(sx, sy, sx, sy + r);
        c.quadraticCurveTo(sx, sy, sx - r, sy);
        c.quadraticCurveTo(sx, sy, sx, sy - r);
        c.closePath();
        c.fill();
      }
    }

    // sleepy bubbles
    if ((L.mood === 'resting' || L.mood === 'sleepy') && !poking) {
      c.fillStyle = 'rgba(244, 245, 255, 0.9)';
      c.font = '700 24px sans-serif';
      c.fillText('z', cx + 70, 56 + Math.sin(t * 1.5) * 4);
      c.font = '700 17px sans-serif';
      c.fillText('z', cx + 92, 36 + Math.sin(t * 1.5 + 1) * 4);
    }
    c.restore();
  }

  build() {
    Column() {
      Canvas(this.ctx)
        .width('100%')
        .height(this.canvasHeight)
        .onAreaChange((oldArea: Area, newArea: Area) => {
          this.cw = Number(newArea.width);
          this.ch = Number(newArea.height);
        })
        .onReady(() => {
          this.draw();
        })
        .accessibilityText('Your creature')
        .onClick(() => {
          if (this.tappable) {
            this.holder.poke();
            AppModel.get().tick(20);
          }
        })
      if (this.label.length > 0) {
        Text(this.label)
          .fontSize(12)
          .fontColor('#B4B8E0')
          .textAlign(TextAlign.Center)
          .margin({ top: 4 })
      }
    }
    .width('100%')
  }
}
