import { GROUPS, WorkoutRecord, SetRecord, clamp, groupThousands } from './Types';

// Converts training history + daily movement into the creature's state.
//
// Design rules (deliberate, documented in the README):
//   * Deterministic and explainable: every state value comes with a human-readable reason.
//   * Non-punitive: levels never fall below a floor and the creature never "dies".
//     Neglect makes it curious/sleepy, never sad. Over-training makes it ask for rest.
//   * Rest is a mechanic: recovery is part of the score.

export class LifeConfig {
  halfLifeDays: number = 4;
  volumeScale: number = 36;        // weighted reps for ~63% of a group's growth
  floor: number = 0.12;
  recoveryHours: number = 48;
  restSessions72h: number = 3;     // this many sessions in 72 h => ask for a rest day
  restLoad48h: number = 150;       // weighted reps in 48 h => ask for a rest day
  stepsGoal: number = 8000;
  proudHours: number = 5;          // right after a session the creature is proud, not tired
  sleepyRecover: number = 0.25;    // below this recovery (and after the proud window) it recharges
  name: string = 'Wisp';           // the creature's name, used in headlines
}

export class Reason {
  key: string;
  label: string;
  value: string;
  target: string;
  ok: boolean;

  constructor(key: string, label: string, value: string, target: string, ok: boolean) {
    this.key = key;
    this.label = label;
    this.value = value;
    this.target = target;
    this.ok = ok;
  }
}

export class CreatureState {
  levels: number[] = [0, 0, 0, 0];   // indexed like GROUPS, floor..1
  train: number = 0;                  // mean of levels
  recover: number = 1;
  move: number = 0;
  mood: string = 'curious';
  restRequested: boolean = false;
  headline: string = '';
  reasons: Reason[] = [];
  workoutsLast7d: number = 0;
  hoursSinceLast: number = -1;
  hoursToFull: number = 0;            // hours until recovery reaches 100%
  sessions72h: number = 0;
  load48h: number = 0;                // weighted reps in the last 48 h
  totalWorkouts: number = 0;
}

const HOUR_MS = 3600000;
const DAY_MS = 86400000;

export class LifeEngine {
  private cfg: LifeConfig;

  constructor(cfg: LifeConfig) {
    this.cfg = cfg;
  }

