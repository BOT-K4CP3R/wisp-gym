import test from 'node:test';
import assert from 'node:assert/strict';
import { LifeEngine, LifeConfig } from '../.test-build/core/LifeEngine.ts';
import { nextAction, weekStats, summarize, startOfWeek, dayLabel, formatDuration, formatSteps, weakestGroup, records, levelFor, plural, joinAnd, newRecords, formatLoad } from '../.test-build/core/Plan.ts';
import { moodInfo, MOODS } from '../.test-build/core/Mood.ts';
import { Profile, ProfileStore, sanitizeName, reducedMotion } from '../.test-build/core/Profile.ts';
import { MemoryStore, HistoryStore } from '../.test-build/core/Store.ts';
import { WorkoutSession, SessionConfig } from '../.test-build/core/WorkoutSession.ts';
import { generateSet, TraceOptions } from '../.test-build/core/Sim.ts';
import { WorkoutRecord, SetRecord } from '../.test-build/core/Types.ts';

// Local-time anchor: Saturday 3 Oct 2026, 12:00.
const NOW = new Date(2026, 9, 3, 12, 0, 0).getTime();
const HOUR = 3600000;
const DAY = 24 * HOUR;
const cfg = new LifeConfig();
const evalAt = (ws: WorkoutRecord[], steps = 0) => new LifeEngine(cfg).evaluate(NOW, ws, steps);

function workout(endMs: number, group: string, sets: number, reps: number, exercise = 'squat'): WorkoutRecord {
  const w = new WorkoutRecord();
  w.endMs = endMs;
  w.startMs = endMs - 40 * 60000;
  for (let i = 0; i < sets; i++) {
    const s = new SetRecord();
    s.exercise = exercise; s.group = group; s.reps = reps; s.endMs = endMs - (sets - i) * 120000; s.startMs = s.endMs - 40000; s.quality = 0.9;
    s.fatigue = i === sets - 1 ? 0.3 : 0.1;
    w.sets.push(s);
  }
  return w;
}

test('next step: a new user is asked for a first set', () => {
  const a = nextAction(evalAt([]), cfg, 0, 3, 0);
  assert.equal(a.kind, 'first');
  assert.equal(a.target, 'train');
});

test('next step: rest guard wins and points to the explanation', () => {
  const ws = [workout(NOW - 60 * HOUR, 'legs', 3, 8), workout(NOW - 36 * HOUR, 'push', 3, 8, 'press'), workout(NOW - 20 * HOUR, 'pull', 3, 8, 'deadlift')];
  const a = nextAction(evalAt(ws), cfg, 3, 3, 0);
  assert.equal(a.kind, 'rest');
  assert.equal(a.target, 'insights');
  assert.match(a.detail, /3 sessions in 72 h/);
});

test('next step: just trained, recharging, then train the weakest group', () => {
  assert.equal(nextAction(evalAt([workout(NOW - 2 * HOUR, 'legs', 3, 8)]), cfg, 1, 3, 0).kind, 'done');
  const recharge = nextAction(evalAt([workout(NOW - 8 * HOUR, 'legs', 3, 8)]), cfg, 1, 3, 2000);
  assert.equal(recharge.kind, 'recharge');
  assert.match(recharge.detail, /in about 4 hours\. .*6k steps/);
  const st = evalAt([workout(NOW - 40 * HOUR, 'legs', 4, 10)]);
  const a = nextAction(st, cfg, 1, 3, 0);
  assert.equal(a.kind, 'train');
  assert.notEqual(a.exercise, 'squat'); // legs are the strongest group now
  assert.match(a.detail, /2 more sessions/);
  assert.equal(nextAction(st, cfg, 3, 3, 0).kind, 'bonus');
  assert.notEqual(weakestGroup(st), 0);
});

test('every mood has a non-empty label', () => {
  for (const m of MOODS) {
    assert.ok(moodInfo(m).label.length > 0);
    assert.ok(moodInfo(m).short.length > 0);
  }
  assert.equal(moodInfo('sleepy').label, 'Recharging');
});

