# HackYeah project form: ready-to-paste answers

Fields marked **[FILL]** need your input (I cannot know or must not invent them).

**Project Name:** Wisp Gym

**Problem:** Most people train without feedback they can trust. They count reps by hand, stop a set too early or too late, and either lose motivation when a streak breaks or overtrain without noticing. Fitness apps usually add pressure (streaks, guilt, notifications) and demand manual logging in the middle of a set. **[FILL: one verified statistic with its source]**

**Solution:** Wisp Gym is a native OpenHarmony/HarmonyOS app in which a small creature grows from your real training. The phone counts reps from the accelerometer alone, whatever its orientation in the pocket, and watches how rep speed and drive change during a set to say when to stop, showing the numbers behind the advice. Each muscle group grows part of Wisp, and Wisp asks for a rest day when you overdo it. It never dies and never punishes. Every value is explainable on an Insights screen, and a home-screen widget shows Wisp at a glance. No account, no cloud, no AI model: signal processing and transparent rules. All data stays on the device.

**Challenge:** Huawei Challenge: "Imagine What's Next". Lead area: Human-Centric Technology, plus Spatial Experiences.

**Cover image:** `submission/cover.png`

**Idea stage:** New idea built from scratch during the hackathon. Working prototype running on an OpenHarmony 6.1 emulator.

**What's done so far and goal:** Done: native ArkTS/ArkUI app (API 20 minimum, compiled against API 23); streaming rep detector with walking and glitch rejection; fatigue analysis with a stop cue; creature model with decay, rest guard and explanations; procedurally drawn creature; home-screen widget; on-device storage; monochrome bento UI; 22 unit tests (including a 300-set randomized sweep); reproducible build scripts that need no DevEco Studio; signed .hap; presentation and narrated demo video. Verified on an emulator: install, launch, all screens, a live-counted set with the stop cue, rest timer, widget. Not verified: real sensors (emulators have no motion), widget tap-through, HarmonyOS devices. Goal at the event: record real accelerometer traces to validate rep counting on real bodies, and polish the demo.

**Team status:** [FILL]  **Current team size:** [FILL]  **Needed skills:** [FILL]
**Skills comment:** Looking for someone who can record real accelerometer traces of gym exercises (phone or watch, short session) to validate the rep detector, and a designer to review the UI. [Adjust or write "Team complete"]

**Video:** [FILL: YouTube link]. File: `submission/wisp-gym-demo.mp4` (85 s, English narration, built from real emulator captures; Demo mode is labelled on screen).

**Website:** (optional) repository link.
**Code Repository:** [FILL: public URL]

**Instructions on how to open project:**
```
Requirements: macOS or Linux, Node.js >= 22, JDK 17. DevEco Studio is not required.
1. ./scripts/setup-macos.sh        # OpenHarmony SDK 6.1 (API 23), hvigor, ohpm
2. ./scripts/test.sh               # 22 unit tests on plain Node
3. ./scripts/build.sh              # signed debug HAP -> dist/wisp-gym.hap
4. ./scripts/emulator-up.sh        # starts the Oniro emulator (macOS: brew install qemu), installs, launches
Or install the pre-built release/wisp-gym-debug.hap:
  hdc install -r release/wisp-gym-debug.hap
  hdc shell aa start -a EntryAbility -b com.hackyeah.wispgym -m entry
In the app: Settings (top right) -> Demo mode on -> Load 2-week history, then the orange button in the tab bar to start a workout.
Emulators have no real motion, so Demo mode replays a simulated sensor stream through the same detector; it is labelled as such.
```

**Presentation:** `submission/wisp-gym-presentation.pptx` (also `.pdf`).
