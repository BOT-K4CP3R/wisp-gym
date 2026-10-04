import { common } from '@kit.AbilityKit';
import { formProvider, formBindingData } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HistoryStore, KeyValueStore, MemoryStore } from '../core/Store';
import { LifeEngine, LifeConfig, CreatureState } from '../core/LifeEngine';
import { CreatureLook, lookFor } from '../core/CreatureLook';
import { WorkoutRecord } from '../core/Types';
import { generateHistory, generateWeights } from '../core/Sim';
import { BodyStore, WeightEntry } from '../core/Body';
import { Profile, ProfileStore, reducedMotion } from '../core/Profile';
import { deviceInfo } from '@kit.BasicServicesKit';
import { setMotion } from '../ui/Motion';
import { moodInfo } from '../core/Mood';
import { NextAction, WeekStats, WorkoutSummary, formatSteps, levelFor, newRecords, nextAction, repsOf, summarize, weekStats } from '../core/Plan';
import { AnalyzerConfig } from '../core/SetAnalyzer';
import { Achievement, evaluateAchievements, newlyUnlocked, unlockedSpecies } from '../core/Achievements';
import { findSpecies } from '../core/Species';
import { PrefsStore } from '../platform/PrefsStore';
import { StepService } from '../platform/StepService';
import { Notifier } from '../platform/Notifier';
import { buzz } from '../platform/Haptics';

const TAG = 'WispApp';
const DOMAIN = 0x0010;
const KEY_DEMO = 'demo.mode';
const KEY_FORMS = 'form.ids';
const KEY_STEPS = 'steps.today';
const KEY_STEPS_BEST = 'steps.best';
const KEY_BADGES = 'badges.v1';
const KEY_STEPS_BEST_AT = 'steps.bestAt';
const KEY_LOADS = 'loads.v1';
const KEY_BODY_SAMPLE = 'body.sample';
const DEMO_SEED = 20261003;
const FORM_NOT_EXIST = 16501001;

// AppStorage key used to route a widget tap (or other deep link) to a screen.
export const NAV_TARGET = 'wisp.navTarget';

