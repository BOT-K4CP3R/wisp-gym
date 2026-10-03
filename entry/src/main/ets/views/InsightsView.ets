import { AppModel } from '../app/AppModel';
import { CreatureState, LifeConfig, Reason } from '../core/LifeEngine';
import { moodInfo } from '../core/Mood';
import { GROUPS } from '../core/Types';
import { MetricBar, Reveal, SectionLabel, Tile } from '../ui/Kit';
import { ACCENT, BG, F_BOLD, F_REG, GAP, PAD, STAGGER, TEXT, TEXT_DIM, TEXT_MUTE, TRACK } from '../ui/Theme';
import { motionOn } from '../ui/Motion';

const GROUP_NAMES: string[] = ['Legs', 'Push', 'Pull', 'Core'];

class Explainer {
  title: string;
  body: string;

  constructor(title: string, body: string) {
    this.title = title;
    this.body = body;
  }
}

const HOW: Explainer[] = [
  new Explainer('Reps from motion', 'With the phone in a pocket or armband, Wisp Gym removes gravity from the accelerometer ' +
    'signal and counts the drive of each rep. Walking rhythm is ignored.'),
  new Explainer('Knowing when to stop', 'Your first reps set a fresh baseline. When reps get slower and weaker, the ring ' +
    'turns orange: one or two good reps left. This is a tempo proxy, not a medical measurement.'),
  new Explainer('Rest is progress', 'Three sessions in 72 hours or a very heavy load triggers a rest day. Muscles grow ' +
    'while you recover, so rest never counts against you.'),
  new Explainer('Private by design', 'Everything is computed and stored on this phone. The app has no network permission.')
];

@Component
export struct InsightsView {
  @Prop @Watch('reload') version: number = 0;
  @State state: CreatureState = new CreatureState();
  @State name: string = 'Wisp';
  @State halfLife: number = 4;
  @State floorPct: number = 12;

  aboutToAppear(): void {
    this.reload();
  }

  reload(): void {
    const model = AppModel.get();
    this.name = model.profile().name;
    const cfg = new LifeConfig();
    this.halfLife = cfg.halfLifeDays;
    this.floorPct = Math.round(cfg.floor * 100);
    this.state = model.evaluateNow();
    model.state().then((st: CreatureState) => {
      this.state = st;
    });
  }

  private reason(key: string): Reason {
    for (let i = 0; i < this.state.reasons.length; i++) {
      if (this.state.reasons[i].key === key) {
        return this.state.reasons[i];
      }
    }
    return new Reason(key, '', '-', '', true);
  }

  private pct(r: Reason): number {
    const n = parseInt(r.value, 10);
    return isNaN(n) ? 0 : Math.max(0, Math.min(100, n)) / 100;
  }

  @Builder
  ReasonTile(key: string, delay: number) {
    Reveal({ delay: delay }) {
      Tile({ pad: 20 }) {
        Row() {
          Text(this.reason(key).label)
            .fontSize(16)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
            .layoutWeight(1)
          Text(this.reason(key).value)
            .fontSize(this.reason(key).value.length > 8 ? 15 : 24)
            .fontFamily(F_BOLD)
            .fontColor(this.reason(key).ok ? TEXT : ACCENT)
            .maxLines(1)
        }
        .width('100%')
        if (this.reason(key).value.indexOf('%') > 0) {
          Progress({ value: Math.round(this.pct(this.reason(key)) * 100), total: 100, type: ProgressType.Linear })
            .color(this.reason(key).ok ? TEXT : ACCENT)
            .backgroundColor(TRACK)
            .style({ strokeWidth: 6, strokeRadius: 3, enableSmoothEffect: motionOn() })
            .width('100%')
            .margin({ top: 14 })
        }
        Text(this.reason(key).target)
          .fontSize(13)
          .fontFamily(F_REG)
          .fontColor(TEXT_MUTE)
          .width('100%')
          .margin({ top: 10 })
      }
    }
  }

  build() {
    Scroll() {
      Column({ space: GAP }) {
        Column() {
          Text('Insights')
            .fontSize(32)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
            .width('100%')
          Text(this.state.headline)
            .fontSize(15)
            .fontFamily(F_REG)
            .fontColor(TEXT_DIM)
            .width('100%')
            .margin({ top: 4 })
        }
        .margin({ top: 8, bottom: 4 })

        Reveal({ delay: 0 }) {
          Tile({ pad: 20 }) {
            Row() {
              Text('Mood').fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
              Text(moodInfo(this.state.mood).label).fontSize(24).fontFamily(F_BOLD).fontColor(ACCENT)
            }
            .width('100%')
            Text('Mood comes from the rest guard, recovery, strength and steps. ' + this.name +
              ' is never sad: time away makes it curious, hard work makes it tired.')
              .fontSize(13)
              .fontFamily(F_REG)
              .fontColor(TEXT_MUTE)
              .width('100%')
              .margin({ top: 10 })
          }
        }

        SectionLabel({ text: 'Strength by muscle group' })
        Reveal({ delay: STAGGER }) {
          Tile({ pad: 20 }) {
            Column({ space: 16 }) {
              ForEach(GROUPS, (g: string, i: number) => {
                Column({ space: 4 }) {
                  MetricBar({
                    label: GROUP_NAMES[i],
                    value: this.state.levels[i],
                    color: this.state.levels[i] >= 0.4 ? TEXT : ACCENT,
                    delay: 150 + i * 60
                  })
                  Text(this.reason('group-' + g).target)
                    .fontSize(12)
                    .fontFamily(F_REG)
                    .fontColor(TEXT_MUTE)
                    .width('100%')
                }
              }, (g: string, i: number) => g + Math.round(this.state.levels[i] * 100))
            }
            .width('100%')
            Text('Older work fades by half every ' + this.halfLife + ' days and never drops below ' + this.floorPct + '%.')
              .fontSize(12)
              .fontFamily(F_REG)
              .fontColor(TEXT_MUTE)
              .width('100%')
              .margin({ top: 16 })
          }
        }

        SectionLabel({ text: 'Recovery and rest' })
        this.ReasonTile('recover', STAGGER * 2)
        this.ReasonTile('rest-guard', STAGGER * 3)

        SectionLabel({ text: 'Movement' })
        this.ReasonTile('move', STAGGER * 4)

        SectionLabel({ text: 'How it works' })
        Reveal({ delay: STAGGER * 5 }) {
          Tile({ pad: 20 }) {
            Column({ space: 16 }) {
              ForEach(HOW, (e: Explainer) => {
                Column({ space: 4 }) {
                  Text(e.title).fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
                  Text(e.body).fontSize(13).fontFamily(F_REG).fontColor(TEXT_DIM).width('100%').lineHeight(19)
                }
              }, (e: Explainer) => e.title)
            }
          }
        }
        Blank().height(104)
      }
      .padding({ left: PAD, right: PAD })
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor(BG)
  }
}
