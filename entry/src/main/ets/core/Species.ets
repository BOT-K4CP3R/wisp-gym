// The creatures a user can raise. Each species has its own body features and colour family;
// three starters (Wisp, Mochi, Pip) are available from the start, the others unlock through
// training milestones
// (see Achievements.ets). Kept pure so the app, widgets and tests share it.

export class Species {
  id: string;
  name: string;
  blurb: string;
  hueBase: number;     // centre of the species' colour family, 0..360
  unlock: string;      // achievement id that unlocks it ('' = always available)

  constructor(id: string, name: string, blurb: string, hueBase: number, unlock: string) {
    this.id = id;
    this.name = name;
    this.blurb = blurb;
    this.hueBase = hueBase;
    this.unlock = unlock;
  }
}

export const SPECIES: Species[] = [
  new Species('wisp', 'Wisp', 'A warm little flame. Glows brighter the more you move.', 24, ''),
  new Species('mochi', 'Mochi', 'Soft and round with long ears. Loves steady routines.', 330, ''),
  new Species('ember', 'Ember', 'Tiny horns and a fiery tail. Thrives on heavy days.', 2, 'reps-100'),
  new Species('pip', 'Pip', 'A round little bird with a crest. Never skips leg day.', 42, ''),
  new Species('nova', 'Nova', 'A star on an antenna. Shines after rest days.', 265, 'week-goal'),
  new Species('moss', 'Moss', 'A sprout on its head. Grows slow and strong.', 120, 'all-groups')
];

export function findSpecies(id: string): Species {
  for (let i = 0; i < SPECIES.length; i++) {
    if (SPECIES[i].id === id) {
      return SPECIES[i];
    }
  }
  return SPECIES[0];
}

// Faces the creature can make. Moods pick one by default; moments (a tap, a rep, the
// stop cue, a finished workout) override it briefly.
export const EXPRESSIONS: string[] = ['neutral', 'happy', 'joy', 'curious', 'sleepy', 'asleep', 'surprised',
  'focused', 'strain', 'love', 'proud'];
