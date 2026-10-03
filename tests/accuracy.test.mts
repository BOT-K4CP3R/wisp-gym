import test from 'node:test';
import assert from 'node:assert/strict';
import { RepDetector, RepDetectorConfig } from '../.test-build/core/RepDetector.ts';
import { generateSet, TraceOptions, Rng } from '../.test-build/core/Sim.ts';

// Randomised robustness sweep over SYNTHETIC sets (3-12 reps, 1.4-3.4 s tempo, noise up to
// 0.45 m/s^2, any phone tilt, up to 60% slow-down and 40% drive loss). This measures the
// detector against the simulator, not against real bodies; real recordings are future work.
test('randomised synthetic sweep: >=97% exact counts and never off by more than one rep', () => {
  const rng = new Rng(12345);
  let exact = 0;
  let within1 = 0;
  const N = 300;
  for (let i = 0; i < N; i++) {
    const o = new TraceOptions();
    o.reps = 3 + Math.floor(rng.next() * 10);
    o.baseIntervalMs = 1400 + rng.next() * 2000;
    o.noise = 0.1 + rng.next() * 0.35;
    o.tilt = rng.next() * 1.3;
    o.slowdown = rng.next() * 0.6;
    o.amplitude = 2 + rng.next() * 2.5;
    o.ampDrop = rng.next() * 0.4;
    o.seed = 1000 + i;
    const d = new RepDetector(new RepDetectorConfig());
    let n = 0;
    for (const s of generateSet(o)) { if (d.feed(s)) n++; }
    if (d.flush()) n++;
    if (n === o.reps) exact++;
    if (Math.abs(n - o.reps) <= 1) within1++;
  }
  assert.ok(exact / N >= 0.97, `exact ${exact}/${N}`);
  assert.equal(within1, N);
});
