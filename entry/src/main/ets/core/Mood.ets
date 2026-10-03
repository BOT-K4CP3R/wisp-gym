// Display names for the creature's moods, shared by the app and the home-screen widget so
// both surfaces always say the same thing. Moods are deliberately never negative.

export const MOODS: string[] = ['thriving', 'proud', 'content', 'curious', 'sleepy', 'resting'];

export class MoodInfo {
  label: string;
  short: string;

  constructor(label: string, short: string) {
    this.label = label;
    this.short = short;
  }
}

export function moodInfo(mood: string): MoodInfo {
  if (mood === 'thriving') {
    return new MoodInfo('Thriving', 'Strong week');
  }
  if (mood === 'proud') {
    return new MoodInfo('Pumped', 'Great session');
  }
  if (mood === 'sleepy') {
    return new MoodInfo('Recharging', 'Recovering from training');
  }
  if (mood === 'resting') {
    return new MoodInfo('Rest day', 'Recovery comes first');
  }
  if (mood === 'curious') {
    return new MoodInfo('Curious', 'Ready when you are');
  }
  return new MoodInfo('Content', 'Steady progress');
}
