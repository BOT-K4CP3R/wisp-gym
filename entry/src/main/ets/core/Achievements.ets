import { GROUPS, WorkoutRecord, SetRecord } from './Types';
import { startOfWeek } from './Plan';
import { SPECIES } from './Species';

// Badges earned from the workout history. Everything is cumulative or "best ever": nothing
// resets when the user takes a break, so a badge, once earned, stays earned as long as the
// history that earned it is kept. Pure functions so the app, widgets and tests share them.

const HOUR_MS = 3600000;

export const CUE_FATIGUE: number = 0.25;      // the "rack it" cue level, see SetAnalyzer
export const STEADY_QUALITY: number = 0.9;
export const STEADY_REPS: number = 8;
export const STEPS_GOAL: number = 10000;

export class Achievement {
  id: string;
  title: string;
  detail: string;       // how to earn it, short
  icon: string;         // bolt | trophy | moon | steps | sparkle | heart | target | phone
  goal: number;
  progress: number = 0;
  unlocked: boolean = false;
  unlockedAt: number = 0;  // ms, 0 while locked

  constructor(id: string, title: string, detail: string, icon: string, goal: number) {
    this.id = id;
    this.title = title;
    this.detail = detail;
    this.icon = icon;
    this.goal = Math.max(1, goal);
  }
}

// One finished session, reduced to what the badges need.
class Session {
  endMs: number;
  sets: SetRecord[];

  constructor(endMs: number, sets: SetRecord[]) {
    this.endMs = endMs;
    this.sets = sets;
  }
}

function startOfDay(ms: number): number {
  const d = new Date(ms);
  d.setHours(0, 0, 0, 0);
  return d.getTime();
}

// Local midnight `days` calendar days after the day containing `ms` (DST safe).
function dayStartAfter(ms: number, days: number): number {
  const d = new Date(startOfDay(ms));
  d.setDate(d.getDate() + days);
  return d.getTime();
}

// Raise progress (never lower it) and unlock at `atMs` the first time the goal is reached.
function bump(a: Achievement, value: number, atMs: number): void {
  const v = Math.min(a.goal, Math.max(0, value));
  if (v > a.progress) {
    a.progress = v;
  }
  if (!a.unlocked && value >= a.goal) {
    a.unlocked = true;
    a.unlockedAt = atMs;
    a.progress = a.goal;
  }
}

function find(list: Achievement[], id: string): Achievement {
  for (let i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      return list[i];
    }
  }
  return list[0];
}

function validSessions(workouts: WorkoutRecord[], nowMs: number): Session[] {
  const out: Session[] = [];
  for (let i = 0; i < workouts.length; i++) {
    const w = workouts[i];
    const end = w.endMs > 0 ? w.endMs : w.startMs;
    if (end <= 0 || end > nowMs) {
      continue;
    }
    const sets: SetRecord[] = [];
    for (let s = 0; s < w.sets.length; s++) {
      if (w.sets[s].reps > 0) {
        sets.push(w.sets[s]);
      }
    }
    if (sets.length > 0) {
      out.push(new Session(end, sets));
    }
  }
  out.sort((a: Session, b: Session): number => a.endMs - b.endMs);
  return out;
}

