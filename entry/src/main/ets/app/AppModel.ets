import { common } from '@kit.AbilityKit';
import { formProvider, formBindingData } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HistoryStore, KeyValueStore, MemoryStore } from '../core/Store';
import { LifeEngine, LifeConfig, CreatureState } from '../core/LifeEngine';
import { CreatureLook, lookFor } from '../core/CreatureLook';
import { WorkoutRecord } from '../core/Types';
import { generateHistory } from '../core/Sim';
import { Profile, ProfileStore } from '../core/Profile';
import { moodInfo } from '../core/Mood';
import { NextAction, WeekStats, WorkoutSummary, formatSteps, nextAction, summarize, weekStats } from '../core/Plan';
import { AnalyzerConfig } from '../core/SetAnalyzer';
import { PrefsStore } from '../platform/PrefsStore';
import { StepService } from '../platform/StepService';
import { Notifier } from '../platform/Notifier';
import { buzz } from '../platform/Haptics';

const TAG = 'WispApp';
const DOMAIN = 0x0010;
const KEY_DEMO = 'demo.mode';
const KEY_FORMS = 'form.ids';
const KEY_STEPS = 'steps.today';
const DEMO_SEED = 20261003;

// AppStorage key used to route a widget tap (or other deep link) to a screen.
export const NAV_TARGET = 'wisp.navTarget';

// Flat, serialisable snapshot pushed to the home-screen widgets.
export class WidgetData {
  name: string = 'Wisp';
  mood: string = 'curious';
  moodLabel: string = 'Curious';
  moodShort: string = 'Ready when you are';
  eyes: string = 'open';          // open | half | closed | happy
  sparkle: boolean = false;
  hue: string = '#FF8A5B';
  hueLight: string = '#FFC2A3';
  hueDark: string = '#B4502C';
  legs: number = 1;
  push: number = 1;
  pull: number = 1;
  core: number = 1;
  train: number = 0;
  recover: number = 100;
  move: number = 0;
  steps: string = '0';
  stepsKnown: boolean = true;
  week: string = '0/3';
  weekDone: number = 0;
  weekGoal: number = 3;
  nextTitle: string = 'Do your first set';
  demo: boolean = false;
  updated: string = '';
}

// App-wide singleton: storage, engine and platform helpers. Created once per process (the
// app and the widget extension each have one) and shared by pages.
export class AppModel {
  private static instance: AppModel | null = null;

  static get(): AppModel {
    if (AppModel.instance === null) {
      AppModel.instance = new AppModel();
    }
    return AppModel.instance;
  }

  private kv: KeyValueStore = new MemoryStore();
  private prefs: PrefsStore | null = null;
  // Widget ids live in their own file: the widget process writes them, the app reads them.
  private forms: KeyValueStore = new MemoryStore();
  private formsPrefs: PrefsStore | null = null;
  private store: HistoryStore = new HistoryStore(new MemoryStore());
  private profiles: ProfileStore = new ProfileStore(new MemoryStore());
  private context: common.Context | null = null;
  private stepSvc: StepService | null = null;
  private notifier: Notifier | null = null;
  private lastSteps: number = -1;
  private summary: WorkoutSummary | null = null;

  init(context: common.Context): void {
    if (this.context !== null) {
      return;
    }
    this.context = context;
    this.prefs = new PrefsStore(context, 'wisp');
    this.kv = this.prefs;
    this.formsPrefs = new PrefsStore(context, 'wisp_forms');
    this.forms = this.formsPrefs;
    this.store = new HistoryStore(this.kv);
    this.profiles = new ProfileStore(this.kv);
    this.stepSvc = new StepService(context, this.kv);
  }

  // The widget process has its own Preferences cache; drop it so it sees the app's writes.
  reloadFromDisk(): void {
    if (this.prefs !== null) {
      this.prefs.reload();
    }
  }

  // Notifications need a UIAbilityContext, which the widget extension does not have.
  attachUiContext(ctx: common.UIAbilityContext): void {
    this.notifier = new Notifier(ctx);
  }

  // ---- Profile ----------------------------------------------------------------------

  profile(): Profile {
    return this.profiles.load();
  }

  saveProfile(p: Profile): void {
    this.profiles.save(p);
    this.pushWidget();
  }

  config(): LifeConfig {
    const p = this.profile();
    const cfg = new LifeConfig();
    cfg.name = p.name;
    cfg.stepsGoal = p.stepGoal;
    return cfg;
  }

