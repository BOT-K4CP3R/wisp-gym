import test from 'node:test';
import assert from 'node:assert/strict';
import { evaluateAchievements, unlockedSpecies, newlyUnlocked, Achievement } from '../.test-build/core/Achievements.ts';
import { SPECIES } from '../.test-build/core/Species.ts';
import { WorkoutRecord, SetRecord } from '../.test-build/core/Types.ts';

const HOUR = 3600000;
const DAY = 24 * HOUR;
// Local-time anchor: Saturday 3 Oct 2026, 12:00.
const NOW = new Date(2026, 9, 3, 12, 0, 0).getTime();
const at = (m: number, d: number, h: number, min = 0) => new Date(2026, m - 1, d, h, min, 0).getTime();

function setRec(group: string, reps: number, fatigue = 0.1, quality = 0.7): SetRecord {
  const s = new SetRecord();
  s.group = group; s.reps = reps; s.fatigue = fatigue; s.quality = quality;
  return s;
}

function workout(endMs: number, sets: SetRecord[]): WorkoutRecord {
  const w = new WorkoutRecord();
  w.endMs = endMs;
  w.startMs = endMs - 30 * 60000;
  w.sets = sets;
  return w;
}

// Plain midday session: one legs set of `reps` reps, no cue, uneven tempo.
const plain = (endMs: number, reps = 5) => workout(endMs, [setRec('legs', reps)]);

const get = (list: Achievement[], id: string): Achievement => {
  const a = list.find((x) => x.id === id);
  assert.ok(a, 'missing achievement ' + id);
  return a;
};

const REQUIRED = ['first-set', 'reps-100', 'reps-500', 'reps-1000', 'sessions-10', 'sessions-25', 'all-groups',
  'week-goal', 'rack-it', 'steady-tempo', 'rested', 'early-bird', 'night-owl', 'steps-10k'];
const ICONS = ['bolt', 'trophy', 'moon', 'steps', 'sparkle', 'heart', 'target', 'phone'];

test('achievements: empty history has every badge locked with zero progress', () => {
  const list = evaluateAchievements([], NOW, 3, 0);
  assert.deepEqual(list.map((a) => a.id).sort(), [...REQUIRED].sort());
  for (const a of list) {
    assert.equal(a.unlocked, false, a.id);
    assert.equal(a.unlockedAt, 0, a.id);
    assert.equal(a.progress, 0, a.id);
    assert.ok(a.goal >= 1, a.id);
    assert.ok(a.title.length > 0 && a.detail.length > 0, a.id);
    assert.ok(ICONS.includes(a.icon), a.id + ' icon ' + a.icon);
  }
});

test('achievements: first set unlocks at the end of that workout, zero-rep sets do not count', () => {
  const empty = workout(NOW - 3 * DAY, [setRec('legs', 0), setRec('push', -2)]);
  let list = evaluateAchievements([empty], NOW, 3, 0);
  assert.equal(get(list, 'first-set').unlocked, false);
  assert.equal(get(list, 'all-groups').progress, 0);
  const real = plain(NOW - 2 * DAY);
  list = evaluateAchievements([real, empty], NOW, 3, 0);
  assert.equal(get(list, 'first-set').unlocked, true);
  assert.equal(get(list, 'first-set').unlockedAt, real.endMs);
  assert.equal(get(list, 'sessions-10').progress, 1); // the empty workout is not a session
});

