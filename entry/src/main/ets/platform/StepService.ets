import { sensor } from '@kit.SensorServiceKit';
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { KeyValueStore } from '../core/Store';

const TAG = 'WispSteps';
const DOMAIN = 0x0005;

// Steps today from the hardware pedometer. The sensor reports a counter since boot, so we
// remember the counter value at the start of each local day.
export class StepService {
  private kv: KeyValueStore;
  private context: common.Context;

  constructor(context: common.Context, kv: KeyValueStore) {
    this.context = context;
    this.kv = kv;
  }

  async requestPermission(): Promise<boolean> {
    try {
      const perms: Permissions[] = ['ohos.permission.ACTIVITY_MOTION'];
      const result = await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context, perms);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'permission request failed: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  // Resolves to -1 when the pedometer is unavailable, so the caller can show "unknown"
  // instead of pretending the user did not move.
  readToday(): Promise<number> {
    return new Promise<number>((resolve: (v: number) => void) => {
      let settled = false;
      const done = (v: number): void => {
        if (!settled) {
          settled = true;
          resolve(v);
        }
      };
      setTimeout(() => done(-1), 1500);
      try {
        sensor.once(sensor.SensorId.PEDOMETER, (data: sensor.PedometerResponse) => {
          done(this.today(data.steps));
        });
      } catch (e) {
        hilog.warn(DOMAIN, TAG, 'pedometer unavailable: %{public}s', JSON.stringify(e));
        done(-1);
      }
    });
  }

  private today(counter: number): number {
    const d = new Date();
    const key = d.getFullYear() + '-' + (d.getMonth() + 1) + '-' + d.getDate();
    const storedDay = this.kv.get('steps.day');
    let base = parseInt(this.kv.get('steps.base'), 10);
    if (storedDay !== key || isNaN(base) || base > counter) {
      base = counter;
      this.kv.put('steps.day', key);
      this.kv.put('steps.base', '' + base);
    }
    return Math.max(0, counter - base);
  }
}
