import { AppModel } from '../app/AppModel';
import { BmiInfo, WeightEntry, WeightStats, bmiInfo, formatDelta, formatKg, series, weightStats } from '../core/Body';
import { dayLabel } from '../core/Plan';
import { ChartData, LineChart } from '../components/LineChart';
import { Button56, Chip, EmptyState, IconButton, Reveal, SectionLabel, Tile, TitleBlock } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { press } from '../ui/Motion';
import {
  ACCENT, ACCENT_SOFT, BG, F_BOLD, F_REG, GAP, HAIRLINE, PAD, STAGGER, SURFACE, SURFACE_HI, TEXT, TEXT_DIM, TEXT_MUTE,
  TRACK
} from '../ui/Theme';

class Row4 {
  key: string;
  day: string;
  kg: string;
  delta: string;
  atMs: number;

  constructor(key: string, day: string, kg: string, delta: string, atMs: number) {
    this.key = key;
    this.day = day;
    this.kg = kg;
    this.delta = delta;
    this.atMs = atMs;
  }
}

const RANGES: number[] = [30, 90, 3650];
const RANGE_LABELS: string[] = ['30 days', '90 days', 'All'];

// Body weight: log weigh-ins, see the trend and the goal, and BMI from height and weight.
@Entry
@Component
struct Body {
  @State stage: number = 0;
  @State stats: WeightStats = new WeightStats();
  @State bmi: BmiInfo = new BmiInfo();
  @State rows: Row4[] = [];
  @State range: number = 0;
  @State chartVersion: number = 0;
  @State heightCm: number = 0;
  @State goalKg: number = 0;
  @State editKey: string = '';           // weight | goal | height
  @State editValue: number = 0;
  @State showEdit: boolean = false;
  @State deleteAt: number = 0;
  @State showDelete: boolean = false;
  private chart: ChartData = new ChartData();
  private entries: WeightEntry[] = [];

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    // Lower sections are built in the next frame: on slow (software-rendered) devices one
    // big first frame can exceed the system's 6 s main-thread watchdog.
    setTimeout(() => {
      this.stage = 1;
    }, 120);
    this.load();
  }

  private load(): void {
    const model = AppModel.get();
    const p = model.profile();
    this.heightCm = p.heightCm;
    this.goalKg = p.goalKg;
    this.entries = model.weights();
    const now = Date.now();
    this.stats = weightStats(this.entries, this.goalKg, now);
    this.bmi = bmiInfo(this.stats.latest, this.heightCm);
    const rows: Row4[] = [];
    for (let i = this.entries.length - 1; i >= 0 && rows.length < 40; i--) {
      const e = this.entries[i];
      const prev = i > 0 ? this.entries[i - 1].kg : e.kg;
      rows.push(new Row4('w' + e.atMs, dayLabel(e.atMs, now), formatKg(e.kg), i > 0 ? formatDelta(e.kg - prev) : 'first',
        e.atMs));
    }
    this.rows = rows;
    this.fillChart();
  }

  private fillChart(): void {
    const s = series(this.entries, Date.now(), RANGES[this.range]);
    this.chart.xs = s.map((e: WeightEntry) => e.atMs);
    this.chart.ys = s.map((e: WeightEntry) => e.kg);
    this.chart.goal = this.goalKg;
    this.chartVersion++;
  }

  private toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1800 });
    } catch (e) {
      // cosmetic
    }
  }

  private openEdit(key: string): void {
    this.editKey = key;
    if (key === 'weight') {
      this.editValue = this.stats.latest > 0 ? this.stats.latest : (this.goalKg > 0 ? this.goalKg : 75);
    } else if (key === 'goal') {
      this.editValue = this.goalKg > 0 ? this.goalKg : (this.stats.latest > 0 ? Math.round(this.stats.latest) : 75);
    } else {
      this.editValue = this.heightCm > 0 ? this.heightCm : 175;
    }
    this.showEdit = true;
  }

  private step(delta: number): void {
    const lo = this.editKey === 'height' ? 100 : 30;
    const hi = this.editKey === 'height' ? 250 : 300;
    this.editValue = Math.round(Math.min(hi, Math.max(lo, this.editValue + delta)) * 10) / 10;
    AppModel.get().tick(6);
  }

  private saveEdit(): void {
    const model = AppModel.get();
    if (this.editKey === 'weight') {
      model.logWeight(this.editValue);
      this.toast('Logged ' + formatKg(this.editValue));
    } else {
      const p = model.profile();
      if (this.editKey === 'goal') {
        p.goalKg = this.editValue;
      } else {
        p.heightCm = this.editValue;
      }
      model.saveProfile(p);
    }
    this.showEdit = false;
    model.tick(20);
    this.load();
  }

  private editTitle(): string {
    if (this.editKey === 'weight') {
      return 'Log today\'s weight';
    }
    return this.editKey === 'goal' ? 'Goal weight' : 'Your height';
  }

  private editUnit(): string {
    return this.editKey === 'height' ? 'cm' : 'kg';
  }

  private goalLine(): string {
    if (this.goalKg <= 0) {
      return 'Set a goal to see your progress.';
    }
    if (this.stats.count === 0) {
      return 'Log your weight to start tracking.';
    }
    const left = Math.abs(this.stats.toGoal);
    if (left < 0.05) {
      return 'Goal reached. Keep it steady.';
    }
    let eta = '';
    if (this.stats.etaDays > 0) {
      const weeks = Math.round(this.stats.etaDays / 7);
      eta = weeks <= 1 ? ' About a week at this pace.' : ' About ' + weeks + ' weeks at this pace.';
    }
    return formatKg(left) + (this.stats.toGoal < 0 ? ' to lose.' : ' to gain.') + eta;
  }

  @Builder
  Delta(label: string, key: string) {
    Column({ space: 2 }) {
      Text(this.deltaText(key))
        .fontSize(17)
        .maxFontSize(17)
        .minFontSize(12)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .maxLines(1)
      Text(label).fontSize(11).fontFamily(F_REG).fontColor(TEXT_MUTE).maxLines(1)
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  private deltaText(key: string): string {
    if (this.stats.count < 2) {
      return '-';
    }
    const span = this.entries.length > 0 ? this.stats.latestAt - this.entries[0].atMs : 0;
    if (key === '7') {
      return span >= 7 * 86400000 ? formatDelta(this.stats.change7) : '-';
    }
    if (key === '30') {
      return span >= 30 * 86400000 ? formatDelta(this.stats.change30) : '-';
    }
    if (key === 'rate') {
      return formatDelta(this.stats.weeklyRate) + '/wk';
    }
    return formatDelta(this.stats.change);
  }

  @Builder
  EditSheet() {
    Column({ space: 16 }) {
      Text(this.editTitle()).fontSize(22).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
      Row({ space: 10 }) {
        IconButton({ icon: $r('app.media.ic_minus'), label: 'Minus one', diameter: 44, onTap: () => this.step(-1) })
        Text('−0.1')
          .fontSize(14)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .height(44)
          .padding({ left: 12, right: 12 })
          .borderRadius(22)
          .backgroundColor(SURFACE_HI)
          .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.92 }))
          .onClick(() => this.step(this.editKey === 'height' ? -0.5 : -0.1))
        Column() {
          Text(this.editValue.toFixed(this.editKey === 'height' ? 0 : 1))
            .fontSize(40)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
          Text(this.editUnit()).fontSize(13).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
        .layoutWeight(1)
        Text('+0.1')
          .fontSize(14)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .height(44)
          .padding({ left: 12, right: 12 })
          .borderRadius(22)
          .backgroundColor(SURFACE_HI)
          .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.92 }))
          .onClick(() => this.step(this.editKey === 'height' ? 0.5 : 0.1))
        IconButton({ icon: $r('app.media.ic_plus'), label: 'Plus one', diameter: 44, onTap: () => this.step(1) })
      }
      .width('100%')
      if (this.editKey === 'weight' && this.heightCm > 0) {
        Text('BMI ' + bmiInfo(this.editValue, this.heightCm).value.toFixed(1) + '  ·  ' +
          bmiInfo(this.editValue, this.heightCm).label)
          .fontSize(13)
          .fontFamily(F_REG)
          .fontColor(TEXT_DIM)
          .width('100%')
          .textAlign(TextAlign.Center)
      }
      Button56({ label: 'Save', onTap: () => this.saveEdit() })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 36 })
  }

  @Builder
  DeleteSheet() {
    Column({ space: 10 }) {
      Text('Delete this weigh-in?').fontSize(22).fontFamily(F_BOLD).fontColor(TEXT).width('100%')
      Text(this.deleteAt > 0 ? dayLabel(this.deleteAt, Date.now()) : '')
        .fontSize(14)
        .fontFamily(F_REG)
        .fontColor(TEXT_DIM)
        .width('100%')
        .margin({ bottom: 8 })
      Button56({ label: 'Delete', kind: 'danger', onTap: () => {
        AppModel.get().removeWeight(this.deleteAt);
        this.showDelete = false;
        this.load();
      } })
      Button56({ label: 'Cancel', kind: 'ghost', onTap: () => {
        this.showDelete = false;
      } })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 36 })
  }

  @Builder
  BmiGauge() {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Start }) {
        Row() {
          Column().layoutWeight(14).height(8).backgroundColor('#5E6B8A').borderRadius({ topLeft: 4, bottomLeft: 4 })
          Column().layoutWeight(26).height(8).backgroundColor('#7FB58A')
          Column().layoutWeight(20).height(8).backgroundColor('#D9B45A')
          Column().layoutWeight(40).height(8).backgroundColor(ACCENT).borderRadius({ topRight: 4, bottomRight: 4 })
        }
        .width('100%')
        if (this.bmi.value > 0) {
          Column()
            .width(4)
            .height(18)
            .borderRadius(2)
            .backgroundColor(TEXT)
            .position({ x: (this.bmi.position * 100).toFixed(1) + '%', y: -5 })
        }
      }
      .width('100%')
      .height(10)
      Row() {
        Text('15').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE).layoutWeight(14)
        Text('18.5').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE).layoutWeight(26)
        Text('25').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE).layoutWeight(20)
        Text('30').fontSize(10).fontFamily(F_REG).fontColor(TEXT_MUTE).layoutWeight(40)
      }
      .width('100%')
    }
    .margin({ top: 14 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        IconButton({ icon: $r('app.media.ic_back'), label: 'Back', onTap: () => this.getUIContext().getRouter().back() })
        Text('Body').fontSize(22).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 8, bottom: 8 })
      .bindSheet($$this.showDelete, this.DeleteSheet(), {
        height: SheetSize.FIT_CONTENT,
        showClose: false,
        dragBar: true,
        backgroundColor: SURFACE
      })

      Scroll() {
        Column({ space: GAP }) {
          Reveal({ delay: 0 }) {
            Tile({ pad: 20 }) {
              if (this.stats.count === 0) {
                EmptyState({
                  icon: $r('app.media.ic_target_accent'),
                  title: 'No weigh-ins yet',
                  detail: 'Log your weight once a week or every morning. Only you see it.'
                })
              } else {
                Row() {
                  Column() {
                    Text(formatKg(this.stats.latest)).fontSize(40).fontFamily(F_BOLD).fontColor(TEXT)
                    Text('Latest  ·  ' + dayLabel(this.stats.latestAt, Date.now()))
                      .fontSize(12)
                      .fontFamily(F_REG)
                      .fontColor(TEXT_MUTE)
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                }
                .width('100%')
                Row({ space: 8 }) {
                  this.Delta('7 days', '7')
                  this.Delta('30 days', '30')
                  this.Delta('since start', 'all')
                  this.Delta('trend', 'rate')
                }
                .width('100%')
                .margin({ top: 16 })
              }
            }
          }

          if (this.stats.count > 0) {
            Reveal({ delay: STAGGER }) {
              Tile({ pad: 16 }) {
                Row({ space: 6 }) {
                  ForEach(RANGE_LABELS, (label: string, i: number) => {
                    Text(label)
                      .fontSize(12)
                      .fontFamily(F_BOLD)
                      .fontColor(this.range === i ? TEXT : TEXT_MUTE)
                      .height(32)
                      .padding({ left: 12, right: 12 })
                      .borderRadius(16)
                      .backgroundColor(this.range === i ? SURFACE_HI : '#00000000')
                      .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.94 }))
                      .onClick(() => {
                        this.range = i;
                        this.fillChart();
                      })
                  }, (label: string) => label)
                }
                .width('100%')
                .margin({ bottom: 8 })
                LineChart({ data: this.chart, version: this.chartVersion, chartHeight: 170 })
              }
            }
          }

          Reveal({ delay: STAGGER * 2 }) {
            Tile({ pad: 20, tappable: true, onTap: () => this.openEdit('goal') }) {
              Row() {
                TitleBlock({ title: 'Goal', subtitle: this.goalLine() })
                  .layoutWeight(1)
                Text(this.goalKg > 0 ? formatKg(this.goalKg) : 'Set')
                  .fontSize(22)
                  .fontFamily(F_BOLD)
                  .fontColor(this.goalKg > 0 ? TEXT : ACCENT)
              }
              .width('100%')
              if (this.goalKg > 0 && this.stats.count > 0) {
                Progress({ value: Math.round(this.stats.goalProgress * 100), total: 100, type: ProgressType.Linear })
                  .width('100%')
                  .color(ACCENT)
                  .backgroundColor(TRACK)
                  .style({ strokeWidth: 6, strokeRadius: 3, enableSmoothEffect: false })
                  .margin({ top: 14 })
              }
            }
          }

          Reveal({ delay: STAGGER * 3 }) {
            Tile({ pad: 20, tappable: true, onTap: () => this.openEdit('height') }) {
              Row() {
                TitleBlock({
                  title: 'BMI',
                  subtitle: this.heightCm > 0 ? 'Height ' + this.heightCm.toFixed(0) + ' cm  ·  tap to change' :
                    'Add your height to see it'
                })
                  .layoutWeight(1)
                Column() {
                  Text(this.bmi.value > 0 ? this.bmi.value.toFixed(1) : '-')
                    .fontSize(26)
                    .fontFamily(F_BOLD)
                    .fontColor(TEXT)
                  Text(this.bmi.label).fontSize(11).fontFamily(F_BOLD).fontColor(ACCENT)
                }
                .alignItems(HorizontalAlign.End)
              }
              .width('100%')
              this.BmiGauge()
              Text(this.bmi.value > 0 ? this.bmi.detail + '. BMI is a rough guide: it does not see muscle.' :
                (this.heightCm > 0 ? 'Log your weight to see your BMI.' : 'BMI uses your height and latest weight.'))
                .fontSize(12)
                .fontFamily(F_REG)
                .fontColor(TEXT_MUTE)
                .width('100%')
                .margin({ top: 12 })
            }
          }

          if (this.stage >= 1) {
            if (this.rows.length > 0) {
              SectionLabel({ text: 'Weigh-ins' })
              Tile({ pad: 6 }) {
                ForEach(this.rows, (r: Row4, idx: number) => {
                  Column() {
                    Row({ space: 12 }) {
                      Text(r.day).fontSize(14).fontFamily(F_BOLD).fontColor(TEXT).layoutWeight(1)
                      Text(r.delta).fontSize(12).fontFamily(F_REG).fontColor(TEXT_MUTE)
                      Text(r.kg).fontSize(15).fontFamily(F_BOLD).fontColor(TEXT).width(76).textAlign(TextAlign.End)
                    }
                    .width('100%')
                    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                    if (idx < this.rows.length - 1) {
                      Divider().color(HAIRLINE).strokeWidth(1).margin({ left: 14, right: 14 })
                    }
                  }
                  .accessibilityText(r.day + ', ' + r.kg + '. Tap to delete.')
                  .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.98 }))
                  .onClick(() => {
                    this.deleteAt = r.atMs;
                    this.showDelete = true;
                  })
                }, (r: Row4) => r.key + r.kg)
              }
              Text('Tap a weigh-in to delete it. Weights stay on this phone.')
                .fontSize(12)
                .fontFamily(F_REG)
                .fontColor(TEXT_MUTE)
                .width('100%')
                .padding({ left: 4 })
            }
          }
          Blank().height(90)
        }
        .padding({ left: PAD, right: PAD })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      Column() {
        Button56({ label: 'Log weight', onTap: () => this.openEdit('weight') })
      }
      .padding({ left: PAD, right: PAD, top: 8, bottom: 14 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
    .bindSheet($$this.showEdit, this.EditSheet(), {
      height: SheetSize.FIT_CONTENT,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
