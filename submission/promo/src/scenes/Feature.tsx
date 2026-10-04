import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Stage } from "../components/Layers";
import { BrandMark, Breathe, Chip, Entrance, SceneOut, WordReveal } from "../components/Motion";
import { Phone } from "../components/Phone";
import { theme } from "../theme";

export type FeatureProps = {
  dur: number; // seconds
  kicker: string;
  head: string;
  hi?: string[];
  sub: string;
  chips?: string[];
  shots: string[];
  shots2?: string[]; // optional second phone behind the first
  every?: number;
  zoom?: "in" | "out";
  overlay?: React.ReactNode; // floating card next to the phone
  hue?: "warm" | "cool";
};

// Text block left, phone(s) sliding in from the right with a parallax lean.
export const Feature: React.FC<FeatureProps> = ({ dur, kicker, head, hi, sub, chips = [], shots, shots2, every, zoom, overlay, hue }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - Math.round(0.15 * fps), fps, config: theme.spring.smooth });
  const p2 = spring({ frame: frame - Math.round(0.45 * fps), fps, config: theme.spring.smooth });
  const drift = interpolate(frame, [0, dur * fps], [0, -26], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: theme.ease.inOut });
  const out = dur - theme.timing.exit - 0.05;
  return (
    <Stage hue={hue}>
      <SceneOut at={out}>
        <BrandMark />
        <AbsoluteFill style={{ padding: "0 140px", flexDirection: "row", alignItems: "center" }}>
          <div style={{ width: 860, display: "flex", flexDirection: "column", gap: 34 }}>
            <Entrance delay={0.05} y={24}>
              <div style={{ display: "flex", alignItems: "center", gap: 18 }}>
                <div style={{ width: 64, height: 8, borderRadius: 4, background: theme.colors.primary }} />
                <span style={{ fontFamily: theme.fonts.body, fontWeight: 800, fontSize: 28, letterSpacing: "0.14em", color: theme.colors.textDim }}>
                  {kicker.toUpperCase()}
                </span>
              </div>
            </Entrance>
            <WordReveal text={head} hi={hi} delay={0.2} size={96} />
            <Entrance delay={0.75} y={26}>
              <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 36, lineHeight: 1.4, color: theme.colors.textDim, maxWidth: 780 }}>
                {sub}
              </div>
            </Entrance>
            {chips.length > 0 && (
              <div style={{ display: "flex", flexWrap: "wrap", gap: 16, marginTop: 6 }}>
                {chips.map((c, i) => (
                  <Entrance key={c} delay={1.05 + i * theme.timing.stagger} y={20} spring="snappy">
                    <Chip>{c}</Chip>
                  </Entrance>
                ))}
              </div>
            )}
          </div>
          <div style={{ flex: 1, position: "relative", height: "100%" }}>
            {shots2 && (
              <div
                style={{
                  position: "absolute", top: "50%", left: "50%", opacity: Math.min(p2, 1) * 0.92,
                  transform: `translate(${-50 + 40 + (1 - p2) * 30}%, ${-50 + 3 + drift * 0.02}%) scale(0.86)`,
                }}
              >
                <Breathe amp={5} period={2.4} phase={1.4}>
                  <Phone shots={shots2} height={780} every={every} zoom={zoom === "in" ? "out" : "in"} tilt={-8} />
                </Breathe>
              </div>
            )}
            <div
              style={{
                position: "absolute", top: "50%", left: "50%", opacity: Math.min(p, 1),
                transform: `translate(${-50 + (shots2 ? -26 : 0) + (1 - p) * 40}%, ${-50 + drift * 0.03}%) scale(${interpolate(p, [0, 1], [0.9, 1])})`,
              }}
            >
              <Breathe amp={6} period={2.2}>
                <Phone shots={shots} height={820} every={every} zoom={zoom} tilt={shots2 ? 6 : -4} />
              </Breathe>
            </div>
            {overlay}
          </div>
        </AbsoluteFill>
      </SceneOut>
    </Stage>
  );
};

// Floating glassy card used as an overlay next to a phone.
export const FloatCard: React.FC<{ delay: number; top: number; left: number; children: React.ReactNode; out?: number }> = ({ delay, top, left, children, out }) => (
  <div style={{ position: "absolute", top, left }}>
    <Entrance delay={delay} y={30} x={-30} from={0.85} spring="bouncy" out={out}>
      <Breathe amp={7} period={2.6} phase={2}>
        <div
          style={{
            padding: "26px 34px", borderRadius: 32, background: "rgba(21, 22, 25, 0.86)",
            border: `1.5px solid ${theme.colors.hairline}`, backdropFilter: "blur(14px)",
            boxShadow: "0 40px 80px -24px rgba(0,0,0,0.7)", fontFamily: theme.fonts.body, color: theme.colors.text,
          }}
        >
          {children}
        </div>
      </Breathe>
    </Entrance>
  </div>
);
