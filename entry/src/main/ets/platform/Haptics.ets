import { vibrator } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'WispHaptics';
const DOMAIN = 0x0003;

// Short haptic cue (stop cue, rest finished). Silently does nothing when the device
// has no vibrator (the emulator) or the permission was denied.
export function buzz(durationMs: number): void {
  try {
    vibrator.startVibration({ type: 'time', duration: durationMs }, { id: 0, usage: 'notification' })
      .catch((e: Error) => hilog.warn(DOMAIN, TAG, 'vibration failed: %{public}s', e.message));
  } catch (e) {
    hilog.warn(DOMAIN, TAG, 'vibration unavailable: %{public}s', JSON.stringify(e));
  }
}
