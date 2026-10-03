import { hilog } from '@kit.PerformanceAnalysisKit';
import { CreatureLook } from '../core/CreatureLook';
import { LookHolder } from './LookHolder';
import { hslToHex } from '../app/AppModel';

function hexToRgb(hex: string): string {
  const r = parseInt(hex.substring(1, 3), 16);
  const g = parseInt(hex.substring(3, 5), 16);
  const b = parseInt(hex.substring(5, 7), 16);
  return r + ', ' + g + ', ' + b;
}

// Procedural creature drawn on a Canvas. Every number comes from CreatureLook, so the
// shape, colour and mood are a direct function of the user's real training state.
@Component
export struct CreatureCanvas {
  holder: LookHolder = new LookHolder();
  @Prop label: string = '';
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private timer: number = -1;
  private t: number = 0;
  private w: number = 340;
  private h: number = 300;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (!this.holder.active) {
        return; // hidden page: skip the frame entirely
      }
      this.t += 0.07;
      try {
        this.draw();
      } catch (e) {
        hilog.error(0x00F0, 'WispCanvas', 'draw failed: %{public}s', JSON.stringify(e));
      }
    }, 66);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  private draw(): void {
    const c = this.ctx;
    const L: CreatureLook = this.holder.look;
    c.clearRect(0, 0, this.w, this.h);
    const cx = this.w / 2;
    const bob = Math.sin(this.t * 2.2) * 7 * L.bob;
    const breathe = 1 + Math.sin(this.t * 1.6) * 0.012;
    // Canvas fillStyle on this runtime needs #RRGGBB / rgba(); hsl() strings render nothing.
    const body = hslToHex(L.hue, 70, 62);
    const dark = hslToHex(L.hue, 70, 46);
    const light = hslToHex(L.hue, 80, 76);
    const glowRgb = hexToRgb(hslToHex(L.hue, 90, 65));

    // glow
    const g = c.createRadialGradient(cx, 150, 10, cx, 150, 150);
    g.addColorStop(0, 'rgba(' + glowRgb + ', ' + (0.15 + L.glow * 0.45).toFixed(2) + ')');
    g.addColorStop(1, 'rgba(' + glowRgb + ', 0)');
    c.fillStyle = g;
    c.beginPath();
    c.arc(cx, 150, 150, 0, Math.PI * 2);
    c.fill();

    c.save();
    c.translate(0, bob);

    // legs (scale with the legs level)
    const legW = 30 * L.legs;
    const legH = 46 * L.legs;
    c.fillStyle = dark;
    this.roundRect(cx - 34 - legW / 2, 232 - legH * 0.3, legW, legH, legW / 2);
    this.roundRect(cx + 34 - legW / 2, 232 - legH * 0.3, legW, legH, legW / 2);

    // arms (pull)
    const armRx = 15 * L.pull;
    const armRy = 46 * L.pull;
    const swing = Math.sin(this.t * 2.2) * 0.12 * L.bob;
    c.fillStyle = dark;
    c.beginPath();
    c.ellipse(cx - 70 * L.push, 150, armRx, armRy, 0.25 + swing, 0, Math.PI * 2);
    c.fill();
    c.beginPath();
    c.ellipse(cx + 70 * L.push, 150, armRx, armRy, -0.25 - swing, 0, Math.PI * 2);
    c.fill();

    // torso / belly (core) with shoulders (push)
    c.fillStyle = body;
    c.beginPath();
    c.ellipse(cx, 175, 58 * L.core * breathe, 66 * L.core * breathe, 0, 0, Math.PI * 2);
    c.fill();
    c.beginPath();
    c.ellipse(cx, 122, 62 * L.push, 38 * L.push, 0, 0, Math.PI * 2);
    c.fill();
    c.fillStyle = light;
    c.beginPath();
    c.ellipse(cx, 190, 34 * L.core, 40 * L.core, 0, 0, Math.PI * 2);
    c.fill();

    // head
    c.fillStyle = body;
    c.beginPath();
    c.arc(cx, 92, 50, 0, Math.PI * 2);
    c.fill();

    // eyes
    const eyeH = Math.max(1.5, 13 * L.eyeOpen);
    c.fillStyle = '#FFFFFF';
    c.beginPath();
    c.ellipse(cx - 18, 88, 11, eyeH, 0, 0, Math.PI * 2);
    c.fill();
    c.beginPath();
    c.ellipse(cx + 18, 88, 11, eyeH, 0, 0, Math.PI * 2);
    c.fill();
    if (L.eyeOpen > 0.3) {
      c.fillStyle = '#1B1B2F';
      c.beginPath();
      c.arc(cx - 18, 89, 5, 0, Math.PI * 2);
      c.fill();
      c.beginPath();
      c.arc(cx + 18, 89, 5, 0, Math.PI * 2);
      c.fill();
    }

    // smile (never a frown)
    c.strokeStyle = '#1B1B2F';
    c.lineWidth = 3;
    c.lineCap = 'round';
    c.beginPath();
    c.moveTo(cx - 16, 112);
    c.quadraticCurveTo(cx, 112 + 18 * L.smile, cx + 16, 112);
    c.stroke();

    // sleepy "z"
    if (L.mood === 'resting' || L.mood === 'sleepy') {
      c.fillStyle = '#E8EAF6';
      c.font = '22px sans-serif';
      c.fillText('z', cx + 52, 56 + Math.sin(this.t * 1.5) * 4);
      c.font = '16px sans-serif';
      c.fillText('z', cx + 70, 40 + Math.sin(this.t * 1.5 + 1) * 4);
    }
    c.restore();
  }

  private roundRect(x: number, y: number, w: number, h: number, r: number): void {
    const c = this.ctx;
    c.beginPath();
    c.moveTo(x + r, y);
    c.lineTo(x + w - r, y);
    c.quadraticCurveTo(x + w, y, x + w, y + r);
    c.lineTo(x + w, y + h - r);
    c.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    c.lineTo(x + r, y + h);
    c.quadraticCurveTo(x, y + h, x, y + h - r);
    c.lineTo(x, y + r);
    c.quadraticCurveTo(x, y, x + r, y);
    c.closePath();
    c.fill();
  }

  build() {
    Column() {
      Canvas(this.ctx)
        .width('100%')
        .height(300)
        .onReady(() => {
          this.draw();
        })
      if (this.label.length > 0) {
        Text(this.label)
          .fontSize(12)
          .fontColor('#9FA8DA')
      }
    }
    .width('100%')
  }
}
