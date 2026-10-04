import { GROUPS, WorkoutRecord, findExercise } from './Types';
import { CreatureState, LifeConfig } from './LifeEngine';

// Small, pure helpers that turn the creature state and history into what the UI shows:
// the "next step" card, weekly totals, the end-of-workout summary and friendly labels.

const DAY_MS = 86400000;

const GROUP_LABELS: string[] = ['Legs', 'Push', 'Pull', 'Core'];
const GROUP_EXERCISE: string[] = ['squat', 'press', 'deadlift', 'crunch'];
const DAY_SHORT: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTH_SHORT: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

// "1 rep", "2 reps"
export function plural(n: number, word: string): string {
  return n + ' ' + (n === 1 ? word : word + 's');
}

// "a", "a and b", "a, b and c"
export function joinAnd(items: string[]): string {
  if (items.length <= 1) {
    return items.length === 1 ? items[0] : '';
  }
  return items.slice(0, items.length - 1).join(', ') + ' and ' + items[items.length - 1];
}

export function groupLabel(group: string): string {
  const i = GROUPS.indexOf(group);
  return i < 0 ? group : GROUP_LABELS[i];
}

export function exerciseForGroup(group: string): string {
  const i = GROUPS.indexOf(group);
  return i < 0 ? 'squat' : GROUP_EXERCISE[i];
}

// Index of the lowest muscle-group level (ties: first group).
export function weakestGroup(st: CreatureState): number {
  let w = 0;
  for (let i = 1; i < st.levels.length; i++) {
    if (st.levels[i] < st.levels[w]) {
      w = i;
    }
  }
  return w;
}

export function formatHours(h: number): string {
  if (h < 1) {
    return 'under an hour';
  }
  const r = Math.round(h);
  return r === 1 ? 'about 1 hour' : 'about ' + r + ' hours';
}

export function formatDuration(ms: number): string {
  const totalS = Math.max(0, Math.round(ms / 1000));
  if (totalS < 60) {
    return totalS + ' s';
  }
  const totalM = Math.round(totalS / 60);
  if (totalM < 60) {
    return totalM + ' min';
  }
  const h = Math.floor(totalM / 60);
  const m = totalM % 60;
  return h + ' h ' + (m < 10 ? '0' + m : '' + m) + ' min';
}

export function formatSteps(steps: number): string {
  const s = Math.max(0, Math.round(steps));
  if (s < 1000) {
    return '' + s;
  }
  if (s < 10000) {
    const k = (s / 1000).toFixed(1);
    return (k.endsWith('.0') ? k.substring(0, k.length - 2) : k) + 'k';
  }
  return Math.round(s / 1000) + 'k';
}

