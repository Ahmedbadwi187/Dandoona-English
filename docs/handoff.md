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

## Button loading feedback - 9 Oct 2026
- Branch: `feature/button-loading-states` (based on `main`). This change adds pending feedback and rejects repeated presses;
  it preserves the app's wording, lessons, audio/image assets, API address, routes and existing button keys.
- Shared implementation: `mobile/kids_english_app/lib/core/loading_action.dart`. `LoadingAction` tracks the callback's returned
  `Future`, accepts an external `loading` state, and releases the action in `finally`, including failure and widget disposal.
  `LoadingContent` keeps a Material button's label/icon footprint and semantics; `LoadingOverlay`, `LoadingTap` and
  `LoadingInkWell` keep pictures/game feedback visible under a small progress badge. `BigTap`/`TapToHear` forward futures too.
- Reviewed press actions throughout Flutter: onboarding/language/auth/reminders/setup completion, parent save/delete/prompts,
  account sync/sign-out/delete, clipboard, certificate sharing, audio/replay/recording, game answers, profile selection,
  wardrobe/chests/stickers, map/download/stories and the session gate. The `site/` legal pages have no action buttons.
  Instant navigation/selection stays immediate; there is no artificial wait to show a spinner.
- When adding a button, use `LoadingCallback` through forwarding widgets and return/await the real operation. Do not use
  `VoidCallback` or `unawaited(...)` around work that the button should track. Keep `context.push(...)` navigation synchronous
  (its future lasts until the destination is popped). Audio stop remains available during playback; recording startup releases
  its loader before recording begins so the child can stop. Conditional Hear/Stop controls have separate loading keys.
- Dedicated regression tests: `loading_action_test.dart`, `onboarding_loading_test.dart`, `parent_loading_test.dart` and
  `child_action_loading_test.dart` under `mobile/kids_english_app/test/`; they cover delayed work, repeated presses, stable
  content/size, recovery, disposal, controller busy state and recording/answer responsiveness. Final validation is recorded
  after the complete Flutter suite finishes.
- The earlier `dist/dandoona-release.apk` predates this branch. Rebuild from this branch for a phone test of these loaders.

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

## Map v2, content packs and sync (merged into main; this is how they work)
- `feature/unit-map-v2`: unit map redesign (one Dandoona on the current island, progress ring, 78 dp play button, locked islands
  muted with a lock badge, "Soon" ribbon instead of the hourglass, own colors per unit, drifting clouds, castle at the end,
  sticky top bar with avatar / greeting / stars bounce / wardrobe dot / parent button behind the gate) and the path model
  (story, chest and review stations; `lib/features/units/map_path.dart`). Screenshots: `docs/design-options/unit-map-v2/`
  (render with `flutter test test_screenshots/map_preview_test.dart --update-goldens`). The owner approved the map; the stations are being built (see "Stations" below).
- `feature/content-packs-sync` (on top of the map branch):
  - Content packs: `delivery: pack` in the units yaml; `export` writes `packs/<track>/<unit>/v<version>/` + `index.json`,
    `content/packs.lock.json` keeps versions; the API serves `/packs` statically (`ContentPacks:Root`); the app downloads the
    current and next unit's pack, checks every sha256, caches it, plays it offline. Details: `docs/content-packs.md`.
  - Sync: new `ChildAchievements` table (migration `ChildAchievements`) for certificates, chests, reviews, stories,
    placement; the app sends them on every sync and reads progress + achievements back on sign-in, "Sync now" and the first
    background sync per app start (union, best result per lesson, earliest date).
  - Anonymous stats: `GET /api/admin/stats/lessons` with `X-Stats-Key` = `Stats:Key` (user-secrets); computed from synced
    summaries only, no ids, groups under 5 children hidden.
  - `docs/privacy-data-map.md` lists what is stored, where and for how long; one open decision (inactive accounts).

