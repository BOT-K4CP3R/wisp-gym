# UX research notes

Patterns from leading apps in this segment that shaped version 1.1. Sources: product teardowns and feature pages
for Finch, Duolingo, Apple Fitness, WHOOP, Hevy / Strong, Pokémon Sleep, Fitbod and Gentler Streak.

| App | Pattern we adopted | Where in Wisp Gym |
|---|---|---|
| Finch, Duolingo | Bond first: meet and name the mascot before any settings; one choice per screen | Onboarding: welcome → how it works → name → goals |
| Duolingo, Gentler Streak | One priming screen per permission, explained in the mascot's words; "Not now" is fine | Onboarding: *Two small permissions* |
| Duolingo | Try before committing; sample content clearly labelled | Onboarding: *Explore the demo* loads labelled sample history |
| WHOOP, Apple Fitness | At most three headline numbers under the hero, details on tap | Home: Strength ring, Move ring, Recovery bar; tiles open Insights |
| Fitbod, WHOOP | A single "next best action" with one primary button | Home: next-step card (first set / train weakest group / recharge / rest day / goal reached) |
| Hevy, Strong | Rest timer starts by itself, −15 s / +15 s / skip, buzz at zero | Workout rest controls and rest-over alert |
| Apple Fitness | Countdown before recording, end-of-workout summary that celebrates first | Workout 3-2-1 countdown; Summary screen (creature reaction, then numbers, then what grew) |
| Hevy | Safe exit: discard behind a confirmation with a non-destructive default | Workout close / back: *Save and finish*, *Discard*, *Keep training* |
| Gentler Streak | Rest is progress; no streaks to lose; never guilt | Moods are never negative; "Rest day" and "Recharging" are framed as progress |
| Duolingo, Finch | Widgets are a mood mirror, small = face + one number, medium = face + next step + metrics | 2x2 widget (mood + weekly sessions), 2x4 widget (next step, strength, recovery, steps) |
| Platform apps | Tap the active tab to scroll to top; tabs keep their state | Tab shell |
| Accessibility guidelines | Reduce motion option; contrast AA for all text | Settings → *Reduce motion*; text tokens re-checked (muted text 5.1:1 on tiles) |

## Changes driven by testing on the emulator

- The widget said *Sleepy* most of the time. Two causes: the widget process read a stale Preferences cache, and the
  creature was "sleepy" for ~17 hours after every workout. Fixed by re-reading storage in the widget process and by
  a new *Pumped* mood for the first hours after a session, with a shorter recharge window.
- Long render-service animation callbacks on the software-rendered emulator stalled frames and JavaScript timers
  (frozen rep counts and rest timers). Timer-driven emphasis no longer uses `animateTo`, failed vibration is not
  retried, and *Reduce motion* is the default on x86 emulators.
