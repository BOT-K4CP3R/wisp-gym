import test from 'node:test';
import assert from 'node:assert/strict';
import { RepDetector, RepDetectorConfig } from '../.test-build/core/RepDetector.ts';
import { SetAnalyzer, AnalyzerConfig } from '../.test-build/core/SetAnalyzer.ts';
import { generateSet, generateIdle, generateWalking, TraceOptions } from '../.test-build/core/Sim.ts';
import { AccelSample } from '../.test-build/core/Types.ts';

function countReps(samples: AccelSample[], minPeak = 1.1): number {
  const cfg = new RepDetectorConfig();
  cfg.minPeak = minPeak;
  const d = new RepDetector(cfg);
  let n = 0;
  for (const s of samples) { if (d.feed(s)) n++; }
  if (d.flush()) n++;
  return n;
}

test('counts a clean 8-rep set exactly', () => {
  const o = new TraceOptions();
  o.reps = 8;
  assert.equal(countReps(generateSet(o)), 8);
});

test('counts different rep counts and tempos', () => {
  for (const reps of [3, 5, 10, 12]) {
    for (const interval of [1600, 2000, 3200]) {
      const o = new TraceOptions();
      o.reps = reps;
      o.baseIntervalMs = interval;
      o.seed = reps * 31 + interval;
      assert.equal(countReps(generateSet(o)), reps, `reps=${reps} interval=${interval}`);
    }
  }
});

test('is robust to phone orientation in the pocket', () => {
  for (const tilt of [0, 0.35, 0.8, 1.2]) {
    const o = new TraceOptions();
    o.reps = 6;
    o.tilt = tilt;
    assert.equal(countReps(generateSet(o)), 6, `tilt=${tilt}`);
  }
});

test('stays at zero reps for a phone lying on a bench', () => {
  assert.equal(countReps(generateIdle(30000, 3, 0)), 0);
});

test('does not count walking as reps', () => {
  assert.equal(countReps(generateWalking(30000, 5, 0)), 0);
});

test('survives corrupt and out-of-order samples', () => {
  const o = new TraceOptions();
  o.reps = 5;
  const s = generateSet(o);
  const d = new RepDetector(new RepDetectorConfig());
  d.feed(new AccelSample(NaN, 0, 0, 9.8));
  d.feed(new AccelSample(10, Infinity, 0, 9.8));
  let n = 0;
  for (const x of s) { if (d.feed(x)) n++; }
  d.feed(s[5]); // duplicate / out-of-order timestamp
  if (d.flush()) n++;
  assert.equal(n, 5);
});

test('fatigue cue fires when reps slow down and drive drops', () => {
  const o = new TraceOptions();
  o.reps = 10;
  o.slowdown = 0.7;
  o.ampDrop = 0.4;
  const d = new RepDetector(new RepDetectorConfig());
  const a = new SetAnalyzer(new AnalyzerConfig());
  let cueRep = -1;
  let cues = 0;
  for (const s of generateSet(o)) {
    const rep = d.feed(s);
    if (rep) {
      const st = a.add(rep);
      if (st.stopCue) { cues++; cueRep = rep.index; }
    }
  }
  assert.equal(cues, 1, 'cue fires exactly once');
  assert.ok(cueRep >= 4 && cueRep <= 10, `cue at rep ${cueRep}`);
});

test('no fatigue cue for a steady set', () => {
  const o = new TraceOptions();
  o.reps = 12;
  const d = new RepDetector(new RepDetectorConfig());
  const a = new SetAnalyzer(new AnalyzerConfig());
  let cues = 0;
  for (const s of generateSet(o)) {
    const rep = d.feed(s);
    if (rep && a.add(rep).stopCue) cues++;
  }
  assert.equal(cues, 0);
});

test('tempo quality is high for steady sets and lower for erratic ones', () => {
  const steady = new TraceOptions();
  steady.reps = 10;
  const slowing = new TraceOptions();
  slowing.reps = 10;
  slowing.slowdown = 0.9;
  const q = (o: TraceOptions): number => {
    const d = new RepDetector(new RepDetectorConfig());
    const a = new SetAnalyzer(new AnalyzerConfig());
    for (const s of generateSet(o)) { const r = d.feed(s); if (r) a.add(r); }
    return a.quality();
  };
  assert.ok(q(steady) > 0.85, `steady ${q(steady)}`);
  assert.ok(q(slowing) < q(steady));
});