## Stations on the map (built after the merge)
- **Treasure chests** (one after every unit): tap to open; shake, sound, the outfit flies to Dandoona, "Got it!" with 3-4 stickers.
  Rewards are fixed per chest and planned for all 15 chests in `docs/chest-rewards.md`; the config is `chest:` per unit in the units
  yaml (validated against the unit's words). What a child owns is derived from opened chests (`features/rewards/chest_rewards.dart`).
  Outfits drawn so far: grad-cap, beret, top-hat, star-headband (Letters, Colors, Numbers, Shapes); preview them with
  `flutter test test_screenshots/accessories_preview_test.dart --update-goldens`. The other 11 are drawn when their unit is built.
- **Sticker Book** (top bar): stickers are the unit's own word pictures and voices; tap to hear the word.
- **Reviews** (after units 4, 8, 11) and the **castle**: a never-failing hear-and-tap game with two words per unit of its group
  (`features/units/review_screen.dart`); passing opens the next unit. The castle uses every unit.
- **Stories**: not built (no unit has one yet).
- **The whole course is built**: all 15 units of the map (76 lessons; Letters and Colors bundled, the other 13 are downloadable packs; an
  installed pack is checked once per run for a newer version). Every unit has its chest outfit drawn (15 outfits in `content/art/accessories`)
  and its stickers; 20 outfits in the wardrobe with the 5 star ones. Pictures: self-drawn SVG by `tools/art/make-*.mjs` (shapes, feelings, body,
  things), reused Letters pictures, Dandoona herself (poses + generated action pictures), and generated pictures picked with `approve`.
  Spent about $4.9 of $25 in all. `tools/art/make-lessons.mjs` writes the lesson files of the later units from one table.
- **Demo data**: `scripts/seed-demo-data.sh` (run it against a running API) gives `demo@dandoona.app` / `Demo!2026x` three children: Sara (Letters and
  Colors done), Adam (Letters A-M) and **Noor, who finished everything** (all lessons, certificates, chests, reviews and the castle): log in on a
  fresh app and pick Noor to see the whole map, the 60 stickers and all 20 outfits. In the emulator, type the password with `adb shell input text`
  (the keyboard drops the `!`).
- Sounds are synthesized by `tools/sounds/*.ps1` (cheer, chest-open); balloon and shape pictures by `tools/art/*.mjs`.

## Tests (all green at the time of writing)
- Flutter: `cd mobile/kids_english_app && flutter test` (309 at the time of writing). `flutter analyze` is clean.
- Generator: `cd tools && dotnet test AssetGenerator.slnx` (54 on main, 57 on the packs branch). API integration tests:
  `dotnet test` at the repo root (30 on main, 39 on the packs branch; they start SQL Server in Docker via Testcontainers).
- Release build: `flutter build apk --release` (about 65 MB); merged permissions: RECORD_AUDIO, INTERNET, POST_NOTIFICATIONS,
  RECEIVE_BOOT_COMPLETED.

## How to run
- API: `dotnet run --project src/KidsEnglish.Api` (listens on 5080; the emulator reaches it at `http://10.0.2.2:5080`). Stop
  `KidsEnglish.Api.exe` before building the API or running EF migrations.
- App on the emulator: `flutter emulators --launch kids_phone`, then `flutter run -d emulator-5554 --debug`.
- Seed demo data: `scripts/seed-demo-data.sh` for a child who finished all levels.

## Gotchas learned the hard way
- Cloud sessions: the proxy blocks dot.net, so .NET comes from Ubuntu (`apt-get install dotnet-sdk-10.0`, 10.0.1xx). `global.json`
  pins 10.0.401, so run `dotnet` from a folder outside the repo with absolute paths (do not edit global.json). Flutter: clone the
  stable branch (the revision in `.metadata`). `dotnet-ef`: `dotnet tool install --global dotnet-ef --version 10.0.12`.
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
5. Content ideas: a story for some units (the map has a Story stop; no unit has one yet), more lessons per unit, mini-games and coloring pages as
   extra chest rewards, a second track (Explorers 6-8). Install ffmpeg and run `export --force` to shrink the packs (about 1-2.6 MB each now).
6. Release signing, privacy policy and terms final text, store listing (see the open items at the end of `store-compliance.md`).
7. Optional: play the "Welcome back!" line on later launches (it is generated and exported but not used).

## The improvement plan (docs/improvement-plan.md): built after the course
Items 1-10 are built (11, the 6-8 track, is deliberately later). What a new session needs to know:
- **Games are data driven**: lesson yaml fields (`sound`, `home`, `lives`, `says`, `group`, `opposite`, `bins`, `odd`, `activities`) are exported to the
  catalog/packs; each activity has a widget in `lib/features/activities/` and a server code in `ActivityCodes`. To add a game: generator
  `ActivityNames` + validation, server enum + map + test, app widget + `activity_screen.dart` + `lesson_screen.dart` icon.
- `node tools/art/make-lessons.mjs <unit>` rewrites the later lessons; run `node tools/art/add-extras.mjs` after it (adds the extra games
  and groups), then `audio`, `export --track little-learners`, `cards`.
- **Voice**: all game instructions and the Actions "says" lines are generated. New games: add `narration.instructions.<activity>` (see `add-extras.mjs`), then `audio` and `export`.
- Smart review: `misses.v1` (phone only), orange Practice button on the map, parent's "Practice at home" list.
- Parent cards: `AssetGenerator cards` -> `cards/little_learners/*.html`, served at `/cards` by the API, link + copy in parent settings.
- Restart the API after pulling (new activity codes, /cards): `KidsEnglish.Api.exe --urls http://localhost:5080`.
- A few widget tests are timing-sensitive under load (a different one failed in two of five full runs, all passed when re-run alone).

## iOS TestFlight (no Mac): branch `ios-testflight`
`.github/workflows/ios-testflight.yml` builds on a GitHub macOS runner and uploads to TestFlight (run by hand from Actions). The owner's
steps (Apple account, Bundle ID, App Store Connect app, API key with Admin access, 4 GitHub secrets, merge the branch so the
"Run workflow" button shows) are in `docs/ios-testflight.md`. Without `API_BASE_URL` only Letters and Colors are playable.
Info.plist now says `ITSAppUsesNonExemptEncryption = false` (HTTPS only). Signing goes through the App Store Connect API
(`ios/ci/asc_signing.py`: a certificate + App Store profile per run, revoked/deleted at the end; `ios/ci/manual_signing.py`
switches the Runner target to manual signing on CI only). Push to the `testflight` branch to build and upload.
`.github/workflows/ios-ipa.yml` builds an unsigned .ipa for Sideloadly (built fine on macOS).

## Explorers (ages 6-8): Phase 0 and Phase 1 are built on branch `explorers` (not merged; Little Learners ships first from main)
Plan: `docs/explorers-plan.md` (sections 11-12 approved 2026-10-08). Built in a cloud session; **the owner still has to generate the
audio, listen to the phonemes and test on the emulator** (the cloud session had no API keys, no emulator and no running API).

What is built (each part its own commit on `explorers`):
- **Catalog per track**: `content/curriculum/units/explorers.yaml`; `export --track explorers` -> `assets/content/explorers.json`.
  Letters is borrowed (`from: little-learners`: same lessons, files and progress); the generator never writes the other track's files.
  App: `contentProvider` is still Little Learners (unchanged); the child area reads `activeContentProvider` (the active child's
  track), the parent area `trackContentProvider(child.track)`.
- **New children**: track from birth month + year (5y11m = Little Learners); the month was already required on the age screen;
  placement by track (`placement` in explorers.yaml); summary shows track + start (track row opens a track choice); Edit child:
  Explorers selectable + "Starting point". Year-only children: the parent is asked once for the month (`asks.v1`).
- **Existing children**: Explorers offered in the parent area at 6 or after the Little Learners castle; never automatic;
  certificates, chests, outfits and progress stay (an Explorers child's chest inventory is Little Learners + Explorers).
- **Hand demo** (`features/activities/hand_demo.dart`): the first time a child meets a game, a hand does each move once while the
  game's instruction plays; "?" replays it (`demos.v1`). **Active days** (`features/progress/active_days.dart`): cumulative, never
  reset, milestones celebrated once (`activeDays.v1`); badge on the Explorers map only.
- **Sound Builders**: 5 lessons (`content/curriculum/sound-builders-{a,e,i,o,u}.yaml`), 20 everyday words, games Sound Tap, Word
  Builder (tap or drag), Read & Pick (`features/activities/phonics_activities.dart`), chest `explorer-hat`, a 5-page decodable story.
  Phoneme table `phonemes:` in explorers.yaml, words carry `graphemes`. 10 new pictures self-drawn (`content/art/explorers`), 10
  reused from Little Learners (`reuse: little-learners:lesson/key`). Server codes sound-tap, word-builder, read-and-pick (no migration).
- **Explorers map look**: deeper colors and sky (`MapLook` in `unit_style.dart`); Little Learners renders exactly as on main.
- Screenshots: `docs/design-options/explorers/sheet.png` (`flutter test test_screenshots/explorers_preview_test.dart --update-goldens`).

**Phase 2 on branch `explorers-phase-2`** (made from `explorers`; not merged):
- **Digraphs** (sh, ch, th, ck), **Blends** (l-, r-, end), **Magic E** (a, i, o/u), **Vowel Teams** (ai, ee, oa, oo/ar): 14 lessons
  (`content/curriculum/{digraphs,blends,magic-e,vowel-teams}-*.yaml`), 56 everyday words, same three games. 29 new self-drawn
  pictures (`content/art/explorers/<lesson>/`), 27 reused from Little Learners. All four units are packs.
- A word part can borrow another sound or be silent: `"ck:c"`, `"a:ay"`, `"e:-"` (generator checks the key against the table and
  the letters against the word; the app shows the letters, plays the sound, shows a silent letter quieter, and Word Builder never
  offers two tiles that look the same). 14 new phonemes (32 in all).
- Each unit: a chest with a new outfit (`headphones`, `bandana`, `wizard-hat`, `team-cap` in `content/art/accessories`) and a
  5-page decodable story. Two review stops on the Explorers map: after Blends and after Vowel Teams.
- Screenshots: `docs/design-options/explorers/phase-2/` (`flutter test test_screenshots/explorers_phase2_test.dart --update-goldens`;
  run one test at a time with `--plain-name` if a run stalls: a picture read from a file can stall the test clock).
- **Grammar early, by pictures only**: plural -s in Sound Builders (`plural: cats`; Read & Pick ends with "cats": two pictures
  right, one wrong, "One cat. Two cats!"), "a"/"an" shown before every word in Read & Pick (from its first sound). ant and egg
  replaced bag and pen so "an" appears. is/are is planned for My Sentences; Grammar Starters reviews these (notes in explorers.yaml).
- Look at: "five" and "nine" reuse the Little Learners counting pictures (balloons), so in Read & Pick the child counts; "kick",
  "math" and "path" are the hardest new drawings to read at a glance.

**Phase 3 on branch `explorers-phase-3`** (made from `explorers-phase-2`; not merged):
- **Sight Words 1 and 2** (6 lessons, 24 sight words: I, see, the, my / is, it, in, on / we, can, go, and / you, look, here, to /
  he, she, was, said / like, have, they, are) and **My Sentences** (is/are, a/an, both mixed): 9 lessons, 41 sentences.
- Lesson files can now list `sightWords` (said aloud, no picture) and `sentences` (`text`, `picture` = one of the lesson's
  words, `two: true` shows it twice, optional `gap` + `choices`). Every sentence uses only sight words taught so far and words the
  child can sound out (a generator test checks this).
- New games (`features/activities/sentence_activities.dart`, server codes 21-23): **Find the Word** (hear a sight word, tap it),
  **Sentence Builder** (put the word cards in order, tap or drag), **Fill the Gap** (read, pick the missing word; one picture
  means "is", two mean "are"). Hand demo + instruction like the other Explorers games.
- No new pictures: every sentence picture is reused. Outfits `book-hat`, `detective-cap`, `pencil-band`; a 5-page story per unit;
  review 3 after My Sentences. Screenshots: `docs/design-options/explorers/phase-3/`.

**To do on the owner's PC (in this order):**
1. `dotnet run --project tools/AssetGenerator -- audio --track explorers --dry-run` (estimate with Phases 2 and 3: 9,134 characters, about
   **$0.73** (Phase 1 alone: 2,388, $0.19; Phase 3 adds about 2,580, $0.21);
   check the remaining ElevenLabs credits first), then without `--dry-run`, then `export --track explorers`. Until then the Sound
   Builders and Phase 2 lessons stay out of the catalog (their islands show "Soon") and the Explorers unit names have no voice.
   `export` then writes the Phase 2 and 3 packs (7 units) to `packs/explorers/`; publish them as for Little Learners (`docs/content-packs.md`).
2. Listen to every phoneme: `docs/explorers-phonemes.md` (32 sounds; fix `say` or record overrides).
3. Run the app on the emulator with an Explorers child (6-8, or accept the offer for a Little Learner) and look at the games.
Spend: **about $5.51 of $50** (nothing was spent in the cloud sessions; Phases 1-3 add about $0.73 of audio when generated; no images).
Tests on `explorers`: Flutter 415, generator 98, application 36. On `explorers-phase-2`: Flutter 424, generator 103, application 36. On `explorers-phase-3`: Flutter 429, generator 112, application 36
(API integration tests need Docker + SQL Server; not run there).

## Explorers: Phase 4 and 5 are built (on main) - state after the owner's first phone test
All 13 Explorers units now have lessons (85 lessons, 24 packs in total with Little Learners): Letters (borrowed), Sound Builders, Digraphs,
Blends, Magic E, Vowel Teams, Sight Words 1-2, My Sentences, **Word Families** (6 families, 19 words, Spell It game), **Everyday English**
(school, weather, town, meals, play; sentences with a gap), **Numbers & Time** (11-20, tens to 100, days, months, o'clock; pictures drawn
by arithmetic, `noArticle` lessons) and **Grammar Starters** (a/an, is/are, has/have, can by picture). Each new unit has a chest outfit
(`rainbow-band`, `sun-visor`, `clock-cap`, `quill-hat`), a 5-page story and review-4 sits before the castle. Parent cards for Explorers:
`AssetGenerator cards --track explorers` (content/parent/tips-explorers.yaml); `/cards` lists both tracks.
- Art scripts (re-runnable): `tools/art/make-families.mjs`, `make-family-lessons.mjs`, `make-numbers-time.mjs`, `make-numbers-time-lessons.mjs`,
  `make-everyday.mjs`, `make-everyday-lessons.mjs`, `make-grammar-lessons.mjs`. A word can carry `say:` (what the voice reads, used for "kite" -> "kyte").
- Spend: about $6.90 of the $50 cap (ElevenLabs $3.74, OpenAI $3.16). Phonemes to listen to: `docs/explorers-phonemes.md` (33 sounds now: `w` added).
- **Hosting**: the API is at https://eyadahmed1192-001-site1.jtempurl.com (SmarterASP). The app downloads the packs from `/packs`, so the
  `packs` and `cards` folders must be uploaded next to the API files: run `scripts/prepare-host-content.ps1` and upload `dist/host-content/packs`
  and `.../cards` by FTP after every content change (a pack version never changes once published). Without them the units after Letters/Colors
  show "Almost ready". The database migrations are applied (`dotnet ef database update ... --connection`, the design-time factory has a fixed local
  connection) and the hosted API runs them at start-up too (`Database:MigrateOnStartup` in appsettings.Production.json).
- APKs: `dist/dandoona-host.apk` (release, API_BASE_URL = the host above); for the emulator use the debug build (10.0.2.2:5080) with the local API.
- **Little Learners only release**: build with `--dart-define=ENABLE_EXPLORERS=false` (see docs/explorers-progress.md section 9).
- **Integration tests without Docker**: `$env:KIDS_TEST_SQL = "Server=(localdb)MSSQLLocalDB;Database=KidsEnglishIntegrationTests;Trusted_Connection=True;TrustServerCertificate=True"; dotnet test tests/KidsEnglish.Api.IntegrationTests` (that database is dropped and recreated: never point it at the hosted one). Stop `KidsEnglish.Api.exe` first. Their settings come from tests/KidsEnglish.Api.IntegrationTests/appsettings.Testing.json.
- True or False and Sight Word Hunt exist (`features/activities/reading_games.dart`); `node tools/art/add-reading-games.mjs` adds them (with instructions) to the lessons.
- **Publishing the API now carries its content**: `src/KidsEnglish.Api/publish-content.targets` runs `scripts/prepare-host-content.ps1` before a publish and adds `packs/` (the newest version of every pack, about 50 MB) and `cards/` to the published files, so one Visual Studio or `dotnet publish` upload sends the API and what it serves. (The output of the script is `dist/host-content`.) No separate FTP upload of the two folders is needed any more.
- Explorers packs are downloaded from `/packs/explorers` (the pack repository is per track, `explorersPackRepositoryProvider`); the Explorers catalog merges its installed packs like the Little Learners one.

## Forgot password (10 Oct 2026, branch `feature/forgot-password`)
- The API already had `POST /api/auth/forgot-password` and `/reset-password`; what was missing was real e-mail and the screens.
- **E-mail** is configured in appsettings, section `Email` (`Host`, `Port` 587, `EnableSsl`, `UserName`, `Password`, `FromAddress`, `FromName`). With `Host` filled the API sends through that SMTP server (`SmtpEmailSender`); with it empty it only writes the message to the log (what development does). Put the real values in the host's `appsettings.json` / environment variables (`Email__Host`...), never in the repo. The committed `appsettings.Production.json` only has the empty section.
- **The reset code is 6 digits** (Identity's e-mail token provider, valid for a few minutes), easy to type on a phone. It works once; resetting signs every device out.
- **The app**: log-in form has "Forgot your password?" -> e-mail -> code + new password (min 8) -> back to log-in with a message. Route `/forgot-password` (the address travels in `extra`, not in the URL). Tests: `forgot_password_test.dart`; the integration test now also checks the code is 6 digits.
- Tried end to end on the emulator against the local API: code read from the log, new password set, old one rejected, new one accepted. The SMTP sender itself has not been run against a real mail server yet (needs the owner's SMTP account).

## Skills, tracks and automatic sync (10 Oct 2026, branch `feature/skills-and-tracks`)
- **The skills list replaces the single-choice level.** Rules are data: `mobile/kids_english_app/assets/content/skills.json` (groups, implied skills, the two
  exclusive answers, age boundaries, the track-up rule, skill -> units per track). Code: `lib/features/skills/skills.dart` (pure functions: `toggleSkill`,
  `suggestTrack`, `placementFor`, `placedAfterEdit`, `convertOldChildren`), `skills_checklist.dart` (the screen list), `skip_ahead.dart`.
  `test/skills_test.dart` checks every unit and skill the file names exists; boundaries 5/6, implied/exclusive, per-track start, old-level conversion.
- Track = age (3-5 Little Learners, 6-8 Explorers, older children Explorers) moved UP by skills only. The summary shows the reason and the start unit with the
  number of units skipped; there is no track box on the age screen. Word skills (colors, counting, animals, everyday words) only cover Little Learners units.
- **Edit child**: skills section with a preview ("X and Y will be marked done, Z will continue from W"), tracks section (progress per track, Active badge,
  confirmation when switching, Champions "Soon"), Save pinned at the bottom. Editing skills never removes real progress (`placedAfterEdit`).
- **Existing children** (skills == null) get skills from the units their old answer counted as done (`convertOldChildren`, run once at start, the track and the
  `updatedAt` are kept). Children of 6+ in Little Learners still get the Explorers offer (never automatic).
- **Skip ahead**: only for "I'm not sure"; a review passed with 3 stars suggests the first unplayed, unplaced unit after it, once per unit, off after two refusals
  in a row, switch back on in Edit child. Phone only (`skipahead.v1`).
- **Per-track progress** is natural (lesson ids differ per track; Letters is shared). `childTracksProvider` feeds the child's page and the dashboard.
- **Sync is automatic** (`lib/features/sync/auto_sync.dart`): start, resume, connectivity back (connectivity_plus), 4 s after a change (burst = one sync), every
  5 min, retry with backoff 30 s .. 15 min; no account = nothing. The settings section has no Sync button, only the status line. Profile fields, skills, goal and
  track sync with the newest change winning; progress is the union (best per lesson), rewards the union. Server: nullable columns + migration
  `ChildSkillsGoalAndProfileTime`, see `docs/deployment.md` (back up, apply, roll back). Tests: `auto_sync_test.dart`, `ChildProfileSyncTests`.
- **Loaders only on real buttons**: `BigTap`, `LoadingTap`, `LoadingInkWell`, the hand-demo `?` run their handler at once with no spinner and no blocking.
- **Forgot password**: see the section above (SMTP in appsettings).
- Dev helpers: `tools/adb-ui.mjs` (drive the emulator by labels), `tools/onboard-demo.sh`, `tools/seed-device-progress.mjs`.
- Audio review for Explorers: `uv run tools/verify-audio/verify_explorers.py`, `verify_phonemes.py`, then `node tools/verify-audio/make_review_page.mjs` ->
  `content/generated/explorers-audio-review.html`. Asset completeness for both tracks: `test/assets_complete_test.dart`.
- **Known limits**: a skill unchecked in Edit child removes the local "done by placement" marks on unplayed units, but the server keeps the union of
  placement marks it already has (it comes back at the next pull). The SMTP sender has not been run against a real mail server. Champions (9-12) is not built.
