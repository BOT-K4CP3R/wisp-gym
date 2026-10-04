import React from "react";
import { AbsoluteFill, Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

// Seconds -> frames, so no component uses magic frame numbers.
export const useSec = () => {
  const { fps } = useVideoConfig();
  return (s: number) => Math.round(s * fps);
};

// Fade + rise + scale, with a faster exit when `out` (seconds into the scene) is given.
export const Entrance: React.FC<{
  delay?: number; // seconds
  out?: number; // seconds; exit starts here
  y?: number;
  x?: number;
  from?: number; // start scale
  spring?: keyof typeof theme.spring;
  style?: React.CSSProperties;
  children: React.ReactNode;
}> = ({ delay = 0, out, y = 40, x = 0, from = 0.94, spring: sp = "smooth", style, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - Math.round(delay * fps), fps, config: theme.spring[sp] });
  let exit = 0;
  if (out !== undefined) {
    const s = Math.round(out * fps);
    exit = interpolate(frame, [s, s + Math.round(theme.timing.exit * fps)], [0, 1], { ...clamp, easing: theme.ease.in });
  }
  return (
    <div
      style={{
        opacity: Math.min(p, 1) * (1 - exit),
        transform: `translate(${interpolate(p, [0, 1], [x, 0])}px, ${interpolate(p, [0, 1], [y, 0]) - exit * 36}px) scale(${interpolate(p, [0, 1], [from, 1]) * (1 - exit * 0.04)})`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

// Word-by-word headline; `hi` words get the hero colour.
export const WordReveal: React.FC<{
  text: string;
  delay?: number;
  hi?: string[];
  size?: number;
  color?: string;
  weight?: number;
  style?: React.CSSProperties;
}> = ({ text, delay = 0, hi = [], size = 110, color = theme.colors.text, weight = 800, style }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  return (
    <div
      style={{
        display: "flex", flexWrap: "wrap", columnGap: Math.round(size * 0.26), rowGap: 0,
        fontFamily: theme.fonts.display, fontWeight: weight, fontSize: size, lineHeight: 1.05,
        letterSpacing: "-0.03em", color, ...style,
      }}
    >
      {text.split(" ").map((w, i) => {
        const p = spring({ frame: frame - Math.round((delay + i * theme.timing.wordStagger) * fps), fps, config: theme.spring.snappy });
        const isHi = hi.includes(w.replace(/[.,]/g, ""));
        return (
          <span
            key={i}
            style={{
              display: "inline-block", opacity: Math.min(p, 1),
              transform: `translateY(${interpolate(p, [0, 1], [size * 0.32, 0])}px) scale(${interpolate(p, [0, 1], [0.92, 1])})`,
              color: isHi ? theme.colors.primary : undefined,
              textShadow: isHi ? `0 0 50px ${theme.colors.glow}` : undefined,
            }}
          >
            {w}
          </span>
        );
      })}
    </div>
  );
};

// Gentle idle motion for anything that stays on screen.
export const Breathe: React.FC<{ amp?: number; period?: number; phase?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({
  amp = 6, period = 1.6, phase = 0, children, style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = frame / fps / period * Math.PI * 2 + phase;
  return (
    <div style={{ transform: `translateY(${Math.sin(t) * amp}px) scale(${1 + Math.sin(t + 1) * 0.012})`, ...style }}>{children}</div>
  );
};

// Animated number with tabular figures.
export const Counter: React.FC<{ to: number; delay?: number; decimals?: number; suffix?: string; style?: React.CSSProperties }> = ({
  to, delay = 0, decimals = 0, suffix = "", style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - Math.round(delay * fps), fps, config: { damping: 30, stiffness: 55 } });
  const v = interpolate(p, [0, 1], [0, to], clamp);
  return <span style={{ fontVariantNumeric: "tabular-nums", ...style }}>{v.toFixed(decimals)}{suffix}</span>;
};

// A creature render from the app's own drawing code.
export const Creature: React.FC<{ species: string; expr: string; size: number; glow?: boolean; style?: React.CSSProperties }> = ({
  species, expr, size, glow = false, style,
}) => (
  <Img
    src={staticFile(`creatures/${species}-${expr}.png`)}
    style={{ width: size, height: size, filter: glow ? `drop-shadow(0 0 ${size * 0.12}px ${theme.colors.glow})` : undefined, ...style }}
  />
);

// Scene-level exit wrapper: everything leaves together, faster than it came.
export const SceneOut: React.FC<{ at: number; children: React.ReactNode }> = ({ at, children }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const s = Math.round(at * fps);
  const e = interpolate(frame, [s, s + Math.round(theme.timing.exit * fps)], [0, 1], { ...clamp, easing: theme.ease.in });
  return <AbsoluteFill style={{ opacity: 1 - e, transform: `scale(${1 + e * 0.05})`, filter: `blur(${e * 8}px)` }}>{children}</AbsoluteFill>;
};

// Small rounded label.
export const Chip: React.FC<{ children: React.ReactNode; hero?: boolean }> = ({ children, hero = false }) => (
  <div
    style={{
      display: "inline-flex", alignItems: "center", gap: 12, padding: "14px 26px", borderRadius: 999,
      background: hero ? theme.colors.primaryTint : theme.colors.surface,
      border: `1.5px solid ${hero ? "rgba(255,138,91,0.45)" : theme.colors.hairline}`,
      color: hero ? theme.colors.primary : theme.colors.text,
      fontFamily: theme.fonts.body, fontWeight: 800, fontSize: 30,
    }}
  >
    {children}
  </div>
);
