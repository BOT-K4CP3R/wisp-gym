import { sensor } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { AccelSample } from '../core/Types';
import { generateSet, TraceOptions } from '../core/Sim';

const TAG = 'WispMotion';
const DOMAIN = 0x0002;

export class MotionSource {
  isSimulated(): boolean {
    return false;
  }

  // Returns false when the sensor is not available on this device.
  start(listener: (s: AccelSample) => void): boolean {
    return false;
  }

  stop(): void {
  }
}

// Real accelerometer through SensorServiceKit (50 Hz).
export class RealAccelSource extends MotionSource {
  private active: boolean = false;

  start(listener: (s: AccelSample) => void): boolean {
    try {
      sensor.on(sensor.SensorId.ACCELEROMETER, (data: sensor.AccelerometerResponse) => {
        listener(new AccelSample(Number(data.timestamp) / 1000000, data.x, data.y, data.z));
      }, { interval: 20000000 });
      this.active = true;
      return true;
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'accelerometer unavailable: %{public}s', JSON.stringify(e));
      return false;
    }
  }

  stop(): void {
    if (!this.active) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.ACCELEROMETER);
    } catch (e) {
      hilog.error(DOMAIN, TAG, 'stop failed: %{public}s', JSON.stringify(e));
    }
    this.active = false;
  }
}

// Replays a synthetic set in real time. The emulator has no real motion, so the demo
// feeds this stream through exactly the same detector as the real sensor.
export class SimulatedSource extends MotionSource {
  private timer: number = -1;
  private trace: AccelSample[] = [];
  private index: number = 0;
  private startedAt: number = 0;
  private opts: TraceOptions;

  constructor(opts: TraceOptions) {
    super();
    this.opts = opts;
  }

  isSimulated(): boolean {
    return true;
  }

  start(listener: (s: AccelSample) => void): boolean {
    this.trace = generateSet(this.opts);
    this.index = 0;
    this.startedAt = Date.now();
    this.timer = setInterval(() => {
      const elapsed = Date.now() - this.startedAt;
      while (this.index < this.trace.length && this.trace[this.index].t <= elapsed) {
        listener(this.trace[this.index]);
        this.index++;
      }
      if (this.index >= this.trace.length) {
        this.stop();
      }
    }, 20);
    return true;
  }

  stop(): void {
    if (this.timer >= 0) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }
}
