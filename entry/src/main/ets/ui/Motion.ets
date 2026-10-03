// Motion policy. Full motion uses implicit animations, transitions and press effects;
// "reduced motion" (a user setting, and the default on x86 emulators where the render
// service is software-only and long animation callbacks stall frames and timers) keeps
// the UI static except for the creature, which is drawn frame by frame on a Canvas.

const KEY_MOTION = 'wisp.motionOn';

export function motionOn(): boolean {
  const v = AppStorage.get<boolean>(KEY_MOTION);
  return v === undefined ? true : v;
}

export function setMotion(on: boolean): void {
  AppStorage.setOrCreate<boolean>(KEY_MOTION, on);
}

// Implicit-animation / animateTo parameters, collapsed to an instant change when reduced.
export function anim(p: AnimateParam): AnimateParam {
  if (motionOn()) {
    return p;
  }
  const q: AnimateParam = { duration: 0, delay: 0 };
  return q;
}

export function fx(e: TransitionEffect): TransitionEffect {
  return motionOn() ? e : TransitionEffect.IDENTITY;
}

export function press(e: ClickEffect): ClickEffect | null {
  return motionOn() ? e : null;
}

export function pageDur(ms: number): number {
  return motionOn() ? ms : 0;
}
