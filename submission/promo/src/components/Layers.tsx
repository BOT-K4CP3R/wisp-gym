import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { theme } from "../theme";

// Layer 1: plain app background (no coloured gradients).
export const BgMesh: React.FC<{ hue?: "warm" | "cool" }> = () => <AbsoluteFill style={{ background: theme.colors.bg }} />;

// Layer 4: grade that unifies screenshots and renders into one look.
export const Grade: React.FC = () => (
  <AbsoluteFill style={{ pointerEvents: "none" }}>
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
