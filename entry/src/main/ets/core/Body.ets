import { KeyValueStore } from './Store';

// Body weight log and BMI. Pure logic: the weight list is stored as validated JSON (one
// entry per local calendar day), and the stats/BMI helpers are plain functions so the
// UI can chart and describe progress without any of it living in a view.

export const KG_MIN = 20;
export const KG_MAX = 400;
export const HEIGHT_MIN = 50;
export const HEIGHT_MAX = 300;
export const MAX_ENTRIES = 2000;
export const BMI_HEALTHY_MIN = 18.5;
export const BMI_HEALTHY_MAX = 24.9;
export const BMI_SCALE_MIN = 15;
export const BMI_SCALE_MAX = 40;

const KEY_BODY = 'body.v1';
const DAY_MS = 24 * 3600000;

export class WeightEntry {
  atMs: number = 0;
  kg: number = 0;

  constructor(atMs: number, kg: number) {
    this.atMs = atMs;
    this.kg = kg;
  }
}

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

function round2(v: number): number {
  return Math.round(v * 100) / 100;
}

function validKg(kg: number): boolean {
  return typeof kg === 'number' && isFinite(kg) && kg >= KG_MIN && kg <= KG_MAX;
}

function validAt(atMs: number): boolean {
  return typeof atMs === 'number' && isFinite(atMs) && atMs > 0;
}

function validHeight(heightCm: number): boolean {
  return typeof heightCm === 'number' && isFinite(heightCm) && heightCm >= HEIGHT_MIN && heightCm <= HEIGHT_MAX;
}

// Local calendar day key, e.g. 20261003.
function dayKey(ms: number): number {
  const d = new Date(ms);
  return d.getFullYear() * 10000 + (d.getMonth() + 1) * 100 + d.getDate();
}

function sortAsc(list: WeightEntry[]): WeightEntry[] {
  list.sort((a: WeightEntry, b: WeightEntry): number => a.atMs - b.atMs);
  return list;
}

export class BodyStore {
  private kv: KeyValueStore;

  constructor(kv: KeyValueStore) {
    this.kv = kv;
  }

  load(): WeightEntry[] {
    const text = this.kv.get(KEY_BODY);
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
    const out: WeightEntry[] = [];
    for (let i = 0; i < parsed.length; i++) {
      const raw = parsed[i] as WeightEntry;
      if (raw === null || raw === undefined || typeof raw !== 'object') {
        continue;
      }
      if (validAt(raw.atMs) && validKg(raw.kg)) {
        out.push(new WeightEntry(raw.atMs, raw.kg));
      }
    }
    return sortAsc(out);
  }

  // Logs a weight. Logging again on the same local day replaces that day's entry.
  // Returns false (and stores nothing) for an invalid time or weight.
  add(atMs: number, kg: number): boolean {
    if (!validAt(atMs) || !validKg(kg)) {
      return false;
    }
    const key = dayKey(atMs);
    const all = this.load().filter((e: WeightEntry): boolean => dayKey(e.atMs) !== key);
    all.push(new WeightEntry(atMs, round2(kg)));
    sortAsc(all);
    while (all.length > MAX_ENTRIES) {
      all.shift();
    }
    this.save(all);
    return true;
  }

  // Removes the entry logged at exactly this time.
  remove(atMs: number): void {
    const all = this.load();
    const kept = all.filter((e: WeightEntry): boolean => e.atMs !== atMs);
    if (kept.length !== all.length) {
      this.save(kept);
    }
  }

  clear(): void {
    this.kv.put(KEY_BODY, '');
  }

  private save(list: WeightEntry[]): void {
    this.kv.put(KEY_BODY, JSON.stringify(list));
  }
}

// ---- BMI ----

// Body mass index rounded to one decimal; 0 when height or weight is missing or invalid.
export function bmi(kg: number, heightCm: number): number {
  if (!validKg(kg) || !validHeight(heightCm)) {
    return 0;
  }
  const m = heightCm / 100;
  return round1(kg / (m * m));
}

// [minKg, maxKg] for a BMI of 18.5-24.9 at this height; [0, 0] for an invalid height.
export function healthyRange(heightCm: number): number[] {
  if (!validHeight(heightCm)) {
    return [0, 0];
  }
  const m = heightCm / 100;
  return [round1(BMI_HEALTHY_MIN * m * m), round1(BMI_HEALTHY_MAX * m * m)];
}

export class BmiInfo {
  value: number = 0;
  label: string = 'Add height and weight';
  detail: string = '';
  position: number = 0; // 0..1 on a 15..40 scale, for a gauge
}

// Neutral wording for the WHO adult categories.
export function bmiInfo(kg: number, heightCm: number): BmiInfo {
  const info = new BmiInfo();
  const v = bmi(kg, heightCm);
  if (v <= 0) {
    info.detail = 'BMI needs your height and a logged weight';
    return info;
  }
  info.value = v;
  if (v < 18.5) {
    info.label = 'Below range';
  } else if (v < 25) {
    info.label = 'Healthy range';
  } else if (v < 30) {
    info.label = 'Above range';
  } else {
    info.label = 'Well above range';
  }
  const r = healthyRange(heightCm);
  info.detail = 'Healthy range for your height: ' + r[0].toFixed(1) + '–' + r[1].toFixed(1) + ' kg';
  const p = (v - BMI_SCALE_MIN) / (BMI_SCALE_MAX - BMI_SCALE_MIN);
  info.position = Math.min(1, Math.max(0, p));
  return info;
}

