// Shared data model. Everything here is a plain class (no interfaces / enums) so the same
// source compiles with ArkTS and can be unit-tested on Node (see tests/run.mjs).

export class AccelSample {
  t: number; // milliseconds, monotonic
  x: number; // m/s^2, device frame
  y: number;
  z: number;

  constructor(t: number, x: number, y: number, z: number) {
    this.t = t;
    this.x = x;
    this.y = y;
    this.z = z;
  }
}

export class RepEvent {
  index: number;      // 1-based rep number within the set
  peakMs: number;     // time of the drive-phase acceleration peak
  intervalMs: number; // time since the previous rep peak (0 for the first rep)
  peak: number;       // peak vertical acceleration above gravity, m/s^2

  constructor(index: number, peakMs: number, intervalMs: number, peak: number) {
    this.index = index;
    this.peakMs = peakMs;
    this.intervalMs = intervalMs;
    this.peak = peak;
  }
}

export class Exercise {
  id: string;
  name: string;
  group: string;      // one of GROUPS
  placement: string;  // where the phone should be carried
  minPeak: number;    // minimum vertical acceleration (m/s^2) counted as a rep drive

  constructor(id: string, name: string, group: string, placement: string, minPeak: number) {
    this.id = id;
    this.name = name;
    this.group = group;
    this.placement = placement;
    this.minPeak = minPeak;
  }
}

export const GROUPS: string[] = ['legs', 'push', 'pull', 'core'];

export const EXERCISES: Exercise[] = [
  new Exercise('squat', 'Squat', 'legs', 'Front pocket or belt', 1.1),
  new Exercise('deadlift', 'Deadlift', 'pull', 'Front pocket or belt', 1.0),
  new Exercise('curl', 'Biceps curl', 'pull', 'Armband or hand', 1.6),
  new Exercise('press', 'Overhead press', 'push', 'Armband or hand', 1.6),
  new Exercise('crunch', 'Crunch', 'core', 'Chest pocket', 0.9)
];

export function findExercise(id: string): Exercise {
  for (let i = 0; i < EXERCISES.length; i++) {
    if (EXERCISES[i].id === id) {
      return EXERCISES[i];
    }
  }
  return EXERCISES[0];
}

export class SetRecord {
  exercise: string = '';
  group: string = 'legs';
  startMs: number = 0;
  endMs: number = 0;
  reps: number = 0;
  intervalsMs: number[] = [];
  peaks: number[] = [];
  fatigue: number = 0;  // 0..1, tempo + drive loss at the end of the set
  quality: number = 1;  // 0..1, tempo consistency
  simulated: boolean = false;
}

export class WorkoutRecord {
  id: string = '';
  startMs: number = 0;
  endMs: number = 0;
  sets: SetRecord[] = [];
  simulated: boolean = false;
}

// 12345 -> "12,345"
export function groupThousands(n: number): string {
  const s = '' + Math.round(Math.abs(n));
  let out = '';
  for (let i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 === 0) {
      out += ',';
    }
    out += s.charAt(i);
  }
  return (n < 0 ? '-' : '') + out;
}

export function clamp(v: number, lo: number, hi: number): number {
  if (isNaN(v)) {
    return lo;
  }
  return Math.min(hi, Math.max(lo, v));
}
