import { common } from '@kit.AbilityKit';
import { formProvider, formBindingData } from '@kit.FormKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HistoryStore, KeyValueStore, MemoryStore } from '../core/Store';
import { LifeEngine, LifeConfig, CreatureState } from '../core/LifeEngine';
import { CreatureLook, lookFor } from '../core/CreatureLook';
import { WorkoutRecord } from '../core/Types';
import { generateHistory } from '../core/Sim';
import { PrefsStore } from '../platform/PrefsStore';
import { StepService } from '../platform/StepService';
import { Notifier } from '../platform/Notifier';

const TAG = 'WispApp';
const DOMAIN = 0x0010;
const KEY_DEMO = 'demo.mode';
const KEY_FORMS = 'form.ids';

export class WidgetData {
  mood: string = 'curious';
  headline: string = '';
  hue: string = '#4F8CFF';
  legs: number = 1;
  push: number = 1;
  pull: number = 1;
  core: number = 1;
  train: number = 0;
  recover: number = 100;
  move: number = 0;
  demo: boolean = false;
}

// App-wide singleton: storage, engine and platform helpers. Created once in the
// UIAbility / FormAbility and shared by pages.
export class AppModel {
  private static instance: AppModel | null = null;

  static get(): AppModel {
    if (AppModel.instance === null) {
      AppModel.instance = new AppModel();
    }
    return AppModel.instance;
  }

  private kv: KeyValueStore = new MemoryStore();
  private store: HistoryStore = new HistoryStore(new MemoryStore());
  private engine: LifeEngine = new LifeEngine(new LifeConfig());
  private context: common.Context | null = null;
  private stepSvc: StepService | null = null;
  private notifier: Notifier | null = null;
  private lastSteps: number = -1;

  init(context: common.Context): void {
    if (this.context !== null) {
      return;
    }
    this.context = context;
    this.kv = new PrefsStore(context);
    this.store = new HistoryStore(this.kv);
    this.stepSvc = new StepService(context, this.kv);
  }

  // Notifications need a UIAbilityContext, which the widget extension does not have.
  attachUiContext(ctx: common.UIAbilityContext): void {
    this.notifier = new Notifier(ctx);
  }

  isDemo(): boolean {
    return this.kv.get(KEY_DEMO) === '1';
  }

  setDemo(on: boolean): void {
    this.kv.put(KEY_DEMO, on ? '1' : '0');
  }

  workouts(): WorkoutRecord[] {
    return this.store.load();
  }

  addWorkout(w: WorkoutRecord): void {
    this.store.add(w);
    this.pushWidget();
  }

  loadDemoHistory(): void {
    const all = generateHistory(Date.now(), 14, 20261003);
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

  seed(): number {
    return this.store.seed();
  }

  notifierOrNull(): Notifier | null {
    return this.notifier;
  }

  // Steps for today. In demo mode (or when the pedometer is unavailable) a clearly
  // labelled simulated value is used so the creature can still be shown.
  async steps(): Promise<number> {
    if (this.isDemo() || this.stepSvc === null) {
      this.lastSteps = 5200;
      return 5200;
    }
    const v = await this.stepSvc.readToday();
    this.lastSteps = v < 0 ? 0 : v;
    return this.lastSteps;
  }

  async requestMotionPermission(): Promise<void> {
    if (this.stepSvc !== null) {
      await this.stepSvc.requestPermission();
    }
  }

  async state(): Promise<CreatureState> {
    const steps = await this.steps();
    return this.engine.evaluate(Date.now(), this.workouts(), steps);
  }

  evaluateNow(): CreatureState {
    return this.engine.evaluate(Date.now(), this.workouts(), this.lastSteps < 0 ? 0 : this.lastSteps);
  }

  lookFor(state: CreatureState): CreatureLook {
    return lookFor(state, this.seed());
  }

  // ---- Home-screen widget -------------------------------------------------------

  registerForm(formId: string): void {
    const ids = this.formIds();
    if (ids.indexOf(formId) < 0) {
      ids.push(formId);
      this.kv.put(KEY_FORMS, JSON.stringify(ids));
    }
  }

  unregisterForm(formId: string): void {
    const ids = this.formIds().filter((id: string) => id !== formId);
    this.kv.put(KEY_FORMS, JSON.stringify(ids));
  }

  widgetData(): WidgetData {
    const st = this.evaluateNow();
    const look = this.lookFor(st);
    const d = new WidgetData();
    d.mood = st.mood;
    d.headline = st.headline;
    d.hue = hslToHex(look.hue, 70, 62);
    d.legs = look.legs;
    d.push = look.push;
    d.pull = look.pull;
    d.core = look.core;
    d.train = Math.round(st.train * 100);
    d.recover = Math.round(st.recover * 100);
    d.move = Math.round(st.move * 100);
    d.demo = this.isDemo();
    return d;
  }

  pushWidget(): void {
    const ids = this.formIds();
    if (ids.length === 0) {
      return;
    }
    const data = formBindingData.createFormBindingData(this.widgetData());
    for (let i = 0; i < ids.length; i++) {
      formProvider.updateForm(ids[i], data).catch((e: Error) => {
        hilog.warn(DOMAIN, TAG, 'updateForm failed: %{public}s', e.message);
      });
    }
  }

  private formIds(): string[] {
    const raw = this.kv.get(KEY_FORMS);
    if (raw.length === 0) {
      return [];
    }
    try {
      const parsed = JSON.parse(raw) as string[];
      return parsed instanceof Array ? parsed : [];
    } catch (e) {
      return [];
    }
  }
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
