import { RepEvent, SetRecord, clamp } from './Types';

// Turns a stream of reps into set-level feedback.
//
// Fatigue is a *proxy* built from what a phone can measure: how much slower the rep
// interval became versus the fastest early reps, and how much the drive peak dropped.
// It is explained to the user with the underlying numbers, never presented as a medical
// or biomechanical measurement.

export class AnalyzerConfig {
  baselineReps: number = 3;      // first N intervals form the "fresh" baseline
  stopFatigue: number = 0.25;    // fatigue level that triggers the "rack it" cue
  minRepsForCue: number = 4;
  speedWeight: number = 0.65;
  powerWeight: number = 0.35;
}

export class SetStatus {
  reps: number = 0;
  fatigue: number = 0;           // smoothed, 0..1
  speedLossPct: number = 0;      // last rep vs fastest early rep
  powerLossPct: number = 0;
  stopCue: boolean = false;      // true exactly once, on the rep that crosses the threshold
  lastIntervalMs: number = 0;    // time since the previous rep (0 for the first)
  explanation: string = '';
}

export class SetAnalyzer {
  private cfg: AnalyzerConfig;
  private intervals: number[] = [];
  private peaks: number[] = [];
  private fatigueHistory: number[] = [];
  private cueFired: boolean = false;
  private nReps: number = 0;

  constructor(cfg: AnalyzerConfig) {
    this.cfg = cfg;
  }

  reset(): void {
    this.intervals = [];
    this.peaks = [];
    this.fatigueHistory = [];
    this.cueFired = false;
    this.nReps = 0;
  }

  add(rep: RepEvent): SetStatus {
    this.nReps++;
    this.peaks.push(rep.peak);
    if (rep.intervalMs > 0) {
      this.intervals.push(rep.intervalMs);
    }
    const st = new SetStatus();
    st.reps = this.nReps;
    st.lastIntervalMs = rep.intervalMs;

    let fatigueNow = 0;
    if (this.intervals.length >= 2) {
      const bestInterval = this.baselineInterval();
      const lastInterval = this.intervals[this.intervals.length - 1];
      const bestPeak = this.baselinePeak();
      const speedLoss = clamp(1 - bestInterval / lastInterval, 0, 1);
      const powerLoss = clamp(1 - rep.peak / bestPeak, 0, 1);
      fatigueNow = this.cfg.speedWeight * speedLoss + this.cfg.powerWeight * powerLoss;
      st.speedLossPct = Math.round(speedLoss * 100);
      st.powerLossPct = Math.round(powerLoss * 100);
      st.explanation = 'Rep ' + rep.index + ' took ' + (lastInterval / 1000).toFixed(1) + ' s vs ' +
        (bestInterval / 1000).toFixed(1) + ' s at your fastest (' + st.speedLossPct + '% slower), ' +
        'drive power ' + st.powerLossPct + '% lower.';
    } else {
      st.explanation = 'Collecting a fresh baseline from your first reps.';
    }
    this.fatigueHistory.push(fatigueNow);
    st.fatigue = this.smoothedFatigue();

    if (!this.cueFired && this.nReps >= this.cfg.minRepsForCue && st.fatigue >= this.cfg.stopFatigue) {
      this.cueFired = true;
      st.stopCue = true;
    }
    return st;
  }

  smoothedFatigue(): number {
    const n = this.fatigueHistory.length;
    if (n === 0) {
      return 0;
    }
    if (n === 1) {
      return this.fatigueHistory[0];
    }
    return (this.fatigueHistory[n - 1] + this.fatigueHistory[n - 2]) / 2;
  }

  // Tempo consistency 0..1 (1 = metronome). Coefficient of variation of the intervals.
  quality(): number {
    if (this.intervals.length < 2) {
      return 1;
    }
    let sum = 0;
    for (let i = 0; i < this.intervals.length; i++) {
      sum += this.intervals[i];
    }
    const mean = sum / this.intervals.length;
    let varSum = 0;
    for (let i = 0; i < this.intervals.length; i++) {
      const d = this.intervals[i] - mean;
      varSum += d * d;
    }
    const cv = Math.sqrt(varSum / this.intervals.length) / mean;
    return clamp(1 - cv * 1.5, 0, 1);
  }

  fillRecord(rec: SetRecord): void {
    rec.reps = this.nReps;
    rec.intervalsMs = this.intervals.slice();
    rec.peaks = this.peaks.slice();
    rec.fatigue = this.smoothedFatigue();
    rec.quality = this.quality();
  }

  private baselineInterval(): number {
    const n = Math.min(this.cfg.baselineReps, this.intervals.length);
    let best = this.intervals[0];
    for (let i = 1; i < n; i++) {
      best = Math.min(best, this.intervals[i]);
    }
    return best;
  }

  private baselinePeak(): number {
    const n = Math.min(this.cfg.baselineReps, this.peaks.length);
    let best = this.peaks[0];
    for (let i = 1; i < n; i++) {
      best = Math.max(best, this.peaks[i]);
    }
    return best;
  }
}