// Flat, serialisable snapshot pushed to the home-screen widgets.
export class WidgetData {
  name: string = 'Wisp';
  mood: string = 'curious';
  moodLabel: string = 'Curious';
  moodShort: string = 'Ready when you are';
  // CreatureLook fields: the widget draws the same creature as the app
  hue: number = 14;
  glow: number = 0.5;
  eyeOpen: number = 1;
  smile: number = 0.55;
  happyEyes: boolean = false;
  species: string = 'wisp';
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
  private body: BodyStore = new BodyStore(new MemoryStore());
  private context: common.Context | null = null;
  private stepSvc: StepService | null = null;
  private notifier: Notifier | null = null;
  private lastSteps: number = -1;
  private summary: WorkoutSummary | null = null;
  private cache: WorkoutRecord[] | null = null;
  private badgeCache: Achievement[] | null = null;
  private badgeGoal: number = -1;
  private profileCache: Profile | null = null;

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
    this.body = new BodyStore(this.kv);
    this.stepSvc = new StepService(context, this.kv);
  }

  // The widget process has its own Preferences cache; drop it so it sees the app's writes.
  reloadFromDisk(): void {
    this.changed();
    this.profileCache = null;
    if (this.prefs !== null) {
      this.prefs.reload();
    }
  }

  // Notifications need a UIAbilityContext, which the widget extension does not have.
  attachUiContext(ctx: common.UIAbilityContext): void {
    this.notifier = new Notifier(ctx);
  }

  // ---- Profile ----------------------------------------------------------------------

  // Cached: called on every rep tick and render. Returns a copy so callers may edit it.
  profile(): Profile {
    if (this.profileCache === null) {
      this.profileCache = this.profiles.load();
    }
    const c = this.profileCache;
    const p = new Profile();
    p.name = c.name;
    p.stepGoal = c.stepGoal;
    p.weeklyGoal = c.weeklyGoal;
    p.onboarded = c.onboarded;
    p.haptics = c.haptics;
    p.restAlerts = c.restAlerts;
    p.motion = c.motion;
    p.species = c.species;
    p.motionAsked = c.motionAsked;
    p.heightCm = c.heightCm;
    p.goalKg = c.goalKg;
    return p;
  }

  saveProfile(p: Profile): void {
    this.profiles.save(p);
    this.profileCache = null;
    this.badgeCache = null;
    this.applyMotion();
    this.pushWidget();
  }

  // x86 builds of OpenHarmony are emulators with a software renderer.
  softwareRenderer(): boolean {
    try {
      return deviceInfo.abiList.indexOf('x86') >= 0;
    } catch (e) {
      return false;
    }
  }

  applyMotion(): void {
    setMotion(!reducedMotion(this.profile().motion, this.softwareRenderer()));
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
    this.badgeCache = null;
    this.pushWidget();
  }

  // ---- History ----------------------------------------------------------------------

  // Parsed history, cached until it changes (parsing and validating the JSON on every call
  // made the first frame of Home take seconds on slow devices). Treat as read-only.
  workouts(): WorkoutRecord[] {
    if (this.cache === null) {
      this.cache = this.store.load();
    }
    return this.cache;
  }

  private changed(): void {
    this.cache = null;
    this.badgeCache = null;
  }

  // Stores a finished workout and prepares the summary screen (before/after levels).
  finishWorkout(w: WorkoutRecord): WorkoutSummary {
    const before = this.evaluateNow();
    const badgesBefore = this.achievements();
    const xpBefore = this.totalReps();
    const speciesBefore = unlockedSpecies(badgesBefore);
    this.store.add(w);
    this.changed();
    const after = this.evaluateNow();
    this.summary = summarize(w, before, after, new AnalyzerConfig().stopFatigue);
    this.summary.prs = newRecords(this.workouts().filter((x: WorkoutRecord) => x !== w && x.id !== w.id), w, Date.now());
    const badgesAfter = this.achievements();
    this.summary.levelBefore = levelFor(xpBefore).level;
    this.summary.levelAfter = levelFor(this.totalReps()).level;
    this.summary.newBadges = newlyUnlocked(badgesBefore, badgesAfter).map((a: Achievement) => a.title);
    this.summary.newSpecies = unlockedSpecies(badgesAfter)
      .filter((id: string) => speciesBefore.indexOf(id) < 0)
      .map((id: string) => findSpecies(id).name);
    this.pushWidget();
    return this.summary;
  }

  // ---- Badges and creatures -------------------------------------------------------------

  // Badges are computed from history and then merged with every badge ever earned, so a
  // badge never disappears (deleted history, a higher weekly goal): nothing is taken away.
  achievements(): Achievement[] {
    const goal = this.profile().weeklyGoal;
    if (this.badgeCache !== null && this.badgeGoal === goal) {
      return this.badgeCache;
    }
    const list = evaluateAchievements(this.workouts(), Date.now(), goal, this.stepsBest(),
      this.stepsBestAt());
    const kept = this.keptBadges();
    let changed = false;
    for (let i = 0; i < list.length; i++) {
      const a = list[i];
      const at = kept.indexOf(a.id);
      if (!a.unlocked && at >= 0) {
        a.unlocked = true;
        a.progress = a.goal;
      } else if (a.unlocked && at < 0) {
        kept.push(a.id);
        changed = true;
      }
    }
    // Sample (demo) history may show badges but never stores them for good.
    if (changed && !this.isDemo()) {
      this.kv.put(KEY_BADGES, JSON.stringify(kept));
    }
    this.badgeCache = list;
    this.badgeGoal = goal;
    return list;
  }

  unlockedSpecies(): string[] {
    return unlockedSpecies(this.achievements());
  }

  private keptBadges(): string[] {
    const raw = this.kv.get(KEY_BADGES);
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as string[];
      return parsed instanceof Array ? parsed.filter((v: string) => typeof v === 'string') : [];
    } catch (e) {
      return [];
    }
  }

  // Experience = every rep ever counted (never decreases).
  totalReps(): number {
    const ws = this.workouts();
    let n = 0;
    for (let i = 0; i < ws.length; i++) {
      n += repsOf(ws[i]);
    }
    return n;
  }

  // ---- Loads and body weight ------------------------------------------------------------

  // Last load used for an exercise (so the next set starts there), 0 = bodyweight.
  loadFor(exerciseId: string): number {
    const list = this.loadList();
    for (let i = 0; i < list.length; i++) {
      const parts = list[i].split(':');
      if (parts[0] === exerciseId) {
        const n = parseFloat(parts[1]);
        return isNaN(n) ? 0 : Math.max(0, Math.min(1000, n));
      }
    }
    return 0;
  }

  setLoad(exerciseId: string, kg: number): void {
    const list = this.loadList().filter((v: string) => v.split(':')[0] !== exerciseId);
    list.push(exerciseId + ':' + Math.max(0, Math.round(kg * 10) / 10));
    this.kv.put(KEY_LOADS, JSON.stringify(list));
  }

  private loadList(): string[] {
    const raw = this.kv.get(KEY_LOADS);
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as string[];
      return parsed instanceof Array ? parsed.filter((v: string) => typeof v === 'string') : [];
    } catch (e) {
      return [];
    }
  }

  private removeSampleWeights(): void {
    const raw = this.kv.get(KEY_BODY_SAMPLE);
    if (raw.length === 0) {
      return;
    }
    try {
      const stamps = JSON.parse(raw) as number[];
      if (stamps instanceof Array) {
        for (let i = 0; i < stamps.length; i++) {
          this.body.remove(stamps[i]);
        }
      }
    } catch (e) {
      // nothing to remove
    }
    this.kv.put(KEY_BODY_SAMPLE, '');
  }

  weights(): WeightEntry[] {
    return this.body.load();
  }

  logWeight(kg: number): boolean {
    const ok = this.body.add(Date.now(), kg);
    this.pushWidget();
    return ok;
  }

  removeWeight(atMs: number): void {
    this.body.remove(atMs);
  }

  latestWeight(): number {
    const all = this.body.load();
    return all.length > 0 ? all[all.length - 1].kg : 0;
  }

  stepsBestAt(): number {
    const n = parseInt(this.kv.get(KEY_STEPS_BEST_AT), 10);
    return isNaN(n) ? 0 : n;
  }

  // Sample history from the demo is present (used when turning Demo mode off).
  hasSampleHistory(): boolean {
    const ws = this.workouts();
    for (let i = 0; i < ws.length; i++) {
      if (ws[i].simulated) {
        return true;
      }
    }
    return false;
  }

  stepsBest(): number {
    const n = parseInt(this.kv.get(KEY_STEPS_BEST), 10);
    return isNaN(n) ? 0 : n;
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
    this.changed();
    // Sample weigh-ins too, starting near the user's own weight when known.
    if (this.body.load().length === 0) {
      const weigh = generateWeights(Date.now(), 14, 78, DEMO_SEED);
      const stamps: number[] = [];
      for (let i = 0; i < weigh.length; i++) {
        this.body.add(weigh[i][0], weigh[i][1]);
        stamps.push(weigh[i][0]);
      }
      this.kv.put(KEY_BODY_SAMPLE, JSON.stringify(stamps)); // so "clear sample data" can remove them
    }
    this.setDemo(true);
    this.pushWidget();
  }

  resetHistory(): void {
    this.store.clear();
    this.removeSampleWeights();
    this.changed();
    this.pushWidget();
  }

  // Erases history, profile and demo mode: the app starts over with the introduction.
  resetAll(): void {
    this.store.clear();
    this.changed();
    this.store.resetSeed();
    this.kv.put(KEY_DEMO, '0');
    this.kv.put(KEY_STEPS, '');
    this.kv.put(KEY_STEPS_BEST, '');
    this.kv.put(KEY_STEPS_BEST_AT, '');
    this.kv.put(KEY_LOADS, '');
    this.body.clear();
    this.kv.put(KEY_BADGES, '');
    this.profiles.save(new Profile());
    this.profileCache = null;
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
    if (v > this.stepsBest() && !this.isDemo()) {
      this.kv.put(KEY_STEPS_BEST, '' + v);
      this.kv.put(KEY_STEPS_BEST_AT, '' + Date.now());
      this.badgeCache = null;
    }
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
    return new LifeEngine(this.config()).evaluate(Date.now(), this.workouts(), steps);
  }

  evaluateNow(): CreatureState {
    return new LifeEngine(this.config()).evaluate(Date.now(), this.workouts(), this.stepsToday());
  }

  nextAction(st: CreatureState): NextAction {
    const p = this.profile();
    return nextAction(st, this.config(), this.weekStats().sessions, p.weeklyGoal, Math.max(0, this.stepsToday()));
  }

  lookFor(state: CreatureState): CreatureLook {
    return lookFor(state, this.seed(), this.profile().species);
  }

  lookForSpecies(state: CreatureState, species: string): CreatureLook {
    return lookFor(state, this.seed(), species);
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
    d.hue = look.hue;
    d.glow = look.glow;
    d.eyeOpen = look.eyeOpen;
    d.smile = look.smile;
    d.happyEyes = look.happyEyes;
    d.species = look.species;
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
      formProvider.updateForm(id, data).catch((e: BusinessError) => {
        hilog.warn(DOMAIN, TAG, 'updateForm %{public}s failed: %{public}d %{public}s', id, e.code, e.message);
        if (e.code === FORM_NOT_EXIST) {
          this.unregisterForm(id); // the widget was removed from the home screen
        }
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