// ---- Stats ----

export class WeightStats {
  latest: number = 0;
  latestAt: number = 0;
  start: number = 0;
  change: number = 0;       // latest - start
  change7: number = 0;      // latest minus the most recent entry at least 7 days older; 0 if none
  change30: number = 0;     // same, 30 days
  weeklyRate: number = 0;   // kg per week, least-squares slope over the last 30 days
  lowest: number = 0;
  highest: number = 0;
  goal: number = 0;
  toGoal: number = 0;       // goal - latest; 0 when no goal
  goalProgress: number = 0; // 0..1 from start to goal
  etaDays: number = -1;     // days to goal at weeklyRate, -1 when not moving towards it
  count: number = 0;
}

function changeOver(list: WeightEntry[], days: number): number {
  const last = list[list.length - 1];
  const cutoff = last.atMs - days * DAY_MS;
  for (let i = list.length - 2; i >= 0; i--) {
    if (list[i].atMs <= cutoff) {
      return round1(last.kg - list[i].kg);
    }
  }
  return 0;
}

// Least-squares slope in kg/week over entries from the last 30 days.
function slopePerWeek(list: WeightEntry[], nowMs: number): number {
  const from = nowMs - 30 * DAY_MS;
  const pts = list.filter((e: WeightEntry): boolean => e.atMs >= from);
  if (pts.length < 2) {
    return 0;
  }
  const t0 = pts[0].atMs;
  let sx = 0;
  let sy = 0;
  for (let i = 0; i < pts.length; i++) {
    sx += (pts[i].atMs - t0) / DAY_MS;
    sy += pts[i].kg;
  }
  const mx = sx / pts.length;
  const my = sy / pts.length;
  let num = 0;
  let den = 0;
  for (let i = 0; i < pts.length; i++) {
    const dx = (pts[i].atMs - t0) / DAY_MS - mx;
    num += dx * (pts[i].kg - my);
    den += dx * dx;
  }
  if (den === 0) {
    return 0;
  }
  return round2((num / den) * 7);
}

export function weightStats(entries: WeightEntry[], goalKg: number, nowMs: number): WeightStats {
  const s = new WeightStats();
  const hasGoal = validKg(goalKg);
  s.goal = hasGoal ? goalKg : 0;
  const list = sortAsc(entries.filter((e: WeightEntry): boolean =>
    e !== null && e !== undefined && validAt(e.atMs) && validKg(e.kg) && e.atMs <= nowMs));
  if (list.length === 0) {
    return s;
  }
  const first = list[0];
  const last = list[list.length - 1];
  s.count = list.length;
  s.latest = last.kg;
  s.latestAt = last.atMs;
  s.start = first.kg;
  s.change = round1(last.kg - first.kg);
  s.change7 = changeOver(list, 7);
  s.change30 = changeOver(list, 30);
  s.weeklyRate = slopePerWeek(list, nowMs);
  let lo = last.kg;
  let hi = last.kg;
  for (let i = 0; i < list.length; i++) {
    lo = Math.min(lo, list[i].kg);
    hi = Math.max(hi, list[i].kg);
  }
  s.lowest = lo;
  s.highest = hi;
  if (hasGoal) {
    s.toGoal = round1(goalKg - last.kg);
    const span = goalKg - first.kg;
    if (Math.abs(span) >= 0.05) {
      const p = (last.kg - first.kg) / span;
      s.goalProgress = Math.min(1, Math.max(0, p));
    }
    if (Math.abs(s.toGoal) < 0.05) {
      s.etaDays = 0;
    } else if (s.weeklyRate !== 0 && (s.weeklyRate > 0) === (s.toGoal > 0)) {
      s.etaDays = Math.ceil(Math.abs(s.toGoal) / Math.abs(s.weeklyRate) * 7);
    }
  }
  return s;
}

// Entries from the last `days` days (not in the future), ascending, for charts.
export function series(entries: WeightEntry[], nowMs: number, days: number): WeightEntry[] {
  const from = nowMs - days * DAY_MS;
  return sortAsc(entries.filter((e: WeightEntry): boolean =>
    e !== null && e !== undefined && e.atMs >= from && e.atMs <= nowMs));
}

// ---- Formatting ----

function oneDecimal(kg: number): string {
  const r = round1(kg);
  return r === Math.round(r) ? ('' + Math.round(r)) : r.toFixed(1);
}

// '72.4 kg', integers as '72 kg'.
export function formatKg(kg: number): string {
  if (typeof kg !== 'number' || !isFinite(kg)) {
    return '– kg';
  }
  return oneDecimal(kg) + ' kg';
}

// '+1.2 kg', '−0.8 kg' (real minus sign), '±0 kg' when the change rounds to nothing.
export function formatDelta(kg: number): string {
  if (typeof kg !== 'number' || !isFinite(kg) || Math.abs(kg) < 0.05) {
    return '±0 kg';
  }
  return (kg > 0 ? '+' : '−') + oneDecimal(Math.abs(kg)) + ' kg';
}
