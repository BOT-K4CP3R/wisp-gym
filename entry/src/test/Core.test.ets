import { describe, it, expect } from '@ohos/hypium';
import { RepDetector, RepDetectorConfig } from '../main/ets/core/RepDetector';
import { generateSet, generateWalking, TraceOptions } from '../main/ets/core/Sim';
import { AccelSample, RepEvent } from '../main/ets/core/Types';
import { LifeEngine, LifeConfig } from '../main/ets/core/LifeEngine';
import { nextAction } from '../main/ets/core/Plan';
import { sanitizeName } from '../main/ets/core/Profile';

function countReps(samples: AccelSample[]): number {
  const d = new RepDetector(new RepDetectorConfig());
  let n = 0;
  for (let i = 0; i < samples.length; i++) {
    const r: RepEvent | null = d.feed(samples[i]);
    if (r !== null) {
      n++;
    }
  }
  if (d.flush() !== null) {
    n++;
  }
  return n;
}

// Mirrors the key scenarios of tests/*.test.mts so they also run inside the OpenHarmony toolchain.
export default function coreTest() {
  describe('coreTest', () => {
    it('countsEightReps', 0, () => {
      const o = new TraceOptions();
      o.reps = 8;
      expect(countReps(generateSet(o))).assertEqual(8);
    });
    it('ignoresWalking', 0, () => {
      expect(countReps(generateWalking(20000, 5, 0))).assertEqual(0);
    });
    it('emptyHistoryIsCurious', 0, () => {
      const st = new LifeEngine(new LifeConfig()).evaluate(Date.now(), [], 0);
      expect(st.mood).assertEqual('curious');
    });
    it('newUserGetsFirstSetCard', 0, () => {
      const cfg = new LifeConfig();
      const st = new LifeEngine(cfg).evaluate(Date.now(), [], 0);
      expect(nextAction(st, cfg, 0, 3, 0).kind).assertEqual('first');
    });
    it('namesAreSanitized', 0, () => {
      expect(sanitizeName('   ')).assertEqual('Wisp');
      expect(sanitizeName('  Pip  ')).assertEqual('Pip');
    });
  });
}