test('achievements: rep thresholds unlock at the crossing workout, progress clamps to goal', () => {
  const ws: WorkoutRecord[] = [];
  for (let i = 0; i < 12; i++) {
    ws.push(workout(NOW - (40 - i) * DAY, [setRec('legs', 25), setRec('push', 25)])); // 50 reps each
  }
  let list = evaluateAchievements(ws, NOW, 3, 0);
  assert.equal(get(list, 'reps-100').unlockedAt, ws[1].endMs);
  assert.equal(get(list, 'reps-500').unlockedAt, ws[9].endMs);
  assert.equal(get(list, 'reps-100').progress, 100);
  assert.equal(get(list, 'reps-1000').unlocked, false);
  assert.equal(get(list, 'reps-1000').progress, 600);
  list = evaluateAchievements(ws.slice(0, 1), NOW, 3, 0);
  assert.equal(get(list, 'reps-100').unlocked, false);
  assert.equal(get(list, 'reps-100').progress, 50);
  // 99 vs 100
  list = evaluateAchievements([plain(NOW - DAY, 99)], NOW, 3, 0);
  assert.equal(get(list, 'reps-100').unlocked, false);
  list = evaluateAchievements([plain(NOW - DAY, 100)], NOW, 3, 0);
  assert.equal(get(list, 'reps-100').unlocked, true);
  list = evaluateAchievements([plain(NOW - DAY, 1000)], NOW, 3, 0);
  assert.equal(get(list, 'reps-1000').unlocked, true);
  assert.equal(get(list, 'reps-1000').progress, 1000);
});

test('achievements: session counts unlock at the 10th and 25th session regardless of input order', () => {
  const ws: WorkoutRecord[] = [];
  for (let i = 0; i < 25; i++) {
    ws.push(plain(NOW - (60 - 2 * i) * DAY));
  }
  const shuffled = [...ws].reverse();
  let list = evaluateAchievements(shuffled, NOW, 3, 0);
  assert.equal(get(list, 'sessions-10').unlockedAt, ws[9].endMs);
  assert.equal(get(list, 'sessions-25').unlockedAt, ws[24].endMs);
  list = evaluateAchievements(ws.slice(0, 9), NOW, 3, 0);
  assert.equal(get(list, 'sessions-10').unlocked, false);
  assert.equal(get(list, 'sessions-10').progress, 9);
  assert.equal(get(list, 'sessions-25').progress, 9);
});

test('achievements: all groups needs legs, push, pull and core at least once', () => {
  const ws = [
    workout(NOW - 9 * DAY, [setRec('legs', 8), setRec('push', 8)]),
    workout(NOW - 7 * DAY, [setRec('pull', 8)]),
    workout(NOW - 5 * DAY, [setRec('legs', 8)])
  ];
  let list = evaluateAchievements(ws, NOW, 3, 0);
  assert.equal(get(list, 'all-groups').unlocked, false);
  assert.equal(get(list, 'all-groups').progress, 3);
  ws.push(workout(NOW - 3 * DAY, [setRec('core', 0)])); // zero reps: still missing core
  list = evaluateAchievements(ws, NOW, 3, 0);
  assert.equal(get(list, 'all-groups').unlocked, false);
  const core = workout(NOW - 2 * DAY, [setRec('core', 10)]);
  ws.push(core);
  list = evaluateAchievements(ws, NOW, 3, 0);
  assert.equal(get(list, 'all-groups').unlocked, true);
  assert.equal(get(list, 'all-groups').unlockedAt, core.endMs);
  assert.equal(get(list, 'all-groups').progress, 4);
});

test('achievements: week goal counts Monday-first weeks', () => {
  // Sun 20 Sep + Mon 21 Sep + Tue 22 Sep: the Sunday belongs to the previous week.
  const split = [plain(at(9, 20, 18)), plain(at(9, 21, 18)), plain(at(9, 22, 18))];
  let list = evaluateAchievements(split, NOW, 3, 0);
  assert.equal(get(list, 'week-goal').unlocked, false);
  assert.equal(get(list, 'week-goal').progress, 2);
  // Mon 21 00:30 .. Sun 27 23:30 is one week.
  const same = [plain(at(9, 21, 0, 30)), plain(at(9, 24, 18)), plain(at(9, 27, 23, 30))];
  list = evaluateAchievements(same, NOW, 3, 0);
  assert.equal(get(list, 'week-goal').unlocked, true);
  assert.equal(get(list, 'week-goal').unlockedAt, same[2].endMs);
  // The goal follows the user's setting.
  list = evaluateAchievements(split, NOW, 2, 0);
  assert.equal(get(list, 'week-goal').unlocked, true);
  assert.equal(get(list, 'week-goal').goal, 2);
  assert.equal(get(list, 'week-goal').unlockedAt, split[2].endMs);
});