function startOfDay(ms: number): number {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

// Local midnight of the Monday of the week containing `ms`.
export function startOfWeek(ms: number): number {
  const d = new Date(startOfDay(ms));
  const dow = (d.getDay() + 6) % 7; // Monday = 0
  d.setDate(d.getDate() - dow);
  return d.getTime();
}

// "Today", "Yesterday" or "Mon 28 Sep".
export function dayLabel(ms: number, nowMs: number): string {
  const diff = Math.round((startOfDay(nowMs) - startOfDay(ms)) / DAY_MS);
  if (diff === 0) {
    return 'Today';
  }
  if (diff === 1) {
    return 'Yesterday';
  }
  const d = new Date(ms);
  return DAY_SHORT[d.getDay()] + ' ' + d.getDate() + ' ' + MONTH_SHORT[d.getMonth()];
}

export function timeOfDayGreeting(nowMs: number): string {
  const h = new Date(nowMs).getHours();
  if (h < 5) {
    return 'Good night';
  }
  if (h < 12) {
    return 'Good morning';
  }
  if (h < 18) {
    return 'Good afternoon';
  }
  return 'Good evening';
}

export function repsOf(w: WorkoutRecord): number {
  let n = 0;
  for (let s = 0; s < w.sets.length; s++) {
    n += w.sets[s].reps;
  }
  return n;
}

// ---- Next step card ---------------------------------------------------------------

export class NextAction {
  kind: string = 'train';     // first | rest | done | recharge | bonus | train
  title: string = '';
  detail: string = '';
  cta: string = '';
  target: string = 'train';   // train | insights | progress
  exercise: string = 'squat';
}

export function nextAction(st: CreatureState, cfg: LifeConfig, sessionsThisWeek: number, weeklyGoal: number,
  steps: number): NextAction {
  const a = new NextAction();
  const weak = weakestGroup(st);
  a.exercise = GROUP_EXERCISE[weak];
  const exName = findExercise(a.exercise).name.toLowerCase();
  const stepsLeft = Math.max(0, Math.round(cfg.stepsGoal - Math.max(0, steps)));
  const hoursToReady = Math.max(0, cfg.sleepyRecover * cfg.recoveryHours - Math.max(0, st.hoursSinceLast));

  if (st.totalWorkouts === 0 || st.hoursSinceLast < 0) {
    a.kind = 'first';
    a.title = 'Do your first set';
    a.detail = 'Pocket your phone and do a few squats. ' + cfg.name + ' grows from every rep.';
    a.cta = 'Start workout';
    a.target = 'train';
    a.exercise = 'squat';
    return a;
  }
  if (st.restRequested) {
    a.kind = 'rest';
    a.title = 'Take a rest day';
    a.detail = (st.sessions72h >= cfg.restSessions72h ?
      st.sessions72h + ' sessions in 72 h.' : 'Heavy training load in the last 48 h.') +
      ' Muscles grow while you rest.';
    a.cta = 'Why rest?';
    a.target = 'insights';
    return a;
  }
  if (st.mood === 'proud') {
    a.kind = 'done';
    a.title = 'Session logged';
    a.detail = 'Nice work. ' + cfg.name + ' is ready for the next one in ' + formatHours(hoursToReady) + '.';
    a.cta = 'See progress';
    a.target = 'progress';
    return a;
  }
  if (st.mood === 'sleepy') {
    a.kind = 'recharge';
    a.title = 'Recharge today';
    a.detail = 'Ready to train again in ' + formatHours(hoursToReady) + '.' +
      (stepsLeft > 0 ? ' A walk counts: ' + formatSteps(stepsLeft) + ' steps to your goal.' : '');
    a.cta = 'See insights';
    a.target = 'insights';
    return a;
  }
  if (sessionsThisWeek >= weeklyGoal) {
    a.kind = 'bonus';
    a.title = 'Weekly goal reached';
    a.detail = sessionsThisWeek + ' of ' + weeklyGoal + ' sessions done. A light ' + exName + ' set is a bonus.';
    a.cta = 'Start workout';
    a.target = 'train';
    return a;
  }
  const left = weeklyGoal - sessionsThisWeek;
  a.kind = 'train';
  a.title = 'Ready to train';
  a.detail = GROUP_LABELS[weak] + ' is your lowest group, try ' + exName + '. ' + left + ' more ' +
    (left === 1 ? 'session' : 'sessions') + ' for your weekly goal.';
  a.cta = 'Start workout';
  a.target = 'train';
  return a;
}

// ---- Weekly totals ----------------------------------------------------------------

export class WeekStats {
  sessions: number = 0;
  sets: number = 0;
  reps: number = 0;
  prevSessions: number = 0;           // last week up to the same weekday and time
  prevReps: number = 0;
  days: boolean[] = [false, false, false, false, false, false, false]; // Monday first
  todayIndex: number = 0;
}

export function weekStats(workouts: WorkoutRecord[], nowMs: number): WeekStats {
  const ws = new WeekStats();
  const start = startOfWeek(nowMs);
  const prevStart = startOfWeek(start - DAY_MS);
  ws.todayIndex = (new Date(nowMs).getDay() + 6) % 7;
  for (let i = 0; i < workouts.length; i++) {
    const w = workouts[i];
    const end = w.endMs > 0 ? w.endMs : w.startMs;
    if (end > nowMs || w.sets.length === 0) {
      continue;
    }
    if (end >= start) {
      ws.sessions++;
      ws.sets += w.sets.length;
      ws.reps += repsOf(w);
      const idx = Math.floor((startOfDay(end) - start) / DAY_MS + 0.5);
      if (idx >= 0 && idx < 7) {
        ws.days[idx] = true;
      }
    } else if (end >= prevStart && end <= nowMs - 7 * DAY_MS) {
      ws.prevSessions++;
      ws.prevReps += repsOf(w);
    }
  }
  return ws;
}

// ---- End-of-workout summary -----------------------------------------------------

export class ExerciseLine {
  name: string;
  sets: number;
  reps: number;

  constructor(name: string, sets: number, reps: number) {
    this.name = name;
    this.sets = sets;
    this.reps = reps;
  }
}

export class GroupGain {
  group: string;
  label: string;
  before: number;
  after: number;

  constructor(group: string, before: number, after: number) {
    this.group = group;
    this.label = groupLabel(group);
    this.before = before;
    this.after = after;
  }
}

export class WorkoutSummary {
  durationMs: number = 0;
  sets: number = 0;
  reps: number = 0;
  bestSet: number = 0;
  cues: number = 0;           // sets that reached the "rack it" fatigue level
  exercises: ExerciseLine[] = [];
  gains: GroupGain[] = [];
  simulated: boolean = false;
  newBadges: string[] = [];   // titles of badges earned by this workout
  newSpecies: string[] = [];  // names of creatures this workout unlocked
  levelBefore: number = 1;
  levelAfter: number = 1;
}

export function summarize(rec: WorkoutRecord, before: CreatureState, after: CreatureState, cueFatigue: number): WorkoutSummary {
  const s = new WorkoutSummary();
  s.durationMs = Math.max(0, rec.endMs - rec.startMs);
  s.sets = rec.sets.length;
  s.simulated = rec.simulated;
  const trained: boolean[] = [false, false, false, false];
  for (let i = 0; i < rec.sets.length; i++) {
    const set = rec.sets[i];
    s.reps += set.reps;
    s.bestSet = Math.max(s.bestSet, set.reps);
    if (set.fatigue >= cueFatigue) {
      s.cues++;
    }
    const gi = GROUPS.indexOf(set.group);
    if (gi >= 0) {
      trained[gi] = true;
    }
    let line: ExerciseLine | null = null;
    const name = findExercise(set.exercise).name;
    for (let k = 0; k < s.exercises.length; k++) {
      if (s.exercises[k].name === name) {
        line = s.exercises[k];
      }
    }
    if (line === null) {
      s.exercises.push(new ExerciseLine(name, 1, set.reps));
    } else {
      line.sets++;
      line.reps += set.reps;
    }
  }
  for (let g = 0; g < GROUPS.length; g++) {
    if (trained[g]) {
      s.gains.push(new GroupGain(GROUPS[g], before.levels[g], after.levels[g]));
    }
  }
  return s;
}

// ---- Personal records (all time) ---------------------------------------------------

export class Records {
  sessions: number = 0;
  sets: number = 0;
  reps: number = 0;
  bestSet: number = 0;          // most reps in one set
  bestSetExercise: string = '';
  bestSession: number = 0;      // most reps in one session
  longestMs: number = 0;        // longest session
  favorite: string = '';        // exercise with the most sets
  activeDays: number = 0;       // distinct days with a session
}

export function records(workouts: WorkoutRecord[], nowMs: number): Records {
  const r = new Records();
  const names: string[] = [];
  const counts: number[] = [];
  const days: string[] = [];
  for (let i = 0; i < workouts.length; i++) {
    const w = workouts[i];
    const end = w.endMs > 0 ? w.endMs : w.startMs;
    if (end > nowMs) {
      continue;
    }
    let reps = 0;
    let counted = 0;
    for (let k = 0; k < w.sets.length; k++) {
      const set = w.sets[k];
      if (set.reps <= 0) {
        continue;
      }
      counted++;
      reps += set.reps;
      if (set.reps > r.bestSet) {
        r.bestSet = set.reps;
        r.bestSetExercise = findExercise(set.exercise).name;
      }
      const n = findExercise(set.exercise).name;
      const at = names.indexOf(n);
      if (at < 0) {
        names.push(n);
        counts.push(1);
      } else {
        counts[at]++;
      }
    }
    if (counted === 0) {
      continue;
    }
    r.sessions++;
    r.sets += counted;
    r.reps += reps;
    r.bestSession = Math.max(r.bestSession, reps);
    r.longestMs = Math.max(r.longestMs, Math.max(0, end - w.startMs));
    const d = new Date(end);
    const key = d.getFullYear() + '-' + d.getMonth() + '-' + d.getDate();
    if (days.indexOf(key) < 0) {
      days.push(key);
    }
  }
  let best = -1;
  for (let i = 0; i < names.length; i++) {
    if (counts[i] > best) {
      best = counts[i];
      r.favorite = names[i];
    }
  }
  r.activeDays = days.length;
  return r;
}

// ---- Experience levels -------------------------------------------------------------
// One rep = one XP. Levels get gradually longer (level n needs 40 + 20 * (n - 1) XP) and
// never go down: experience is cumulative, unlike strength, which fades without training.

export class LevelInfo {
  level: number = 1;
  into: number = 0;    // XP gained inside the current level
  need: number = 40;   // XP the current level needs
}

export function levelFor(xp: number): LevelInfo {
  const info = new LevelInfo();
  let left = Math.max(0, Math.floor(xp));
  let need = 40;
  while (left >= need && info.level < 99) {
    left -= need;
    info.level++;
    need += 20;
  }
  info.into = left;
  info.need = need;
  return info;
}
