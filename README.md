# OpenBlock

**Take back your attention.**

OpenBlock is an open-source, privacy-first Android app that helps you break
infinite scrolling and regain control of your attention. Block an app at
certain hours, set daily limits, add a short pause before opening an app, or —
where supported — block only a feed such as YouTube Shorts while keeping the
rest of the app usable.

No account. No server. No ads. No tracking. The app does not even request
network access.

> **Status: 0.1.0 pre-release (MVP).** App blocking, limits, pause screens and
> focus sessions work and are tested end-to-end on the Android emulator in CI.
> Feed blocking (Shorts/Reels) is **experimental** and has not been verified on
> real devices yet. See [Limitations](#limitations).

[Português](#em-português) · [Download](https://github.com/Gabriel-Richard-dev/OpenBlocker/releases) · [Docs](docs/)

## Features

| Feature | Description |
|---|---|
| Block app | Blocks the whole app on a schedule (weekdays and time window, overnight windows supported) or only during focus sessions. |
| Daily limit | Blocks the app once today's usage, **measured by Android**, reaches your limit. |
| Block feed | Blocks only a feed inside an app — YouTube Shorts and Instagram Reels for now (experimental). |
| Pause screen | Shows a short countdown before you can continue into an app. |
| Exceptions | Allows an app at specific times, overriding other rules. |
| Focus sessions | 25/45/60 minutes or custom; the rules you pick stay active until the timer ends. Survives restarts and reboots. |
| Presets | Study Mode, No Shorts, Social Media Limit, Deep Focus and Custom. |
| Statistics | Interventions per day, focus time, completed sessions and measured usage — all stored on the device. |
| Your data | Export/import as JSON, delete statistics or everything. |

When a rule triggers, OpenBlock shows a calm, full-screen intervention:

> You opened this feed during your focus session.
>
> Want to go back to what you were doing?

You can go back, snooze the rule for a few minutes or end the focus session.
OpenBlock never hides the system settings or locks you out of your own device.

The UI is available in English and Brazilian Portuguese.

## Install

1. Download `openblock-<version>-universal.apk` (or the APK for your CPU, usually
   `arm64-v8a`) from the [releases page](https://github.com/Gabriel-Richard-dev/OpenBlocker/releases)
   and check it against `SHA256SUMS.txt`.
2. Install it (allow installing from your browser or file manager when asked).
3. Open OpenBlock and follow the introduction.
4. Turn on **Settings › Accessibility › OpenBlock**.
   On Android 13+, if the switch is greyed out, open
   **Settings › Apps › OpenBlock › ⋮ › Allow restricted settings** first.
5. For daily limits and usage statistics, grant
   **Settings › Apps › Special app access › Usage access › OpenBlock**.

Requires Android 8.0 (API 26) or newer.

## Permissions

| Permission | Why | Required for |
|---|---|---|
| Accessibility service | Notice which app is on screen and draw the pause/block screen. For feed rules, check whether views with known ids are visible. | Every rule |
| Usage access | Read measured minutes per app today. | Daily limits, usage statistics |

OpenBlock does **not** use "Display over other apps", `QUERY_ALL_PACKAGES` or
the Internet permission. CI fails the build if a release APK requests any of
them. Details: [docs/permissions.md](docs/permissions.md) and
[docs/privacy.md](docs/privacy.md).

## Limitations

- **Feed blocking is app-specific and fragile.** Adapters recognise the feed by
  view ids of the current app version. An app update can break detection; when
  that happens the rest of the app keeps working and the feed is simply not
  blocked. See [docs/supported-apps.md](docs/supported-apps.md).
- **Not yet verified on real devices.** So far OpenBlock has been tested on the
  Android emulator in CI. Reports from real devices are very welcome — see
  [docs/tested-devices.md](docs/tested-devices.md).
- **You can always turn it off.** OpenBlock is a tool for your own intentions,
  not parental control: anyone with access to the device settings can disable
  the service. See [docs/threat-model.md](docs/threat-model.md).
- **Usage data can lag** a few minutes behind, because it comes from Android.
- **Android only** for now. An iOS version is planned with app/category limits
  through Apple's Screen Time APIs; blocking a single feed inside another app is
  not possible there.
- Some manufacturers aggressively stop background services; the app tells you
  when the service is enabled but not running.

## Build from source

Requirements: Flutter 3.41 (stable), JDK 17, Android SDK.

```sh
git clone https://github.com/Gabriel-Richard-dev/OpenBlocker.git
cd OpenBlocker
flutter pub get
flutter test                       # Dart unit and widget tests
flutter run                        # on a connected device or emulator
flutter build apk --release        # debug-signed unless signing is configured
cd android && ./gradlew :app:testDebugUnitTest   # Kotlin unit tests
```

See [docs/contributing.md](docs/contributing.md) for the development guide and
[docs/release.md](docs/release.md) for signing and releases.

## Documentation

- [Architecture](docs/architecture.md) — layers, method channel contract, data flow
- [Rule precedence](docs/rule-precedence.md)
- [Permissions](docs/permissions.md) and Google Play policy notes
- [Privacy](docs/privacy.md)
- [Supported apps](docs/supported-apps.md) and the [YouTube Shorts adapter](docs/adapters/youtube-shorts.md)
- [Adapter review process](docs/adapter-review.md)
- [Threat model](docs/threat-model.md)
- [Tested devices](docs/tested-devices.md)
- [Contributing](CONTRIBUTING.md) · [Code of conduct](CODE_OF_CONDUCT.md) · [Security](SECURITY.md)
- [Product specification](SPECS.md)

## Em português

O OpenBlock é um app Android de código aberto e com privacidade em primeiro
lugar que ajuda você a interromper a rolagem infinita. Você pode bloquear apps
em horários definidos, criar limites diários, mostrar uma pausa antes de abrir
um app ou — onde houver suporte — bloquear só um feed, como o YouTube Shorts,
mantendo o resto do app utilizável. Também há sessões de foco, presets e
estatísticas locais.

Sem conta, sem servidor, sem anúncios e sem rastreamento: o app nem pede acesso
à Internet. A interface está em português e inglês.

**Instalação:** baixe o APK na
[página de releases](https://github.com/Gabriel-Richard-dev/OpenBlocker/releases),
instale, ative **Configurações › Acessibilidade › OpenBlock** (no Android 13+,
se o botão estiver desativado, abra **Configurações › Apps › OpenBlock › ⋮ ›
Permitir configurações restritas**) e, para limites diários, conceda o
**Acesso ao uso**.

**Limitações:** o bloqueio de feeds é experimental e ainda não foi verificado
em dispositivos reais; até agora os testes foram feitos no emulador Android no
CI. Você sempre pode desligar o serviço nas configurações do Android.

## License

[MIT](LICENSE) © 2026 Gabriel Richard and OpenBlock contributors.
