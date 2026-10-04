# Third-party material

| Component | Use | License |
|---|---|---|
| [Nunito](https://github.com/googlefonts/nunito) (Regular/ExtraBold instances in `entry/src/main/resources/rawfile/fonts`) | UI typeface | SIL Open Font License 1.1 (`OFL.txt` next to the fonts) |
| [Oniro App Builder](https://github.com/eclipse-oniro4openharmony/oniro-app-builder) | build/sign/emulator CLI (tooling only, not shipped) | Apache-2.0 |
| OpenHarmony SDK 6.1, hvigor, ohpm | build toolchain (not shipped) | Apache-2.0 / as published by OpenAtom |
| `@ohos/hypium`, `@ohos/hamock` | test framework dev-dependencies from the project template | Apache-2.0 |
| Project scaffold (`EmptyAbility` template) | initial project structure | Apache-2.0 |
| [`@napi-rs/canvas`](https://github.com/Brooooooklyn/canvas) | renders the splash image and launcher icon from the app's drawing code (`scripts/render-creature.mjs`; tooling only, installed outside the repo, not shipped) | MIT |

The app icon, the six creatures and their expressions, UI and all source code were created for this project (MIT, see `LICENSE`).

Promo video tooling (`submission/promo`, not shipped in the app):

| Component | Use | License |
|---|---|---|
| [Remotion](https://www.remotion.dev/) 4, React 19 | renders the silent promo video | Remotion License (free for individuals and small teams), MIT |
| [remotion-motion-graphics skill](https://github.com/haidrrrry/claude-remotion-skill) | Claude Code skill with motion-design rules used to build the promo | see its repository |
