# Release process

Releases are built and published by GitHub Actions
(`.github/workflows/release.yml`) when a `v*` tag is pushed.

## One-time setup: signing key

Android only installs updates signed with the same key, so all releases must
use one project key. **Keep a backup of the keystore and its passwords** — if
the key is lost, users will have to uninstall and reinstall to update.

1. Create a keystore (once):

   ```sh
   keytool -genkeypair -v -keystore openblock-release.jks \
     -alias openblock -keyalg RSA -keysize 4096 -validity 10000
   ```

2. Add these repository secrets (Settings › Secrets and variables › Actions):

   | Secret | Value |
   |---|---|
   | `OPENBLOCK_KEYSTORE_BASE64` | `base64 -w0 openblock-release.jks` |
   | `OPENBLOCK_KEYSTORE_PASSWORD` | keystore password |
   | `OPENBLOCK_KEY_ALIAS` | `openblock` |
   | `OPENBLOCK_KEY_PASSWORD` | key password |

   With the GitHub CLI: `gh secret set OPENBLOCK_KEYSTORE_BASE64 < <(base64 -w0 openblock-release.jks)`.

3. For local release builds, create `android/key.properties` (git-ignored):

   ```properties
   storeFile=/absolute/path/openblock-release.jks
   storePassword=…
   keyAlias=openblock
   keyPassword=…
   ```

Without `key.properties` or the environment variables, local release builds
are signed with the debug key. The release workflow refuses to publish an APK
signed with a debug key.

## Cutting a release

1. Make sure `main` is green in CI (including the emulator e2e job).
2. Update `version:` in `pubspec.yaml` (for example `0.2.0+2` — the build number
   must increase for every release) and `appVersion` in `lib/app/version.dart`.
3. Move the *Unreleased* notes in `CHANGELOG.md` to a new `## [0.2.0] - date`
   section and update the links at the bottom.
4. Commit, then tag and push:

   ```sh
   git tag -a v0.2.0 -m "OpenBlock 0.2.0"
   git push origin main v0.2.0
   ```

5. The workflow checks that the tag matches `pubspec.yaml`, runs the tests,
   builds a universal APK and per-ABI APKs, verifies the permissions and the
   signature, and publishes the GitHub release with the changelog section,
   `SHA256SUMS.txt` and the signing certificate fingerprint.

Versions `0.x` are published as pre-releases.

## Verifying a download

```sh
sha256sum -c SHA256SUMS.txt --ignore-missing
apksigner verify --print-certs openblock-0.1.0-universal.apk
```

The certificate SHA-256 must match the one in the release notes.
