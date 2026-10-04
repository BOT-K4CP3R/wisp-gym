<p align="center">
  <img src="docs/app-icon.png" width="132" alt="Wisp Gym icon">
</p>

<h1 align="center">Wisp Gym</h1>

<p align="center">
  A creature that grows from your <b>real</b> training.<br>
  Your phone counts reps from motion alone, tells you when a set is getting too slow, and asks for a rest day when you overdo it.<br>
  <sub>Native ArkTS/ArkUI app for OpenHarmony and HarmonyOS. No account. No cloud. No AI model.</sub>
</p>

<p align="center">
  <a href="https://github.com/BOT-K4CP3R/wisp-gym/actions/workflows/test.yml"><img src="https://github.com/BOT-K4CP3R/wisp-gym/actions/workflows/test.yml/badge.svg" alt="tests"></a>
  <img src="https://img.shields.io/badge/OpenHarmony-API%2020%2B-orange" alt="API 20+">
  <img src="https://img.shields.io/badge/ArkTS-ArkUI-blue" alt="ArkTS ArkUI">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT">
</p>

<p align="center">
  <a href="https://github.com/BOT-K4CP3R/wisp-gym/releases/latest"><b>Download the .hap</b></a> ·
  <a href="https://github.com/BOT-K4CP3R/wisp-gym/releases/latest/download/wisp-gym-demo.mp4">Demo video (85 s)</a> ·
  <a href="docs/ARCHITECTURE.md">Architecture</a> ·
  <a href="AI_WORKFLOW.md">AI workflow</a>
</p>

Built for **HackYeah 2026 / Huawei Challenge "Imagine What's Next"**. Lead area: *Human-Centric Technology*
(wellbeing, responsible design), plus *Spatial Experiences* (sensing body motion). Targets **API 20+** (compiled against API 23).

<p align="center">
  <img src="docs/screenshots/01-onboarding-welcome.jpg" width="19%">
  <img src="docs/screenshots/04-home.jpg" width="19%">
  <img src="docs/screenshots/09-set-rack-it.jpg" width="19%">
  <img src="docs/screenshots/11-summary.jpg" width="19%">
  <img src="docs/screenshots/15-widgets.jpg" width="19%">
</p>

## What it does

1. **Reps counted automatically.** Carry the phone in a pocket or armband. A streaming detector removes gravity,
   projects motion on the gravity axis (phone orientation does not matter) and counts the drive peaks. Walking and
   sensor glitches are rejected.
2. **Knows when to stop.** It learns your fresh tempo from the first reps. When reps get slower and weaker the ring
   turns orange and Wisp says *"rack it"*, with the numbers behind the advice.
3. **Wisp is your training made visible.** Each muscle group (legs, push, pull, core) grows a body part of the
   creature. Its colour, glow, eyes and mood come from recovery and daily steps.
4. **Rest is part of the game.** Three sessions in 72 h, or a very heavy load, and Wisp asks for a rest day.
5. **Never punishes.** Levels have a floor, there are no streaks to lose, and the creature is never sad: neglect
   makes it *curious*, a fresh session makes it *pumped*, hard training makes it *recharge* or ask for a rest day.
6. **Explainable.** The *Insights* tab lists every value with its source numbers.
7. **Tells you what to do next.** One card on Home picks the next step: your first set, the weakest muscle group,
   a recharge day, a rest day or a bonus set once the weekly goal is met.
8. **A real workout flow.** 3-2-1 countdown, live count, rest timer with −15 s / skip / +15 s and a rest-over alert,
   a safe exit (save / discard / keep training) and a summary that shows what grew.
9. **Friendly first run.** Meet and name your creature, set a gentle weekly goal, permission primers, and a choice
   between real sensors and a clearly labelled demo.
10. **Two home-screen widgets** (2x2 mood mirror, 2x4 with next step, strength, recovery and steps) that open the app.
11. **Accessible.** Reduce-motion setting (default on emulators that render in software), AA contrast, labelled controls.

Everything is computed and stored **on the phone**. The app requests no network permission.

## Platform capabilities used

| OpenHarmony capability | Used for |
|---|---|
| Accelerometer (SensorServiceKit) | live rep detection and tempo / drive analysis |
| Pedometer (SensorServiceKit, `ACTIVITY_MOTION`) | daily movement for the creature |
| Service widget (`FormExtensionAbility`, `formProvider`) | creature + status on the home screen |
| Vibrator | stop cue and end-of-rest haptics |
| NotificationKit | "rest over" notification |
| Preferences (`@ohos.data.preferences`) | local, validated persistence |
| Window (`keepScreenOn`, system-bar styling) | the workout screen stays on |
| ArkUI Canvas | procedural creature rendering |

## Quick start

