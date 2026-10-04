import { hilog } from '@kit.PerformanceAnalysisKit';
import { CreatureLook } from '../core/CreatureLook';
import { AppModel } from '../app/AppModel';
import { drawCreatureFit } from './CreatureDraw';
import { LookHolder } from './LookHolder';
import { motionOn } from '../ui/Motion';


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
  private cw: number = 340;
  private ch: number = 320;
  private cur: CreatureLook = new CreatureLook();
  private idleFrames: number = 0;
  private lastW: number = 0;
  private lastH: number = 0;

  aboutToAppear(): void {
    this.timer = setInterval(() => {
      if (!this.holder.active) {
        return; // hidden page: skip the frame entirely
      }
      if (!motionOn() && !this.needsFrame()) {
        return; // reduced motion: no idle animation, draw only when something changes
      }
      try {
        this.draw();
      } catch (e) {
        hilog.error(0x00F0, 'WispCanvas', 'draw failed: %{public}s', JSON.stringify(e));
      }
    }, motionOn() ? 40 : 66);
  }

  // With reduced motion the creature is still: frames are drawn only while it reacts to a tap,
  // morphs to a new look, or its size changes.
  private needsFrame(): boolean {
    const now = Date.now();
    if (now - this.holder.pokedAt < 1000) {
      return true;
    }
    if (this.holder.snap || this.idleFrames < 3) {
      this.idleFrames++;
      return true;
    }
    const T = this.holder.look;
    const C = this.cur;
    const moving = Math.abs(T.legs - C.legs) + Math.abs(T.core - C.core) + Math.abs(T.push - C.push) +
      Math.abs(T.pull - C.pull) + Math.abs(T.hue - C.hue) / 50 + Math.abs(T.eyeOpen - C.eyeOpen) +
      Math.abs(T.smile - C.smile) > 0.01 || T.mood !== C.mood || T.happyEyes !== C.happyEyes;
    if (moving) {
      this.idleFrames = 0;
      return true;
    }
    if (this.ctx.width !== this.lastW || this.ctx.height !== this.lastH) {
      this.lastW = this.ctx.width;
      this.lastH = this.ctx.height;
      return true;
    }
    return false;
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
    this.follow();
    drawCreatureFit(c, this.cur, (Date.now() - this.startedAt) / 1000, (Date.now() - this.holder.pokedAt) / 900,
      this.cw, this.ch);
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