export function evaluateAchievements(workouts: WorkoutRecord[], nowMs: number, weeklyGoal: number,
  stepsBestDay: number, stepsBestAt?: number): Achievement[] {
  const goal = Math.max(1, Math.round(weeklyGoal > 0 ? weeklyGoal : 1));
  const list: Achievement[] = [
    new Achievement('first-set', 'First spark', 'Record your first set.', 'bolt', 1),
    new Achievement('reps-100', 'Warmed up', 'Reach 100 reps in total.', 'target', 100),
    new Achievement('reps-500', 'Rep collector', 'Reach 500 reps in total.', 'target', 500),
    new Achievement('reps-1000', 'Thousand club', 'Reach 1,000 reps in total.', 'trophy', 1000),
    new Achievement('sessions-10', 'Regular', 'Finish 10 sessions.', 'trophy', 10),
    new Achievement('sessions-25', 'Devoted', 'Finish 25 sessions.', 'trophy', 25),
    new Achievement('all-groups', 'Well rounded', 'Train legs, push, pull and core at least once.', 'sparkle',
      GROUPS.length),
    new Achievement('week-goal', 'Goal week', 'Hit your weekly session goal in any week.', 'target', goal),
    new Achievement('rack-it', 'Rack it', 'Push a set until the stop cue appears.', 'phone', 1),
    new Achievement('steady-tempo', 'Steady tempo', 'Do 8+ reps with a very even tempo.', 'heart', 1),
    new Achievement('rested', 'Well rested', 'Take a full rest day after 3 sessions in 72 h.', 'moon', 1),
    new Achievement('early-bird', 'Early bird', 'Finish a session before 9:00.', 'sparkle', 1),
    new Achievement('night-owl', 'Night owl', 'Finish a session after 21:00.', 'moon', 1),
    new Achievement('steps-10k', '10k walker', 'Walk 10,000 steps in one day.', 'steps', STEPS_GOAL)
  ];
  const firstSet = find(list, 'first-set');
  const reps100 = find(list, 'reps-100');
  const reps500 = find(list, 'reps-500');
  const reps1000 = find(list, 'reps-1000');
  const sessions10 = find(list, 'sessions-10');
  const sessions25 = find(list, 'sessions-25');
  const allGroups = find(list, 'all-groups');
  const weekGoal = find(list, 'week-goal');
  const rackIt = find(list, 'rack-it');
  const steady = find(list, 'steady-tempo');
  const rested = find(list, 'rested');
  const earlyBird = find(list, 'early-bird');
  const nightOwl = find(list, 'night-owl');
  const steps = find(list, 'steps-10k');

  const sessions = validSessions(workouts, nowMs);
  let totalSets = 0;
  let totalReps = 0;
  const groupSeen: boolean[] = [];
  for (let g = 0; g < GROUPS.length; g++) {
    groupSeen.push(false);
  }
  let groupCount = 0;
  const weekStarts: number[] = [];
  const weekCounts: number[] = [];

  for (let i = 0; i < sessions.length; i++) {
    const ses = sessions[i];
    const end = ses.endMs;
    for (let s = 0; s < ses.sets.length; s++) {
      const set = ses.sets[s];
      totalSets++;
      totalReps += set.reps;
      const gi = GROUPS.indexOf(set.group);
      if (gi >= 0 && !groupSeen[gi]) {
        groupSeen[gi] = true;
        groupCount++;
      }
      if (set.fatigue >= CUE_FATIGUE) {
        bump(rackIt, 1, end);
      }
      if (set.quality >= STEADY_QUALITY && set.reps >= STEADY_REPS) {
        bump(steady, 1, end);
      }
    }
    bump(firstSet, totalSets, end);
    bump(reps100, totalReps, end);
    bump(reps500, totalReps, end);
    bump(reps1000, totalReps, end);
    bump(sessions10, i + 1, end);
    bump(sessions25, i + 1, end);
    bump(allGroups, groupCount, end);

    // Best Monday-first week so far.
    const wk = startOfWeek(end);
    let wi = weekStarts.indexOf(wk);
    if (wi < 0) {
      weekStarts.push(wk);
      weekCounts.push(0);
      wi = weekStarts.length - 1;
    }
    weekCounts[wi]++;
    bump(weekGoal, weekCounts[wi], end);

    // Time of day, local. Night owl also covers the small hours (before 4:00).
    const h = new Date(end).getHours();
    if (h >= 4 && h < 9) {
      bump(earlyBird, 1, end);
    }
    if (h >= 21 || h < 4) {
      bump(nightOwl, 1, end);
    }

    // Rest after a block: 3 sessions within 72 h, then a whole calendar day without a session.
    if (!rested.unlocked && i >= 2 && end - sessions[i - 2].endMs <= 72 * HOUR_MS) {
      const restEnd = dayStartAfter(end, 2);  // midnight ending the first full day after `end`
      const nextEnd = i + 1 < sessions.length ? sessions[i + 1].endMs : Number.MAX_VALUE;
      if (nextEnd >= restEnd && nowMs >= restEnd) {
        bump(rested, 1, restEnd);
      }
    }
  }

  // Unlock time = the day of the best step count (when known), not "now".
  bump(steps, Math.max(0, stepsBestDay), stepsBestAt !== undefined && stepsBestAt > 0 ? stepsBestAt : nowMs);
  return list;
}

// Species ids available to the user, in SPECIES order. An empty unlock id is always available.
export function unlockedSpecies(achievements: Achievement[]): string[] {
  const out: string[] = [];
  for (let i = 0; i < SPECIES.length; i++) {
    const sp = SPECIES[i];
    let ok = sp.unlock === '';
    for (let k = 0; !ok && k < achievements.length; k++) {
      if (achievements[k].id === sp.unlock && achievements[k].unlocked) {
        ok = true;
      }
    }
    if (ok) {
      out.push(sp.id);
    }
  }
  return out;
}

// Badges unlocked in `after` that were not unlocked in `before` (for the summary celebration).
export function newlyUnlocked(before: Achievement[], after: Achievement[]): Achievement[] {
  const out: Achievement[] = [];
  for (let i = 0; i < after.length; i++) {
    const a = after[i];
    if (!a.unlocked) {
      continue;
    }
    let was = false;
    for (let k = 0; k < before.length; k++) {
      if (before[k].id === a.id && before[k].unlocked) {
        was = true;
      }
    }
    if (!was) {
      out.push(a);
    }
  }
  return out;
}
