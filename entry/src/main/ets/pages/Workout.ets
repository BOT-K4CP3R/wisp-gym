import { window } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AppModel } from '../app/AppModel';
import { Button56, IconButton, Tag } from '../ui/Kit';
import { registerFonts } from '../ui/Fonts';
import { RouteParams, navReplace } from '../ui/Nav';
import {
  ACCENT, ACCENT_TINT, BG, DUR_FAST, F_BOLD, F_REG, HAIRLINE, ON_ACCENT, PAD, SURFACE, SURFACE_HI, TEXT, TEXT_DIM,
  TEXT_MUTE, TRACK
} from '../ui/Theme';
import { AccelSample, EXERCISES, Exercise, SetRecord, findExercise } from '../core/Types';
import { WorkoutSession, SessionConfig } from '../core/WorkoutSession';
import { AnalyzerConfig } from '../core/SetAnalyzer';
import { TraceOptions } from '../core/Sim';
import { MotionSource, RealAccelSource, SimulatedSource } from '../platform/MotionSource';
import { CreatureCanvas } from '../components/CreatureCanvas';
import { LookHolder } from '../components/LookHolder';
import { anim, fx, motionOn, press, pageDur } from '../ui/Motion';

const TAG = 'WispSet';
const COUNTDOWN_MS = 3000;

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

class DoneSet {
  key: string;
  label: string;
  fatigued: boolean;

  constructor(key: string, label: string, fatigued: boolean) {
    this.key = key;
    this.label = label;
    this.fatigued = fatigued;
  }
}

@Entry
@Component
struct Workout {
  @State exerciseId: string = 'squat';
  @State phase: string = 'idle';        // idle | countdown | set | rest (UI phase)
  @State countdown: number = 3;
  @State countScale: number = 1;
  @State reps: number = 0;
  @State fatigue: number = 0;
  @State cue: boolean = false;
  @State explanation: string = '';
  @State restLeft: number = 0;
  @State restTotal: number = 90000;
  @State sets: number = 0;
  @State totalReps: number = 0;
  @State done: DoneSet[] = [];
  @State demo: boolean = false;
  @State scenario: string = 'fatigue';
  @State sensorOk: boolean = true;
  @State noData: boolean = false;       // sensor registered but silent (e.g. an emulator)
  @State repScale: number = 1;
  @State showPicker: boolean = false;
  @State showConfirm: boolean = false;
  @State lastRep: string = '-';
  @State ringScale: number = 1;
  private session: WorkoutSession = new WorkoutSession(0, false, new SessionConfig());
  private source: MotionSource | null = null;
  private timer: number = -1;
  private clockOffset: number = 0;
  private haveOffset: boolean = false;
  private restNotified: boolean = false;
  private countdownEnd: number = 0;
  private cueFatigue: number = new AnalyzerConfig().stopFatigue;
  private leaving: boolean = false;
  private buddy: LookHolder = new LookHolder();
  private setStartedAt: number = 0;
  private gotSample: boolean = false;

