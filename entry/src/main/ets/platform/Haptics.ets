import { vibrator } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'WispHaptics';
const DOMAIN = 0x0003;
const MIN_GAP_MS = 120;

// Set after the first failure: a device without a working vibrator (an emulator) is not
// asked again. Repeated failing vibrator IPC calls stalled the UI thread's timers on the
// OpenHarmony 6.1 emulator.
let unavailable = false;
let lastAt = 0;

// Short haptic cue (rep tick, stop cue, rest finished). Never throws; does nothing on
// devices without a vibrator or when the permission was denied.
export function buzz(durationMs: number): void {
  if (unavailable) {
    return;
  }
  const now = Date.now();
  if (now - lastAt < MIN_GAP_MS) {
    return; // coalesce bursts (e.g. a rep tick and the stop cue in the same moment)
  }
  lastAt = now;
  try {
    vibrator.startVibration({ type: 'time', duration: durationMs }, { id: 0, usage: 'notification' })
      .catch((e: Error) => {
        unavailable = true;
        hilog.warn(DOMAIN, TAG, 'vibration failed, haptics off for this session: %{public}s', e.message);
      });
  } catch (e) {
    unavailable = true;
    hilog.warn(DOMAIN, TAG, 'vibration unavailable: %{public}s', JSON.stringify(e));
  }
}
