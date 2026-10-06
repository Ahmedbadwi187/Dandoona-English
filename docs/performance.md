# Performance and size (measured 2026-10-06)

## App size (release, `flutter build apk --release --split-per-abi`)
| ABI | Size |
|---|---|
| arm64-v8a (most phones) | 24.7 MB |
| armeabi-v7a (older phones) | 22.4 MB |
| x86_64 | 26.2 MB |

About 5.6 MB is the bundled lessons (185 audio files, 26 illustrations, 29 SVGs). The audio is still the raw stereo 128 kbps
MP3 from ElevenLabs and the images are 1024 px WebP because ffmpeg is not installed on the dev machine: running the asset tool's
`export --force` with ffmpeg (mono, loudness-normalised, 768 px) should cut this noticeably. CI fails the build above 40 MB arm64.
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
