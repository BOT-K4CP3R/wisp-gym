# 90-second demo script

Record on the emulator (or a real device). Say clearly that the emulator has no real motion, so **Demo mode**
replays a synthetic accelerometer stream through the same detector as the real sensor. On x86 emulators the app
turns on *Reduce motion* by default (software rendering); the creature still animates.

| Time | Action | What to say |
|---|---|---|
| 0:00 | First launch: *Meet Wisp*, *How it works*, pick a name, goals | "First the bond: a creature that grows from real training. No account, no cloud." |
| 0:15 | Permission primers, then **Explore the demo** | "The emulator has no motion, so the demo is a clearly labelled simulation." |
| 0:25 | Home: mood, next-step card, Strength / Move rings, Recovery, This week | "One card tells me what to do next. Today: train my weakest group." |
| 0:35 | *Start workout*: 3-2-1 countdown, live rep count | "Reps are counted from motion alone, in any phone orientation." |
| 0:50 | Ring turns orange, "rack it" with the numbers | "Reps got slower and weaker, so it tells me to stop, and shows why." |
| 1:00 | Rest timer with -15 s / skip / +15 s, then *Finish* | "Rest is part of the plan." |
| 1:05 | Summary: creature celebrates, what grew | "My legs grew. Wisp is pumped." |
| 1:15 | Progress (time-lapse) and Insights | "Every value is explainable." |
| 1:25 | Launcher: 2x2 and 2x4 widgets | "The widgets mirror its mood and today's numbers. Data stays on the phone." |

A narrated version of the previous release is attached to the GitHub release (`wisp-gym-demo.mp4`) and can be
regenerated with `submission/make_video.py`.
