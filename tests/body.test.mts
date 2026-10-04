import test from 'node:test';
import assert from 'node:assert/strict';
import { WeightEntry, BodyStore, bmi, bmiInfo, healthyRange, weightStats, series, formatKg, formatDelta } from '../.test-build/core/Body.ts';
import { MemoryStore } from '../.test-build/core/Store.ts';

// Local-time anchor: Saturday 3 Oct 2026, 12:00.
const NOW = new Date(2026, 9, 3, 12, 0, 0).getTime();
const HOUR = 3600000;
const DAY = 24 * HOUR;
const at = (daysAgo: number, hour = 8) => {
  const d = new Date(NOW - daysAgo * DAY);
  d.setHours(hour, 0, 0, 0);
  return d.getTime();
};
const e = (daysAgo: number, kg: number) => new WeightEntry(at(daysAgo), kg);

test('bmi: value rounded to one decimal, 0 for missing or invalid input', () => {
  assert.equal(bmi(70, 175), 22.9);
  assert.equal(bmi(0, 175), 0);
  assert.equal(bmi(70, 0), 0);
  assert.equal(bmi(NaN, 175), 0);
  assert.equal(bmi(70, Infinity), 0);
  assert.equal(bmi(-70, 175), 0);
});

test('bmi labels follow the WHO adult boundaries', () => {
  assert.equal(bmiInfo(59.0, 180).label, 'Below range');      // 18.2
  assert.equal(bmiInfo(59.94, 180).label, 'Healthy range');   // 18.5
  assert.equal(bmiInfo(80.676, 180).label, 'Healthy range');  // 24.9
  assert.equal(bmiInfo(81, 180).label, 'Above range');        // 25.0
  assert.equal(bmiInfo(97, 180).label, 'Above range');        // 29.9
  assert.equal(bmiInfo(97.2, 180).label, 'Well above range'); // 30.0
});

test('bmi info: detail, gauge position and the empty state', () => {
  const i = bmiInfo(89.1, 180); // 27.5, middle of 15..40
  assert.equal(i.value, 27.5);
  assert.ok(Math.abs(i.position - 0.5) < 1e-9);
  assert.equal(i.detail, 'Healthy range for your height: 59.9–80.7 kg');
  assert.equal(bmiInfo(400, 120).position, 1);
  assert.equal(bmiInfo(25, 190).position, 0);
  const empty = bmiInfo(70, 0);
  assert.equal(empty.value, 0);
  assert.equal(empty.label, 'Add height and weight');
  assert.equal(empty.position, 0);
});

test('healthy range for a height', () => {
  assert.deepEqual(healthyRange(180), [59.9, 80.7]);
  assert.deepEqual(healthyRange(160), [47.4, 63.7]);
  assert.deepEqual(healthyRange(0), [0, 0]);
});

test('store: loads validated entries sorted by time; corrupt JSON gives []', () => {
  const kv = new MemoryStore();
  const store = new BodyStore(kv);
  assert.deepEqual(store.load(), []);
  kv.put('body.v1', JSON.stringify([
    { atMs: 3000, kg: 70 }, { atMs: 1000, kg: 71 }, { atMs: 2000, kg: 10 }, { atMs: 0, kg: 70 },
    { atMs: 4000, kg: 401 }, { atMs: 5000, kg: 'x' }, null, 7, { atMs: -5, kg: 60 }, { atMs: 6000, kg: 20 },
  ]));
  const list = store.load();
  assert.deepEqual(list.map((x) => x.atMs), [1000, 3000, 6000]);
  assert.deepEqual(list.map((x) => x.kg), [71, 70, 20]);
  kv.put('body.v1', '{not json');
  assert.deepEqual(store.load(), []);
  kv.put('body.v1', '{"atMs":1,"kg":70}');
  assert.deepEqual(store.load(), []);
});

test('store: logging twice on the same local day replaces that day', () => {
  const store = new BodyStore(new MemoryStore());
  store.add(at(1, 7), 72.4);
  store.add(at(0, 7), 72.0);
  store.add(at(0, 21), 71.6);
  const list = store.load();
  assert.equal(list.length, 2);
  assert.equal(list[1].kg, 71.6);
  assert.equal(list[1].atMs, at(0, 21));
  assert.equal(list[0].kg, 72.4);
});

test('store: adds out of order stay sorted; invalid weights are rejected', () => {
  const store = new BodyStore(new MemoryStore());
  store.add(at(2), 70);
  store.add(at(5), 71);
  store.add(at(3), 72);
  assert.equal(store.add(at(4), 10), false);
  assert.equal(store.add(NaN, 70), false);
  assert.deepEqual(store.load().map((x) => x.kg), [71, 72, 70]);
});

test('store: remove by exact time and clear', () => {
  const store = new BodyStore(new MemoryStore());
  store.add(at(2), 70);
  store.add(at(1), 71);
  store.remove(at(2) + 1); // not an exact match
  assert.equal(store.load().length, 2);
  store.remove(at(2));
  assert.deepEqual(store.load().map((x) => x.kg), [71]);
  store.clear();
  assert.deepEqual(store.load(), []);
});

