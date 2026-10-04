import { CreatureLook } from '../../core/CreatureLook';
import { drawCreatureFit } from '../../components/CreatureDraw';

// The app's creature on a home-screen widget: one still frame drawn with the shared
// CreatureDraw code, redrawn whenever the widget data changes.
@Component
export struct WidgetCreature {
  @Prop @Watch('redraw') mood: string = 'curious';
  @Prop @Watch('redraw') hue: number = 14;
  @Prop @Watch('redraw') glow: number = 0.5;
  @Prop @Watch('redraw') eyeOpen: number = 1;
  @Prop @Watch('redraw') smile: number = 0.55;
  @Prop @Watch('redraw') happyEyes: boolean = false;
  @Prop @Watch('redraw') species: string = 'wisp';
  @Prop @Watch('redraw') legs: number = 1;
  @Prop @Watch('redraw') push: number = 1;
  @Prop @Watch('redraw') pull: number = 1;
  @Prop @Watch('redraw') core: number = 1;
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private ctx: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private ready: boolean = false;

  redraw(): void {
    if (!this.ready) {
      return;
    }
    const L = new CreatureLook();
    L.mood = this.mood;
    L.hue = this.hue;
    L.glow = this.glow;
    L.eyeOpen = this.eyeOpen;
    L.smile = this.smile;
    L.happyEyes = this.happyEyes;
    L.species = this.species;
    L.legs = this.legs;
    L.push = this.push;
    L.pull = this.pull;
    L.core = this.core;
    L.bob = 0;
    const c = this.ctx;
    c.clearRect(0, 0, c.width, c.height);
    // t = 1 s: eyes open (outside the blink), a still, centred pose
    drawCreatureFit(c, L, 1, -1, c.width, c.height);
  }

  build() {
    Canvas(this.ctx)
      .width('100%')
      .height('100%')
      .onReady(() => {
        this.ready = true;
        this.redraw();
      })
  }
}
