// theme.ts: the single source of truth for the promo. Mirrors entry/src/main/ets/ui/Theme.ets.
import { Easing } from "remotion";

export const theme = {
  colors: {
    bg: "#0A0A0C",
    surface: "#151619",
    surfaceHi: "#1E1F23",
    hairline: "rgba(255, 255, 255, 0.12)",
    primary: "#FF8A5B", // THE hero colour (the app's single accent)
    primaryMid: "#B8623F",
    primaryTint: "rgba(255, 138, 91, 0.12)",
    accent: "#8B5CF6", // a cool counter-glow in the background mesh only (Nova's violet)
    text: "#F4F4F5",
    textDim: "#A1A1AA",
    textMute: "#8B8B94",
    onPrimary: "#1A0F0A",
    glow: "rgba(255, 138, 91, 0.45)",
    bezel: "#222328",
    bezelEdge: "#46474E",
  },
  fonts: {
    display: "Nunito",
    body: "Nunito",
  },
  ease: {
    out: Easing.bezier(0.16, 1, 0.3, 1), // entrances
    inOut: Easing.bezier(0.83, 0, 0.17, 1), // moves, Ken Burns
    in: Easing.bezier(0.7, 0, 0.84, 0), // exits only
  },
  spring: {
    snappy: { damping: 14, stiffness: 160, mass: 0.6 },
    smooth: { damping: 20, stiffness: 90, mass: 1 },
    bouncy: { damping: 11, stiffness: 170, mass: 0.7 },
  },
  // seconds; every frame number is derived from fps
  timing: {
    exit: 0.4,
    stagger: 0.13,
    wordStagger: 0.1,
  },
} as const;
