import { AppModel } from '../app/AppModel';
import { CreatureState } from '../core/LifeEngine';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { ActivityDots, IconButton, TabBar, Tag, TitleBlock, Tile, RingNumber } from '../ui/Kit';
import { goTab } from '../ui/Nav';
import { registerFonts } from '../ui/Fonts';
import { ACCENT, BG, F_BOLD, F_REG, GAP, HAIRLINE, PAD, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE } from '../ui/Theme';

@Entry
@Component
struct Index {
  @State state: CreatureState = new CreatureState();
  @State demo: boolean = false;
  @State message: string = '';
  @State showSheet: boolean = false;
  @State steps: number = 0;
  @State days: number[] = [];
  private holder: LookHolder = new LookHolder();

  onPageHide(): void {
    this.holder.active = false;
  }

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    this.reload();
    if (!AppModel.get().isDemo()) {
      // Ask once, with a stated reason, for the pedometer; the app works without it.
      AppModel.get().requestMotionPermission();
    }
  }

  onPageShow(): void {
    this.holder.active = true;
    this.reload();
  }

  private async reload(): Promise<void> {
    const model = AppModel.get();
    this.demo = model.isDemo();
    const st = await model.state();
    this.state = st;
    this.steps = model.stepsToday();
    this.days = model.repsPerDay(35);
    this.holder.look = model.lookFor(st);
    model.pushWidget();
  }

  private moodTitle(): string {
    return this.state.mood.charAt(0).toUpperCase() + this.state.mood.substring(1);
  }

  private moodSubtitle(): string {
    const m = this.state.mood;
    if (m === 'resting') {
      return 'Rest day suggested';
    }
    if (m === 'sleepy') {
      return 'Recovering';
    }
    if (m === 'thriving') {
      return 'Strong week';
    }
    if (m === 'curious') {
      return 'Ready when you are';
    }
    return 'Steady';
  }

  private stepsText(): string {
    return this.steps >= 1000 ? (this.steps / 1000).toFixed(1) + 'k' : '' + this.steps;
  }

  private activeDays(): number {
    let n = 0;
    for (let i = 0; i < this.days.length; i++) {
      if (this.days[i] > 0) {
        n++;
      }
    }
    return n;
  }

  @Builder
  SettingsSheet() {
    Column({ space: 16 }) {
      Text('Settings')
        .fontSize(22)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
      Row() {
        Column() {
          Text('Demo mode').fontSize(16).fontFamily(F_BOLD).fontColor(TEXT)
          Text('Simulated sensors, for emulators without motion')
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_MUTE)
            .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        Toggle({ type: ToggleType.Switch, isOn: this.demo })
          .selectedColor(ACCENT)
          .onChange((isOn: boolean) => {
            AppModel.get().setDemo(isOn);
            this.reload();
          })
      }
      .width('100%')
      Row({ space: GAP }) {
        Button('Load 2-week history')
          .layoutWeight(1)
          .height(48)
          .fontSize(14)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .backgroundColor(SURFACE_HI)
          .borderRadius(24)
          .border({ width: 1, color: HAIRLINE })
          .onClick(() => {
            AppModel.get().loadDemoHistory();
            this.message = 'Loaded 14 days of simulated history.';
            this.reload();
          })
        Button('Reset')
          .width(96)
          .height(48)
          .fontSize(14)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .backgroundColor(SURFACE_HI)
          .borderRadius(24)
          .border({ width: 1, color: HAIRLINE })
          .onClick(() => {
            AppModel.get().resetHistory();
            this.message = 'History cleared.';
            this.reload();
          })
      }
      if (this.message.length > 0) {
        Text(this.message).fontSize(12).fontFamily(F_REG).fontColor(TEXT_DIM).width('100%')
      }
      Text('Demo data is simulated and labelled as such. Everything else stays on this phone.')
        .fontSize(12)
        .fontFamily(F_REG)
        .fontColor(TEXT_MUTE)
        .width('100%')
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 24 })
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Row({ space: 10 }) {
            Text('Wisp')
              .fontSize(34)
              .fontFamily(F_BOLD)
              .fontColor(TEXT)
              .layoutWeight(1)
            if (this.demo) {
              Tag({ text: 'DEMO' })
            }
            IconButton({ icon: $r('app.media.ic_sliders'), label: 'Settings', onTap: () => {
              this.showSheet = true;
            } })
          }
          .width('100%')
          .margin({ top: 8, bottom: 16 })

          Tile({ pad: 16 }) {
            CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 220 })
            Row() {
              TitleBlock({ title: this.moodTitle(), subtitle: this.moodSubtitle() })
            }
            .width('100%')
            .margin({ top: 4, left: 4 })
          }

          Row({ space: GAP }) {
            Column() {
              Tile({ pad: 20 }) {
                RingNumber({ value: this.state.train, diameter: 60 })
                Blank().height(28)
                TitleBlock({ title: 'Strength', subtitle: '7-day load' })
              }
            }
            .layoutWeight(1)
            Column() {
              Tile({ pad: 20 }) {
                Text(this.stepsText())
                  .fontSize(40)
                  .fontFamily(F_BOLD)
                  .fontColor(TEXT)
                  .height(60)
                Blank().height(28)
                TitleBlock({ title: 'Move', subtitle: 'Steps today' })
              }
            }
            .layoutWeight(1)
          }
          .margin({ top: GAP })
          .alignItems(VerticalAlign.Top)

          Column() {
            Tile({ pad: 20 }) {
              Row() {
                TitleBlock({ title: 'Recovery', subtitle: 'Since last session' })
                Blank()
                Text(Math.round(this.state.recover * 100) + '%')
                  .fontSize(32)
                  .fontFamily(F_BOLD)
                  .fontColor(this.state.restRequested ? ACCENT : TEXT)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            }
          }
          .margin({ top: GAP })

          Column() {
            Tile({ pad: 20 }) {
              ActivityDots({ values: this.days })
              Column() {
                TitleBlock({ title: 'Last 5 weeks', subtitle: this.activeDays() + ' active days' })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .margin({ top: 20 })
            }
          }
          .margin({ top: GAP, bottom: GAP })
        }
        .padding({ left: PAD, right: PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column() {
        TabBar({ active: 'home', onNavigate: (t: string) => goTab(this.getUIContext(), 'home', t) })
      }
      .padding({ left: PAD, right: PAD, bottom: 12, top: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
    .bindSheet($$this.showSheet, this.SettingsSheet(), {
      height: 340,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
