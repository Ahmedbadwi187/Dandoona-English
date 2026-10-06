# Branding: Dandoona (دندونة)

Dandoona is the app's main character, the owner's own original character from their YouTube channel. Her artwork was
copied into this repo; nothing references the channel's project folder at build time. The app name is unchanged.

| Piece | Where | Notes |
|---|---|---|
| Locked reference | `content/style/mascot.reference.webp` | Transparent 1024 px cut-out. `export` turns it into `assets/images/mascot/mascot.webp`, which praise, rewards, the wardrobe and parent onboarding all use. |
| Style / palette | `content/style/mascot.md`, `art-style.md`, `palette.json` | Brand colours: plum `#9B6BD3`, sunflower `#FFC93C`, night ink `#2E1F47`. The Flutter theme now seeds from plum. |
| Accessories | `content/art/accessories/*.svg` | Redrawn for her head and chest (night-ink outline). |
| App icon | `mobile/kids_english_app/icon/`, `flutter_launcher_icons.yaml` | Android adaptive icon with a separate foreground (transparent) and background colour (`#8FD3F4`); iOS 1024 px icon is opaque (no alpha) and all iOS sizes are generated. Regenerate: `dart run flutter_launcher_icons`. |
| Splash | `flutter_native_splash.yaml`, `lib/features/splash/dandoona_splash.dart` | Native static first frame (cream, Dandoona centered), then a 2.3 s Flutter animation: jump, wave, fade. The app builds underneath in parallel; a tap skips it. Regenerate the native part: `dart run flutter_native_splash:create`, then discard its edits to `ios/Runner/Info.plist`, `ios/Runner.xcodeproj/project.pbxproj` and `web/`. |
| Greeting | `assets/audio/brand/dandoona_hello_{ar,en}.mp3` | Her own voice from the channel ("I'm Dandoona!" / "أنا دندونة!", about 1.2 s), copied from the channel's branding audio. Played in the parent's language; silent when the phone is muted (iOS silent switch honoured, Android media volume). No other sound. |

Screenshots from the Android emulator: `docs/screenshots/android-launcher-icon.png`, `android-splash-sequence.png`.

The previous generated otter mascot is listed under "Replaced mascot" in `asset-decisions.md`.
