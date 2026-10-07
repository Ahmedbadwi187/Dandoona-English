# Performance and size (measured 2026-10-06)

## App size (release, `flutter build apk --release --split-per-abi`)
| ABI | Before ffmpeg export (2026-10-06) | After (2026-10-07) |
|---|---|---|
| arm64-v8a (most phones) | 24.7 MB | 21.6 MB |
| arm64-v8a, after units + Colors + certificate (2026-10-07) | | 27.1 MB (armeabi-v7a 24.8, x86_64 28.5; +2.4 MB of Colors lessons, the rest the share package) |
| armeabi-v7a (older phones) | 22.4 MB | 19.4 MB |
| x86_64 | 26.2 MB | 23.1 MB |

The bundled lessons are now 2.4 MB (were 5.5 MB): audio 4388 KB -> 2456 KB (185 files, mono MP3 64 kbps, loudness-normalised
to -16 LUFS, 44.1 kHz); images 1730 KB -> 570 KB (61 files, 768 px WebP q80). Re-encoded with ffmpeg through the asset tool's
`export --force`; hand-recorded `.override.mp3` files still win. CI fails the build above 40 MB arm64.
The Flutter engine and framework make up most of the rest.

## Permissions in the release manifest
`RECORD_AUDIO` and `INTERNET` only (checked with `apkanalyzer manifest permissions`).
Found and fixed during this check: the release manifest had no `INTERNET` (debug builds add it silently), which would have broken the
optional sync on real phones.

## Weak-device check (Android emulator, 2 CPU cores, software graphics, release build)
| Measure | Result |
|---|---|
| Cold start to first frame | 5.8 s, 6.4 s, 6.9 s (three runs) |
| Memory after scrolling the 26-letter map | 74 MB PSS (188 MB RSS) |
| Map, profile picker, forms | Rendered correctly; scrolled and tapped without errors |

Honest limits: this is an emulator with software rendering, a harsher environment than most low-end phones in some ways
(no GPU) and kinder in others (fast host storage), so treat the numbers as indicative. Per-frame timings (jank) could not be
captured: Android's frame counters do not see Flutter's surface. **Test on two or three real low-end phones before launch**
(for example 2 GB RAM, Android Go) and, if needed, profile with `flutter run --profile` and DevTools.

## Design choices that keep it light
- Lessons are bundled assets (no network, no downloads); images are SVG or compressed WebP; icons are tree-shaken (the
  Material icon font shrinks from 1.6 MB to 7 KB in release).
- One small audio player and one recorder; recordings are deleted immediately; no background services.
- Local storage is a few small JSON values (SharedPreferences).
