import { AppModel } from '../app/AppModel';
import { LifeEngine, CreatureState } from '../core/LifeEngine';
import { lookFor } from '../core/CreatureLook';
import { WorkoutRecord, SetRecord, findExercise } from '../core/Types';
import { generateHistory } from '../core/Sim';
import { Records, WeekStats, dayLabel, formatDuration, formatLoad, plural, records, repsOf } from '../core/Plan';
import { groupThousands } from '../core/Types';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { Button56, EmptyState, InfoRow, Reveal, SectionLabel, Tag, Tile } from '../ui/Kit';
import {
  ACCENT, BG, F_BOLD, F_REG, GAP, PAD, STAGGER, SURFACE, TEXT, TEXT_DIM, TEXT_MUTE, TRACK, ACCENT_MID, HAIRLINE
} from '../ui/Theme';
import { anim, press } from '../ui/Motion';

const DAY_LETTERS: string[] = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

class DayBar {
  label: string;
  reps: number;
  today: boolean;

  constructor(label: string, reps: number, today: boolean) {
    this.label = label;
    this.reps = reps;
    this.today = today;
  }
}

class SessionRow {
  key: string;
  day: string;
  time: string;
  title: string;
  reps: number;
  sets: number;
  simulated: boolean;
  workout: WorkoutRecord;

  constructor(key: string, day: string, time: string, title: string, w: WorkoutRecord) {
    this.key = key;
    this.day = day;
    this.time = time;
    this.title = title;
    this.reps = repsOf(w);
    this.sets = w.sets.length;
    this.simulated = w.simulated;
    this.workout = w;
  }
}

function hhmm(ms: number): string {
  const d = new Date(ms);
  return d.getHours() + ':' + (d.getMinutes() < 10 ? '0' : '') + d.getMinutes();
}

function deltaText(now: number, prev: number): string {
  if (now === 0 && prev === 0) {
    return ' ';
  }
  const d = now - prev;
  if (d === 0) {
    return 'same as last wk';
  }
  return (d > 0 ? '+' : '') + d + ' vs last wk';
}

// One stat in the records tile. A component (not a @Builder) so values refresh on reload.
@Component
struct RecordCell {
  @Prop value: string = '';
  @Prop label: string = '';

