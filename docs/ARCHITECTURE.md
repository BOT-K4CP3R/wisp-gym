# Architecture

Wisp Gym is a native **ArkTS / ArkUI** application (API 20 minimum, compiled against API 23) with one
`entry` module, one UIAbility and one `FormExtensionAbility` (home-screen widget).

```
                        ┌────────────────────────── UI (ArkUI) ──────────────────────────┐
                        │ pages/Index  Workout  Why  Week     components/CreatureCanvas    │
                        └───────────────┬───────────────────────────────────┬────────────┘
                                        │                                   │ draws
                        ┌───────────────▼──────────────┐          ┌─────────▼──────────┐
 widget/WispCard  ◄──── │ app/AppModel (singleton)      │          │ core/CreatureLook   │
 WispFormAbility        │ storage · engine · widget push │          │ state -> draw params│
                        └───────┬──────────┬────────────┘          └─────────────────────┘
                                │          │
              ┌─────────────────▼───┐  ┌───▼────────────────────────────────────────────┐
              │ platform/ (OS APIs) │  │ core/ (pure logic, unit-tested on plain Node)  │
              │ MotionSource  (accel)│  │ RepDetector  -> SetAnalyzer -> WorkoutSession  │
              │ StepService (pedom.) │  │ LifeEngine (history -> CreatureState + reasons)│
              │ PrefsStore (prefs)   │  │ Store (validated persistence) · Sim (traces)   │
              │ Haptics · Notifier   │  └────────────────────────────────────────────────┘
              └──────────────────────┘
```

## Layers

### `core/` — pure, deterministic, tested
No imports from `@kit.*`. Plain classes only (no enums/interfaces), so the exact same source compiles with
ArkTS and runs on Node for tests (`scripts/test.sh`).

| File | Responsibility |
|---|---|
| `RepDetector` | Streaming rep counter. Removes gravity with a low-pass filter, projects the remainder on the gravity axis (so phone orientation does not matter), counts peaks of that vertical signal. Rejects walking cadence, double bumps and corrupt samples. Each rep is confirmed 1.4 s after its peak so a walking rhythm can retract the tentative count. |
| `SetAnalyzer` | Builds a *fatigue proxy* from rep-interval slow-down and drive-peak loss versus the first reps. Fires the "rack it" cue once. Produces a human-readable explanation with the real numbers. |
| `WorkoutSession` | State machine `idle → set → rest → …`. Auto-ends a set after 7 s without a rep, schedules rest (longer after a fatiguing set), emits one `WorkoutRecord` per visit. |
| `LifeEngine` | Training history + steps → `CreatureState`: per-muscle-group level (exponential decay, 4-day half-life), recovery, rest guard, mood, and a `Reason` list that explains every value. |
| `CreatureLook` | State → drawing parameters (scales, hue, glow, eyes, smile). Shared by the Canvas and the widget. |
| `Store` | `KeyValueStore` abstraction, validated JSON persistence. Corrupt storage never crashes the app. |
| `Sim` | Deterministic synthetic accelerometer traces and a 14-day history for the demo and the tests. |
| `Plan` | Next-step card, weekly totals (Monday first, compared with last week up to the same time), workout summary, labels. |
| `Mood` | Display names for moods, shared by the app and the widgets. |
| `Profile` | Name, goals, haptics, rest alerts and motion mode, validated on load and save. |

### `platform/` — thin OS adapters
`MotionSource` (accelerometer via SensorServiceKit, or a simulated replay), `StepService` (hardware pedometer,
day baseline), `PrefsStore` (`@ohos.data.preferences`), `Haptics` (vibrator), `Notifier` (NotificationKit).
Each adapter degrades gracefully: no sensor → clear message; no vibrator → silent; no permission → feature off.

### UI
- `Onboarding`: welcome, how it works, name, goals, permission primers, real sensors or demo, ready. Replayable.
- `Index`: tab shell (`Tabs` with a hidden bar and a floating custom bar) hosting `views/HomeView`,
  `views/ProgressView` and `views/InsightsView`; tabs keep their state, re-tapping scrolls to top, widget taps are
  routed through `AppStorage` (`NAV_TARGET`).
- `HomeView`: creature (tap for a hop and a heart), next-step card, Strength and Move rings, Recovery, this week,
  muscle groups, 5-week activity grid.
- `Workout`: exercise picker, 3-2-1 countdown, live ring, coaching line with the fatigue explanation, rest controls,
  completed-set chips, save/discard confirmation, silent-sensor fallback to Demo mode.
- `Summary`: creature reaction, duration / sets / reps, what grew (before → after), exercises.
- `ProgressView`: weekly totals, 7-day reps chart, simulated 14-day time-lapse, history with per-set details.
- `InsightsView`: every number behind the creature's state (explainability) and how the app works.
- `Settings`: name, goals, haptics, rest alerts, reduce motion, demo, sample data, replay intro, erase all.
- `ui/Motion`: one place that decides whether animations, transitions and press effects run.
- `widget/WispCard` (2×2) and `widget/WispWide` (2×4): a creature built from rounded boxes (`widget/common/MiniWisp`,
  cards cannot host a Canvas), refreshed by `formProvider.updateForm` after workouts, settings changes, when the app
  goes to the background and by the scheduled update. The widget process re-reads Preferences from disk, because
  Preferences caches per process; widget ids live in their own file and dead ids are pruned.

## Data flow of one set
1. After a 3-second countdown `Workout` starts a `MotionSource` (real accelerometer, or a simulated stream in Demo mode).
2. Each `AccelSample` is shifted onto the wall clock once and passed to `WorkoutSession.onSample`.
3. `RepDetector` emits a confirmed `RepEvent`; `SetAnalyzer` updates fatigue and may raise the stop cue.
4. The page shows the live count, vibrates on the cue, and the 250 ms tick auto-ends the set after a pause.
5. `finish` stores a `WorkoutRecord`; `AppModel` computes the before/after summary, re-evaluates the creature and
   pushes the widgets; the Summary page replaces the Workout page.

## Design decisions
- **Non-punitive by construction**: levels have a floor, recovery is a score (not a streak), the smile is never
  negative. Covered by tests (`creature never looks sad`, `old work fades but never below the floor`).
- **Explainable**: nothing in the creature state is opaque; `Reason` objects feed the Why screen.
- **Privacy**: all data is local (`Preferences`). The app requests no network permission.
- **Minimal permissions**: `ACCELEROMETER`, `VIBRATE` (both normal) and `ACTIVITY_MOTION` (asked at use, with a
  stated reason).
- **No AI/ML in the product.** The "intelligence" is signal processing and transparent rules.
