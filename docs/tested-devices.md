# Tested devices and apps

This list records where OpenBlock was actually tested. Please add your results
with a pull request or an [app support issue](../.github/ISSUE_TEMPLATE/app_support.yml).

## Automated (CI)

| Environment | Android | What is covered | Result |
|---|---|---|---|
| Android emulator, Pixel 5 profile, x86_64 (GitHub Actions) | 11 (API 30) | Flutter ↔ Kotlin bridge, DataStore persistence across restarts, accessibility service start, whole-app block of the Settings app with an intervention recorded | Runs on every push to `main` (`e2e` job in `.github/workflows/ci.yml`) |
| JVM unit tests (GitHub Actions) | — | Kotlin rule engine against the shared vectors, config parser | Every push and pull request |

## Real devices

No real-device reports yet for 0.1.0. Until there are, feed adapters stay
**experimental** and whole-app rules are considered tested only on the emulator.

| Device | Android | OpenBlock | Target app and version | Rules tested | Result | Reporter |
|---|---|---|---|---|---|---|
| _your device here_ | | | | | | |

### What to test

1. Onboarding and permissions (including restricted settings on Android 13+).
2. Block app on a schedule; daily limit with usage access; pause screen;
   exception overriding a block.
3. Focus session: start, intervention shows "End focus session", end from the
   app and from the intervention.
4. Feed adapters: follow the protocol in
   [adapters/youtube-shorts.md](adapters/youtube-shorts.md).
5. Robustness: reboot during a focus session, revoke usage access, disable and
   re-enable the service, switch apps quickly, dark mode, large font sizes.
6. Battery: note battery usage attributed to OpenBlock after a normal day.
