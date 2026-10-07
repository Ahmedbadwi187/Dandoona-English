# Handoff: where the project stands (read this first in a new session)

Kids' English app, "Little Learners" (ages 3-5). Child area is always English; the parent area is Arabic (RTL) or English.
Stack: ASP.NET Core 10 API (`src/`, EF Core + SQL Server, Identity + JWT), Flutter app (`mobile/kids_english_app`, Riverpod 3,
go_router, hand-written localisation), dev-only `tools/AssetGenerator` (ElevenLabs voice, OpenAI images, ffmpeg export).
Main character: **Dandoona (دندونة)**, the owner's own character.

## Standing rules (from the owner)
- No AI, ads, analytics or paid services inside the product. Free licenses only (SQL Server Express is the one accepted exception).
- Assets are bundled in the app. Keys live only in `.env` / user-secrets; never read or commit `.env`.
- Never mention AI in user-facing text. Do not change the app name.
- One commit per logical step. Ask only when blocked or when spend would pass the **$25 cap** (spent about $3.72). Show a cost
  estimate before generating audio (`dotnet run --project tools/AssetGenerator -- audio --track little-learners --dry-run`).
- `D:\Projects\Dandona` (the old character project) is read-only; never modify it or reference it at build time.
- "Don't start Numbers until I've tested Colors on a real phone."

## What is built (all committed on main)
- Units: Letters (A-Z), Colors (10 lessons); 8 units in `content/curriculum/units/little-learners.yaml` (the rest "coming soon"),
  placement table, certificates, unit map.
- First launch: splash -> language -> parent welcome (start without an account is the default) -> optional sign-up/log-in ->
  child setup (name+avatar, birth month+year, English level, daily goal, reminder, summary, greeting) -> unit map.
  Code: `lib/features/onboarding/` (`setup_flow.dart` holds the flow state and the finish logic).
- Later launches: one child opens that child's unit map; more than one opens "Who is playing?" (`router.dart`, `ActiveChildNotifier`).
- Child screens: "Who is playing?" in Dandoona's sky (`core/sky.dart`, drifting clouds, speech bubble with her voice, bouncing avatar +
  chime). Every other screen sits on the same sky in a quiet version (`SkyBackground(calm: true)` in `app.dart`; scaffolds are transparent).
- Parent area (`lib/features/parent/`): dashboard with per-child cards, child detail (Hear the words, practice at home, units with
  stars, certificates, history), Manage children, Edit child (save only when changed, discard question, delete with named confirmation).
  Shared styles in `parent_ui.dart`; data helper `parent_data.dart`.
- Reminders: local notification only (`features/reminders/`), permission asked only after the parent taps "Remind me".
- Avatars: Dandoona + 7 drawn friends; the old icon avatars map to characters with their own colors (`core/widgets.dart`).
- Server: sign-up needs guardian + terms confirmations (stored with time), optional first name, e-mail verification and password reset
  endpoints with a development e-mail sender that only logs, optional birth month.
- Dandoona's own voice lines: `app:` section in the units yaml (Who is playing?, hello greeting, Welcome back!), generated and exported.
- Docs: `privacy-data-map.md`, `store-compliance.md`, `licenses.md`, `onboarding-flow.md`, `units-proposal.md`.

## Tests (all green at the time of writing)
- Flutter: `cd mobile/kids_english_app && flutter test` (256). `flutter analyze` is clean.
- Generator: `cd tools && dotnet test AssetGenerator.slnx` (54). API integration tests: `dotnet test` at the repo root (30).
- Release build: `flutter build apk --release` (about 65 MB); merged permissions: RECORD_AUDIO, INTERNET, POST_NOTIFICATIONS,
  RECEIVE_BOOT_COMPLETED.

## How to run
- API: `dotnet run --project src/KidsEnglish.Api` (listens on 5080; the emulator reaches it at `http://10.0.2.2:5080`). Stop
  `KidsEnglish.Api.exe` before building the API or running EF migrations.
- App on the emulator: `flutter emulators --launch kids_phone`, then `flutter run -d emulator-5554 --debug`.
- Seed demo data: `scripts/seed-demo-data.sh` for a child who finished all levels.

## Gotchas learned the hard way
- The Bash tool breaks on apostrophes inside heredocs and on perl replacements with `$` or `\n` inside quotes: write files with the editor
  tool, or write a perl script file and run it.
- Widget tests: set a phone-size surface (`t.view.physicalSize = Size(1080, 2400)`, `devicePixelRatio = 1080/411`); a tall surface
  (4200) builds a long form fully; avoid it on the unit map (layout overflow). The test font is Ahem (very wide), so avoid fixed-width rows.
- `flutter_test_config.dart` turns the drifting clouds off (a repeating animation never lets tests settle).
- Never modify one provider from inside another provider's initialisation (the router redirect); that is why the single child is
  chosen in `ActiveChildNotifier.build`.
- FakeAudio records played paths as `asset:<path>`; `testOverrides` already installs fake audio-less defaults and `FakeReminders`
  (pass `reminders:` to inspect it); do not add a second override of the same provider.
- Every self-drawn SVG may use only palette.json colors (a generator test enforces it).
- `ffmpeg` is not on this PC's PATH, so `export` copies new audio unchanged; install ffmpeg and run `export --force` to optimise.

## What is left / ideas (nothing here is started)
1. Look at the new screens on a real phone and in both languages (screenshots), then polish.
2. One rounded font family for the parent area (needs a free font file, for example Nunito under OFL; ask the owner first).
3. Certificate screen: a separate "Save" button next to "Share" (today saving goes through the share sheet).
4. Real e-mail provider for verification and password reset (not chosen; only the logging sender exists). Show the parent's first name
   after log-in too (today it is stored at sign-up only).
5. Numbers unit and the rest, only after the owner has tested Colors on a real phone.
6. Release signing, privacy policy and terms final text, store listing (see the open items at the end of `store-compliance.md`).
7. Optional: play the "Welcome back!" line on later launches (it is generated and exported but not used).