  isDemo(): boolean {
    return this.kv.get(KEY_DEMO) === '1';
  }

  setDemo(on: boolean): void {
    this.kv.put(KEY_DEMO, on ? '1' : '0');
    this.pushWidget();
  }

  // ---- History ----------------------------------------------------------------------

  workouts(): WorkoutRecord[] {
    return this.store.load();
  }

  // Stores a finished workout and prepares the summary screen (before/after levels).
  finishWorkout(w: WorkoutRecord): WorkoutSummary {
    const before = this.evaluateNow();
    this.store.add(w);
    const after = this.evaluateNow();
    this.summary = summarize(w, before, after, new AnalyzerConfig().stopFatigue);
    this.pushWidget();
    return this.summary;
  }

  lastSummary(): WorkoutSummary | null {
    return this.summary;
  }

  loadDemoHistory(): void {
    const all = generateHistory(Date.now(), 14, DEMO_SEED);
    this.store.clear();
    for (let i = 0; i < all.length; i++) {
      this.store.add(all[i]);
    }
    this.setDemo(true);
    this.pushWidget();
  }

  resetHistory(): void {
    this.store.clear();
    this.pushWidget();
  }

  // Erases history, profile and demo mode: the app starts over with the introduction.
  resetAll(): void {
    this.store.clear();
    this.kv.put(KEY_DEMO, '0');
    this.kv.put(KEY_STEPS, '');
    this.profiles.save(new Profile());
    this.summary = null;
    this.pushWidget();
  }

  // Reps per calendar day for the last `days` days, oldest first.
  repsPerDay(days: number): number[] {
    const ws = this.workouts();
    const out: number[] = [];
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    for (let k = days - 1; k >= 0; k--) {
      const d = new Date(today.getTime());
      d.setDate(d.getDate() - k);
      const from = d.getTime();
      const n = new Date(from);
      n.setDate(n.getDate() + 1);
      const to = n.getTime();
      let reps = 0;
      for (let i = 0; i < ws.length; i++) {
        if (ws[i].endMs >= from && ws[i].endMs < to) {
          for (let s = 0; s < ws[i].sets.length; s++) {
            reps += ws[i].sets[s].reps;
          }
        }
      }
      out.push(reps);
    }
    return out;
  }

  weekStats(): WeekStats {
    return weekStats(this.workouts(), Date.now());
  }

  seed(): number {
    return this.store.seed();
  }

  notifierOrNull(): Notifier | null {
    return this.notifier;
  }

  // ---- Steps ------------------------------------------------------------------------

  // Steps for today. Demo mode uses a clearly labelled simulated value that grows through
  // the day. Returns -1 when the pedometer is unavailable or permission was refused.
  async steps(): Promise<number> {
    let v = -1;
    if (this.isDemo()) {
      v = demoSteps(Date.now());
    } else if (this.stepSvc !== null) {
      v = await this.stepSvc.readToday();
    }
    this.lastSteps = v;
    this.kv.put(KEY_STEPS, dayKey(Date.now()) + '|' + v);
    return v;
  }

  // Last known value for today without touching the sensor (used by the widget process).
  stepsToday(): number {
    if (this.lastSteps >= 0) {
      return this.lastSteps;
    }
    if (this.isDemo()) {
      return demoSteps(Date.now());
    }
    const raw = this.kv.get(KEY_STEPS);
    const bar = raw.indexOf('|');
    if (bar > 0 && raw.substring(0, bar) === dayKey(Date.now())) {
      const n = parseInt(raw.substring(bar + 1), 10);
      return isNaN(n) ? -1 : n;
    }
    return -1;
  }

  async requestMotionPermission(): Promise<boolean> {
    if (this.stepSvc !== null) {
      return await this.stepSvc.requestPermission();
    }
    return false;
  }

  // ---- Creature ---------------------------------------------------------------------

  async state(): Promise<CreatureState> {
    const steps = await this.steps();
    return new LifeEngine(this.config()).evaluate(Date.now(), this.workouts(), Math.max(0, steps));
  }

  evaluateNow(): CreatureState {
    return new LifeEngine(this.config()).evaluate(Date.now(), this.workouts(), Math.max(0, this.stepsToday()));
  }

  nextAction(st: CreatureState): NextAction {
    const p = this.profile();
    return nextAction(st, this.config(), this.weekStats().sessions, p.weeklyGoal, Math.max(0, this.stepsToday()));
  }

  lookFor(state: CreatureState): CreatureLook {
    return lookFor(state, this.seed());
  }

