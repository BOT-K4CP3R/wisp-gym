# Wisp Gym promo (silent, 59 s, 1920x1080)

A motion-graphics presentation of the app built with [Remotion](https://www.remotion.dev/),
following the `remotion-motion-graphics` Claude Code skill
([haidrrrry/claude-remotion-skill](https://github.com/haidrrrry/claude-remotion-skill)).
Colours and type mirror the app (`entry/src/main/ets/ui/Theme.ets`, Nunito); the creatures are
rendered from the app's own drawing code and the phones show real emulator screenshots
from `docs/screenshots`.

```bash
cd submission/promo
npm install
npm run assets   # copies screenshots + fonts, renders creatures (needs @napi-rs/canvas, see scripts/render-creature.mjs)
npm run render   # -> out/wisp-gym-promo.mp4
```

`src/theme.ts` holds every colour, easing and spring; scenes are in `src/scenes`, shared motion
pieces (entrances, word reveals, counters, the phone mockup, grain/vignette/grade layers) in
`src/components`.
