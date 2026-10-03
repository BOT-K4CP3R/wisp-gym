import { AppModel } from '../app/AppModel';
import { CreatureState, Reason } from '../core/LifeEngine';
import { TabBar, Tile } from '../ui/Kit';
import { goTab } from '../ui/Nav';
import { registerFonts } from '../ui/Fonts';
import { ACCENT, BG, F_BOLD, F_REG, GAP, PAD, TEXT, TEXT_MUTE, TRACK } from '../ui/Theme';

@Entry
@Component
struct Why {
  @State state: CreatureState = new CreatureState();

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    AppModel.get().state().then((st: CreatureState) => {
      this.state = st;
    });
  }

  // 0..1 for reasons whose value is a percentage, otherwise -1 (no bar).
  private pct(r: Reason): number {
    if (r.value.indexOf('%') < 0) {
      return -1;
    }
    const n = parseInt(r.value, 10);
    return isNaN(n) ? -1 : Math.max(0, Math.min(100, n)) / 100;
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: GAP }) {
          Text('Insights')
            .fontSize(34)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
            .width('100%')
            .margin({ top: 8 })
          Text(this.state.headline)
            .fontSize(15)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
            .width('100%')
            .margin({ bottom: 4 })

          ForEach(this.state.reasons, (r: Reason) => {
            Tile({ pad: 20 }) {
              Row() {
                Text(r.label)
                  .fontSize(16)
                  .fontFamily(F_BOLD)
                  .fontColor(TEXT)
                  .layoutWeight(1)
                Text(r.value)
                  .fontSize(r.value.length > 8 ? 14 : 24)
                  .fontFamily(F_BOLD)
                  .fontColor(r.ok ? TEXT : ACCENT)
                  .maxLines(1)
              }
              .width('100%')
              if (this.pct(r) >= 0) {
                Progress({ value: Math.round(this.pct(r) * 100), total: 100, type: ProgressType.Linear })
                  .color(r.ok ? TEXT : ACCENT)
                  .backgroundColor(TRACK)
                  .style({ strokeWidth: 4, strokeRadius: 2 })
                  .width('100%')
                  .margin({ top: 14 })
              }
              Text(r.target)
                .fontSize(12)
                .fontFamily(F_REG)
                .fontColor(TEXT_MUTE)
                .width('100%')
                .margin({ top: 10 })
            }
          }, (r: Reason) => r.key)
        }
        .padding({ left: PAD, right: PAD, bottom: 16 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column() {
        TabBar({ active: 'why', onNavigate: (t: string) => goTab(this.getUIContext(), 'why', t) })
      }
      .padding({ left: PAD, right: PAD, bottom: 12, top: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
