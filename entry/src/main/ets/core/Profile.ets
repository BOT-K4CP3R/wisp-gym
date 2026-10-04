import { KeyValueStore } from './Store';
import { SPECIES } from './Species';

// The user's personal settings, chosen during onboarding and editable in Settings.
// Stored as validated JSON, so a corrupt value falls back to safe defaults.

export const NAME_MAX = 14;
export const STEP_GOAL_MIN = 2000;
export const STEP_GOAL_MAX = 20000;
export const WEEKLY_GOAL_MIN = 1;
export const WEEKLY_GOAL_MAX = 7;

export class Profile {
  name: string = 'Wisp';
  stepGoal: number = 8000;
  weeklyGoal: number = 3;       // training sessions per week
  onboarded: boolean = false;
  haptics: boolean = true;
  restAlerts: boolean = true;   // notification + buzz when a rest timer ends
  motion: string = 'auto';      // auto | full | reduced
  species: string = 'wisp';     // the creature being raised (see Species.ets)
}

function validSpecies(id: string): boolean {
  for (let i = 0; i < SPECIES.length; i++) {
    if (SPECIES[i].id === id) {
      return true;
    }
  }
  return false;
}

export const MOTION_MODES: string[] = ['auto', 'full', 'reduced'];

// Whether animations are reduced: an explicit choice wins; 'auto' reduces motion on
// devices with a software-only renderer (x86 emulators).
export function reducedMotion(mode: string, softwareRenderer: boolean): boolean {
  if (mode === 'reduced') {
    return true;
  }
  if (mode === 'full') {
    return false;
  }
  return softwareRenderer;
}

// Trims, collapses whitespace, drops control characters and caps the length.
export function sanitizeName(raw: string): string {
  if (typeof raw !== 'string') {
    return 'Wisp';
  }
  let s = '';
  for (let i = 0; i < raw.length; i++) {
    const c = raw.charCodeAt(i);
    s += c < 32 || c === 127 ? ' ' : raw.charAt(i);
  }
  s = s.replace(/\s+/g, ' ').trim();
  if (s.length > NAME_MAX) {
    s = s.substring(0, NAME_MAX).trim();
  }
  return s.length === 0 ? 'Wisp' : s;
}

function intIn(v: Object | undefined | null, lo: number, hi: number, fallback: number): number {
  const n = v as number;
  if (typeof n !== 'number' || !isFinite(n)) {
    return fallback;
  }
  return Math.min(hi, Math.max(lo, Math.round(n)));
}

const KEY_PROFILE = 'profile.v1';

export class ProfileStore {
  private kv: KeyValueStore;

  constructor(kv: KeyValueStore) {
    this.kv = kv;
  }

  load(): Profile {
    const p = new Profile();
    const text = this.kv.get(KEY_PROFILE);
    if (text.length === 0) {
      return p;
    }
    let raw: Profile | null = null;
    try {
      raw = JSON.parse(text) as Profile;
    } catch (e) {
      return p;
    }
    if (raw === null || typeof raw !== 'object') {
      return p;
    }
    p.name = sanitizeName(raw.name);
    p.stepGoal = intIn(raw.stepGoal, STEP_GOAL_MIN, STEP_GOAL_MAX, p.stepGoal);
    p.weeklyGoal = intIn(raw.weeklyGoal, WEEKLY_GOAL_MIN, WEEKLY_GOAL_MAX, p.weeklyGoal);
    p.onboarded = raw.onboarded === true;
    p.haptics = raw.haptics !== false;
    p.restAlerts = raw.restAlerts !== false;
    p.motion = MOTION_MODES.indexOf(raw.motion) >= 0 ? raw.motion : 'auto';
    p.species = validSpecies(raw.species) ? raw.species : 'wisp';
    return p;
  }

  save(p: Profile): void {
    const clean = new Profile();
    clean.name = sanitizeName(p.name);
    clean.stepGoal = intIn(p.stepGoal, STEP_GOAL_MIN, STEP_GOAL_MAX, clean.stepGoal);
    clean.weeklyGoal = intIn(p.weeklyGoal, WEEKLY_GOAL_MIN, WEEKLY_GOAL_MAX, clean.weeklyGoal);
    clean.onboarded = p.onboarded === true;
    clean.haptics = p.haptics !== false;
    clean.restAlerts = p.restAlerts !== false;
    clean.motion = MOTION_MODES.indexOf(p.motion) >= 0 ? p.motion : 'auto';
    clean.species = validSpecies(p.species) ? p.species : 'wisp';
    this.kv.put(KEY_PROFILE, JSON.stringify(clean));
  }
}
