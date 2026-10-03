import test from 'node:test';
import assert from 'node:assert/strict';
import { LifeEngine, LifeConfig } from '../.test-build/core/LifeEngine.ts';
import { lookFor } from '../.test-build/core/CreatureLook.ts';
import { generateHistory, generateSet, TraceOptions } from '../.test-build/core/Sim.ts';
import { WorkoutSession, SessionConfig } from '../.test-build/core/WorkoutSession.ts';
import { HistoryStore, MemoryStore } from '../.test-build/core/Store.ts';
import { WorkoutRecord, SetRecord, GROUPS } from '../.test-build/core/Types.ts';

const NOW = Date.UTC(2026, 9, 3, 12, 0, 0);
const HOUR = 3600000;
const DAY = 24 * HOUR;
const engine = () => new LifeEngine(new LifeConfig());

function workout(endMs: number, group: string, sets: number, reps: number): WorkoutRecord {
  const w = new WorkoutRecord();
  w.endMs = endMs;
  w.startMs = endMs - 40 * 60000;
  for (let i = 0; i < sets; i++) {
    const s = new SetRecord();
    s.group = group; s.reps = reps; s.endMs = endMs - (sets - i) * 120000; s.startMs = s.endMs - 40000; s.quality = 0.9;
    w.sets.push(s);
  }
  return w;
}

test('an empty history gives a curious, fully recovered creature with the floor level', () => {
  const st = engine().evaluate(NOW, [], 0);
  assert.equal(st.mood, 'curious');
  assert.equal(st.recover, 1);
  assert.ok(st.levels.every((l: number) => l >= 0.12 && l < 0.2));
});

test('training a group raises only that group', () => {
  const st = engine().evaluate(NOW, [workout(NOW - 3 * DAY, 'legs', 5, 8)], 0);
  const legs = st.levels[GROUPS.indexOf('legs')];
  assert.ok(legs > 0.5, `legs ${legs}`);
  assert.ok(st.levels[GROUPS.indexOf('pull')] < 0.2);
});

test('old work fades but never below the floor (non-punitive)', () => {
  const old = engine().evaluate(NOW, [workout(NOW - 60 * DAY, 'legs', 5, 8)], 0);
  assert.ok(old.levels[0] >= 0.12);
  assert.ok(old.levels[0] < 0.2);
  assert.notEqual(old.mood, 'resting');
});

test('three sessions in 72h makes the creature ask for a rest day', () => {
  const ws = [workout(NOW - 60 * HOUR, 'legs', 3, 8), workout(NOW - 36 * HOUR, 'push', 3, 8), workout(NOW - 5 * HOUR, 'pull', 3, 8)];
  const st = engine().evaluate(NOW, ws, 3000);
  assert.equal(st.restRequested, true);
  assert.equal(st.mood, 'resting');
  assert.match(st.headline, /rest day/);
});

test('recovery grows with time since the last session', () => {
  const soon = engine().evaluate(NOW, [workout(NOW - 4 * HOUR, 'legs', 3, 8)], 0);
  const later = engine().evaluate(NOW, [workout(NOW - 40 * HOUR, 'legs', 3, 8)], 0);
  assert.ok(later.recover > soon.recover);
  assert.equal(soon.mood, 'sleepy');
});

test('future / corrupt records are ignored', () => {
  const st = engine().evaluate(NOW, [workout(NOW + 5 * DAY, 'legs', 5, 10)], 0);
  assert.equal(st.mood, 'curious');
});

test('every state has an explanation for each driver', () => {
  const st = engine().evaluate(NOW, generateHistory(NOW, 14, 4), 6000);
  const keys = st.reasons.map((r: { key: string }) => r.key);
  for (const k of ['group-legs', 'group-push', 'group-pull', 'group-core', 'recover', 'rest-guard', 'move']) {
    assert.ok(keys.includes(k), k);
  }
});

test('creature never looks sad: smile stays positive in every mood', () => {
  for (const [hist, steps] of [[[], 0], [generateHistory(NOW, 14, 1), 9000], [[workout(NOW - HOUR, 'legs', 9, 12)], 0]] as [WorkoutRecord[], number][]) {
    const look = lookFor(engine().evaluate(NOW, hist, steps), 123);
    assert.ok(look.smile > 0, `${look.mood} smile ${look.smile}`);
    assert.ok(look.legs >= 0.8 && look.legs <= 1.45);
  }
});

test('session: counts a set, auto-ends after a pause, schedules rest and stores a record', () => {
  const o = new TraceOptions();
  o.reps = 6;
  o.tailMs = 15000;
  const ses = new WorkoutSession(0, true, new SessionConfig());
  ses.startSet('squat', 0);
  let reps = 0;
  let ended = false;
  for (const s of generateSet(o)) {
    const u = ses.onSample(s);
    if (u.newRep) reps = u.reps;
    if (ses.tick(s.t).autoEnded) { ended = true; break; }
  }
  assert.equal(ended, true);
  assert.equal(ses.phase(), 'rest');
  assert.ok(reps >= 5, `live count ${reps}`);
  const rec = ses.finish(60000);
  assert.equal(rec.sets.length, 1);
  assert.equal(rec.sets[0].reps, 6);
  assert.equal(rec.sets[0].group, 'legs');
  assert.equal(rec.simulated, true);
});

test('session: ending an empty set records nothing', () => {
  const ses = new WorkoutSession(0, false, new SessionConfig());
  ses.startSet('curl', 0);
  assert.equal(ses.endSet(1000), null);
  assert.equal(ses.setsDone(), 0);
});

test('store: round-trips workouts and survives corrupt or hostile storage', () => {
  const kv = new MemoryStore();
  const store = new HistoryStore(kv);
  store.add(workout(NOW - DAY, 'legs', 2, 8));
  assert.equal(store.load().length, 1);
  assert.equal(store.load()[0].sets[0].reps, 8);

  kv.put('workouts.v1', '{not json');
  assert.deepEqual(store.load(), []);
  kv.put('workouts.v1', '"a string"');
  assert.deepEqual(store.load(), []);
  kv.put('workouts.v1', JSON.stringify([{ sets: 'bad' }, null, { endMs: 'x', sets: [{ group: 'nope', reps: 5 }, { group: 'legs', reps: -9, fatigue: 99 }] }]));
  const w = store.load();
  assert.equal(w.length, 1);
  assert.equal(w[0].sets.length, 1);
  assert.equal(w[0].sets[0].reps, 0);
  assert.equal(w[0].sets[0].fatigue, 1);
});

test('store: keeps a stable creature seed', () => {
  const store = new HistoryStore(new MemoryStore());
  const a = store.seed();
  assert.equal(store.seed(), a);
});
