# Threat model and limitations

OpenBlock helps people keep their **own** intentions. It is not parental
control, device management or anti-tamper software. This page lists what it
protects, what it deliberately does not, and the risks of running an
accessibility service.

## Assets

1. **What is on the user's screen.** The accessibility service could, in
   principle, read any text shown by any app.
2. **Usage patterns.** Which apps are used and for how long.
3. **The user's configuration.** Rules and focus history.

## Design decisions that protect them

| Risk | Mitigation |
|---|---|
| Screen content leaves the device | No `INTERNET` permission in release builds (checked in CI); no SDKs. |
| Screen content is stored | The service reads only the package name and the presence of known view ids. Nothing from the screen is written to storage or logs. |
| More data observed than needed | Content-change events are only subscribed to while a feed rule is enabled; apps without rules are ignored immediately. |
| Data copied to the cloud | `allowBackup="false"` and data-extraction rules exclude all app data from backup and device transfer. |
| Other apps read OpenBlock's data | All storage is app-private. The service is not exported; only the system can bind it (`BIND_ACCESSIBILITY_SERVICE`). The method channel is in-process only. |
| Remote code execution | No remote code, scripts, rules or updates are downloaded. Adapters are compiled into the app. |
| Malicious modified builds | Releases are built by GitHub Actions from tagged sources, signed with the project key, and published with SHA-256 checksums and the signing certificate fingerprint. |
| Permissions enabled without consent | Every permission is enabled by the user in system settings; the app only opens those screens. |

## Out of scope (documented limitations)

- **The device owner can always disable OpenBlock** — by turning off the
  accessibility service, revoking usage access, force-stopping, uninstalling or
  changing the device time. This is intentional: OpenBlock must never lock
  people out of their own device. A future optional *strict mode* may add
  friction (for example a delay before disabling) but not a lock.
- **Feed detection can be bypassed or break**: app updates, alternative clients,
  web versions in a browser and split-screen tricks can avoid an adapter.
- **Usage data comes from Android** and may lag or be incomplete on some
  devices; limits are enforced only when usage can be measured.
- **Vendor battery management** can stop the service. The app reports when the
  service is enabled but not running.
- **A compromised device** (root, malware with accessibility access) is outside
  what an app can defend against.

## Accessibility service risks

An accessibility service is powerful by nature. Users should only enable it for
apps they trust; OpenBlock's code is open so that anyone can verify the claims
above. Areas to review carefully in changes:

- `accessibility/OpenBlockAccessibilityService.kt` — which events are handled.
- `accessibility/adapters/` — detection must stay id-based and text-free.
- `storage/NativeStore.kt` — what is persisted.
- `AndroidManifest.xml` — permissions and exported components.

Report issues privately as described in [SECURITY.md](../SECURITY.md).
