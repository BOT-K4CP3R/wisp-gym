# AI_WORKFLOW

This project was built with an AI coding agent. **The product itself contains no AI/ML model**: rep counting,
fatigue and the creature are signal processing and transparent rules, so there is no model, inference flow or
user-data processing to document beyond what is below. No API keys, credentials or personal data are used or
stored in this repository.

## Tools used

| Tool | Role |
|---|---|
| **Claude Sonnet 5.5** (`claude-sonnet-5-5`) in **Claude Code** (desktop app) | brainstorming the idea, architecture, all code, tests, docs, build/troubleshooting |
| Claude Code built-in tools: Bash, file Read/Write/Edit, WebSearch, WebFetch | running builds/tests, writing files, looking up OpenHarmony API docs |
| claude-mem `work_state` (task list) | tracking progress across the session |
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
- `./scripts/test.sh`: 22 unit tests (including a 300-set randomised synthetic sweep) against the same source files the app compiles.
- Compiler: every change is built with hvigor (`BUILD SUCCESSFUL`); a hypium suite also compiles.
- Test-driven fixes: a test showed walking was counted as reps; the detector was extended with cadence
  detection and the test now passes.
- Claims in the README are limited to what was run; limits are stated in *Limitations*.
- See the repository's commit history for the order of work.

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

## Privacy
No network permission, no analytics, no accounts. All workout data stays in the app's local `Preferences`.