  // Light confirmation tick, respecting the user's haptics setting.
  tick(ms: number): void {
    if (this.profile().haptics) {
      buzz(ms);
    }
  }

  // ---- Home-screen widget -------------------------------------------------------------

  registerForm(formId: string): void {
    const ids = this.formIds();
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      this.forms.put(KEY_FORMS, JSON.stringify(ids));
    }
  }

  unregisterForm(formId: string): void {
    const ids = this.formIds().filter((id: string) => id !== formId);
    this.forms.put(KEY_FORMS, JSON.stringify(ids));
  }

  widgetData(): WidgetData {
    const st = this.evaluateNow();
    const look = this.lookFor(st);
    const p = this.profile();
    const info = moodInfo(st.mood);
    const steps = this.stepsToday();
    const d = new WidgetData();
    d.name = p.name;
    d.mood = st.mood;
    d.moodLabel = info.label;
    d.moodShort = info.short;
    d.eyes = look.happyEyes ? 'happy' : (look.eyeOpen < 0.3 ? 'closed' : (look.eyeOpen < 0.7 ? 'half' : 'open'));
    d.sparkle = st.mood === 'thriving' || st.mood === 'proud';
    d.hue = hslToHex(look.hue, 72, 62);
    d.hueLight = hslToHex((look.hue + 10) % 360, 86, 80);
    d.hueDark = hslToHex((look.hue + 350) % 360, 62, 42);
    d.legs = look.legs;
    d.push = look.push;
    d.pull = look.pull;
    d.core = look.core;
    d.train = Math.round(st.train * 100);
    d.recover = Math.round(st.recover * 100);
    d.move = Math.round(st.move * 100);
    d.stepsKnown = steps >= 0;
    d.steps = steps >= 0 ? formatSteps(steps) : '--';
    d.weekDone = this.weekStats().sessions;
    d.weekGoal = p.weeklyGoal;
    d.week = d.weekDone + '/' + p.weeklyGoal;
    d.nextTitle = this.nextAction(st).title;
    d.demo = this.isDemo();
    const now = new Date();
    d.updated = now.getHours() + ':' + (now.getMinutes() < 10 ? '0' : '') + now.getMinutes();
    return d;
  }

  pushWidget(): void {
    const ids = this.formIds();
    if (ids.length === 0) {
      return;
    }
    let data: formBindingData.FormBindingData;
    try {
      data = formBindingData.createFormBindingData(this.widgetData());
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'widget data failed: %{public}s', JSON.stringify(e));
      return;
    }
    for (let i = 0; i < ids.length; i++) {
      const id = ids[i];
      formProvider.updateForm(id, data).catch((e: Error) => {
        hilog.warn(DOMAIN, TAG, 'updateForm %{public}s failed: %{public}s', id, e.message);
      });
    }
  }

  private formIds(): string[] {
    if (this.formsPrefs !== null) {
      this.formsPrefs.reload();
    }
    let raw = this.forms.get(KEY_FORMS);
    if (raw.length === 0) {
      raw = this.kv.get(KEY_FORMS); // ids stored by version 1.0 in the main file
      if (raw.length === 0) {
        return [];
      }
      this.forms.put(KEY_FORMS, raw);
    }
    try {
      const parsed = JSON.parse(raw) as string[];
      return parsed instanceof Array ? parsed.filter((v: string) => typeof v === 'string' && v.length > 0) : [];
    } catch (e) {
      return [];
    }
  }
}

function dayKey(ms: number): string {
  const d = new Date(ms);
  return d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
}

// Simulated steps for demo mode: a smooth ramp from the morning to the evening.
export function demoSteps(nowMs: number): number {
  const d = new Date(nowMs);
  const h = d.getHours() + d.getMinutes() / 60;
  const ramp = Math.min(1, Math.max(0.12, (h - 7) / 12));
  return Math.round(9400 * ramp / 10) * 10;
}

export function hslToHex(h: number, s: number, l: number): string {
  const sat = s / 100;
  const lig = l / 100;
  const k = (n: number): number => (n + h / 30) % 12;
  const a = sat * Math.min(lig, 1 - lig);
  const f = (n: number): number => lig - a * Math.max(-1, Math.min(k(n) - 3, Math.min(9 - k(n), 1)));
  const hex = (x: number): string => {
    const v = Math.round(255 * x).toString(16);
    return v.length === 1 ? '0' + v : v;
  };
  return '#' + hex(f(0)) + hex(f(8)) + hex(f(4));
}
