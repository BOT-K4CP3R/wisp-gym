import { ACCENT, TEXT_MUTE } from '../ui/Theme';

// Mutable data box shared with the chart (same pattern as LookHolder): set new values and
// bump `version` on the owner to redraw.
export class ChartData {
  xs: number[] = [];       // timestamps (ms), ascending
  ys: number[] = [];       // values
  goal: number = 0;        // horizontal goal line (0 = none)
  unit: string = 'kg';
}

// A small line chart drawn on a Canvas: soft area, line, last-point marker, a dashed goal
// line and min/max labels. Static (redrawn only when data changes), so it is cheap.
@Component
export struct LineChart {
  data: ChartData = new ChartData();
  @Prop @Watch('redraw') version: number = 0;
  @Prop chartHeight: number = 160;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  redraw(): void {
    if (!this.ready) {
      return;
    }
    const c = this.ctx;
    const w = c.width;
    const h = c.height;
    c.clearRect(0, 0, w, h);
    const xs = this.data.xs;
    const ys = this.data.ys;
    if (xs.length === 0) {
      return;
    }
    let lo = ys[0];
    let hi = ys[0];
    for (let i = 1; i < ys.length; i++) {
      lo = Math.min(lo, ys[i]);
      hi = Math.max(hi, ys[i]);
    }
    if (this.data.goal > 0) {
      lo = Math.min(lo, this.data.goal);
      hi = Math.max(hi, this.data.goal);
    }
    const pad = Math.max(0.5, (hi - lo) * 0.15);
    lo -= pad;
    hi += pad;
    const left = 36;
    const right = w - 10;
    const top = 10;
    const bottom = h - 18;
    const x0 = xs[0];
    const x1 = xs.length > 1 ? xs[xs.length - 1] : xs[0] + 1;
    const px = (x: number): number => xs.length > 1 ? left + (right - left) * (x - x0) / (x1 - x0) : (left + right) / 2;
    const py = (y: number): number => bottom - (bottom - top) * (y - lo) / (hi - lo);

    // grid labels
    c.fillStyle = TEXT_MUTE;
    c.font = '10px sans-serif';
    c.fillText(hi.toFixed(1), 0, top + 8);
    c.fillText(lo.toFixed(1), 0, bottom);
    c.strokeStyle = 'rgba(255, 255, 255, 0.08)';
    c.lineWidth = 1;
    c.beginPath();
    c.moveTo(left, top);
    c.lineTo(right, top);
    c.moveTo(left, bottom);
    c.lineTo(right, bottom);
    c.stroke();

    // goal line
    if (this.data.goal > 0) {
      const gy = py(this.data.goal);
      c.strokeStyle = 'rgba(255, 138, 91, 0.7)';
      c.setLineDash([5, 5]);
      c.beginPath();
      c.moveTo(left, gy);
      c.lineTo(right, gy);
      c.stroke();
      c.setLineDash([]);
      c.fillStyle = ACCENT;
      c.fillText('goal', right - 24, gy - 4);
    }

    // area + line
    if (xs.length > 1) {
      const g = c.createLinearGradient(0, top, 0, bottom);
      g.addColorStop(0, 'rgba(255, 138, 91, 0.28)');
      g.addColorStop(1, 'rgba(255, 138, 91, 0)');
      c.fillStyle = g;
      c.beginPath();
      c.moveTo(px(xs[0]), bottom);
      for (let i = 0; i < xs.length; i++) {
        c.lineTo(px(xs[i]), py(ys[i]));
      }
      c.lineTo(px(xs[xs.length - 1]), bottom);
      c.closePath();
      c.fill();
      c.strokeStyle = '#F4F4F5';
      c.lineWidth = 2;
      c.lineJoin = 'round';
      c.beginPath();
      for (let i = 0; i < xs.length; i++) {
        if (i === 0) {
          c.moveTo(px(xs[i]), py(ys[i]));
        } else {
          c.lineTo(px(xs[i]), py(ys[i]));
        }
      }
      c.stroke();
    }
    // points
    c.fillStyle = '#F4F4F5';
    for (let i = 0; i < xs.length; i++) {
      c.beginPath();
      c.arc(px(xs[i]), py(ys[i]), 2.2, 0, Math.PI * 2);
      c.fill();
    }
    const lx = px(xs[xs.length - 1]);
    const ly = py(ys[ys.length - 1]);
    c.fillStyle = ACCENT;
    c.beginPath();
    c.arc(lx, ly, 5, 0, Math.PI * 2);
    c.fill();
    // first / last dates
    c.fillStyle = TEXT_MUTE;
    c.fillText(shortDate(xs[0]), left, h - 2);
    if (xs.length > 1) {
      c.fillText(shortDate(xs[xs.length - 1]), right - 34, h - 2);
    }
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height(this.chartHeight)
      .onReady(() => {
        this.ready = true;
        this.redraw();
      })
      .accessibilityText('Weight chart')
  }
}

function shortDate(ms: number): string {
  const d = new Date(ms);
  return d.getDate() + '/' + (d.getMonth() + 1);
}
