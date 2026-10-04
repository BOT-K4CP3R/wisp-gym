import React from "react";
import { AbsoluteFill, interpolate, spring, useCurrentFrame, useVideoConfig } from "remotion";
import { Stage } from "../components/Layers";
import { Breathe, Counter, Creature, Entrance, SceneOut, WordReveal } from "../components/Motion";
import { theme } from "../theme";

const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

// Swaps a creature's face at `at` seconds with a tiny squash, like a blink of emotion.
const FaceSwap: React.FC<{ species: string; a: string; b: string; at: number; size: number; glow?: boolean }> = ({ species, a, b, at, size, glow }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const t = Math.round(at * fps);
  const squash = spring({ frame: frame - t, fps, config: theme.spring.bouncy });
  const sq = frame < t ? 1 : 1 + Math.sin(Math.min(squash, 1) * Math.PI) * 0.05;
  return (
    <div style={{ transform: `scale(${sq}, ${2 - sq})`, transformOrigin: "50% 90%" }}>
      <Creature species={species} expr={frame < t ? a : b} size={size} glow={glow} />
    </div>
  );
};

// HOOK: the creature pops in, smiles wider, the wordmark lands under it.
export const Hook: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame: frame - 2, fps, config: theme.spring.bouncy });
  return (
    <Stage>
      <SceneOut at={dur - theme.timing.exit - 0.05}>
        <AbsoluteFill style={{ alignItems: "center", justifyContent: "center", flexDirection: "column" }}>
          <div style={{ transform: `translateY(${interpolate(p, [0, 1], [120, -40])}px) scale(${interpolate(p, [0, 1], [0.5, 1])})`, opacity: Math.min(p * 1.4, 1) }}>
            <Breathe amp={10} period={1.8}>
              <FaceSwap species="wisp" a="happy" b="joy" at={1.3} size={560} glow />
            </Breathe>
          </div>
          <div style={{ marginTop: -30, display: "flex", flexDirection: "column", alignItems: "center", gap: 22 }}>
            <WordReveal text="Wisp Gym" delay={0.55} size={150} style={{ justifyContent: "center" }} />
            <Entrance delay={1.25} y={22}>
              <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 42, color: theme.colors.textDim }}>
                A creature that grows from your real training.
              </div>
            </Entrance>
          </div>
        </AbsoluteFill>
      </SceneOut>
    </Stage>
  );
};

// CONTEXT: one bold statement in two lines.
export const Statement: React.FC<{ dur: number }> = ({ dur }) => (
  <Stage hue="cool">
    <SceneOut at={dur - theme.timing.exit - 0.05}>
      <AbsoluteFill style={{ justifyContent: "center", padding: "0 180px", gap: 30 }}>
        <WordReveal text="Your phone counts the reps." delay={0.1} size={104} color={theme.colors.textDim} />
        <WordReveal text="Your creature grows from them." hi={["grows"]} delay={0.9} size={104} />
      </AbsoluteFill>
    </SceneOut>
  </Stage>
);

const ROSTER: [string, string, string][] = [
  ["wisp", "Wisp", "joy"], ["mochi", "Mochi", "love"], ["pip", "Pip", "happy"],
  ["ember", "Ember", "proud"], ["nova", "Nova", "surprised"], ["moss", "Moss", "joy"],
];

// COLLECTION: six species file in, then their faces start to change.
export const Collection: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const exprs = ["happy", "joy", "focused", "proud", "love", "surprised", "strain", "sleepy"];
  return (
    <Stage hue="cool">
      <SceneOut at={dur - theme.timing.exit - 0.05}>
        <AbsoluteFill style={{ alignItems: "center", paddingTop: 120 }}>
          <WordReveal text="Six creatures to raise." hi={["Six"]} delay={0.1} size={100} style={{ justifyContent: "center" }} />
          <Entrance delay={0.6} y={22}>
            <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 36, color: theme.colors.textDim, marginTop: 22 }}>
              Three starters. Three more hatch from real milestones.
            </div>
          </Entrance>
          <div style={{ display: "flex", gap: 28, marginTop: 70 }}>
            {ROSTER.map(([id, name, expr], i) => {
              const locked = i >= 3;
              // after the roster lands, faces cycle one creature at a time
              const cycle = Math.floor((frame / fps - 2.2 - i * 0.18) / 0.55);
              const e = cycle < 0 ? expr : exprs[(cycle + i * 3) % exprs.length];
              return (
                <Entrance key={id} delay={0.75 + i * theme.timing.stagger} y={70} from={0.8} spring="bouncy">
                  <div
                    style={{
                      width: 250, padding: "22px 0 26px", borderRadius: 36, display: "flex", flexDirection: "column", alignItems: "center",
                      background: i === 0 ? theme.colors.primaryTint : theme.colors.surface,
                      border: `1.5px solid ${i === 0 ? "rgba(255,138,91,0.45)" : theme.colors.hairline}`,
                    }}
                  >
                    <Breathe amp={6} period={1.7} phase={i * 0.9}>
                      <Creature species={id} expr={e} size={210} />
                    </Breathe>
                    <div style={{ fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 36, color: theme.colors.text, marginTop: 4 }}>{name}</div>
                    <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 22, color: theme.colors.textMute, marginTop: 4 }}>
                      {locked ? "Unlocks with a badge" : "Starter"}
                    </div>
                  </div>
                </Entrance>
              );
            })}
          </div>
          <div style={{ display: "flex", gap: 90, marginTop: 70 }}>
            {[[14, "badges to earn"], [11, "expressions each"], [6, "muscle groups shape it"]].map(([n, l], i) => (
              <Entrance key={String(l)} delay={1.8 + i * theme.timing.stagger} y={24}>
                <div style={{ display: "flex", alignItems: "baseline", gap: 16, fontFamily: theme.fonts.display }}>
                  <Counter to={Number(n)} delay={1.8 + i * theme.timing.stagger} style={{ fontWeight: 800, fontSize: 64, color: theme.colors.text }} />
                  <span style={{ fontWeight: 500, fontSize: 30, color: theme.colors.textDim }}>{l}</span>
                </div>
              </Entrance>
            ))}
          </div>
        </AbsoluteFill>
      </SceneOut>
    </Stage>
  );
};

