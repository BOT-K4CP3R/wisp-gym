import { WorkoutRecord, SetRecord, GROUPS, clamp } from './Types';

// Persistence layer. KeyValueStore is implemented by Preferences on the device and by an
// in-memory map in tests. Loaded JSON is validated field by field so a corrupt or
// hand-edited file can never crash the app.

export class KeyValueStore {
  get(key: string): string {
    return '';
  }

  put(key: string, value: string): void {
  }
}

export class MemoryStore extends KeyValueStore {
  private data: Map<string, string> = new Map<string, string>();

  get(key: string): string {
    const v = this.data.get(key);
    return v === undefined ? '' : v;
  }

  put(key: string, value: string): void {
    this.data.set(key, value);
  }
}

const KEY_WORKOUTS = 'workouts.v1';
const KEY_SEED = 'creature.seed';
const MAX_WORKOUTS = 400;

function num(v: Object | undefined | null, fallback: number): number {
  const n = v as number;
  return typeof n === 'number' && isFinite(n) ? n : fallback;
}

export class HistoryStore {
  private kv: KeyValueStore;

  constructor(kv: KeyValueStore) {
    this.kv = kv;
  }

  seed(): number {
    const raw = this.kv.get(KEY_SEED);
    let s = parseInt(raw, 10);
    if (isNaN(s)) {
      s = Math.floor(Math.random() * 360000);
      this.kv.put(KEY_SEED, '' + s);
    }
    return s;
  }

  load(): WorkoutRecord[] {
    const text = this.kv.get(KEY_WORKOUTS);
    if (text.length === 0) {
      return [];
    }
    let parsed: Object[] = [];
    try {
      parsed = JSON.parse(text) as Object[];
    } catch (e) {
      return []; // corrupt storage: start fresh instead of crashing
    }
    if (!(parsed instanceof Array)) {
      return [];
    }
    const out: WorkoutRecord[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const w = this.sanitizeWorkout(parsed[i] as WorkoutRecord);
      if (w !== null) {
        out.push(w);
      }
    }
    return out;
  }

  add(w: WorkoutRecord): void {
    const all = this.load();
    all.push(w);
    while (all.length > MAX_WORKOUTS) {
      all.shift();
    }
    this.kv.put(KEY_WORKOUTS, JSON.stringify(all));
  }

  clear(): void {
    this.kv.put(KEY_WORKOUTS, '');
  }

  // A new creature: the next seed() call picks a fresh personal shade.
  resetSeed(): void {
    this.kv.put(KEY_SEED, '');
  }

  private sanitizeWorkout(raw: WorkoutRecord): WorkoutRecord | null {
    if (raw === null || raw === undefined || !(raw.sets instanceof Array)) {
      return null;
    }
    const w = new WorkoutRecord();
    w.id = typeof raw.id === 'string' ? raw.id : '';
    w.startMs = num(raw.startMs, 0);
    w.endMs = num(raw.endMs, w.startMs);
    w.simulated = raw.simulated === true;
    for (let i = 0; i < raw.sets.length; i++) {
      const rs = raw.sets[i];
      if (rs === null || rs === undefined || GROUPS.indexOf(rs.group) < 0) {
        continue;
      }
      const s = new SetRecord();
      s.exercise = typeof rs.exercise === 'string' ? rs.exercise : '';
      s.group = rs.group;
      s.startMs = num(rs.startMs, 0);
      s.endMs = num(rs.endMs, s.startMs);
      s.reps = Math.max(0, Math.floor(num(rs.reps, 0)));
      s.fatigue = clamp(num(rs.fatigue, 0), 0, 1);
      s.quality = clamp(num(rs.quality, 1), 0, 1);
      s.simulated = rs.simulated === true;
      s.intervalsMs = rs.intervalsMs instanceof Array ? rs.intervalsMs.filter((v) => isFinite(v)) : [];
      s.peaks = rs.peaks instanceof Array ? rs.peaks.filter((v) => isFinite(v)) : [];
      w.sets.push(s);
    }
    return w;
  }
}
