# AI_WORKFLOW

This project was built with an AI coding agent. **The product itself contains no AI/ML model**: rep counting,
fatigue and the creature are signal processing and transparent rules, so there is no model, inference flow or
user-data processing to document beyond what is below. No API keys, credentials or personal data are used or
stored in this repository.

## Tools used

| Tool | Role |
|---|---|
| **Claude Sonnet 5.5** (`claude-sonnet-5-5`) in **Claude Code** (desktop app) | first build: brainstorming the idea, architecture, all code, tests, docs, build/troubleshooting |
| **Claude Opus 5.5** (`claude-opus-5-5`) in **Claude Code** (desktop app) | second session (v1.1–1.3.1): production polish, onboarding, species/expressions, badges, loads, body weight and BMI, emulator debugging, docs |
| Claude Code **subagents** (general-purpose agents run in parallel) | UX research of comparable apps; drawing six species and eleven expressions; badge logic + tests; body-weight/BMI logic + tests; a read-only review of every screen that produced 24 findings (all fixed) |
| Claude Code built-in browser pane | checking the emulator remote page layout |
| Claude Code built-in tools: Bash, file Read/Write/Edit, WebSearch, WebFetch | running builds/tests, writing files, looking up OpenHarmony API docs |
| claude-mem `work_state` (task list) | tracking progress across the session |
| Agent Skill `remotion-motion-graphics` ([haidrrrry/claude-remotion-skill](https://github.com/haidrrrry/claude-remotion-skill)), installed at the user's request | motion-design rules (springs, staggered entrances, grade/grain/vignette, render-and-inspect loop) for the silent Remotion promo in `submission/promo` |
| MCP servers / Agent Skills from the challenge repository | **not used**: the installer prompt in `onirodeveloper/hackyeah2026-challenge` is Windows-only; this project was built on macOS without DevEco Studio. The challenge repo's README, FAQ, and slides were read by the agent. |
| Oniro App Builder CLI (`@oniroproject/oniro-app`), OpenHarmony SDK 6.1, hvigor/ohpm | open-source build chain (not AI) |

## Pre-existing and third-party material
- Project scaffold: `oniro-app create` (`EmptyAbility` template). Default icons come from that template.
- `@ohos/hypium`, `@ohos/hamock` (template devDependencies).
- Everything else (core logic, UI, widget, tests, docs, scripts) was written during the hackathon.

## Workflow

1. **Ideation (human + AI).** The human read the challenge criteria and asked the agent for ideas; the agent
   proposed options and the human rejected several ("boring", "too specialist", "a feature, not an app") before
   choosing the final concept: a creature that grows from real gym training, with rest as a mechanic.
   Key human decisions: no AI in the product, must be an *app*, daily-use and original, non-punitive design.
2. **Feasibility check (AI).** The agent read the challenge docs (README, FAQ, emulator capability table, slide
   deck) and web-checked OpenHarmony API availability before committing (e.g. kiosk APIs are system-only, which
   is why an earlier "lend mode" idea was dropped).
3. **Toolchain (AI).** DevEco Studio was unavailable, so the agent assembled a command-line build chain on macOS
   (documented in `scripts/setup-macos.sh`).
4. **Core first, tested on Node (AI).** Pure logic was written as dependency-free classes and tested before any UI.
5. **UI and platform adapters (AI), compiler-driven.** ArkTS compile errors were fixed iteratively.
6. **Docs (AI)**, reviewed against the code for accuracy of claims.

## Main prompts / instructions (paraphrased)
- "Read the challenge criteria and rules" (two PDFs), then "here is the whole challenge repository".
- "Invent something that does not exist yet, preferably without AI, for daily usage, original, able to win."
- "Develop the tamagotchi idea so it is at a winning level", then "combine it with the gym, a motivator".
- `/goal`: "execute the advanced plan, prepare everything, act autonomously, hand over a finished, tested and
  reviewed project."

## How generated output was validated
- `./scripts/test.sh`: 74 unit tests (including a 300-set randomised synthetic sweep) against the same source files the app compiles.
- Compiler: every change is built with hvigor (`BUILD SUCCESSFUL`); a hypium suite also compiles.
- Test-driven fixes: a test showed walking was counted as reps; the detector was extended with cadence
  detection and the test now passes.
- Claims in the README are limited to what was run; limits are stated in *Limitations*.
- See the repository's commit history for the order of work.

## UI redesign (human + AI)
The first UI was rejected as generic ("vibecoded"). The agent researched references (web search, Dribbble minimal
workout apps) and the human supplied reference images; the final direction is a monochrome bento dark UI with one
coral accent that matches the creature, a bundled rounded font (Nunito, SIL OFL) and a tab bar. Each change was
built and checked on the emulator.

## Submission material
The presentation (python-pptx), the narrated promo video (Pillow + ffmpeg + macOS `say`) and the form answers were
generated by scripts in `submission/` from real emulator captures. The narration is synthetic speech.

## Emulator verification (agent-driven)
The agent installed the open-source Oniro emulator, booted it headless, installed the HAP over `hdc`, drove the UI
with `uitest uiInput`, captured screenshots with `snapshot_display`, read the layout tree with `uitest dumpLayout`
and read `hilog`. The `docs/screenshots/` images are real captures from that emulator.

## Failures and lessons
- First detector version counted walking as reps (caught by a test, fixed).
- `offset` is a reserved attribute name on ArkUI components; `deviceTypes: phone` is not valid in the
  OpenHarmony SDK (only `default`, `tablet`, `2in1`, ...). Both were caught by the compiler.
- Real recordings of squats/curls were not available during the hackathon, so accuracy on a real body is
  unmeasured. This is the main known risk and is listed as a limitation.
- Found only on the running emulator (not by tests or the compiler): (1) Canvas `fillStyle` with `hsl()` strings draws
  nothing on this runtime (use `#RRGGBB`/`rgba()`); (2) a class instance passed through `@Prop` went stale, the child
  kept the first value (replaced by a shared mutable holder polled each frame); (3) a continuously animating Canvas on
  a hidden page starved the main thread on the slow emulator (frames are now skipped on hidden pages, 15 fps).
- Polling `uitest dumpLayout` every few seconds disturbed timers on the slow emulator and looked like an app freeze;
  it was an artefact of the measurement, confirmed by an un-polled run that completed normally. Logging
  (`hilog`) was added to prove what the app was doing instead of guessing.
- A `previewImages` key in `form_config.json` broke the build (schema), caught by the build, reverted.
- The Huawei macOS command-line tools are not public; the Linux archive works because hvigor/ohpm are Node programs.

## Second session: polish to v1.3.1 (Claude Opus 5.5)

**Main prompts (paraphrased, Polish in the original):**
- `/goal` "polish the app, learn from top mobile apps, add a proper first-run setup, make it production-grade, test
  everything in demo mode, look for UI/UX bugs such as missing animations, the widget always saying Sleepy and
  ugly data layout; research and compare; commit as bot-k4cp3r without a co-author line".
- "the widget creature is boxy, use the app's creature; same on the loading screen".
- `/goal` "spawn subagents, review every screen, fix empty areas, bugs and old icons, many creatures with many
  faces, make it rich enough to win".
- "add loads and reps logging, body-weight logging with loss/gain, charts and stats, a weight goal, BMI, and ask
  for it during setup".
- "finish: remove unused files, update README/ARCHITECTURE and version, run tests, build, commit, make it ready
  for submission against the two requirement PDFs".
- "install the claude-remotion-skill and make a nice silent presentation video in the app's colours and vibe";
  then "the screen floats inside the phone, remove the orange background gradients".
- "the app icon still shows the old creature from the demo, make a new one; put it in the video as the logo".

**Workflow.** Research subagent (Finch, Duolingo, Apple Fitness, WHOOP, Hevy, Gentler Streak; summarised in
`docs/UX_RESEARCH.md`) → plan → pure core modules first with Node tests (`Profile`, `Mood`, `Plan`, `Species`,
`Achievements`, `Body`) → UI → hvigor build → install on the Oniro emulator → screenshots and `hilog` after every
change → fix → commit. Independent pieces were delegated to parallel subagents with strict file ownership and
the ArkTS rules spelled out in the prompt; the main agent integrated, built and verified on the emulator.

**How output was reviewed.** Every change was compiled with hvigor and the 74 Node tests; every screen was checked
on the emulator from screenshots; a separate review agent read all screens and reported 24 defects with
file:line evidence, which were fixed and re-checked; subagent claims (e.g. "build passes") were re-run by the main
agent.

**Failures and lessons from this session.**
- The widget showed "Sleepy" all day: the widget process read a stale Preferences cache, and the creature really was
  sleepy for ~17 h after any workout. Fixed in both places (re-read from disk; a new "Pumped" mood).
- `@Builder` parameters are passed by value: rows built from them froze at their first value (onboarding cards,
  settings toggles, widget metrics). Builders now read component state directly.
- `NumericTextTransition()` without options crashed the runtime; removed.
- On the software-rendered emulator, long render-service animation callbacks stalled frames and JS timers (frozen
  rep counts) and frames longer than 6 s got the app killed by the watchdog. Mitigations: no `animateTo` from
  timers, a Reduce-motion mode that is the default on x86 emulators, a Canvas that only redraws on change there,
  cached history/profile/badges, and pages that build in stages. The underlying cause was often the host Mac
  swapping (8 GB RAM, emulator + browsers); restarting the emulator restored normal speed.
- The QEMU VNC pointer did not move the OpenHarmony cursor; `scripts/emu-remote.py` shows the screen in a browser
  and injects real touch events over `hdc` instead.
- The launcher icon and the first onboarding screen still showed an early salmon-red Wisp: the species' base hue
  only drifted to the peach seen on Home after training. The base hue was moved to that peach and the icon/splash
  regenerated from the same drawing code (`scripts/render-creature.mjs`). The emulator launcher caches icons, so
  checking it needed an uninstall + reinstall.
- The first promo cut zoomed the screenshots inside a phone that itself floated, which read as the screen sliding
  around in the bezel; the screen is now fixed to the phone and only the whole phone moves.
- Autofocusing a text field in a sheet blocked the UI thread for >6 s on the emulator (keyboard attach); removed.

## Privacy
No network permission, no analytics, no accounts. All workout, body-weight and profile data stays in the app's local `Preferences`. Height and weight are used only to compute BMI on the device.
