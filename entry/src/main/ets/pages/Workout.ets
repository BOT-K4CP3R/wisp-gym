import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppModel } from '../app/AppModel';
import { Button56, IconButton, InfoRow, Tag, Tile } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { ACCENT, BG, F_BOLD, F_REG, HAIRLINE, ON_ACCENT, PAD, SURFACE, TEXT, TEXT_DIM, TEXT_MUTE, TRACK } from '../ui/Theme';
import { AccelSample, EXERCISES, Exercise, findExercise } from '../core/Types';
import { WorkoutSession, SessionConfig } from '../core/WorkoutSession';
import { TraceOptions } from '../core/Sim';
import { MotionSource, RealAccelSource, SimulatedSource } from '../platform/MotionSource';
import { buzz } from '../platform/Haptics';

class Scenario {
  id: string;
  label: string;

  constructor(id: string, label: string) {
    this.id = id;
    this.label = label;
  }
}

const SCENARIOS: Scenario[] = [
  new Scenario('steady', 'Steady 8 reps'),
  new Scenario('fatigue', 'Slowing 10 reps')
];

@Entry
@Component
struct Workout {
  @State exerciseId: string = 'squat';
  @State phase: string = 'idle';
  @State reps: number = 0;
  @State fatigue: number = 0;
  @State cue: string = '';
  @State explanation: string = '';
  @State restLeft: number = 0;
  @State sets: number = 0;
  @State demo: boolean = false;
  @State scenario: string = 'fatigue';
  @State sensorOk: boolean = true;
  @State repScale: number = 1;
  @State showPicker: boolean = false;
  @State lastRep: string = '-';
  @State restTotal: number = 90000;
  private session: WorkoutSession = new WorkoutSession(0, false, new SessionConfig());
  private source: MotionSource | null = null;
  private timer: number = -1;
  private clockOffset: number = 0;
  private haveOffset: boolean = false;
  private restNotified: boolean = false;


  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    this.demo = AppModel.get().isDemo();
    this.session = new WorkoutSession(Date.now(), this.demo, new SessionConfig());
    this.keepScreenOn(true);
    this.timer = setInterval(() => this.onTick(), 250);
    const n = AppModel.get().notifierOrNull();
    if (n !== null) {
      n.ensureEnabled();
    }
  }

  aboutToDisappear(): void {
    this.stopSource();
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
    this.keepScreenOn(false);
  }

  private keepScreenOn(on: boolean): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      window.getLastWindow(ctx).then((w: window.Window) => {
        w.setWindowKeepScreenOn(on);
      }).catch((e: Error) => {
        console.warn('keep screen on failed: ' + e.message);
      });
    } catch (e) {
      console.warn('keep screen on unavailable');
    }
  }

  private stopSource(): void {
    if (this.source !== null) {
      this.source.stop();
      this.source = null;
    }
  }

  private makeSource(): MotionSource {
    if (!this.demo) {
      return new RealAccelSource();
    }
    const o = new TraceOptions();
    if (this.scenario === 'steady') {
      o.reps = 8;
    } else {
      o.reps = 10;
      o.slowdown = 0.7;
      o.ampDrop = 0.4;
    }
    o.tailMs = 12000;
    return new SimulatedSource(o);
  }

  private startSet(): void {
    this.cue = '';
    this.explanation = '';
    this.reps = 0;
    this.lastRep = '-';
    this.fatigue = 0;
    this.restNotified = false;
    this.haveOffset = false;
    hilog.info(0x00F1, 'WispSet', 'startSet %{public}s demo=%{public}s', this.exerciseId, '' + this.demo);
    this.session.startSet(this.exerciseId, Date.now());
    this.phase = 'set';
    this.stopSource();
    const src = this.makeSource();
    const ok = src.start((s: AccelSample) => this.onSample(s));
    this.sensorOk = ok;
    this.source = ok ? src : null;
  }

  private onSample(raw: AccelSample): void {
    if (this.session.phase() !== 'set') {
      return;
    }
    if (!this.haveOffset) {
      this.clockOffset = Date.now() - raw.t; // map sensor time onto the wall clock once
      this.haveOffset = true;
    }
    const s = new AccelSample(raw.t + this.clockOffset, raw.x, raw.y, raw.z);
    const u = this.session.onSample(s);
    if (u.newRep) {
      hilog.info(0x00F1, 'WispSet', 'REP %{public}d fatigue=%{public}s', u.reps, u.fatigue.toFixed(2));
      this.reps = u.reps;
      this.fatigue = u.fatigue;
      this.explanation = u.explanation;
      this.lastRep = u.intervalMs > 0 ? (u.intervalMs / 1000).toFixed(1) + ' s' : '-';
      this.repScale = 1.14;
      setTimeout(() => {
        this.repScale = 1;
      }, 150);
    }
    if (u.stopCue) {
      this.cue = 'Rack it: one or two reps left.';
      buzz(400);
    }
  }

  private onTick(): void {
    try {
      this.tickBody();
    } catch (e) {
      const err = e as Error;
      hilog.error(0x00F1, 'WispSet', 'tick failed: %{public}s | %{public}s', err.message, err.stack);
    }
  }

  private tickBody(): void {
    const now = Date.now();
    if (this.session.phase() === 'set') {
      const u = this.session.tick(now);
      if (u.autoEnded) {
        this.afterSetEnded();
      }
    } else if (this.session.phase() === 'rest') {
      this.restLeft = this.session.restRemainingMs(now);
      if (this.restLeft <= 0 && !this.restNotified) {
        this.restNotified = true;
        buzz(300);
        const n = AppModel.get().notifierOrNull();
        if (n !== null) {
          n.post(1, 'Rest over', 'Time for your next set.');
        }
      }
    }
    this.phase = this.session.phase();
  }

  private endSet(): void {
    this.session.endSet(Date.now());
    this.afterSetEnded();
  }

  private afterSetEnded(): void {
    this.stopSource();
    this.sets = this.session.setsDone();
    this.restTotal = Math.max(1, this.session.restTotalMs());
    hilog.info(0x00F1, 'WispSet', 'set ended, sets=%{public}d phase=%{public}s', this.sets, this.session.phase());
    this.phase = this.session.phase();
  }

  private finish(): void {
    this.stopSource();
    const rec = this.session.finish(Date.now());
    if (rec.sets.length > 0) {
      AppModel.get().addWorkout(rec);
    }
    this.getUIContext().getRouter().back();
  }

  private fmt(ms: number): string {
    const total = Math.ceil(ms / 1000);
    const m = Math.floor(total / 60);
    const s = total % 60;
    return m + ':' + (s < 10 ? '0' + s : '' + s);
  }

  private ringValue(): number {
    if (this.phase === 'rest') {
      return Math.round(100 * this.restLeft / Math.max(1, this.restTotal));
    }
    if (this.phase === 'set') {
      return Math.max(3, Math.round(this.fatigue * 100 * 2.5)); // 40% fatigue fills the ring
    }
    return 0;
  }

  private ringColor(): string {
    if (this.phase === 'set' && this.fatigue >= 0.25) {
      return ACCENT;
    }
    return TEXT;
  }

  private bigText(): string {
    if (this.phase === 'rest') {
      return this.restLeft > 0 ? this.fmt(this.restLeft) : '0:00';
    }
    return '' + this.reps;
  }

  private subLabel(): string {
    if (this.phase === 'set') {
      return this.cue.length > 0 ? 'rack it' : 'reps';
    }
    if (this.phase === 'rest') {
      return this.restLeft > 0 ? 'rest' : 'rest over';
    }
    return 'ready';
  }

  @Builder
  ExerciseSheet() {
    Column() {
      Text('Exercise')
        .fontSize(22)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
        .margin({ bottom: 8 })
      ForEach(EXERCISES, (ex: Exercise) => {
        Row() {
          Column() {
            Text(ex.name).fontSize(16).fontFamily(F_BOLD).fontColor(TEXT)
            Text(ex.placement).fontSize(12).fontFamily(F_REG).fontColor(TEXT_MUTE).margin({ top: 2 })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          if (this.exerciseId === ex.id) {
            Image($r('app.media.ic_check')).width(22).height(22)
          }
        }
        .width('100%')
        .height(64)
        .border({ width: { bottom: 1 }, color: HAIRLINE })
        .onClick(() => {
          this.exerciseId = ex.id;
          this.showPicker = false;
        })
      }, (ex: Exercise) => ex.id)
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 24 })
  }

  build() {
    Column() {
      Row({ space: 12 }) {
        IconButton({ icon: $r('app.media.ic_close'), label: 'Close', onTap: () => {
          this.stopSource();
          this.getUIContext().getRouter().back();
        } })
        Blank()
        if (this.demo) {
          Tag({ text: 'DEMO' })
        }
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 8 })

      Column() {
        Text(findExercise(this.exerciseId).name)
          .fontSize(28)
          .fontFamily(F_BOLD)
          .fontColor(TEXT)
          .onClick(() => {
            if (this.phase !== 'set') {
              this.showPicker = true;
            }
          })
        Text(this.sets === 0 ? 'First set' : 'Set ' + (this.sets + (this.phase === 'set' ? 1 : 0)))
          .fontSize(13)
          .fontFamily(F_REG)
          .fontColor(TEXT_MUTE)
          .margin({ top: 2 })
      }
      .margin({ top: 4 })

      Column() {
        Stack() {
          Progress({ value: this.ringValue(), total: 100, type: ProgressType.Ring })
            .width(240)
            .height(240)
            .color(this.ringColor())
            .backgroundColor(TRACK)
            .style({ strokeWidth: 8 })
          Column() {
            Text(this.bigText())
              .fontSize(this.phase === 'rest' ? 64 : 88)
              .fontFamily(F_BOLD)
              .fontColor(TEXT)
              .scale({ x: this.repScale, y: this.repScale })
              .animation({ duration: 150, curve: Curve.EaseOut })
            Text(this.subLabel())
              .fontSize(14)
              .fontFamily(F_BOLD)
              .fontColor(this.phase === 'set' && this.cue.length > 0 ? ACCENT : TEXT_MUTE)
          }
        }
        .width(240)
        .height(240)

        if (!this.sensorOk) {
          Text('Accelerometer unavailable. Turn on Demo mode in Settings.')
            .fontSize(12)
            .fontFamily(F_REG)
            .fontColor(TEXT_DIM)
            .textAlign(TextAlign.Center)
            .margin({ top: 16, left: PAD, right: PAD })
        }
        if (this.demo && this.phase !== 'set') {
          Row({ space: 8 }) {
            ForEach(SCENARIOS, (sc: Scenario) => {
              Text(sc.label)
                .fontSize(13)
                .fontFamily(F_BOLD)
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
                .borderRadius(18)
                .fontColor(this.scenario === sc.id ? ON_ACCENT : TEXT_DIM)
                .backgroundColor(this.scenario === sc.id ? ACCENT : SURFACE)
                .border({ width: this.scenario === sc.id ? 0 : 1, color: HAIRLINE })
                .onClick(() => {
                  this.scenario = sc.id;
                })
            }, (sc: Scenario) => sc.id)
          }
          .margin({ top: 16 })
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)

      Column() {
        Tile({ pad: 20 }) {
          InfoRow({ label: 'Sets done', value: '' + this.sets })
          InfoRow({ label: 'Last rep', value: this.lastRep })
          InfoRow({ label: 'Fatigue', value: Math.round(this.fatigue * 100) + '%', divider: false, strong: this.fatigue >= 0.25 })
        }
      }
      .padding({ left: PAD, right: PAD })

      Row({ space: 12 }) {
        IconButton({ icon: $r('app.media.ic_list'), label: 'Choose exercise', onTap: () => {
          if (this.phase !== 'set') {
            this.showPicker = true;
          }
        } })
        Column() {
          if (this.phase === 'set') {
            Button56({ label: 'End set', primary: false, onTap: () => this.endSet() })
          } else {
            Button56({ label: this.phase === 'rest' ? 'Start next set' : 'Start set', onTap: () => this.startSet() })
          }
        }
        .layoutWeight(1)
        IconButton({ icon: $r('app.media.ic_check'), label: 'Finish workout', onTap: () => this.finish() })
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 16, bottom: 12 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
    .bindSheet($$this.showPicker, this.ExerciseSheet(), {
      height: 420,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
