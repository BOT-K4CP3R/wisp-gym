import React from "react";
import { Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { theme } from "../theme";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

// A phone with real emulator screenshots (360x720). Several shots cross-fade at `every` seconds.
// The screen content gets a slow Ken Burns push so stills never sit dead.
export const Phone: React.FC<{
  shots: string[];
  height?: number;
  every?: number; // seconds per shot
  zoom?: "in" | "out";
  tilt?: number; // degrees, a slight 3D lean
}> = ({ shots, height = 820, every = 2.2, zoom = "in", tilt = 0 }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const w = height / 2;
  const pad = 14;
  const per = Math.round(every * fps);
  const fade = Math.round(0.35 * fps);
  const kb = interpolate(frame, [0, durationInFrames], zoom === "in" ? [1, 1.06] : [1.06, 1], { ...clamp, easing: theme.ease.inOut });
  return (
    <div
      style={{
        width: w + pad * 2, height: height + pad * 2, borderRadius: 64, padding: pad,
        background: theme.colors.bezel, border: `2px solid ${theme.colors.bezelEdge}`,
        boxShadow: `0 60px 120px -30px rgba(0,0,0,0.75), 0 0 0 1px rgba(0,0,0,0.6), 0 0 120px -40px ${theme.colors.glow}`,
        transform: `perspective(2200px) rotateY(${tilt}deg)`,
      }}
    >
      <div style={{ position: "relative", width: w, height, borderRadius: 50, overflow: "hidden", background: theme.colors.bg }}>
        {shots.map((s, i) => {
          const start = i * per;
          const inP = i === 0 ? 1 : interpolate(frame, [start - fade, start], [0, 1], { ...clamp, easing: theme.ease.inOut });
          const outP = i === shots.length - 1 ? 0 : interpolate(frame, [start + per - fade, start + per], [0, 1], { ...clamp, easing: theme.ease.inOut });
          const o = inP * (1 - outP);
          if (o <= 0) return null;
          return (
            <Img
              key={s}
              src={staticFile(`shots/${s}`)}
              style={{
                position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover",
                opacity: o, transform: `scale(${kb})`, transformOrigin: "50% 35%",
              }}
            />
          );
        })}
      </div>
    </div>
  );
};
