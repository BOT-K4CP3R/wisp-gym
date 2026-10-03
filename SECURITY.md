# Security

- The app declares no network permission and stores everything locally (`@ohos.data.preferences`).
- Requested permissions: `ohos.permission.ACCELEROMETER`, `ohos.permission.VIBRATE` (normal) and
  `ohos.permission.ACTIVITY_MOTION` (asked at use, with a stated reason).
- Release packages are signed with the OpenHarmony SDK's public **development** certificate and are meant for
  emulators and development devices. **No signing key, keystore or password is stored in this repository**;
  `signatures/`, `*.p12`, `*.p7b`, `*.cer` and `local.properties` are git-ignored, and `scripts/build.sh`
  generates throw-away signing material locally.
- To report a problem, open a GitHub issue (no sensitive data please).