test('achievements: rack it and steady tempo come from individual sets', () => {
  let list = evaluateAchievements([workout(NOW - DAY, [setRec('legs', 10, 0.24, 0.89), setRec('legs', 7, 0.1, 0.95)])],
    NOW, 3, 0);
  assert.equal(get(list, 'rack-it').unlocked, false);
  assert.equal(get(list, 'steady-tempo').unlocked, false); // 0.89 quality, or only 7 reps
  const w = workout(NOW - DAY, [setRec('legs', 8, 0.25, 0.9)]);
  list = evaluateAchievements([w], NOW, 3, 0);
  assert.equal(get(list, 'rack-it').unlocked, true);
  assert.equal(get(list, 'rack-it').unlockedAt, w.endMs);
  assert.equal(get(list, 'steady-tempo').unlocked, true);
  // A zero-rep set with high fatigue is ignored.
  list = evaluateAchievements([workout(NOW - DAY, [setRec('legs', 0, 0.9, 1)])], NOW, 3, 0);
  assert.equal(get(list, 'rack-it').unlocked, false);
});

test('achievements: rested needs a full calendar day off after 3 sessions in 72 h', () => {
  // Block: Mon 21, Tue 22, Wed 23 Sep at 18:00.
  const block = [plain(at(9, 21, 18)), plain(at(9, 22, 18)), plain(at(9, 23, 18))];
  // Trained again Thu 24: no full rest day.
  let list = evaluateAchievements([...block, plain(at(9, 24, 8))], at(9, 24, 12), 3, 0);
  assert.equal(get(list, 'rested').unlocked, false);
  // Now is still Thursday: rest day not finished yet.
  list = evaluateAchievements(block, at(9, 24, 23, 59), 3, 0);
  assert.equal(get(list, 'rested').unlocked, false);
  // Thursday passed without a session: unlocked at Friday midnight.
  list = evaluateAchievements(block, at(9, 25, 0, 1), 3, 0);
  assert.equal(get(list, 'rested').unlocked, true);
  assert.equal(get(list, 'rested').unlockedAt, at(9, 25, 0));
  // Next session on Friday after a Thursday off also counts.
  list = evaluateAchievements([...block, plain(at(9, 25, 7)), plain(at(9, 26, 7))], NOW, 3, 0);
  assert.equal(get(list, 'rested').unlocked, true);
  // Three sessions spread over more than 72 h are not a block, however long the break.
  const spread = [plain(at(9, 1, 18)), plain(at(9, 3, 18)), plain(at(9, 5, 19))];
  list = evaluateAchievements(spread, NOW, 3, 0);
  assert.equal(get(list, 'rested').unlocked, false);
});

test('achievements: early bird and night owl use local time of the session end', () => {
  let list = evaluateAchievements([plain(at(9, 30, 8, 59))], NOW, 3, 0);
  assert.equal(get(list, 'early-bird').unlocked, true);
  assert.equal(get(list, 'night-owl').unlocked, false);
  list = evaluateAchievements([plain(at(9, 30, 9, 0)), plain(at(9, 29, 20, 59))], NOW, 3, 0);
  assert.equal(get(list, 'early-bird').unlocked, false);
  assert.equal(get(list, 'night-owl').unlocked, false);
  const late = plain(at(9, 30, 21, 30));
  list = evaluateAchievements([late], NOW, 3, 0);
  assert.equal(get(list, 'night-owl').unlocked, true);
  assert.equal(get(list, 'night-owl').unlockedAt, late.endMs);
  list = evaluateAchievements([plain(at(9, 30, 1, 15))], NOW, 3, 0); // after midnight counts as night
  assert.equal(get(list, 'night-owl').unlocked, true);
  assert.equal(get(list, 'early-bird').unlocked, false);
});