**Just try it:** download `wisp-gym-debug.hap` from the [latest release](https://github.com/BOT-K4CP3R/wisp-gym/releases/latest)
and install it on an OpenHarmony 6.x emulator or development device:

```bash
hdc install -r wisp-gym-debug.hap
hdc shell aa start -a EntryAbility -b com.hackyeah.wispgym -m entry
```

The package is signed with the SDK's public *development* certificate. On other targets build and sign it yourself (below).

**In the app:** on first launch choose **Explore the demo** (or later: *Settings → Demo mode*, *Load sample history*),
then *Start workout*. Emulators have no real motion, so Demo mode replays a **simulated** accelerometer stream through the same
detector as the real sensor; it is labelled as such in the UI.

## Build from source

Requirements: macOS or Linux, Node.js ≥ 22, JDK 17. **DevEco Studio is not required.**

```bash
./scripts/setup-macos.sh     # one-time: OpenHarmony SDK 6.1 (API 23), hvigor, ohpm (macOS; on Linux use `oniro-app cmdtools install`)
./scripts/test.sh            # 35 unit tests on plain Node, no SDK needed
./scripts/build.sh           # signed debug HAP -> dist/wisp-gym.hap (throw-away development certificate, never committed)
./scripts/emulator-up.sh     # start the Oniro emulator (macOS: brew install qemu), install and launch
```

With DevEco Studio instead: open the folder, *File → Project Structure → Signing Configs → Automatically generate*,
choose a device and press Run. Settings: `compatibleSdkVersion` 20, `compileSdkVersion` 23.

## How it works

```
Accelerometer ──► RepDetector ──► SetAnalyzer ──► WorkoutSession ──► WorkoutRecord ──► LifeEngine ──► Creature + widget
 (SensorKit)       peaks, gravity   tempo + drive     set / rest         (Preferences)    decay, rest      (Canvas / Form)
                   axis, walking    loss -> fatigue   state machine                       guard, reasons
                   rejection        proxy, stop cue
```

`entry/src/main/ets/core` is pure, dependency-free logic that is unit-tested on Node **and** compiled for the device
from the same source files. OS access is isolated in `platform/`. See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Verified, and what is not

| Checked | Result |
|---|---|
| Builds and signs with hvigor against SDK 6.1; installs and launches on an OpenHarmony 6.1 emulator | yes |
| Onboarding (demo and real-sensor paths, replay from Settings), Home, Progress, Insights, Settings, tab navigation | yes (emulator) |
| Live-counted demo sets with the "rack it" cue, rest controls, multi-set workout, summary, discard confirmation | yes (emulator) |
| Fallback when the motion sensor is silent (offers Demo mode in place) | yes (emulator) |
| Both widgets added from the launcher, updated after workouts and settings changes | yes (emulator) |
| Tapping a widget opens the app | yes (emulator) |
| System permission dialog for `ACTIVITY_MOTION` with a stated reason | yes |
| Unit tests | 35 pass, incl. a 300-set randomised sweep (99.3% exact counts, 100% within ±1 rep) |
| **Real** accelerometer / pedometer / vibration data | **not verifiable** on an emulator; code paths exist and fail gracefully |
| Rep accuracy on real bodies | **not measured**; the sweep above is on synthetic traces |
| HarmonyOS device, DevEco emulator | **not tested** |

First launch on the software-emulated Oniro emulator can take about a minute; it is much faster on hardware-accelerated emulators.

## Project layout

```
entry/src/main/ets/core/        pure logic: RepDetector, SetAnalyzer, WorkoutSession, LifeEngine, Plan, Mood, Profile, Store, Sim
entry/src/main/ets/platform/    sensors, pedometer, preferences, haptics, notifications
entry/src/main/ets/ui/          design tokens, components, motion policy, fonts, navigation helpers
entry/src/main/ets/pages/       Index (tab shell), Onboarding, Workout, Summary, Settings
entry/src/main/ets/views/       Home, Progress, Insights tabs
entry/src/main/ets/widget/      2x2 and 2x4 home-screen cards, shared mini creature
tests/                          Node tests (35) + hypium suite in entry/src/test
scripts/                        setup, build, test, emulator + browser remote, splash/icon rendering
submission/                     scripts that build the demo video and presentation from real emulator captures
docs/                           architecture, demo script, UX research, screenshots
```

## Limitations

- Phone-in-pocket sensing suits squats, deadlifts, curls, presses and crunches; bench-type lifts are not supported.
- The fatigue value is a *tempo and drive proxy*, not bar velocity or a medical measurement. The app gives no medical advice.
- Widgets refresh after each workout, when you leave the app and every 30 minutes; they do not animate.
- On the software-rendered emulator the first launch can take a minute and Reduce motion is on by default.

## Documentation

[Architecture](docs/ARCHITECTURE.md) · [Demo script](docs/DEMO_SCRIPT.md) · [UX research](docs/UX_RESEARCH.md) · [AI workflow](AI_WORKFLOW.md) ·
[Third-party notices](THIRD_PARTY.md) · [Security](SECURITY.md)

## AI disclosure

The product contains **no AI model**. The project was built with an AI coding agent (Claude Sonnet 5.5 in Claude Code);
tools, prompts, validation and lessons are documented in [AI_WORKFLOW.md](AI_WORKFLOW.md).

## License

MIT, see [LICENSE](LICENSE). Bundled font: Nunito (SIL OFL 1.1), see [THIRD_PARTY.md](THIRD_PARTY.md).
