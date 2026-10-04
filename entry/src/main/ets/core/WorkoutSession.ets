import { AccelSample, Exercise, SetRecord, WorkoutRecord, findExercise } from './Types';
import { RepDetector, RepDetectorConfig } from './RepDetector';
import { SetAnalyzer, AnalyzerConfig, SetStatus } from './SetAnalyzer';

// State machine for one gym visit: idle -> set -> rest -> set -> ... -> finished.

export class SessionUpdate {
  phase: string = 'idle';
  reps: number = 0;
  newRep: boolean = false;
  stopCue: boolean = false;
  fatigue: number = 0;
  explanation: string = '';
  autoEnded: boolean = false;
  intervalMs: number = 0;
}

export class SessionConfig {
  setIdleEndMs: number = 7000;   // no rep for this long after >=1 rep ends the set
  restBaseMs: number = 90000;
  restFatiguedMs: number = 150000;
  restFatigueLimit: number = 0.3;
  maxRestMs: number = 600000;
}

export class WorkoutSession {
  private cfg: SessionConfig;
  private simulated: boolean;
  private detector: RepDetector = new RepDetector(new RepDetectorConfig());
  private analyzer: SetAnalyzer = new SetAnalyzer(new AnalyzerConfig());
  private current: Exercise = findExercise('squat');
  private phaseName: string = 'idle';
  private setStartMs: number = 0;
  private restEndMs: number = 0;
  private restTotal: number = 0;
  private lastRepMs: number = 0;
  private record: WorkoutRecord = new WorkoutRecord();
  private lastStatus: SetStatus = new SetStatus();
  private weightKg: number = 0;

  constructor(startMs: number, simulated: boolean, cfg: SessionConfig) {
    this.cfg = cfg;
    this.simulated = simulated;
    this.record.id = 'w' + Math.floor(startMs);
    this.record.startMs = startMs;
    this.record.simulated = simulated;
  }

  // Switching to the simulated stream mid-visit: everything recorded from now on, and the
  // visit itself, are flagged as simulated.
  markSimulated(): void {
    this.simulated = true;
    this.record.simulated = true;
  }

  phase(): string {
    return this.phaseName;
  }

  exercise(): Exercise {
    return this.current;
  }

  setsDone(): number {
    return this.record.sets.length;
  }

  startSet(exerciseId: string, nowMs: number, weightKg?: number): void {
    this.current = findExercise(exerciseId);
    this.weightKg = weightKg === undefined ? 0 : Math.max(0, weightKg);
    const cfg = new RepDetectorConfig();
    cfg.minPeak = this.current.minPeak;
    this.detector = new RepDetector(cfg);
    this.analyzer.reset();
    this.setStartMs = nowMs;
    this.lastRepMs = nowMs;
    this.lastStatus = new SetStatus();
    this.phaseName = 'set';
  }

  onSample(s: AccelSample): SessionUpdate {
    const upd = new SessionUpdate();
    upd.phase = this.phaseName;
    if (this.phaseName !== 'set') {
      return upd;
    }
    const rep = this.detector.feed(s);
    if (rep !== null) {
      this.lastRepMs = s.t;
      this.lastStatus = this.analyzer.add(rep);
      upd.newRep = true;
      upd.stopCue = this.lastStatus.stopCue;
    }
    upd.reps = this.lastStatus.reps;
    upd.fatigue = this.lastStatus.fatigue;
    upd.explanation = this.lastStatus.explanation;
    upd.intervalMs = this.lastStatus.lastIntervalMs;
    return upd;
  }

  // Called periodically by the UI. Ends the set automatically after a pause.
  tick(nowMs: number): SessionUpdate {
    const upd = new SessionUpdate();
    upd.phase = this.phaseName;
    upd.reps = this.lastStatus.reps;
    upd.fatigue = this.lastStatus.fatigue;
    if (this.phaseName === 'set' && this.lastStatus.reps > 0 && nowMs - this.lastRepMs > this.cfg.setIdleEndMs) {
      this.endSet(nowMs);
      upd.autoEnded = true;
      upd.phase = this.phaseName;
    }
    return upd;
  }

  endSet(nowMs: number): SetRecord | null {
    if (this.phaseName !== 'set') {
      return null;
    }
    const late = this.detector.flush();
    if (late !== null) {
      this.lastRepMs = nowMs;
      this.lastStatus = this.analyzer.add(late);
    }
    let result: SetRecord | null = null;
    if (this.lastStatus.reps > 0) {
      const rec = new SetRecord();
      rec.exercise = this.current.id;
      rec.group = this.current.group;
      rec.startMs = this.setStartMs;
      rec.endMs = nowMs;
      rec.simulated = this.simulated;
      rec.weightKg = this.weightKg;
      this.analyzer.fillRecord(rec);
      this.record.sets.push(rec);
      result = rec;
      const rest = rec.fatigue >= this.cfg.restFatigueLimit ? this.cfg.restFatiguedMs : this.cfg.restBaseMs;
      this.restEndMs = nowMs + rest;
      this.restTotal = rest;
      this.phaseName = 'rest';
    } else {
      this.phaseName = 'idle'; // nothing counted: discard silently
    }
    return result;
  }

  // Rest timer controls (like +15 s / -15 s in gym loggers). The remaining time stays
  // between 0 and maxRestMs; the ring total follows so progress never jumps backwards.
  adjustRest(deltaMs: number, nowMs: number): void {
    if (this.phaseName !== 'rest') {
      return;
    }
    const remaining = Math.max(0, this.restEndMs - nowMs);
    const next = Math.min(this.cfg.maxRestMs, Math.max(0, remaining + deltaMs));
    this.restEndMs = nowMs + next;
    this.restTotal = Math.max(next, Math.min(this.cfg.maxRestMs, this.restTotal + deltaMs), 1);
  }

  // Ends the rest early: the next set can start right away.
  skipRest(): void {
    if (this.phaseName === 'rest') {
      this.phaseName = 'idle';
    }
  }

  // Sets recorded so far in this visit (newest last).
  sets(): SetRecord[] {
    return this.record.sets;
  }

  restTotalMs(): number {
    return this.restTotal;
  }

  restRemainingMs(nowMs: number): number {
    if (this.phaseName !== 'rest') {
      return 0;
    }
    return Math.max(0, this.restEndMs - nowMs);
  }

  finish(nowMs: number): WorkoutRecord {
    if (this.phaseName === 'set') {
      this.endSet(nowMs);
    }
    this.record.endMs = nowMs;
    this.phaseName = 'finished';
    return this.record;
  }
}
