import { AccelSample, SetRecord, WorkoutRecord, EXERCISES, GROUPS } from './Types';

// Deterministic simulation used for the emulator demo and the unit tests.
// Everything produced here is flagged `simulated = true` and the UI shows a DEMO badge:
// the emulator has no real motion, so the demo replays this synthetic stream.

export class Rng {
  private s: number;

  constructor(seed: number) {
    this.s = seed >>> 0;
  }

  next(): number {
    this.s = (this.s + 0x6D2B79F5) >>> 0;
    let t = this.s;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return (((t ^ (t >>> 14)) >>> 0) / 4294967296);
  }

  gauss(): number {
    const u = Math.max(1e-9, this.next());
    const v = this.next();
    return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
  }
}

export class TraceOptions {
  reps: number = 8;
  baseIntervalMs: number = 2000;
  slowdown: number = 0.0;        // 0.5 => the last rep takes 50% longer
  amplitude: number = 3.0;       // m/s^2 of the drive phase
  ampDrop: number = 0.0;         // 0.3 => last rep has 30% less drive
  noise: number = 0.12;
  hz: number = 50;
  leadInMs: number = 1500;
  tailMs: number = 8000;
  seed: number = 7;
  startMs: number = 0;
  tilt: number = 0.35;           // phone orientation in the pocket, radians
}

function bump(x: number, center: number, width: number): number {
  const d = (x - center) / width;
  return Math.exp(-0.5 * d * d);
}

// One synthetic set: gravity (tilted), a down/drive/stop acceleration pattern per rep,
// lateral sway and sensor noise.
export function generateSet(o: TraceOptions): AccelSample[] {
  const rng = new Rng(o.seed);
  const out: AccelSample[] = [];
  const dt = 1000 / o.hz;
  const g = 9.81;
  // gravity direction (device frame), tilted by o.tilt around x and y
  const ux = Math.sin(o.tilt) * 0.6;
  const uy = -Math.sin(o.tilt) * 0.5;
  const uz = Math.sqrt(1 - ux * ux - uy * uy);

  // build rep schedule
  const periods: number[] = [];
  for (let k = 0; k < o.reps; k++) {
    const f = o.reps > 1 ? k / (o.reps - 1) : 0;
    periods.push(o.baseIntervalMs * (1 + o.slowdown * f));
  }
  let total = o.leadInMs;
  for (let k = 0; k < periods.length; k++) {
    total += periods[k];
  }
  total += o.tailMs;

  const starts: number[] = [];
  let acc = o.leadInMs;
  for (let k = 0; k < periods.length; k++) {
    starts.push(acc);
    acc += periods[k];
  }

  for (let t = 0; t <= total; t += dt) {
    let dyn = 0;
    for (let k = 0; k < periods.length; k++) {
      const T = periods[k];
      const f = o.reps > 1 ? k / (o.reps - 1) : 0;
      const amp = o.amplitude * (1 - o.ampDrop * f);
      const local = t - starts[k];
      if (local < -T * 0.2 || local > T * 1.2) {
        continue;
      }
      dyn += amp * (-0.45 * bump(local, 0.12 * T, 0.07 * T) + 1.0 * bump(local, 0.56 * T, 0.09 * T) - 0.4 * bump(local, 0.92 * T, 0.07 * T));
    }
    const sway = 0.25 * Math.sin(t / 700);
    const ax = (g + dyn) * ux + sway + o.noise * rng.gauss();
    const ay = (g + dyn) * uy + 0.5 * sway + o.noise * rng.gauss();
    const az = (g + dyn) * uz + o.noise * rng.gauss();
    out.push(new AccelSample(o.startMs + t, ax, ay, az));
  }
  return out;
}

// Stationary phone (resting on a bench) with sensor noise only.
export function generateIdle(durationMs: number, seed: number, startMs: number): AccelSample[] {
  const rng = new Rng(seed);
  const out: AccelSample[] = [];
  for (let t = 0; t <= durationMs; t += 20) {
    out.push(new AccelSample(startMs + t, 0.1 * rng.gauss(), 0.1 * rng.gauss(), 9.81 + 0.1 * rng.gauss()));
  }
  return out;
}

// Walking: strong rhythmic vertical motion at ~1.8 Hz, which must not be counted as reps
// of a slow lift because of the minimum interval and amplitude rules.
export function generateWalking(durationMs: number, seed: number, startMs: number): AccelSample[] {
  const rng = new Rng(seed);
  const out: AccelSample[] = [];
  for (let t = 0; t <= durationMs; t += 20) {
    const phase = 2 * Math.PI * 1.8 * (t / 1000);
    out.push(new AccelSample(startMs + t, 0.4 * Math.sin(phase / 2) + 0.1 * rng.gauss(), 0.3 * rng.gauss(), 9.81 + 1.6 * Math.sin(phase) + 0.1 * rng.gauss()));
  }
  return out;
}

// A believable two-week history for the "week in 30 seconds" demo.
export function generateHistory(nowMs: number, days: number, seed: number): WorkoutRecord[] {
  const rng = new Rng(seed);
  const result: WorkoutRecord[] = [];
  const dayMs = 86400000;
  const plan: string[][] = [
    ['squat', 'deadlift'],
    ['press', 'curl'],
    [],
    ['squat', 'crunch'],
    ['deadlift', 'press'],
    [],
    []
  ];
  for (let d = days; d >= 1; d--) {
    const exs = plan[(days - d) % plan.length];
    if (exs.length === 0) {
      continue;
    }
    const w = new WorkoutRecord();
    const end = nowMs - d * dayMs + 18 * 3600000;
    w.endMs = Math.min(end, nowMs - 3600000);
    w.startMs = w.endMs - 55 * 60000;
    w.id = 'sim' + d;
    w.simulated = true;
    let t = w.startMs;
    for (let e = 0; e < exs.length; e++) {
      const ex = EXERCISES.filter((x) => x.id === exs[e])[0];
      for (let s = 0; s < 3; s++) {
        const rec = new SetRecord();
        rec.exercise = ex.id;
        rec.group = ex.group;
        rec.startMs = t;
        rec.endMs = t + 45000;
        rec.reps = 6 + Math.floor(rng.next() * 5);
        rec.quality = 0.75 + rng.next() * 0.2;
        rec.fatigue = 0.1 + rng.next() * 0.25;
        rec.simulated = true;
        for (let r = 1; r < rec.reps; r++) {
          rec.intervalsMs.push(2000 + Math.round(rng.gauss() * 80) + r * 25);
          rec.peaks.push(3 - r * 0.05);
        }
        w.sets.push(rec);
        t += 150000;
      }
    }
    result.push(w);
  }
  return result;
}

export function groupIndex(group: string): number {
  return GROUPS.indexOf(group);
}
