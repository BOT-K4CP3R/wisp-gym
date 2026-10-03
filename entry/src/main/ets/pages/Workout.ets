import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { AppModel } from '../app/AppModel';
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
  private session: WorkoutSession = new WorkoutSession(0, false, new SessionConfig());
  private source: MotionSource | null = null;
  private timer: number = -1;
  private clockOffset: number = 0;
  private haveOffset: boolean = false;
  private restNotified: boolean = false;

  aboutToAppear(): void {
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
    this.fatigue = 0;
    this.restNotified = false;
    this.haveOffset = false;
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
      this.reps = u.reps;
      this.fatigue = u.fatigue;
      this.explanation = u.explanation;
    }
    if (u.stopCue) {
      this.cue = 'Rack it: one or two reps left.';
      buzz(400);
    }
  }

  private onTick(): void {
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

  build() {
    Scroll() {
      Column() {
        Row() {
          Text('Workout')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#E8EAF6')
          Blank()
          Text(this.demo ? 'DEMO: simulated' : 'LIVE sensor')
            .fontSize(11)
            .fontColor(this.demo ? '#FFB74D' : '#81C784')
        }
        .width('100%')
        .margin({ top: 16 })

        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(EXERCISES, (ex: Exercise) => {
            Text(ex.name)
              .fontSize(13)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .margin({ right: 8, bottom: 8 })
              .borderRadius(16)
              .fontColor(this.exerciseId === ex.id ? '#FFFFFF' : '#C5CAE9')
              .backgroundColor(this.exerciseId === ex.id ? '#5C7CFA' : '#2A2C5A')
              .opacity(this.phase === 'set' ? 0.5 : 1)
              .onClick(() => {
                if (this.phase !== 'set') {
                  this.exerciseId = ex.id;
                }
              })
          }, (ex: Exercise) => ex.id)
        }
        .margin({ top: 12 })

        Text('Carry the phone: ' + findExercise(this.exerciseId).placement)
          .fontSize(12)
          .fontColor('#9FA8DA')
          .width('100%')

        Column() {
          Text('' + this.reps)
            .fontSize(96)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(this.phase === 'set' ? 'reps counted automatically' : (this.phase === 'rest' ? 'resting' : 'ready'))
            .fontSize(14)
            .fontColor('#9FA8DA')
          Progress({ value: Math.round(this.fatigue * 100), total: 100, type: ProgressType.Linear })
            .color(this.fatigue >= 0.25 ? '#FF8A65' : '#66D9A8')
            .backgroundColor('#34376B')
            .width('80%')
            .height(8)
            .margin({ top: 12 })
          Text('Tempo fatigue ' + Math.round(this.fatigue * 100) + '%')
            .fontSize(12)
            .fontColor('#9FA8DA')
            .margin({ top: 4 })
        }
        .width('100%')
        .padding(16)
        .margin({ top: 8 })
        .borderRadius(16)
        .backgroundColor('#1F2147')

        if (this.cue.length > 0) {
          Text(this.cue)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FF8A65')
            .margin({ top: 12 })
        }
        if (this.explanation.length > 0) {
          Text(this.explanation)
            .fontSize(12)
            .fontColor('#9FA8DA')
            .margin({ top: 6 })
        }
        if (this.phase === 'rest') {
          Text(this.restLeft > 0 ? 'Rest ' + this.fmt(this.restLeft) : 'Rest over. Next set when ready.')
            .fontSize(20)
            .fontColor('#66D9A8')
            .margin({ top: 12 })
        }
        if (!this.sensorOk) {
          Text('Accelerometer unavailable on this device. Turn on Demo mode on the home screen.')
            .fontSize(12)
            .fontColor('#FFB74D')
            .margin({ top: 8 })
        }
        if (this.demo && this.phase !== 'set') {
          Row() {
            ForEach(SCENARIOS, (sc: Scenario) => {
              Text(sc.label)
                .fontSize(12)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .margin({ right: 8 })
                .borderRadius(14)
                .fontColor(this.scenario === sc.id ? '#FFFFFF' : '#C5CAE9')
                .backgroundColor(this.scenario === sc.id ? '#7E57C2' : '#2A2C5A')
                .onClick(() => {
                  this.scenario = sc.id;
                })
            }, (sc: Scenario) => sc.id)
          }
          .margin({ top: 12 })
          .width('100%')
          Text('DEMO: a synthetic accelerometer stream is replayed through the real detector.')
            .fontSize(11)
            .fontColor('#FFB74D')
            .margin({ top: 4 })
            .width('100%')
        }

        if (this.phase === 'set') {
          Button('End set')
            .width('100%')
            .height(52)
            .margin({ top: 16 })
            .backgroundColor('#EF5350')
            .onClick(() => this.endSet())
        } else {
          Button(this.phase === 'rest' ? 'Start next set' : 'Start set')
            .width('100%')
            .height(52)
            .margin({ top: 16 })
            .backgroundColor('#5C7CFA')
            .onClick(() => this.startSet())
        }
        Button('Finish workout (' + this.sets + ' sets)')
          .width('100%')
          .height(44)
          .margin({ top: 10, bottom: 24 })
          .backgroundColor('#2A2C5A')
          .onClick(() => this.finish())
      }
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#14152E')
    .scrollBar(BarState.Off)
  }
}
