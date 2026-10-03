import { AppModel } from '../app/AppModel';
import { LifeEngine, LifeConfig, CreatureState } from '../core/LifeEngine';
import { lookFor } from '../core/CreatureLook';
import { WorkoutRecord } from '../core/Types';
import { generateHistory } from '../core/Sim';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { Button56, InfoRow, TabBar, Tag, Tile } from '../ui/Kit';
import { goTab } from '../ui/Nav';
import { registerFonts } from '../ui/Fonts';
import { ACCENT, BG, F_BOLD, F_REG, GAP, PAD, SURFACE, TEXT, TEXT_DIM, TEXT_MUTE, TRACK } from '../ui/Theme';

class DayBar {
  label: string;
  reps: number;

  constructor(label: string, reps: number) {
    this.label = label;
    this.reps = reps;
  }
}

class SessionRow {
  day: string;
  detail: string;
  simulated: boolean;

  constructor(day: string, detail: string, simulated: boolean) {
    this.day = day;
    this.detail = detail;
    this.simulated = simulated;
  }
}

@Entry
@Component
struct Week {
  @State label: string = '';
  @State playing: boolean = false;
  @State sessions: SessionRow[] = [];
  @State bars: DayBar[] = [];
  private holder: LookHolder = new LookHolder();
  private timer: number = -1;
  private engine: LifeEngine = new LifeEngine(new LifeConfig());

  onPageHide(): void {
    this.holder.active = false;
  }

  onPageShow(): void {
    this.holder.active = true;
  }

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    const model = AppModel.get();
    this.holder.look = model.lookFor(model.evaluateNow());
    const ws = model.workouts();
    const rows: SessionRow[] = [];
    const names = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (let i = Math.max(0, ws.length - 8); i < ws.length; i++) {
      const w = ws[i];
      let reps = 0;
      for (let s = 0; s < w.sets.length; s++) {
        reps += w.sets[s].reps;
      }
      const d = new Date(w.endMs);
      rows.push(new SessionRow(names[d.getDay()] + ' ' + d.getDate() + '/' + (d.getMonth() + 1), w.sets.length + ' sets  |  ' + reps + ' reps', w.simulated));
    }
    this.sessions = rows.reverse();

    // reps per day for the last 7 days
    const now = Date.now();
    const day = 86400000;
    const bars: DayBar[] = [];
    for (let k = 6; k >= 0; k--) {
      const start = new Date(now - k * day);
      start.setHours(0, 0, 0, 0);
      const from = start.getTime();
      let reps = 0;
      for (let i = 0; i < ws.length; i++) {
        if (ws[i].endMs >= from && ws[i].endMs < from + day) {
          for (let s = 0; s < ws[i].sets.length; s++) {
            reps += ws[i].sets[s].reps;
          }
        }
      }
      bars.push(new DayBar(names[start.getDay()].substring(0, 1), reps));
    }
    this.bars = bars;
  }

  aboutToDisappear(): void {
    this.stopTimeLapse();
  }

  private stopTimeLapse(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.playing = false;
  }

  private maxReps(): number {
    let m = 1;
    for (let i = 0; i < this.bars.length; i++) {
      m = Math.max(m, this.bars[i].reps);
    }
    return m;
  }

  private playTimeLapse(): void {
    if (this.playing) {
      return;
    }
    // A simulated 14-day journey: clearly labelled, independent of the user's real data.
    const now = Date.now();
    const all: WorkoutRecord[] = generateHistory(now, 14, 20261003);
    const seed = AppModel.get().seed();
    let day = 14;
    this.playing = true;
    this.timer = setInterval(() => {
      const t = now - (day - 1) * 86400000;
      const upTo: WorkoutRecord[] = all.filter((w: WorkoutRecord) => w.endMs <= t);
      const st: CreatureState = this.engine.evaluate(t, upTo, 5200);
      this.holder.look = lookFor(st, seed);
      this.label = 'Simulated  |  day ' + (15 - day) + ' of 14';
      day--;
      if (day < 1) {
        this.stopTimeLapse();
      }
    }, 1200);
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          Text('Week')
            .fontSize(34)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
            .width('100%')
            .margin({ top: 8, bottom: 16 })

          Tile({ pad: 16 }) {
            CreatureCanvas({ holder: this.holder, label: this.label, canvasHeight: 200 })
          }

          Column() {
            Button56({
              label: this.playing ? 'Playing' : 'Play 14-day evolution',
              primary: false,
              onTap: () => this.playTimeLapse()
            })
          }
          .margin({ top: GAP })
          .opacity(this.playing ? 0.6 : 1)

          Column() {
            Tile({ pad: 20 }) {
              Text('Reps, last 7 days')
                .fontSize(16)
                .fontFamily(F_BOLD)
                .fontColor(TEXT)
                .width('100%')
              Row({ space: 10 }) {
                ForEach(this.bars, (b: DayBar) => {
                  Column({ space: 8 }) {
                    Column()
                      .width('100%')
                      .height(Math.max(4, Math.round(88 * b.reps / this.maxReps())))
                      .borderRadius(6)
                      .backgroundColor(b.reps > 0 ? ACCENT : TRACK)
                    Text(b.label)
                      .fontSize(11)
                      .fontFamily(F_BOLD)
                      .fontColor(TEXT_MUTE)
                  }
                  .layoutWeight(1)
                  .justifyContent(FlexAlign.End)
                  .height(116)
                }, (b: DayBar, idx: number) => '' + idx)
              }
              .width('100%')
              .margin({ top: 16 })
            }
          }
          .margin({ top: GAP })

          if (this.sessions.length > 0) {
            Column() {
              Tile({ pad: 20 }) {
                ForEach(this.sessions, (row: SessionRow, idx: number) => {
                  InfoRow({ label: row.day, value: row.detail, divider: idx < this.sessions.length - 1 })
                }, (row: SessionRow, idx: number) => '' + idx)
              }
            }
            .margin({ top: GAP })
          }
          Blank().height(GAP)
        }
        .padding({ left: PAD, right: PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column() {
        TabBar({ active: 'week', onNavigate: (t: string) => goTab(this.getUIContext(), 'week', t) })
      }
      .padding({ left: PAD, right: PAD, bottom: 12, top: 4 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
  }
}