  aboutToAppear(): void {
    registerFonts(this.getUIContext());
    const model = AppModel.get();
    this.demo = model.isDemo();
    this.buddy.set(model.lookFor(model.evaluateNow()), true);
    this.setFace('curious');
    const params = this.getUIContext().getRouter().getParams() as RouteParams;
    if (params !== undefined && params !== null && typeof params.exercise === 'string') {
      this.exerciseId = findExercise(params.exercise).id;
    }
    this.session = new WorkoutSession(Date.now(), this.demo, new SessionConfig());
    this.keepScreenOn(true);
    this.timer = setInterval(() => this.onTick(), 200);
    const n = model.notifierOrNull();
    if (n !== null && model.profile().restAlerts) {
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

  onPageShow(): void {
    this.buddy.active = true;
  }

  onPageHide(): void {
    this.buddy.active = false;
  }

  // System back gesture: never lose a workout by accident.
  onBackPress(): boolean {
    if (this.leaving) {
      return false;
    }
    if (this.sets > 0 || this.phase === 'set') {
      this.showConfirm = true;
      return true;
    }
    this.stopSource();
    return false;
  }

  pageTransition() {
    PageTransitionEnter({ type: RouteType.Push, duration: pageDur(380), curve: Curve.Friction })
      .slide(SlideEffect.Bottom)
    PageTransitionExit({ type: RouteType.Pop, duration: pageDur(300), curve: Curve.Friction })
      .slide(SlideEffect.Bottom)
  }

  private keepScreenOn(on: boolean): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      window.getLastWindow(ctx).then((w: window.Window) => {
        w.setWindowKeepScreenOn(on);
      }).catch((e: Error) => {
        hilog.warn(0x00F1, TAG, 'keep screen on failed: %{public}s', e.message);
      });
    } catch (e) {
      hilog.warn(0x00F1, TAG, 'keep screen on unavailable');
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
    o.seed = 7 + this.sets * 13;
    o.tailMs = 12000;
    return new SimulatedSource(o);
  }

  // ---- Flow -------------------------------------------------------------------------

  private beginCountdown(): void {
    this.phase = 'countdown';
    this.setFace('focused');
    this.countdownEnd = Date.now() + COUNTDOWN_MS;
    this.countdown = 3;
    this.bumpCount();
    AppModel.get().tick(25);
  }

  // Timer-driven emphasis uses implicit animations (.animation on the element) plus a
  // timeout. animateTo from a timer stalled all JS timers on the OpenHarmony 6.1 emulator
  // whenever the render service was late with the finish callback.
  private bumpCount(): void {
    this.countScale = 1.35;
    setTimeout(() => {
      this.countScale = 1;
    }, 140);
  }

  private cancelCountdown(): void {
    this.setFace('curious');
    this.phase = this.session.phase() === 'rest' ? 'rest' : 'idle';
  }

  private startSet(): void {
    this.cue = false;
    this.ringScale = 1;
    this.explanation = '';
    this.reps = 0;
    this.lastRep = '-';
    this.fatigue = 0;
    this.restNotified = false;
    this.haveOffset = false;
    this.noData = false;
    this.gotSample = false;
    this.setStartedAt = Date.now();
    hilog.info(0x00F1, TAG, 'startSet %{public}s demo=%{public}s', this.exerciseId, '' + this.demo);
    this.session.startSet(this.exerciseId, Date.now());
    this.setFace('focused');
    this.phase = 'set';
    this.stopSource();
    const src = this.makeSource();
    const ok = src.start((s: AccelSample) => this.onSample(s));
    this.sensorOk = ok;
    this.source = ok ? src : null;
    AppModel.get().tick(60);
  }

  private onSample(raw: AccelSample): void {
    if (this.session.phase() !== 'set') {
      return;
    }
    if (!this.gotSample) {
      this.gotSample = true;
      this.noData = false;
    }
    if (!this.haveOffset) {
      this.clockOffset = Date.now() - raw.t; // map sensor time onto the wall clock once
      this.haveOffset = true;
    }
    const s = new AccelSample(raw.t + this.clockOffset, raw.x, raw.y, raw.z);
    const u = this.session.onSample(s);
    if (u.newRep) {
      this.noData = false;
      this.reps = u.reps;
      this.fatigue = u.fatigue;
      this.explanation = u.explanation;
      this.lastRep = u.intervalMs > 0 ? (u.intervalMs / 1000).toFixed(1) + ' s' : '-';
      this.repScale = 1.16;
      setTimeout(() => {
        this.repScale = 1;
      }, 140);
      if (!u.stopCue) {
        AppModel.get().tick(18);
        if (!this.cue) {
          this.buddy.express('happy', 450);
        }
      }
    }
    if (u.stopCue) {
      this.cue = true;
      this.setFace('strain');
      this.emphasizeRing();
      AppModel.get().tick(400); // the stronger cue replaces the rep tick
    }
  }

  // One-shot "pop" of the ring for the stop cue.
  private emphasizeRing(): void {
    this.ringScale = 1.07;
    setTimeout(() => {
      this.ringScale = 1;
    }, 220);
  }

  private onTick(): void {
    try {
      this.tickBody();
    } catch (e) {
      const err = e as Error;
      hilog.error(0x00F1, TAG, 'tick failed: %{public}s | %{public}s', err.message, err.stack);
    }
  }

  private tickBody(): void {
    const now = Date.now();
    if (this.phase === 'countdown') {
      const left = Math.ceil((this.countdownEnd - now) / 1000);
      if (left <= 0) {
        this.startSet();
      } else if (left !== this.countdown) {
        this.countdown = left;
        this.bumpCount();
        AppModel.get().tick(25);
      }
      return;
    }
    const sp = this.session.phase();
    if (sp === 'set') {
      // Silent sensor after 3 s, or no rep at all after 12 s: offer the simulated stream.
      if (!this.noData && !this.demo && ((!this.gotSample && now - this.setStartedAt > 3000) ||
        (this.reps === 0 && now - this.setStartedAt > 12000))) {
        this.noData = true;
      }
      const u = this.session.tick(now);
      if (u.autoEnded) {
        this.afterSetEnded();
      }
    } else if (sp === 'rest') {
      this.restLeft = this.session.restRemainingMs(now);
      this.restTotal = Math.max(1, this.session.restTotalMs());
      if (this.restLeft <= 0 && !this.restNotified) {
        this.restNotified = true;
        this.setFace('curious');
        this.buddy.express('surprised', 1200);
        const model = AppModel.get();
        if (model.profile().restAlerts) {
          model.tick(300);
          const n = model.notifierOrNull();
          if (n !== null) {
            n.post(1, 'Rest over', 'Time for your next ' + findExercise(this.exerciseId).name.toLowerCase() + ' set.');
          }
        }
      }
      this.phase = 'rest';
    } else {
      this.phase = 'idle';
    }
  }

  private endSet(): void {
    this.session.endSet(Date.now());
    this.afterSetEnded();
  }

  private afterSetEnded(): void {
    this.stopSource();
    this.setFace('happy');
    this.buddy.express('proud', 1600);
    const all: SetRecord[] = this.session.sets();
    this.sets = all.length;
    let total = 0;
    const rows: DoneSet[] = [];
    for (let i = 0; i < all.length; i++) {
      total += all[i].reps;
      rows.push(new DoneSet('s' + i + '-' + all[i].endMs, all[i].reps + ' × ' + findExercise(all[i].exercise).name,
        all[i].fatigue >= this.cueFatigue));
    }
    this.totalReps = total;
    this.done = rows;
    this.restTotal = Math.max(1, this.session.restTotalMs());
    this.restLeft = this.session.restRemainingMs(Date.now());
    this.phase = this.session.phase() === 'rest' ? 'rest' : 'idle';
    hilog.info(0x00F1, TAG, 'set ended, sets=%{public}d phase=%{public}s', this.sets, this.phase);
  }

  private adjustRest(deltaMs: number): void {
    this.session.adjustRest(deltaMs, Date.now());
    this.restLeft = this.session.restRemainingMs(Date.now());
    this.restTotal = Math.max(1, this.session.restTotalMs());
    if (this.restLeft > 0) {
      this.restNotified = false;
    }
    AppModel.get().tick(10);
  }

  private skipRest(): void {
    this.setFace('curious');
    this.session.skipRest();
    this.restLeft = 0;
    this.phase = 'idle';
    AppModel.get().tick(10);
  }

  private finish(): void {
    this.stopSource();
    this.leaving = true;
    const rec = this.session.finish(Date.now());
    const router = this.getUIContext().getRouter();
    if (rec.sets.length > 0) {
      AppModel.get().finishWorkout(rec);
      navReplace(this.getUIContext(), 'pages/Summary');
    } else {
      router.back();
    }
  }

  private discard(): void {
    this.stopSource();
    this.leaving = true;
    this.showConfirm = false;
    this.getUIContext().getRouter().back();
  }

  private close(): void {
    if (this.sets > 0 || this.phase === 'set') {
      this.showConfirm = true;
      return;
    }
    this.stopSource();
    this.leaving = true;
    this.getUIContext().getRouter().back();
  }

  // ---- View helpers ------------------------------------------------------------------

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
      // Fills completely when the fatigue proxy reaches the "rack it" level.
      return Math.max(2, Math.min(100, Math.round(100 * this.fatigue / this.cueFatigue)));
    }
    if (this.phase === 'countdown') {
      return Math.round(100 * this.countdown / 3);
    }
    return 0;
  }

  private ringColor(): string {
    if (this.phase === 'set' && (this.cue || this.fatigue >= this.cueFatigue)) {
      return ACCENT;
    }
    if (this.phase === 'countdown') {
      return ACCENT;
    }
    return TEXT;
  }

  private bigText(): string {
    if (this.phase === 'countdown') {
      return '' + this.countdown;
    }
    if (this.phase === 'rest') {
      return this.restLeft > 0 ? this.fmt(this.restLeft) : '0:00';
    }
    if (this.phase === 'idle') {
      return this.sets === 0 ? 'Go' : '' + this.sets;
    }
    return '' + this.reps;
  }

  private subLabel(): string {
    if (this.phase === 'countdown') {
      return 'get ready';
    }
    if (this.phase === 'set') {
      return this.cue ? 'rack it' : (this.reps === 1 ? 'rep' : 'reps');
    }
    if (this.phase === 'rest') {
      return this.restLeft > 0 ? 'rest' : 'rest over';
    }
    return this.sets === 0 ? 'ready' : (this.sets === 1 ? 'set done' : 'sets done');
  }

  private hint(): string {
    const ex = findExercise(this.exerciseId);
    if (this.phase === 'countdown') {
      return 'Put the phone in place: ' + ex.placement.toLowerCase() + '.';
    }
    if (this.phase === 'set') {
      if (this.cue) {
        return this.explanation;
      }
      return this.reps < 3 ? 'Move steadily. Your first reps set the baseline.' : this.explanation;
    }
    if (this.phase === 'rest') {
      return this.restLeft > 0 ? 'Breathe. The timer buzzes when rest is over.' : 'Ready for the next set.';
    }
    return 'Phone: ' + ex.placement.toLowerCase() + '. Counting starts after a 3 s countdown.';
  }

  private confirmText(): string {
    const live = this.phase === 'set' ? this.reps : 0;
    const sets = this.sets + (live > 0 ? 1 : 0);
    if (sets === 0) {
      return 'Nothing has been counted yet.';
    }
    return 'So far: ' + sets + (sets === 1 ? ' set' : ' sets') + ' and ' + (this.totalReps + live) + ' reps.';
  }

  private primaryLabel(): string {
    if (this.phase === 'countdown') {
      return 'Cancel';
    }
    if (this.phase === 'set') {
      return 'End set';
    }
    return this.sets === 0 ? 'Start set' : 'Start next set';
  }

  // The motion sensor is silent: offer the simulated stream instead of waiting forever.
  private switchToDemo(): void {
    AppModel.get().setDemo(true);
    this.demo = true;
    this.session.markSimulated();
    this.session.endSet(Date.now());
    this.stopSource();
    this.noData = false;
    this.startSet();
  }

  private coachText(): string {
    if (!this.sensorOk) {
      return 'Motion sensor unavailable on this device. Turn on Demo mode in Settings.';
    }
    if (this.noData && this.phase === 'set') {
      return this.gotSample ? 'No reps detected yet. Check the phone placement, or tap here to try Demo mode.' :
        'No motion data from the sensor. Tap here to use Demo mode instead.';
    }
    return this.hint();
  }

  // Resting face of the little coach for the current phase; moments use buddy.express().
  private setFace(face: string): void {
    this.buddy.look.expression = face;
  }

  private onPrimary(): void {
    if (this.phase === 'countdown') {
      this.cancelCountdown();
    } else if (this.phase === 'set') {
      this.endSet();
    } else {
      this.beginCountdown();
    }
  }

  // ---- Builders ----------------------------------------------------------------------

  @Builder
  ExerciseSheet() {
    Column() {
      Text('Choose exercise')
        .fontSize(22)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
        .margin({ bottom: 8 })
      ForEach(EXERCISES, (ex: Exercise) => {
        Row({ space: 14 }) {
          Image(this.exerciseId === ex.id ? $r('app.media.ic_phone_accent') : $r('app.media.ic_phone'))
            .width(22)
            .height(22)
            .opacity(this.exerciseId === ex.id ? 1 : 0.6)
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
        .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.98 }))
        .onClick(() => {
          this.exerciseId = ex.id;
          this.showPicker = false;
          AppModel.get().tick(10);
        })
      }, (ex: Exercise) => ex.id)
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 24 })
  }

  @Builder
  ConfirmSheet() {
    Column({ space: 10 }) {
      Text('End workout?')
        .fontSize(22)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .width('100%')
      Text(this.confirmText())
        .fontSize(14)
        .fontFamily(F_REG)
        .fontColor(TEXT_DIM)
        .width('100%')
        .margin({ bottom: 8 })
      if (this.sets > 0 || this.phase === 'set') {
        Button56({ label: 'Save and finish', onTap: () => {
          this.showConfirm = false;
          this.finish();
        } })
      }
      Button56({ label: 'Discard workout', kind: 'danger', onTap: () => this.discard() })
      Button56({ label: 'Keep training', kind: 'ghost', onTap: () => {
        this.showConfirm = false;
      } })
    }
    .padding({ left: PAD, right: PAD, top: 8, bottom: 16 })
  }

  @Builder
  Ring() {
    Stack() {
      Progress({ value: this.ringValue(), total: 100, type: ProgressType.Ring })
        .width(this.ringSize())
        .height(this.ringSize())
        .color(this.ringColor())
        .backgroundColor(TRACK)
        .style({ strokeWidth: 10, enableSmoothEffect: motionOn() })
        .scale({ x: this.ringScale, y: this.ringScale })
        .animation(anim({ duration: 220, curve: Curve.EaseOut }))
      Column() {
        Text(this.bigText())
          .fontSize(this.phase === 'rest' ? 60 : (this.phase === 'idle' && this.sets === 0 ? 64 : 84))
          .fontFamily(F_BOLD)
          .fontColor(this.phase === 'countdown' ? ACCENT : TEXT)
          .scale({
            x: this.phase === 'countdown' ? this.countScale : this.repScale,
            y: this.phase === 'countdown' ? this.countScale : this.repScale
          })
          .animation(anim({ duration: 160, curve: Curve.EaseOut }))
        Text(this.subLabel())
          .fontSize(14)
          .fontFamily(F_BOLD)
          .fontColor(this.phase === 'set' && this.cue ? ACCENT : TEXT_MUTE)
          .letterSpacing(0.5)
      }
    }
    .width(this.ringSize() + 12)
    .height(this.ringSize() + 12)
    .animation(anim({ duration: DUR_FAST * 2, curve: Curve.Friction }))
  }

  // The ring shrinks a little while resting so the rest controls fit on small screens.
  private ringSize(): number {
    return this.phase === 'rest' ? 196 : 224;
  }

  @Builder
  RestControls() {
    Row({ space: 10 }) {
      Text('−15 s')
        .fontSize(14)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .height(40)
        .padding({ left: 16, right: 16 })
        .borderRadius(20)
        .backgroundColor(SURFACE_HI)
        .accessibilityText('Fifteen seconds less rest')
        .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.92 }))
        .onClick(() => this.adjustRest(-15000))
      Text('Skip')
        .fontSize(14)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .height(40)
        .padding({ left: 20, right: 20 })
        .borderRadius(20)
        .backgroundColor(SURFACE_HI)
        .accessibilityText('Skip rest')
        .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.92 }))
        .onClick(() => this.skipRest())
      Text('+15 s')
        .fontSize(14)
        .fontFamily(F_BOLD)
        .fontColor(TEXT)
        .height(40)
        .padding({ left: 16, right: 16 })
        .borderRadius(20)
        .backgroundColor(SURFACE_HI)
        .accessibilityText('Fifteen seconds more rest')
        .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.92 }))
        .onClick(() => this.adjustRest(15000))
    }
    .margin({ top: 10 })
    .transition(fx(TransitionEffect.OPACITY.animation(anim({ duration: DUR_FAST }))))
  }

  @Builder
  Scenarios() {
    Row({ space: 8 }) {
      Text('Simulated').fontSize(12).fontFamily(F_BOLD).fontColor(TEXT_MUTE)
      Row({ space: 6 }) {
        ForEach(SCENARIOS, (sc: Scenario) => {
          Text(sc.label)
            .fontSize(12)
            .fontFamily(F_BOLD)
            .height(32)
            .padding({ left: 12, right: 12 })
            .borderRadius(16)
            .fontColor(this.scenario === sc.id ? ON_ACCENT : TEXT_DIM)
            .backgroundColor(this.scenario === sc.id ? ACCENT : SURFACE)
            .border({ width: this.scenario === sc.id ? 0 : 1, color: HAIRLINE })
            .animation(anim({ duration: DUR_FAST }))
            .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.94 }))
            .onClick(() => {
              this.scenario = sc.id;
            })
        }, (sc: Scenario) => sc.id)
      }
    }
    .margin({ top: 10 })
    .transition(fx(TransitionEffect.OPACITY.animation(anim({ duration: DUR_FAST }))))
  }

  build() {
    Column() {
      // Top bar: close, exercise selector, demo badge
      Row({ space: 10 }) {
        IconButton({ icon: $r('app.media.ic_close'), label: 'Close workout', onTap: () => this.close() })
        Row({ space: 6 }) {
          Text(findExercise(this.exerciseId).name)
            .fontSize(17)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
            .maxLines(1)
          if (this.phase !== 'set' && this.phase !== 'countdown') {
            Image($r('app.media.ic_down')).width(16).height(16).opacity(0.7)
          }
        }
        .height(44)
        .padding({ left: 16, right: 14 })
        .borderRadius(22)
        .backgroundColor(SURFACE)
        .border({ width: 1, color: HAIRLINE })
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .accessibilityText('Exercise: ' + findExercise(this.exerciseId).name + '. Tap to change.')
        .clickEffect(this.phase === 'set' || this.phase === 'countdown' ? null : press({ level: ClickEffectLevel.LIGHT, scale: 0.96 }))
        .onClick(() => {
          if (this.phase !== 'set' && this.phase !== 'countdown') {
            this.showPicker = true;
          }
        })
        if (this.demo) {
          Tag({ text: 'DEMO', accent: true }).width(56)
        } else {
          Blank().width(48)
        }
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 8 })
      .bindSheet($$this.showConfirm, this.ConfirmSheet(), {
        height: 330,
        showClose: false,
        dragBar: true,
        backgroundColor: SURFACE
      })

      // Ring + hint
      if (this.demo && (this.phase === 'idle' || this.phase === 'rest')) {
        this.Scenarios()
      }
      Column() {
        this.Ring()
        if (this.phase === 'rest' && this.restLeft > 0) {
          this.RestControls()
        }
      }
      .layoutWeight(1)
      .width('100%')
      .justifyContent(FlexAlign.Center)

      // Coaching line (fatigue explanation, placement, rest)
      Column() {
        Row({ space: 10 }) {
          // The creature coaches along: its face follows the set (see setFace)
          Column() {
            CreatureCanvas({ holder: this.buddy, label: '', canvasHeight: 52 })
          }
          .width(52)
          .height(52)
          Text(this.coachText())
            .fontSize(13)
            .fontFamily(F_REG)
            .fontColor(this.cue && this.phase === 'set' ? TEXT : TEXT_DIM)
            .layoutWeight(1)
            .maxLines(3)
        }
        .width('100%')
        .padding(14)
        .borderRadius(18)
        .backgroundColor((this.cue || this.noData) && this.phase === 'set' ? ACCENT_TINT : SURFACE)
        .border({ width: 1, color: (this.cue || this.noData) && this.phase === 'set' ? '#40FF8A5B' : HAIRLINE })
        .animation(anim({ duration: DUR_FAST }))
        .constraintSize({ minHeight: 64 })
        .onClick(() => {
          if (this.noData && this.phase === 'set') {
            this.switchToDemo();
          }
        })
      }
      .padding({ left: PAD, right: PAD })

      // Live stats
      Row() {
        Column({ space: 2 }) {
          Text('' + this.sets).fontSize(20).fontFamily(F_BOLD).fontColor(TEXT)
          Text('sets').fontSize(11).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text('' + (this.totalReps + (this.phase === 'set' ? this.reps : 0))).fontSize(20).fontFamily(F_BOLD).fontColor(TEXT)
          Text('total reps').fontSize(11).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text(this.lastRep).fontSize(20).fontFamily(F_BOLD).fontColor(TEXT)
          Text('last rep').fontSize(11).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
        .layoutWeight(1)
        Column({ space: 2 }) {
          Text(Math.round(this.fatigue * 100) + '%')
            .fontSize(20)
            .fontFamily(F_BOLD)
            .fontColor(this.fatigue >= this.cueFatigue ? ACCENT : TEXT)
          Text('fatigue').fontSize(11).fontFamily(F_REG).fontColor(TEXT_MUTE)
        }
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 14 })

      // Completed sets
      if (this.done.length > 0) {
        Scroll() {
          Row({ space: 8 }) {
            ForEach(this.done, (d: DoneSet) => {
              Text(d.label)
                .fontSize(12)
                .fontFamily(F_BOLD)
                .fontColor(d.fatigued ? ACCENT : TEXT_DIM)
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .borderRadius(14)
                .backgroundColor(SURFACE)
                .border({ width: 1, color: HAIRLINE })
                .transition(fx(TransitionEffect.OPACITY.combine(TransitionEffect.scale({ x: 0.8, y: 0.8 }))
                  .animation(anim({ duration: 260, curve: Curve.Friction }))))
            }, (d: DoneSet) => d.key)
          }
          .padding({ left: PAD, right: PAD })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .margin({ top: 12 })
      }

      // Actions
      Row({ space: 12 }) {
        Column() {
          Button56({ label: this.primaryLabel(), kind: this.phase === 'set' || this.phase === 'countdown' ? 'secondary' : 'primary',
            onTap: () => this.onPrimary() })
        }
        .layoutWeight(1)
        if (this.sets > 0 && this.phase !== 'set' && this.phase !== 'countdown') {
          Text('Finish')
            .fontSize(17)
            .fontFamily(F_BOLD)
            .fontColor(TEXT)
            .height(56)
            .padding({ left: 22, right: 22 })
            .borderRadius(28)
            .backgroundColor(SURFACE_HI)
            .border({ width: 1, color: HAIRLINE })
            .accessibilityText('Finish workout')
            .clickEffect(press({ level: ClickEffectLevel.LIGHT, scale: 0.94 }))
            .transition(fx(TransitionEffect.OPACITY.combine(TransitionEffect.translate({ x: 40 }))
              .animation(anim({ duration: 260, curve: Curve.Friction }))))
            .onClick(() => this.finish())
        }
      }
      .width('100%')
      .padding({ left: PAD, right: PAD, top: 14, bottom: 14 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(BG)
    .bindSheet($$this.showPicker, this.ExerciseSheet(), {
      height: 440,
      showClose: false,
      dragBar: true,
      backgroundColor: SURFACE
    })
  }
}
