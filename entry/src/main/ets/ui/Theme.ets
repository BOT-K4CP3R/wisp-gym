// Design tokens. Monochrome "bento" dark: a near-black canvas, charcoal tiles with a hairline
// border, big numerals and a single warm accent that matches the creature. No gradients,
// no glass, no glow. Every text/background pair is at least WCAG AA.

export const BG = '#0A0A0C';
export const SURFACE = '#151619';
export const SURFACE_HI = '#1E1F23';
export const SURFACE_TOP = '#26272C';
export const HAIRLINE = '#1FFFFFFF';       // 12% white, tile borders
export const TRACK = '#26FFFFFF';          // progress / empty dot
export const SCRIM = '#99000000';

export const TEXT = '#F4F4F5';
export const TEXT_DIM = '#A1A1AA';         // 7.6:1 on BG
export const TEXT_MUTE = '#8B8B94';        // 5.6:1 on BG, 5.1:1 on SURFACE

export const ACCENT = '#FF8A5B';
export const ACCENT_MID = '#B8623F';
export const ACCENT_LOW = '#6B3A28';
export const ACCENT_TINT = '#1FFF8A5B';    // 12% accent, for highlighted surfaces
export const ON_ACCENT = '#1A0F0A';
export const DANGER = '#FF6B6B';

export const F_REG = 'WispMedium';
export const F_BOLD = 'WispBold';

// 4/8-point grid
export const PAD = 20;                     // page gutter
export const GAP = 12;                     // gap between tiles
export const R_TILE = 28;
export const R_PILL = 28;

// Motion
export const DUR_FAST = 160;
export const DUR_MED = 320;
export const DUR_SLOW = 520;
export const STAGGER = 55;                 // delay between tiles entering
