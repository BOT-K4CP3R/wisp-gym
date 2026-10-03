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
  <img src="docs/screenshots/01-home-thriving.jpg" width="19%">
  <img src="docs/screenshots/03-set-counting.jpg" width="19%">
  <img src="docs/screenshots/04-set-rack-it.jpg" width="19%">
  <img src="docs/screenshots/05-home-resting.jpg" width="19%">
  <img src="docs/screenshots/06-insights.jpg" width="19%">
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
   makes it *curious*, over-training makes it *sleepy*.
6. **Explainable.** The *Insights* tab lists every value with its source numbers.
7. **Home-screen widget** shows Wisp and today's status without opening the app.

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

**In the app:** *Settings (top right) → Demo mode on → Load 2-week history*, then the orange tab-bar button to start a
workout. Emulators have no real motion, so Demo mode replays a **simulated** accelerometer stream through the same
detector as the real sensor; it is labelled as such in the UI.

## Build from source

Requirements: macOS or Linux, Node.js ≥ 22, JDK 17. **DevEco Studio is not required.**

```bash
./scripts/setup-macos.sh     # one-time: OpenHarmony SDK 6.1 (API 23), hvigor, ohpm (macOS; on Linux use `oniro-app cmdtools install`)
./scripts/test.sh            # 22 unit tests on plain Node, no SDK needed
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
| Home, Workout, Insights, Week screens and tab navigation | yes (emulator) |
| A live-counted demo set with the "rack it" cue, rest timer, over-training state | yes (emulator) |
| Home-screen widget offered by the launcher, added, shows creature + status | yes (emulator) |
| System permission dialog for `ACTIVITY_MOTION` with a stated reason | yes |
| Unit tests | 22 pass, incl. a 300-set randomised sweep (99.3% exact counts, 100% within ±1 rep) |
| **Real** accelerometer / pedometer / vibration data | **not verifiable** on an emulator; code paths exist and fail gracefully |
| Rep accuracy on real bodies | **not measured**; the sweep above is on synthetic traces |
| Tapping the widget to open the app | **not verified** |
| HarmonyOS device, DevEco emulator | **not tested** |

First launch on the software-emulated Oniro emulator can take about a minute; it is much faster on hardware-accelerated emulators.

## Project layout

```
entry/src/main/ets/core/        pure logic: RepDetector, SetAnalyzer, WorkoutSession, LifeEngine, Store, Sim
entry/src/main/ets/platform/    sensors, pedometer, preferences, haptics, notifications
entry/src/main/ets/ui/          design tokens, components, fonts, tab navigation
entry/src/main/ets/pages/       Index (Home), Workout, Why (Insights), Week
entry/src/main/ets/widget/      home-screen card, FormExtensionAbility
tests/                          Node tests (22) + hypium suite in entry/src/test
scripts/                        setup, build, test, emulator, icon generation
submission/                     scripts that build the demo video and presentation from real emulator captures
docs/                           architecture, demo script, screenshots
```

## Limitations

- Phone-in-pocket sensing suits squats, deadlifts, curls, presses and crunches; bench-type lifts are not supported.
- The fatigue value is a *tempo and drive proxy*, not bar velocity or a medical measurement. The app gives no medical advice.
- The widget refreshes periodically and after each workout; it does not animate.

## Documentation

[Architecture](docs/ARCHITECTURE.md) · [Demo script](docs/DEMO_SCRIPT.md) · [AI workflow](AI_WORKFLOW.md) ·
[Third-party notices](THIRD_PARTY.md) · [Security](SECURITY.md)

## AI disclosure

The product contains **no AI model**. The project was built with an AI coding agent (Claude Sonnet 5.5 in Claude Code);
tools, prompts, validation and lessons are documented in [AI_WORKFLOW.md](AI_WORKFLOW.md).

## License

MIT, see [LICENSE](LICENSE). Bundled font: Nunito (SIL OFL 1.1), see [THIRD_PARTY.md](THIRD_PARTY.md).