  evaluate(nowMs: number, workouts: WorkoutRecord[], stepsToday: number): CreatureState {
    const st = new CreatureState();
    const vol: number[] = [0, 0, 0, 0];
    const setCount: number[] = [0, 0, 0, 0];
    let load48 = 0;
    let sessions72 = 0;
    let lastEnd = -1;
    let last7 = 0;

    for (let w = 0; w < workouts.length; w++) {
      const wo = workouts[w];
      const end = wo.endMs > 0 ? wo.endMs : wo.startMs;
      if (end > nowMs) {
        continue; // ignore corrupt / future records
      }
      const age = nowMs - end;
      if (age <= 72 * HOUR_MS) {
        sessions72++;
      }
      if (age <= 7 * DAY_MS) {
        last7++;
      }
      if (end > lastEnd) {
        lastEnd = end;
      }
      for (let s = 0; s < wo.sets.length; s++) {
        const set: SetRecord = wo.sets[s];
        const gi = GROUPS.indexOf(set.group);
        if (gi < 0 || set.reps <= 0) {
          continue;
        }
        const ageDays = Math.max(0, (nowMs - set.endMs) / DAY_MS);
        const weighted = set.reps * (0.5 + 0.5 * clamp(set.quality, 0, 1));
        vol[gi] += weighted * Math.pow(0.5, ageDays / this.cfg.halfLifeDays);
        if (ageDays <= 7) {
          setCount[gi]++;
        }
        if (nowMs - set.endMs <= 48 * HOUR_MS) {
          load48 += weighted;
        }
      }
    }

    let sum = 0;
    for (let i = 0; i < GROUPS.length; i++) {
      const lvl = this.cfg.floor + (1 - this.cfg.floor) * (1 - Math.exp(-vol[i] / this.cfg.volumeScale));
      st.levels[i] = clamp(lvl, this.cfg.floor, 1);
      sum += st.levels[i];
    }
    st.train = sum / GROUPS.length;
    st.workoutsLast7d = last7;

    if (lastEnd < 0) {
      st.hoursSinceLast = -1;
      st.recover = 1;
    } else {
      st.hoursSinceLast = (nowMs - lastEnd) / HOUR_MS;
      st.recover = clamp(st.hoursSinceLast / this.cfg.recoveryHours, 0, 1);
    }
    st.hoursToFull = lastEnd < 0 ? 0 : Math.max(0, this.cfg.recoveryHours - st.hoursSinceLast);
    st.sessions72h = sessions72;
    st.load48h = load48;
    st.totalWorkouts = workouts.length;
    st.move = clamp(Math.max(0, stepsToday) / this.cfg.stepsGoal, 0, 1);
    st.restRequested = sessions72 >= this.cfg.restSessions72h || load48 >= this.cfg.restLoad48h;

    st.mood = this.pickMood(st);
    st.headline = this.headlineFor(st);

    for (let i = 0; i < GROUPS.length; i++) {
      const g = GROUPS[i];
      st.reasons.push(new Reason(
        'group-' + g,
        this.cap(g) + ' strength',
        Math.round(st.levels[i] * 100) + '%',
        setCount[i] + (setCount[i] === 1 ? ' set' : ' sets') + ' in the last 7 days',
        st.levels[i] >= 0.4
      ));
    }
    st.reasons.push(new Reason(
      'recover',
      'Recovery',
      Math.round(st.recover * 100) + '%',
      lastEnd < 0 ? 'No workouts yet.' : st.hoursSinceLast.toFixed(0) + ' h since your last session. Fully recovered after ' +
        this.cfg.recoveryHours + ' h.',
      st.recover >= 0.6
    ));
    st.reasons.push(new Reason(
      'rest-guard',
      'Rest guard',
      st.restRequested ? 'Rest day' : 'All good',
      sessions72 + (sessions72 === 1 ? ' session' : ' sessions') + ' in 72 h (rest at ' + this.cfg.restSessions72h +
        '), ' + Math.round(load48) + ' weighted reps in 48 h (rest at ' + this.cfg.restLoad48h + ').',
      !st.restRequested
    ));
    st.reasons.push(new Reason(
      'move',
      'Daily movement',
      stepsToday < 0 ? 'Off' : groupThousands(stepsToday) + ' steps',
      stepsToday < 0 ? 'Step sensor unavailable or permission not granted. Goal ' +
        groupThousands(this.cfg.stepsGoal) + ' steps a day.' : 'Goal ' + groupThousands(this.cfg.stepsGoal) + ' steps a day.',
      st.move >= 0.6
    ));
    return st;
  }

  private pickMood(st: CreatureState): string {
    if (st.restRequested) {
      return 'resting';
    }
    if (st.hoursSinceLast >= 0 && st.hoursSinceLast < this.cfg.proudHours) {
      return 'proud';
    }
    if (st.hoursSinceLast >= 0 && st.recover < this.cfg.sleepyRecover) {
      return 'sleepy';
    }
    if (st.train >= 0.55 && st.move >= 0.5) {
      return 'thriving';
    }
    if (st.train < 0.25) {
      return 'curious';
    }
    return 'content';
  }

  private headlineFor(st: CreatureState): string {
    if (st.mood === 'resting') {
      return this.cfg.name + ' is tired and asks for a rest day.';
    }
    if (st.mood === 'proud') {
      return this.cfg.name + ' is pumped after your session.';
    }
    if (st.mood === 'sleepy') {
      return this.cfg.name + ' is recharging after your last session.';
    }
    if (st.mood === 'thriving') {
      return this.cfg.name + ' is thriving. Strong week.';
    }
    if (st.mood === 'curious') {
      return this.cfg.name + ' is curious. Ready when you are.';
    }
    return this.cfg.name + ' is content and steady.';
  }

  private cap(s: string): string {
    return s.charAt(0).toUpperCase() + s.substring(1);
  }
}