test('week stats count this week (Monday first) and last week up to the same time', () => {
  const monday = startOfWeek(NOW);
  assert.equal(new Date(monday).getDay(), 1);
  const ws = [
    workout(monday + 10 * HOUR, 'legs', 3, 8),        // Monday
    workout(monday + 3 * DAY + 18 * HOUR, 'push', 2, 10, 'press'), // Thursday
    workout(monday - 2 * DAY, 'pull', 2, 5, 'deadlift'),   // last Saturday, before this time
    workout(NOW - 7 * DAY + HOUR, 'pull', 2, 5, 'deadlift'), // last Saturday, later than now: not comparable
    workout(NOW + DAY, 'legs', 3, 8)                 // future: ignored
  ];
  const s = weekStats(ws, NOW);
  assert.equal(s.sessions, 2);
  assert.equal(s.sets, 5);
  assert.equal(s.reps, 44);
  assert.equal(s.prevSessions, 1);
  assert.equal(s.prevReps, 10);
  assert.deepEqual(s.days, [true, false, false, true, false, false, false]);
  assert.equal(s.todayIndex, 5);
});

test('summary lists exercises and the groups that grew', () => {
  const before = evalAt([]);
  const w = workout(NOW - 60000, 'legs', 3, 8);
  w.sets.push(Object.assign(new SetRecord(), { exercise: 'curl', group: 'pull', reps: 12, endMs: NOW - 30000, startMs: NOW - 60000 }));
  const after = evalAt([w]);
  const s = summarize(w, before, after, 0.25);
  assert.equal(s.sets, 4);
  assert.equal(s.reps, 36);
  assert.equal(s.bestSet, 12);
  assert.equal(s.cues, 1);
  assert.deepEqual(s.exercises.map((e) => e.name), ['Squat', 'Biceps curl']);
  assert.deepEqual(s.gains.map((g) => g.label), ['Legs', 'Pull']);
  for (const g of s.gains) assert.ok(g.after > g.before, g.label);
});

test('labels: relative days, durations and steps', () => {
  assert.equal(dayLabel(NOW - HOUR, NOW), 'Today');
  assert.equal(dayLabel(NOW - DAY, NOW), 'Yesterday');
  assert.equal(dayLabel(NOW - 5 * DAY, NOW), 'Mon 28 Sep');
  assert.equal(formatDuration(45000), '45 s');
  assert.equal(formatDuration(42 * 60000), '42 min');
  assert.equal(formatDuration(65 * 60000), '1 h 05 min');
  assert.equal(formatSteps(950), '950');
  assert.equal(formatSteps(5230), '5.2k');
  assert.equal(formatSteps(12400), '12k');
  assert.equal(formatSteps(6000), '6k');
});

test('profile: sanitized, clamped and safe against corrupt storage', () => {
  assert.equal(sanitizeName('  Mo\u0000chi   the\tgreat  '), 'Mo chi the gre');
  assert.equal(sanitizeName('   '), 'Wisp');
  const kv = new MemoryStore();
  const store = new ProfileStore(kv);
  assert.equal(store.load().onboarded, false);
  const p = new Profile();
  p.name = 'Ember'; p.stepGoal = 999999; p.weeklyGoal = 0; p.onboarded = true; p.haptics = false;
  store.save(p);
  const q = store.load();
  assert.equal(q.name, 'Ember');
  assert.equal(q.stepGoal, 20000);
  assert.equal(q.weeklyGoal, 1);
  assert.equal(q.onboarded, true);
  assert.equal(q.haptics, false);
  assert.equal(q.restAlerts, true);
  kv.put('profile.v1', '{oops');
  assert.equal(store.load().name, 'Wisp');
  kv.put('profile.v1', JSON.stringify({ name: 42, stepGoal: 'x', weeklyGoal: 4.6 }));
  const r = store.load();
  assert.equal(r.name, 'Wisp');
  assert.equal(r.stepGoal, 8000);
  assert.equal(r.weeklyGoal, 5);
});