test('achievements: steps badge uses the best day and unlocks at now', () => {
  let list = evaluateAchievements([], NOW, 3, 9999);
  assert.equal(get(list, 'steps-10k').unlocked, false);
  assert.equal(get(list, 'steps-10k').progress, 9999);
  list = evaluateAchievements([], NOW, 3, 23000);
  assert.equal(get(list, 'steps-10k').unlocked, true);
  assert.equal(get(list, 'steps-10k').unlockedAt, NOW);
  assert.equal(get(list, 'steps-10k').progress, 10000);
  list = evaluateAchievements([], NOW, 3, -5);
  assert.equal(get(list, 'steps-10k').progress, 0);
});

test('achievements: records in the future are ignored', () => {
  const future = [workout(NOW + HOUR, [setRec('legs', 500, 0.9, 1), setRec('push', 500), setRec('pull', 1),
    setRec('core', 1)])];
  const list = evaluateAchievements(future, NOW, 1, 0);
  for (const a of list) {
    assert.equal(a.unlocked, false, a.id);
  }
});

test('achievements: non-punitive, old badges stay after a long break', () => {
  const ws = [workout(at(1, 5, 7), [setRec('legs', 60, 0.3, 0.95), setRec('push', 60)])];
  const early = evaluateAchievements(ws, at(1, 6, 12), 1, 0);
  const late = evaluateAchievements(ws, NOW, 1, 0);
  for (const a of early) {
    const b = get(late, a.id);
    assert.equal(b.unlocked, a.unlocked, a.id);
    assert.equal(b.unlockedAt, a.unlockedAt, a.id);
    assert.equal(b.progress, a.progress, a.id);
  }
  for (const id of ['first-set', 'reps-100', 'week-goal', 'rack-it', 'steady-tempo', 'early-bird']) {
    assert.equal(get(late, id).unlocked, true, id);
  }
});

test('unlockedSpecies: starters always, others by achievement, in SPECIES order', () => {
  const starters = SPECIES.filter((s) => s.unlock === '').map((s) => s.id);
  assert.ok(starters.length > 0);
  assert.deepEqual(unlockedSpecies(evaluateAchievements([], NOW, 3, 0)), starters);
  assert.deepEqual(unlockedSpecies([]), starters);
  // Every unlock id is an achievement we compute.
  for (const s of SPECIES) {
    if (s.unlock !== '') {
      assert.ok(REQUIRED.includes(s.unlock), s.id + ' unlock ' + s.unlock);
    }
  }
  // Unlock everything: all species, SPECIES order.
  const ws: WorkoutRecord[] = [];
  for (let i = 0; i < 25; i++) {
    ws.push(workout(NOW - (30 - i) * DAY, [setRec('legs', 10), setRec('push', 10), setRec('pull', 10),
      setRec('core', 10, 0.3, 0.95)]));
  }
  const all = evaluateAchievements(ws, NOW, 3, 12000);
  assert.deepEqual(unlockedSpecies(all), SPECIES.map((s) => s.id));
  // Unlock exactly one gated species: the rest stay locked, order preserved.
  const gated = SPECIES.filter((s) => s.unlock !== '');
  const one = evaluateAchievements([], NOW, 3, 0);
  get(one, gated[gated.length - 1].unlock).unlocked = true;
  const expect = SPECIES.filter((s) => s.unlock === '' || s.unlock === gated[gated.length - 1].unlock).map((s) => s.id);
  assert.deepEqual(unlockedSpecies(one), expect);
});

test('newlyUnlocked: only badges that flipped to unlocked', () => {
  const before = evaluateAchievements([plain(NOW - 3 * DAY, 60)], NOW - DAY, 3, 0);
  const after = evaluateAchievements([plain(NOW - 3 * DAY, 60), workout(NOW - HOUR, [setRec('legs', 50, 0.3, 0.95)])],
    NOW, 3, 0);
  const fresh = newlyUnlocked(before, after).map((a) => a.id).sort();
  assert.deepEqual(fresh, ['rack-it', 'reps-100', 'steady-tempo']);
  assert.deepEqual(newlyUnlocked(after, after), []);
  assert.deepEqual(newlyUnlocked(after, before), []);
  assert.deepEqual(newlyUnlocked([], before).map((a) => a.id), ['first-set']);
});
