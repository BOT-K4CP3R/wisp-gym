import React from "react";
import { interpolate, Series, useCurrentFrame, useVideoConfig } from "remotion";
import { Counter } from "./components/Motion";
import { Chip } from "./components/Motion";
import { Collection, CTA, Hook, Stats, Statement } from "./scenes/Brand";
import { Feature, FloatCard } from "./scenes/Feature";
import { theme } from "./theme";

// Scene lengths in seconds (the composition length is their sum).
export const SCENES = { hook: 4.6, statement: 3.6, setup: 5.6, home: 5.4, set: 6.2, loads: 5.6, body: 5.8, collection: 6.4, widgets: 5.2, stats: 5.2, cta: 5.4 };
export const totalSeconds = Object.values(SCENES).reduce((a, b) => a + b, 0);

const Label: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ fontFamily: theme.fonts.body, fontWeight: 800, fontSize: 22, letterSpacing: "0.12em", color: theme.colors.textMute }}>{children}</div>
);
const Big: React.FC<{ children: React.ReactNode }> = ({ children }) => (
  <div style={{ fontFamily: theme.fonts.display, fontWeight: 800, fontSize: 76, lineHeight: 1.05, color: theme.colors.text }}>{children}</div>
);

// A weight trend that draws itself.
const MiniChart: React.FC<{ delay: number }> = ({ delay }) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const p = interpolate(frame, [delay * fps, (delay + 1.4) * fps], [0, 1], { extrapolateLeft: "clamp", extrapolateRight: "clamp", easing: theme.ease.out });
  const ys = [40, 34, 38, 28, 30, 22, 24, 16, 18, 10];
  const pts = ys.map((y, i) => `${i * 34},${y + 6}`).join(" ");
  const len = 360;
  return (
    <svg width={320} height={70} style={{ marginTop: 16, overflow: "visible" }}>
      <line x1={0} x2={306} y1={14} y2={14} stroke={theme.colors.primaryMid} strokeDasharray="8 8" strokeWidth={2} opacity={0.7 * p} />
      <polyline points={pts} fill="none" stroke={theme.colors.text} strokeWidth={4} strokeLinecap="round" strokeLinejoin="round" strokeDasharray={len} strokeDashoffset={len * (1 - p)} />
    </svg>
  );
};

export const Promo: React.FC = () => {
  const { fps } = useVideoConfig();
  const f = (s: number) => Math.round(s * fps);
  const S = SCENES;
  return (
    <Series>
      <Series.Sequence durationInFrames={f(S.hook)}><Hook dur={S.hook} /></Series.Sequence>
      <Series.Sequence durationInFrames={f(S.statement)}><Statement dur={S.statement} /></Series.Sequence>
      <Series.Sequence durationInFrames={f(S.setup)}>
        <Feature dur={S.setup} kicker="First run" head="Set up in a minute." hi={["minute."]} sub="Pick a starter creature, set your goals, add height and weight for BMI. Everything stays on the phone."
          chips={["Creature", "Goals", "BMI", "Sensors or demo"]} shots={["16-onboarding-creature.jpg", "17-onboarding-body.jpg", "02-onboarding-how.jpg"]} every={1.9} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={f(S.home)}>
        <Feature dur={S.home} kicker="Home" head="It lives on your training." hi={["training."]} sub="Every muscle group you train grows a part of it. Its mood comes from recovery and daily movement."
          chips={["Level + XP", "Mood", "Next step"]} shots={["05-home-pumped.jpg", "24-home-body.jpg", "06-home-stats.jpg"]} every={1.8} zoom="out" hue="cool" />
      </Series.Sequence>
      <Series.Sequence durationInFrames={f(S.set)}>
        <Feature dur={S.set} kicker="Workout" head="Reps counted from motion alone." hi={["motion"]} sub="Phone in your pocket. When reps slow down and lose drive, it tells you to rack it."
          shots={["07-workout-ready.jpg", "08-set-counting.jpg", "09-set-rack-it.jpg", "22-coach-rest.jpg"]} every={1.55}
          overlay={<FloatCard delay={1.4} top={600} left={-40}><Label>REPS</Label><Big><Counter to={10} delay={1.5} /></Big><div style={{ marginTop: 14 }}><Chip hero>Rack it</Chip></div></FloatCard>} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={f(S.loads)}>
        <Feature dur={S.loads} kicker="Loads + records" head="Every kilo counts." hi={["kilo"]} sub="Set the load per exercise. The summary adds up volume, new personal records and what grew."
          chips={["Per-exercise load", "Volume", "PRs"]} shots={["21-load.jpg"]} shots2={["23-summary-volume.jpg", "11-summary.jpg"]} every={2.6} hue="cool" />
      </Series.Sequence>
      <Series.Sequence durationInFrames={f(S.body)}>
        <Feature dur={S.body} kicker="Body" head="Weight, goal and BMI." hi={["BMI."]} sub="Log weigh-ins, follow the trend against your goal and see where you sit in a healthy range."
          shots={["18-body.jpg", "19-body-bmi.jpg"]} every={2.6}
          overlay={<FloatCard delay={1.5} top={560} left={-60}><Label>BMI</Label><Big><Counter to={25} decimals={1} delay={1.6} /></Big><MiniChart delay={1.9} /></FloatCard>} />
      </Series.Sequence>
      <Series.Sequence durationInFrames={f(S.collection)}><Collection dur={S.collection} /></Series.Sequence>
      <Series.Sequence durationInFrames={f(S.widgets)}>
        <Feature dur={S.widgets} kicker="Everywhere" head="Insights and widgets." hi={["widgets."]} sub="Every value is explained. Two home-screen widgets show your creature without opening the app."
          shots={["15-widgets.jpg"]} shots2={["13-insights.jpg", "12-progress.jpg"]} every={2.4} zoom="out" />
      </Series.Sequence>
      <Series.Sequence durationInFrames={f(S.stats)}><Stats dur={S.stats} /></Series.Sequence>
      <Series.Sequence durationInFrames={f(S.cta)}><CTA dur={S.cta} /></Series.Sequence>
    </Series>
  );
};