test('session: rest can be extended, shortened and skipped', () => {
  const o = new TraceOptions();
  o.reps = 5;
  const ses = new WorkoutSession(0, true, new SessionConfig());
  ses.startSet('squat', 0);
  let last = 0;
  for (const s of generateSet(o)) { ses.onSample(s); last = s.t; }
  ses.endSet(last);
  assert.equal(ses.phase(), 'rest');
  const r0 = ses.restRemainingMs(last);
  ses.adjustRest(15000, last);
  assert.equal(ses.restRemainingMs(last), r0 + 15000);
  assert.ok(ses.restTotalMs() >= r0 + 15000);
  ses.adjustRest(-10 * 60000, last);
  assert.equal(ses.restRemainingMs(last), 0);
  ses.adjustRest(60 * 60000, last);
  assert.equal(ses.restRemainingMs(last), 600000);
  ses.skipRest();
  assert.equal(ses.phase(), 'idle');
  assert.equal(ses.sets().length, 1);
});

test('session: switching to the simulated stream flags the visit and later sets', () => {
  const o = new TraceOptions();
  o.reps = 4;
  const ses = new WorkoutSession(0, false, new SessionConfig());
  ses.markSimulated();
  ses.startSet('press', 0);
  let last = 0;
  for (const s of generateSet(o)) { ses.onSample(s); last = s.t; }
  ses.endSet(last);
  const rec = ses.finish(last + 1000);
  assert.equal(rec.simulated, true);
  assert.equal(rec.sets[0].simulated, true);
});

test('profile: motion mode is validated and auto follows the renderer', () => {
  const kv = new MemoryStore();
  const store = new ProfileStore(kv);
  assert.equal(store.load().motion, 'auto');
  kv.put('profile.v1', JSON.stringify({ motion: 'wild' }));
  assert.equal(store.load().motion, 'auto');
  const p = new Profile(); p.motion = 'reduced'; store.save(p);
  assert.equal(store.load().motion, 'reduced');
  assert.equal(reducedMotion('auto', true), true);
  assert.equal(reducedMotion('auto', false), false);
  assert.equal(reducedMotion('full', true), false);
  assert.equal(reducedMotion('reduced', false), true);
});

test('profile: species is validated', () => {
  const kv = new MemoryStore();
  const store = new ProfileStore(kv);
  assert.equal(store.load().species, 'wisp');
  const p = new Profile(); p.species = 'pip'; store.save(p);
  assert.equal(store.load().species, 'pip');
  kv.put('profile.v1', JSON.stringify({ species: 'dragon' }));
  assert.equal(store.load().species, 'wisp');
});

test('records: all-time totals, bests and favourite exercise', () => {
  const a = workout(NOW - 2 * DAY, 'legs', 3, 8);                 // 24 reps, squat
  const b = workout(NOW - DAY, 'push', 2, 12, 'press');           // 24 reps, press
  b.sets.push(Object.assign(new SetRecord(), { exercise: 'squat', group: 'legs', reps: 15, endMs: NOW - DAY, startMs: NOW - DAY - 60000 }));
  const empty = workout(NOW - DAY, 'legs', 1, 0);                 // no reps: not a session
  const future = workout(NOW + DAY, 'legs', 5, 50);
  const r = records([a, b, empty, future], NOW);
  assert.equal(r.sessions, 2);
  assert.equal(r.sets, 6);
  assert.equal(r.reps, 63);
  assert.equal(r.bestSet, 15);
  assert.equal(r.bestSetExercise, 'Squat');
  assert.equal(r.bestSession, 39);
  assert.equal(r.favorite, 'Squat');
  assert.equal(r.activeDays, 2);
  assert.ok(r.longestMs >= 40 * 60000);
});

