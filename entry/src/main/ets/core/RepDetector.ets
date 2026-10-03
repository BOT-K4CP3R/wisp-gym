import { AccelSample, RepEvent } from './Types';

// Streaming repetition detector.
//
// A phone carried on the body sees each repetition as one dominant upward acceleration
// burst (the drive out of the bottom of a squat, the pull of a curl, ...). We remove the
// slow gravity component, project the remainder onto the gravity axis (so the phone's
// orientation in the pocket does not matter) and count peaks of that signal.
//
// This is a heuristic counter, not a form checker: it is validated on synthetic and
// recorded traces (see tests/) and exposes a tempo proxy rather than true bar velocity.

export class RepDetectorConfig {
  minPeak: number = 1.1;          // m/s^2 above gravity needed to count a rep
  minIntervalMs: number = 600;    // refractory time between two reps
  maxIntervalMs: number = 9000;   // longer pauses restart the tempo baseline
  gravityTauMs: number = 2500;    // low-pass time constant for the gravity estimate
  smoothTauMs: number = 90;       // smoothing of the vertical signal
  releaseRatio: number = 0.5;     // burst ends when the signal drops below this share of its peak
  adaptiveFloor: number = 0.4;    // peaks below this share of the recent median are ignored
  stepMinMs: number = 350;        // walking cadence band (raw peak spacing)
  stepMaxMs: number = 800;
  walkClearMs: number = 2500;     // walking state ends after this long without a step-like peak
  confirmMs: number = 1400;       // a rep is confirmed once no walking cadence follows it
}

export class RepDetector {
  private cfg: RepDetectorConfig;
  private ready: boolean = false;
  private lastT: number = 0;
  private gx: number = 0;
  private gy: number = 0;
  private gz: number = 0;
  private vert: number = 0;
  private inBurst: boolean = false;
  private burstPeak: number = 0;
  private burstPeakT: number = 0;
  private lastRepT: number = -1;
  private count: number = 0;
  private recentPeaks: number[] = [];
  private rawLastT: number = -1;
  private stepStreak: number = 0;
  private walking: boolean = false;
  private pending: RepEvent | null = null;
  private pendingDue: number = 0;

  constructor(cfg: RepDetectorConfig) {
    this.cfg = cfg;
  }

  reset(): void {
    this.ready = false;
    this.inBurst = false;
    this.burstPeak = 0;
    this.lastRepT = -1;
    this.count = 0;
    this.recentPeaks = [];
    this.vert = 0;
    this.rawLastT = -1;
    this.stepStreak = 0;
    this.walking = false;
    this.pending = null;
  }

  reps(): number {
    return this.count;
  }

  lastRepTime(): number {
    return this.lastRepT;
  }

  isWalking(): boolean {
    return this.walking;
  }

  // Emit a repetition that is still waiting for confirmation (call when the set ends).
  flush(): RepEvent | null {
    const p = this.pending;
    this.pending = null;
    return p;
  }

  // Feed one accelerometer sample. Returns a RepEvent when a repetition was completed.
  feed(s: AccelSample): RepEvent | null {
    if (!isFinite(s.t) || !isFinite(s.x) || !isFinite(s.y) || !isFinite(s.z)) {
      return null; // drop corrupt samples instead of poisoning the filters
    }
    if (!this.ready) {
      this.gx = s.x;
      this.gy = s.y;
      this.gz = s.z;
      this.lastT = s.t;
      this.ready = true;
      return null;
    }
    let dt = s.t - this.lastT;
    if (dt <= 0) {
      return null;
    }
    this.lastT = s.t;
    if (dt > 250) {
      // sensor gap: do not integrate across it
      dt = 250;
    }
    const ag = 1 - Math.exp(-dt / this.cfg.gravityTauMs);
    this.gx += ag * (s.x - this.gx);
    this.gy += ag * (s.y - this.gy);
    this.gz += ag * (s.z - this.gz);
    const gm = Math.sqrt(this.gx * this.gx + this.gy * this.gy + this.gz * this.gz);
    if (gm < 1) {
      return null; // free fall / invalid orientation
    }
    const ux = this.gx / gm;
    const uy = this.gy / gm;
    const uz = this.gz / gm;
    // Dynamic acceleration projected on the "up" axis (positive = accelerating upwards).
    const dyn = (s.x - this.gx) * ux + (s.y - this.gy) * uy + (s.z - this.gz) * uz;
    const as = 1 - Math.exp(-dt / this.cfg.smoothTauMs);
    this.vert += as * (dyn - this.vert);

    let due: RepEvent | null = null;
    if (this.pending !== null && s.t >= this.pendingDue) {
      due = this.pending;
      this.pending = null;
    }

    const threshold = this.threshold();
    if (!this.inBurst) {
      if (this.vert > threshold) {
        this.inBurst = true;
        this.burstPeak = this.vert;
        this.burstPeakT = s.t;
      }
      return due;
    }
    if (this.vert > this.burstPeak) {
      this.burstPeak = this.vert;
      this.burstPeakT = s.t;
    }
    if (this.vert < this.burstPeak * this.cfg.releaseRatio) {
      this.inBurst = false;
      const emitted = this.completeBurst();
      return due !== null ? due : emitted;
    }
    return due;
  }

  private threshold(): number {
    let t = this.cfg.minPeak;
    if (this.recentPeaks.length >= 3) {
      const med = this.median(this.recentPeaks);
      t = Math.max(t, med * this.cfg.adaptiveFloor);
    }
    return t;
  }

  private completeBurst(): RepEvent | null {
    const peakT = this.burstPeakT;
    const peak = this.burstPeak;
    this.burstPeak = 0;

    // Walking detection on the raw peak cadence (before any rep filtering).
    const raw = this.rawLastT >= 0 ? peakT - this.rawLastT : 99999;
    this.rawLastT = peakT;
    if (raw >= this.cfg.stepMinMs && raw <= this.cfg.stepMaxMs) {
      this.stepStreak++;
    } else {
      this.stepStreak = 0;
      if (raw > this.cfg.walkClearMs) {
        this.walking = false; // a real pause: lifting can resume
      }
    }
    if (this.stepStreak >= 2) {
      this.walking = true;
      if (this.pending !== null) {
        this.pending = null; // the pending "rep" was just a step
        this.count--;
      }
      this.lastRepT = peakT;
      return null;
    }
    if (this.walking) {
      return null;
    }

    let interval = 0;
    if (this.lastRepT >= 0) {
      interval = peakT - this.lastRepT;
      if (interval < this.cfg.minIntervalMs) {
        return null; // double bump inside one repetition
      }
      if (interval > this.cfg.maxIntervalMs) {
        interval = 0; // too long: treat as the first rep of a new run
      }
    }
    this.lastRepT = peakT;
    this.recentPeaks.push(peak);
    if (this.recentPeaks.length > 5) {
      this.recentPeaks.shift();
    }
    const previous = this.pending;
    this.count++;
    this.pending = new RepEvent(this.count, peakT, interval, peak);
    this.pendingDue = peakT + this.cfg.confirmMs;
    return previous;
  }

  private median(values: number[]): number {
    const copy: number[] = values.slice();
    copy.sort((a: number, b: number): number => a - b);
    const mid = Math.floor(copy.length / 2);
    if (copy.length % 2 === 1) {
      return copy[mid];
    }
    return (copy[mid - 1] + copy[mid]) / 2;
  }
}
