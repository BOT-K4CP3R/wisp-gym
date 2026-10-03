import { GROUPS, clamp } from './Types';
import { CreatureState } from './LifeEngine';

// Pure mapping from creature state to drawing parameters. The UI (Canvas / widget) only
// consumes these numbers, so the look is testable and identical on every surface.

export class CreatureLook {
  legs: number = 1;      // scale multipliers, 0.8 .. 1.45
  push: number = 1;      // shoulders / chest
  pull: number = 1;      // arms
  core: number = 1;      // belly
  hue: number = 200;     // 0..360
  glow: number = 0.5;    // 0..1
  eyeOpen: number = 1;   // 0..1
  smile: number = 0.5;   // -0.2..1 (never negative below -0.2: the creature is never sad)
  bob: number = 0.5;     // idle animation amplitude
  mood: string = 'curious';
  happyEyes: boolean = false; // closed, upturned "^ ^" eyes
}

export function lookFor(state: CreatureState, seed: number): CreatureLook {
  const look = new CreatureLook();
  const scale = (lvl: number): number => 0.86 + lvl * 0.5;
  look.legs = scale(state.levels[GROUPS.indexOf('legs')]);
  look.push = scale(state.levels[GROUPS.indexOf('push')]);
  look.pull = scale(state.levels[GROUPS.indexOf('pull')]);
  look.core = scale(state.levels[GROUPS.indexOf('core')]);

  // Personal base hue from the creature seed, nudged towards the dominant muscle group.
  let dominant = 0;
  for (let i = 1; i < state.levels.length; i++) {
    if (state.levels[i] > state.levels[dominant]) {
      dominant = i;
    }
  }
  // Hue stays in the warm coral-to-amber family so the creature always matches the app accent;
  // the seed gives each creature its own shade, the dominant muscle group nudges it.
  const base = 8 + (Math.abs(seed) % 14);
  look.hue = base + dominant * 6;
  look.glow = clamp(0.25 + 0.5 * state.recover + 0.25 * state.move, 0, 1);
  look.mood = state.mood;

  if (state.mood === 'resting') {
    look.eyeOpen = 0.15;
    look.smile = 0.3;
    look.bob = 0.1;
  } else if (state.mood === 'sleepy') {
    look.eyeOpen = 0.4;
    look.smile = 0.35;
    look.bob = 0.2;
  } else if (state.mood === 'proud') {
    look.eyeOpen = 1;
    look.smile = 1;
    look.bob = 0.9;
    look.happyEyes = true;
    look.glow = Math.max(look.glow, 0.85);
  } else if (state.mood === 'thriving') {
    look.eyeOpen = 1;
    look.smile = 1;
    look.bob = 1;
  } else if (state.mood === 'curious') {
    look.eyeOpen = 1;
    look.smile = 0.55;
    look.bob = 0.6;
  } else {
    look.eyeOpen = 0.85;
    look.smile = 0.7;
    look.bob = 0.5;
  }
  return look;
}