test('levels: cumulative XP, growing level size, never below 1', () => {
  assert.equal(levelFor(0).level, 1);
  assert.equal(levelFor(-5).level, 1);
  assert.equal(levelFor(39).level, 1);
  assert.equal(levelFor(40).level, 2);
  assert.equal(levelFor(40).into, 0);
  assert.equal(levelFor(40).need, 60);
  assert.equal(levelFor(99).level, 2);
  assert.equal(levelFor(100).level, 3);
  assert.equal(levelFor(1000000).level, 99);
});

test('labels: plurals and natural lists', () => {
  assert.equal(plural(1, 'rep'), '1 rep');
  assert.equal(plural(0, 'rep'), '0 reps');
  assert.equal(plural(12, 'set'), '12 sets');
  assert.equal(joinAnd([]), '');
  assert.equal(joinAnd(['legs']), 'legs');
  assert.equal(joinAnd(['legs', 'pull']), 'legs and pull');
  assert.equal(joinAnd(['legs', 'pull', 'core']), 'legs, pull and core');
});

test('movement reason says Off when the step sensor is unavailable', () => {
  const st = new LifeEngine(cfg).evaluate(NOW, [], -1);
  const r = st.reasons.find((x: { key: string }) => x.key === 'move');
  assert.equal(r.value, 'Off');
  assert.equal(st.move, 0);
});

test('loads: volume, heaviest set, new records and formatting', () => {
  const old = workout(NOW - 3 * DAY, 'legs', 2, 8);
  old.sets.forEach((x: SetRecord) => { x.weightKg = 60; });
  const now = workout(NOW - HOUR, 'legs', 2, 6);
  now.sets[0].weightKg = 62.5;
  now.sets[1].weightKg = 60;
  const press = workout(NOW - HOUR, 'push', 1, 10, 'press');
  press.sets[0].weightKg = 30;
  now.sets.push(press.sets[0]);
  assert.deepEqual(newRecords([old], now, NOW), ['Squat 62.5 kg', 'Overhead press 30 kg']);
  assert.deepEqual(newRecords([old, now], now, NOW), []);
  const r = records([old, now], NOW);
  assert.equal(r.heaviestKg, 62.5);
  assert.equal(r.heaviestExercise, 'Squat');
  assert.equal(r.volumeKg, 8 * 60 * 2 + 6 * 62.5 + 6 * 60 + 10 * 30);
  const s = summarize(now, evalAt([]), evalAt([now]), 0.25);
  assert.equal(s.volumeKg, 6 * 62.5 + 6 * 60 + 10 * 30);
  assert.equal(formatLoad(0), 'bodyweight');
  assert.equal(formatLoad(60), '60 kg');
  assert.equal(formatLoad(62.5), '62.5 kg');
});

test('store keeps the load of a set and clamps nonsense', () => {
  const kv = new MemoryStore();
  const store = new HistoryStore(kv);
  const w = workout(NOW - DAY, 'legs', 1, 8);
  w.sets[0].weightKg = 42.5;
  store.add(w);
  assert.equal(store.load()[0].sets[0].weightKg, 42.5);
  kv.put('workouts.v1', JSON.stringify([{ sets: [{ group: 'legs', reps: 5, weightKg: -3 }, { group: 'legs', reps: 5, weightKg: 'x' }] }]));
  assert.deepEqual(store.load()[0].sets.map((x: SetRecord) => x.weightKg), [0, 0]);
});

test('profile: height and goal weight are optional and clamped', () => {
  const kv = new MemoryStore();
  const store = new ProfileStore(kv);
  assert.equal(store.load().heightCm, 0);
  assert.equal(store.load().goalKg, 0);
  const p = new Profile(); p.heightCm = 181.26; p.goalKg = 5; store.save(p);
  assert.equal(store.load().heightCm, 181.3);
  assert.equal(store.load().goalKg, 30);
  kv.put('profile.v1', JSON.stringify({ heightCm: 'tall', goalKg: -2 }));
  assert.equal(store.load().heightCm, 0);
  assert.equal(store.load().goalKg, 0);
});