  build() {
    Column({ space: 2 }) {
      Text(this.value)
        .fontSize(20)
        .maxFontSize(20)
        .minFontSize(12)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(this.label)
        .fontSize(11)
        .fontFamily(F_REG)
        .fontColor(TEXT_MUTE)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@Component
export struct ProgressView {
  @Prop @Watch('reload') version: number = 0;
  @Prop @Watch('scrollTop') topSignal: number = 0;
  private scroller: Scroller = new Scroller();
  @Prop @Watch('onActive') active: boolean = false;
  holder: LookHolder = new LookHolder();
  @State week: WeekStats = new WeekStats();
  @State bars: DayBar[] = [];
  @State sessions: SessionRow[] = [];
  @State total: number = 0;
  @State rec: Records = new Records();
  @State playing: boolean = false;
  @State lapseLabel: string = '';
  @State showDetail: boolean = false;
  @State detailTitle: string = '';
  @State detailSets: SetRecord[] = [];
  @State detailMeta: string = '';
  private timer: number = -1;

  aboutToAppear(): void {
    this.reload();
  }

  aboutToDisappear(): void {
    this.stopTimeLapse();
  }

  onActive(): void {
    if (!this.active) {
      this.stopTimeLapse();
    }
  }

  // Tapping the active tab again returns to the top, as in platform apps.
  scrollTop(): void {
    this.scroller.scrollEdge(Edge.Top);
  }

  reload(): void {
    const model = AppModel.get();
    this.stopTimeLapse();
    this.holder.set(model.lookFor(model.evaluateNow()), true);
    this.lapseLabel = '';
    const ws = model.workouts();
    const now = Date.now();
    this.week = model.weekStats();
    this.total = ws.length;
    this.rec = records(ws, now);

    const rows: SessionRow[] = [];
    for (let i = ws.length - 1; i >= 0 && rows.length < 30; i--) {
      const w = ws[i];
      if (w.sets.length === 0) {
        continue;
      }
      const names: string[] = [];
      for (let s = 0; s < w.sets.length; s++) {
        const n = findExercise(w.sets[s].exercise).name;
        if (names.indexOf(n) < 0) {
          names.push(n);
        }
      }
      rows.push(new SessionRow(w.id + '-' + i, dayLabel(w.endMs, now), hhmm(w.endMs), names.join(', '), w));
    }
    this.sessions = rows;

    const per = model.repsPerDay(7);
    const bars: DayBar[] = [];
    for (let k = 0; k < 7; k++) {
      const d = new Date(now);
      d.setDate(d.getDate() - (6 - k));
      bars.push(new DayBar(DAY_LETTERS[d.getDay()], per[k], k === 6));
    }
    this.bars = bars;
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
      this.stopTimeLapse();
      this.holder.set(AppModel.get().lookFor(AppModel.get().evaluateNow()), false);
      this.lapseLabel = '';
      return;
    }
    // A simulated 14-day journey: clearly labelled, independent of the user's real data.
    const now = Date.now();
    const all: WorkoutRecord[] = generateHistory(now, 14, 20261003);
    const seed = AppModel.get().seed();
    const species = AppModel.get().profile().species;
    const engine = new LifeEngine(AppModel.get().config());
    let day = 14;
    this.playing = true;
    const step = (): void => {
      const t = now - (day - 1) * 86400000;
      const upTo: WorkoutRecord[] = all.filter((w: WorkoutRecord) => w.endMs <= t);
      const st: CreatureState = engine.evaluate(t, upTo, 5200);
      this.holder.set(lookFor(st, seed, species), false);
      this.lapseLabel = 'Simulated journey  ·  day ' + (15 - day) + ' of 14';
      day--;
      if (day < 1) {
        this.stopTimeLapse();
        // Hold the final day for a moment, then morph back to the user's own creature.
        setTimeout(() => {
          if (!this.playing) {
            this.holder.set(AppModel.get().lookFor(AppModel.get().evaluateNow()), false);
            this.lapseLabel = '';
          }
        }, 2500);
      }
    };
    step();
    this.timer = setInterval(step, 900);
  }

  private openDetail(row: SessionRow): void {
    this.detailTitle = row.day + ', ' + row.time;
    this.detailMeta = formatDuration(row.workout.endMs - row.workout.startMs) + '  ·  ' +
      plural(row.sets, 'set') + '  ·  ' + plural(row.reps, 'rep') + (row.simulated ? '  ·  simulated' : '');
    this.detailSets = row.workout.sets;
    this.showDetail = true;
  }

  private statValue(key: string): number {
    return key === 'sessions' ? this.week.sessions : (key === 'sets' ? this.week.sets : this.week.reps);
  }

  private statPrev(key: string): number {
    return key === 'sessions' ? this.week.prevSessions : (key === 'sets' ? -1 : this.week.prevReps);
  }

  @Builder
  Stat(label: string, key: string) {
    Column({ space: 2 }) {
      Text('' + this.statValue(key))
        .fontSize(30)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
      Text(label).fontSize(13).fontFamily(F_BOLD).fontColor(TEXT_DIM)
      Text(this.statPrev(key) < 0 ? ' ' : deltaText(this.statValue(key), this.statPrev(key)))
        .fontSize(11)
        .fontFamily(F_REG)
        .fontColor(TEXT_MUTE)
        .maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  @Builder
  RecordsTile() {
    Tile({ pad: 20 }) {
      Row() {
        Text('Personal records').fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
        Text(this.rec.activeDays + (this.rec.activeDays === 1 ? ' active day' : ' active days'))
          .fontSize(12)
          .fontFamily(F_REG)
          .fontColor(TEXT_MUTE)
      }
      .width('100%')
      Row({ space: 8 }) {
        RecordCell({ value: groupThousands(this.rec.reps), label: 'total reps' })
          .layoutWeight(1)
        RecordCell({ value: '' + this.rec.sessions, label: 'sessions' })
          .layoutWeight(1)
        RecordCell({ value: '' + this.rec.bestSet, label: 'best set' })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 14 })
      Row({ space: 8 }) {
        RecordCell({ value: '' + this.rec.bestSession, label: 'best session' })
          .layoutWeight(1)
        RecordCell({ value: this.rec.longestMs > 0 ? formatDuration(this.rec.longestMs) : '-', label: 'longest session' })
          .layoutWeight(1)
        RecordCell({ value: this.rec.favorite.length > 0 ? this.rec.favorite : '-', label: 'favourite' })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ top: 14 })
      if (this.rec.heaviestKg > 0) {
        Row({ space: 8 }) {
          RecordCell({ value: formatLoad(this.rec.heaviestKg), label: 'heaviest (' + this.rec.heaviestExercise + ')' })
            .layoutWeight(1)
          RecordCell({ value: groupThousands(Math.round(this.rec.volumeKg)) + ' kg', label: 'total volume' })
            .layoutWeight(2)
        }
        .width('100%')
        .margin({ top: 14 })
      }
    }
  }

  @Builder
  DetailSheet() {
    Column() {
      Text(this.detailTitle).fontSize(22).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
      Text(this.detailMeta).fontSize(13).fontFamily(F_REG).fontColor(TEXT_MUTE).width('100%').margin({ top: 4, bottom: 8 })
      List() {
        ForEach(this.detailSets, (s: SetRecord, i: number) => {
          ListItem() {
            InfoRow({
              label: 'Set ' + (i + 1) + '  ·  ' + findExercise(s.exercise).name,
              sub: 'Fatigue ' + Math.round(s.fatigue * 100) + '%  ·  tempo ' + Math.round(s.quality * 100) + '% steady',
              value: plural(s.reps, 'rep') + (s.weightKg > 0 ? ' × ' + formatLoad(s.weightKg) : ''),
              divider: i < this.detailSets.length - 1,
              strong: s.fatigue >= 0.25
            })
          }
        }, (s: SetRecord, i: number) => 'd' + i + '-' + s.endMs)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 16 })
    .height('100%')
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: GAP }) {
        Text('Progress')
          .fontSize(32)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .width('100%')
          .margin({ top: 8, bottom: 4 })

        Reveal({ delay: 0 }) {
          Tile({ pad: 20 }) {
            Text('This week').fontSize(16).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
            Row({ space: 8 }) {
              this.Stat('Sessions', 'sessions')
              this.Stat('Sets', 'sets')
              this.Stat('Reps', 'reps')
            }
            .width('100%')
            .margin({ top: 12 })
            .alignItems(VerticalAlign.Top)
          }
        }

        Reveal({ delay: STAGGER }) {
          Tile({ pad: 20 }) {
            Row() {
              Text('Reps, last 7 days').fontSize(16).fontFamily(F_BOLD).fontColor(TEXT)
              Blank()
              Text(this.maxReps() > 1 ? 'max ' + this.maxReps() : '').fontSize(12).fontFamily(F_REG).fontColor(TEXT_MUTE)
            }
            .width('100%')
            Stack() {
            Row({ space: 10 }) {
              ForEach(this.bars, (b: DayBar, idx: number) => {
                Column({ space: 6 }) {
                  Text(b.reps > 0 ? '' + b.reps : '')
                    .fontSize(10)
                    .fontFamily(F_BOLD)
                    .fontColor(TEXT_DIM)
                  Column()
                    .width('100%')
                    .height(Math.max(4, Math.round(96 * b.reps / this.maxReps())))
                    .borderRadius(6)
                    .backgroundColor(b.reps > 0 ? (b.today ? ACCENT : ACCENT_MID) : TRACK)
                    .animation(anim({ duration: 500, curve: Curve.Friction, delay: idx * 40 }))
                  Text(b.label)
                    .fontSize(11)
                    .fontFamily(F_BOLD)
                    .fontColor(b.today ? TEXT : TEXT_MUTE)
                }
                .layoutWeight(1)
                .justifyContent(FlexAlign.End)
                .height(140)
              }, (b: DayBar, idx: number) => '' + idx + b.label + (b.today ? 't' : 'f') + '-' + b.reps)
            }
            .width('100%')
            if (this.maxReps() <= 1 && this.bars.every((b: DayBar) => b.reps === 0)) {
              Text('No reps in the last 7 days yet')
                .fontSize(13)
                .fontFamily(F_REG)
                .fontColor(TEXT_MUTE)
                .margin({ bottom: 40 })
            }
            }
            .width('100%')
            .margin({ top: 12 })
          }
        }

        if (this.rec.sessions > 0) {
          Reveal({ delay: STAGGER * 2 }) {
            this.RecordsTile()
          }
        }

        Reveal({ delay: STAGGER * 2 }) {
          Tile({ pad: 16 }) {
            Row() {
              Column() {
                Text('Evolution').fontSize(16).fontFamily(F_BOLD).fontColor(TEXT)
                Text(this.lapseLabel.length > 0 ? this.lapseLabel : 'How two weeks of training shape a creature')
                  .fontSize(12)
                  .fontFamily(F_REG)
                  .fontColor(TEXT_MUTE)
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              if (this.playing) {
                Tag({ text: 'SIMULATED', accent: true })
              }
            }
            .width('100%')
            .padding({ left: 4, right: 4, top: 4 })
            CreatureCanvas({ holder: this.holder, label: '', canvasHeight: 190, tappable: true })
            Button56({
              label: this.playing ? 'Stop' : 'Play 14-day evolution',
              kind: 'secondary',
              height56: 48,
              onTap: () => this.playTimeLapse()
            })
          }
        }

        SectionLabel({ text: 'History' })
        if (this.sessions.length === 0) {
          Tile({ pad: 20 }) {
            EmptyState({
              icon: $r('app.media.ic_dumbbell'),
              title: 'No sessions yet',
              detail: 'Finished workouts appear here with every set.'
            })
          }
        } else {
          Tile({ pad: 6 }) {
            ForEach(this.sessions, (row: SessionRow, idx: number) => {
              Column() {
                Row({ space: 12 }) {
                  Column() {
                    Row({ space: 8 }) {
                      Text(row.day).fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).maxLines(1)
                      Text(row.time).fontSize(13).fontFamily(F_REG).fontColor(TEXT_MUTE)
                    }
                    Text(row.title)
                      .fontSize(13)
                      .fontFamily(F_REG)
                      .fontColor(TEXT_DIM)
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .margin({ top: 3 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  Column() {
                    Text(plural(row.reps, 'rep')).fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).maxLines(1)
                    Text(row.sets + (row.sets === 1 ? ' set' : ' sets') + (row.simulated ? '  ·  sim' : ''))
                      .fontSize(12)
                      .fontFamily(F_REG)
                      .fontColor(TEXT_MUTE)
                      .maxLines(1)
                      .margin({ top: 3 })
                  }
                  .alignItems(HorizontalAlign.End)
                  Image($r('app.media.ic_chevron')).width(16).height(16).opacity(0.4)
                }
                .width('100%')
                .padding({ left: 14, right: 12, top: 12, bottom: 12 })
                if (idx < this.sessions.length - 1) {
                  Divider().color(HAIRLINE).strokeWidth(1).margin({ left: 14, right: 14 })
                }
              }
              .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.98 }))
              .onClick(() => this.openDetail(row))
            }, (row: SessionRow) => row.key)
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
    .bindSheet($$this.showDetail, this.DetailSheet(), {
      height: SheetSize.MEDIUM,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
