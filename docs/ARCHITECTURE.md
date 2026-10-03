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

### `platform/` — thin OS adapters
`MotionSource` (accelerometer via SensorServiceKit, or a simulated replay), `StepService` (hardware pedometer,
day baseline), `PrefsStore` (`@ohos.data.preferences`), `Haptics` (vibrator), `Notifier` (NotificationKit).
Each adapter degrades gracefully: no sensor → clear message; no vibrator → silent; no permission → feature off.

### UI
- `Index` home: creature, three stats, entry points, demo controls.
- `Workout`: exercise chips, live rep counter, fatigue bar, stop cue, rest timer, finish.
- `Why`: every number behind the creature's state (explainability).
- `Week`: recent sessions and a *simulated* 14-day evolution time-lapse.
- `widget/WispCard` (2×2, 2×4): a creature built from rounded boxes (cards cannot host a Canvas), refreshed by
  `formProvider.updateForm` after every workout and by the scheduled update.

## Data flow of one set
1. `Workout` starts a `MotionSource` (real accelerometer, or a simulated stream in Demo mode).
2. Each `AccelSample` is shifted onto the wall clock once and passed to `WorkoutSession.onSample`.
3. `RepDetector` emits a confirmed `RepEvent`; `SetAnalyzer` updates fatigue and may raise the stop cue.
4. The page shows the live count, vibrates on the cue, and the 250 ms tick auto-ends the set after a pause.
5. `finish` stores a `WorkoutRecord`; `AppModel` re-evaluates the creature and pushes the widget.

## Design decisions
- **Non-punitive by construction**: levels have a floor, recovery is a score (not a streak), the smile is never
  negative. Covered by tests (`creature never looks sad`, `old work fades but never below the floor`).
- **Explainable**: nothing in the creature state is opaque; `Reason` objects feed the Why screen.
- **Privacy**: all data is local (`Preferences`). The app requests no network permission.
- **Minimal permissions**: `ACCELEROMETER`, `VIBRATE` (both normal) and `ACTIVITY_MOTION` (asked at use, with a
  stated reason).
- **No AI/ML in the product.** The "intelligence" is signal processing and transparent rules.