// PAYOFF: the numbers behind it.
export const Stats: React.FC<{ dur: number }> = ({ dur }) => {
  const items: { n: number; pre?: string; suf?: string; label: string; sub: string }[] = [
    { n: 74, label: "unit tests", sub: "incl. 300 randomised sets" },
    { n: 0, label: "network permissions", sub: "no account, no cloud" },
    { n: 20, pre: "API", suf: "+", label: "OpenHarmony native", sub: "ArkTS + ArkUI" },
    { n: 2, label: "home-screen widgets", sub: "2x2 and 2x4" },
  ];
  return (
    <Stage>
      <SceneOut at={dur - theme.timing.exit - 0.05}>
        <AbsoluteFill style={{ padding: "130px 160px", gap: 70 }}>
          <WordReveal text="Built native. Private by design." hi={["Private"]} delay={0.1} size={96} />
          <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 30 }}>
            {items.map((it, i) => (
              <Entrance key={it.label} delay={0.6 + i * theme.timing.stagger} y={50} from={0.9}>
                <div
                  style={{
                    height: 250, borderRadius: 40, background: theme.colors.surface, border: `1.5px solid ${theme.colors.hairline}`,
                    display: "flex", alignItems: "center", gap: 46, padding: "0 56px",
                  }}
                >
                  <div style={{ fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 112, color: theme.colors.text, minWidth: 300, whiteSpace: "nowrap" }}>
                    {it.pre && <span style={{ fontSize: 56, marginRight: 10 }}>{it.pre}</span>}
                    <Counter to={it.n} delay={0.7 + i * theme.timing.stagger} />
                    {it.suf}
                  </div>
                  <div>
                    <div style={{ fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 40, color: theme.colors.text }}>{it.label}</div>
                    <div style={{ fontFamily: theme.fonts.body, fontWeight: 500, fontSize: 28, color: theme.colors.textMute, marginTop: 8 }}>{it.sub}</div>
                  </div>
                </div>
              </Entrance>
            ))}
          </div>
        </AbsoluteFill>
      </SceneOut>
    </Stage>
  );
};

// CTA: calm close on the creature and the wordmark.
export const CTA: React.FC<{ dur: number }> = ({ dur }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = spring({ frame, fps, config: theme.spring.smooth });
  const fadeEnd = interpolate(frame, [(dur - 0.6) * fps, dur * fps], [1, 0], { ...clamp, easing: theme.ease.in });
  return (
    <Stage>
      <AbsoluteFill style={{ opacity: fadeEnd, alignItems: "center", justifyContent: "center", flexDirection: "column" }}>
        <div style={{ display: "flex", alignItems: "flex-end", gap: 10, marginBottom: 10 }}>
          {(["mochi", "wisp", "pip"] as const).map((sp, i) => (
            <Entrance key={sp} delay={i * theme.timing.stagger} y={60} from={0.7} spring="bouncy">
              <Breathe amp={8} period={1.9} phase={i * 1.1}>
                <FaceSwap species={sp} a="happy" b={sp === "wisp" ? "love" : "joy"} at={1.6 + i * 0.2} size={sp === "wisp" ? 380 : 260} glow={sp === "wisp"} />
              </Breathe>
            </Entrance>
          ))}
        </div>
        <div style={{ transform: `scale(${interpolate(p, [0, 1], [0.96, 1])})` }}>
          <WordReveal text="Train. Rest. Grow." hi={["Grow."]} delay={0.45} size={128} style={{ justifyContent: "center" }} />
        </div>
        <Entrance delay={1.2} y={24}>
          <div style={{ marginTop: 34, display: "flex", gap: 28, alignItems: "center", fontFamily: theme.fonts.body, fontSize: 34, color: theme.colors.textDim, fontWeight: 500 }}>
            <span style={{ fontWeight: 800, color: theme.colors.text }}>Wisp Gym</span>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: theme.colors.textMute }} />
            <span>OpenHarmony / HarmonyOS</span>
            <span style={{ width: 8, height: 8, borderRadius: 4, background: theme.colors.textMute }} />
            <span>github.com/BOT-K4CP3R/wisp-gym</span>
          </div>
        </Entrance>
      </AbsoluteFill>
    </Stage>
  );
};