test('store: keeps at most 2000 entries, dropping the oldest', () => {
  const kv = new MemoryStore();
  const raw = [];
  for (let i = 0; i < 2000; i++) raw.push({ atMs: NOW - (2100 - i) * DAY, kg: 80 });
  kv.put('body.v1', JSON.stringify(raw));
  const store = new BodyStore(kv);
  store.add(NOW, 75);
  const list = store.load();
  assert.equal(list.length, 2000);
  assert.equal(list[0].atMs, NOW - 2099 * DAY);
  assert.equal(list[list.length - 1].kg, 75);
});

test('stats: empty list gives zeros and no eta', () => {
  const s = weightStats([], 70, NOW);
  assert.equal(s.count, 0);
  assert.equal(s.latest, 0);
  assert.equal(s.change, 0);
  assert.equal(s.weeklyRate, 0);
  assert.equal(s.etaDays, -1);
  assert.equal(s.goalProgress, 0);
});

test('stats: change, change7, change30, lowest and highest', () => {
  const list = [e(40, 85), e(30, 84), e(20, 83), e(8, 82.5), e(6, 82), e(0, 81.4)];
  const s = weightStats(list, 0, NOW);
  assert.equal(s.count, 6);
  assert.equal(s.start, 85);
  assert.equal(s.latest, 81.4);
  assert.equal(s.latestAt, at(0));
  assert.equal(s.change, -3.6);
  assert.equal(s.change7, -1.1);   // vs 8 days ago (6 days ago is too recent)
  assert.equal(s.change30, -2.6);  // vs 30 days ago
  assert.equal(s.lowest, 81.4);
  assert.equal(s.highest, 85);
  // Only two entries a few days apart: nothing old enough.
  const short = weightStats([e(3, 80), e(0, 79)], 0, NOW);
  assert.equal(short.change7, 0);
  assert.equal(short.change30, 0);
});

test('stats: weekly rate sign follows the trend; needs two points', () => {
  const losing = weightStats([e(21, 84), e(14, 83.5), e(7, 83), e(0, 82.5)], 0, NOW);
  assert.ok(Math.abs(losing.weeklyRate - -0.5) < 0.01);
  const gaining = weightStats([e(14, 60), e(7, 60.4), e(0, 60.8)], 0, NOW);
  assert.ok(gaining.weeklyRate > 0);
  assert.equal(weightStats([e(0, 70)], 0, NOW).weeklyRate, 0);
  // Points older than 30 days do not count.
  assert.equal(weightStats([e(60, 90), e(0, 70)], 0, NOW).weeklyRate, 0);
});

test('stats: goal progress and eta for a losing goal', () => {
  const s = weightStats([e(21, 84), e(14, 83.5), e(7, 83), e(0, 82.5)], 80, NOW);
  assert.equal(s.goal, 80);
  assert.equal(s.toGoal, -2.5);
  assert.ok(Math.abs(s.goalProgress - 0.375) < 1e-9); // 1.5 of 4 kg
  assert.equal(s.etaDays, 35); // 2.5 kg at 0.5 kg/week
});

test('stats: goal progress for a gaining goal, clamped, and moving away gives no eta', () => {
  const s = weightStats([e(14, 60), e(7, 61), e(0, 62)], 64, NOW);
  assert.equal(s.toGoal, 2);
  assert.ok(Math.abs(s.goalProgress - 0.5) < 1e-9);
  assert.equal(s.etaDays, 14);
  const away = weightStats([e(14, 62), e(7, 61), e(0, 60)], 64, NOW);
  assert.equal(away.goalProgress, 0);
  assert.equal(away.etaDays, -1);
  const past = weightStats([e(14, 60), e(0, 66)], 64, NOW);
  assert.equal(past.goalProgress, 1);
  const none = weightStats([e(14, 60), e(0, 62)], 0, NOW);
  assert.equal(none.toGoal, 0);
  assert.equal(none.goalProgress, 0);
  assert.equal(none.etaDays, -1);
  const reached = weightStats([e(14, 60), e(0, 64)], 64, NOW);
  assert.equal(reached.etaDays, 0);
});

test('stats and series ignore future entries', () => {
  const list = [e(2, 70), e(0, 69), new WeightEntry(NOW + DAY, 60)];
  const s = weightStats(list, 0, NOW);
  assert.equal(s.count, 2);
  assert.equal(s.latest, 69);
  assert.equal(s.lowest, 69);
  const sr = series(list, NOW, 30);
  assert.deepEqual(sr.map((x) => x.kg), [70, 69]);
});

test('series: only the last N days, ascending, input untouched', () => {
  const list = [e(0, 70), e(40, 75), e(10, 72), e(5, 71)];
  const sr = series(list, NOW, 14);
  assert.deepEqual(sr.map((x) => x.kg), [72, 71, 70]);
  assert.equal(list[0].kg, 70);
  assert.equal(series(list, NOW, 90).length, 4);
});

test('formatting weights and deltas', () => {
  assert.equal(formatKg(72.4), '72.4 kg');
  assert.equal(formatKg(72), '72 kg');
  assert.equal(formatKg(71.96), '72 kg');
  assert.equal(formatKg(72.44), '72.4 kg');
  assert.equal(formatDelta(1.2), '+1.2 kg');
  assert.equal(formatDelta(-0.8), '−0.8 kg');
  assert.equal(formatDelta(0.04), '±0 kg');
  assert.equal(formatDelta(-0.049), '±0 kg');
  assert.equal(formatDelta(2), '+2 kg');
});
