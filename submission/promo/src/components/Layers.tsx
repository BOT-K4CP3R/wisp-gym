import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { theme } from "../theme";

// Layer 1: slow drifting warm/cool mesh, never a flat background.
export const BgMesh: React.FC<{ hue?: "warm" | "cool" }> = ({ hue = "warm" }) => {
  const frame = useCurrentFrame();
  const d1 = Math.sin(frame / 55) * 60;
  const d2 = Math.cos(frame / 70) * 45;
  const a = hue === "warm" ? theme.colors.primary : theme.colors.accent;
  const b = hue === "warm" ? theme.colors.accent : theme.colors.primary;
  return (
    <AbsoluteFill style={{ background: theme.colors.bg }}>
      <div
        style={{
          position: "absolute", width: 1400, height: 1400, borderRadius: "50%",
          top: -620, left: -360 + d1, filter: "blur(60px)",
          background: `radial-gradient(circle, ${a}2E, transparent 62%)`,
        }}
      />
      <div
        style={{
          position: "absolute", width: 1100, height: 1100, borderRadius: "50%",
          bottom: -560, right: -300 - d2, filter: "blur(80px)",
          background: `radial-gradient(circle, ${b}1F, transparent 65%)`,
        }}
      />
    </AbsoluteFill>
  );
};

// Layer 4: grade that unifies screenshots and renders into one look.
export const Grade: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
    <AbsoluteFill style={{ backgroundColor: theme.colors.primary, mixBlendMode: "soft-light", opacity: 0.08 }} />
    <AbsoluteFill
      style={{ background: "linear-gradient(180deg, rgba(0,0,0,0.18), transparent 26%, transparent 74%, rgba(0,0,0,0.28))" }}
    />
  </AbsoluteFill>
);

// Layer 5a: procedural film grain.
export const Grain: React.FC = () => {
  const frame = useCurrentFrame();
  const noise = `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='220' height='220'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2'/%3E%3C/filter%3E%3Crect width='220' height='220' filter='url(%23n)' opacity='0.5'/%3E%3C/svg%3E")`;
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none", backgroundImage: noise, backgroundSize: "220px",
        backgroundPosition: `${(frame * 7) % 220}px ${(frame * 13) % 220}px`,
        opacity: 0.06, mixBlendMode: "overlay",
      }}
    />
  );
};

// Layer 5b: vignette, topmost.
export const Vignette: React.FC = () => (
  <AbsoluteFill
    style={{ pointerEvents: "none", background: "radial-gradient(ellipse at center, transparent 55%, rgba(0,0,0,0.45) 100%)" }}
  />
);

// The five-layer stack: mesh -> (assets + type as children) -> grade -> grain -> vignette.
export const Stage: React.FC<{ children: React.ReactNode; hue?: "warm" | "cool" }> = ({ children, hue }) => (
  <AbsoluteFill>
    <BgMesh hue={hue} />
    <AbsoluteFill>{children}</AbsoluteFill>
    <Grade />
    <Grain />
    <Vignette />
  </AbsoluteFill>
);
