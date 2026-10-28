# Security policy

OpenBlock runs an Android accessibility service, which can observe sensitive
parts of the screen. We take reports seriously.

## Supported versions

Only the latest release receives security fixes.

## Reporting a vulnerability

Please **do not open a public issue**. Use GitHub's private vulnerability
reporting instead:
<https://github.com/Gabriel-Richard-dev/OpenBlocker/security/advisories/new>

Include the OpenBlock version, the Android version and device, and steps to
reproduce. You should receive an answer within 7 days. Once a fix is released
we will credit you in the release notes unless you prefer otherwise.

## Scope

In scope, for example:

- The accessibility service reading, storing or exposing more data than
  described in [docs/privacy.md](docs/privacy.md).
- Any way for another app to read OpenBlock's data or drive its service.
- A release that requests network access or other undocumented permissions.
- Bypassing a rule in a way that is not a documented limitation.

Out of scope: the documented limitations in
[docs/threat-model.md](docs/threat-model.md) (for example, that the device owner
can always turn the service off), and issues in third-party apps.
