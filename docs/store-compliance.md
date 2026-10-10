# Store compliance review (Google Play Families, Apple Kids Category)

Status of each requirement for the app: **two released tracks, Little Learners (ages 3-5) and Explorers (ages 6-8)**, with the evidence. "Owner action" items need something
that only the account owner can do (publishing accounts, hosting pages, store-console forms). This is an engineering
review, not legal advice: have the privacy policy checked for the markets you ship to (COPPA in the US, GDPR-K in the EU,
and the privacy laws of the Arab countries you target).

## What the shipped app contains (verified on the 2026-10-06 release build)
- **Android release APK:** arm64 21.6 MB, armeabi-v7a 19.4 MB, x86_64 23.1 MB (`flutter build apk --release --split-per-abi`).
  Budget enforced in `azure-pipelines.yml`: arm64 <= 40 MB. About 2.4 MB of that is the bundled lessons (mono,
  loudness-normalised audio and 768 px WebP, re-encoded with ffmpeg).
- **Permissions in the final manifest:** `RECORD_AUDIO` (record-and-listen only, requested on first use), `INTERNET`, `POST_NOTIFICATIONS` (asked only after the parent taps "Remind me") and `RECEIVE_BOOT_COMPLETED` (the daily reminder survives a restart)
  (optional parent sync only). Nothing else: no advertising ID (`AD_ID`), no location, contacts, camera, storage or phone state.
  Re-check after any dependency change: `apkanalyzer manifest permissions app-arm64-v8a-release.apk`.
- **SDKs / libraries:** only Flutter, Riverpod, go_router, flutter_svg, shared_preferences, audioplayers, record,
  path_provider, http, crypto and flutter_secure_storage (all MIT/BSD-3, see `licenses.md`). No ad network, no analytics or
  crash-reporting SDK, no social login, no cloud AI. AI tools are used only offline by the developer to produce static files.
- **Network:** none unless a parent signs in under Settings > Account & sync. Release builds require https (cleartext is
  allowed only in the debug manifest, for the emulator).

## Google Play - Families Policy
| Requirement | Status | Evidence / action |
|---|---|---|
| Target audience includes children; choose the right age bands in Play Console | **Owner action (new)** | In Play Console > App content > Target audience, tick **5 and under** and **6-8** (not 9-12: Champions is not built). Enrol in the Designed for Families program. Then answer the questionnaire again: the app targets children and parents, no ads, no social features. |
| No ads, or only Families-certified ad SDKs | Done | No ad SDK present. |
| No personal data collected from children without parental consent; no persistent identifiers | Done | Child profile = nickname, avatar, birth year, stored locally. No advertising ID, no analytics. |
| Parental gate before anything leaving the child experience | Done | Press-and-hold + multiplication before the parent area, settings, and the session time-up override. The child area has no external links, purchases or ads. |
| Only age-appropriate content | Done | Self-drawn and generated illustrations reviewed by hand; no text in images; audio is the developer's reviewed script. |
| Permissions only as needed, with explanation | Done | Microphone prompted on first use of record-and-listen; iOS usage string written. The activity works without it (skip, 1 star). |
| Data safety form | **Owner action (update)** | Local-only mode: "No data collected". With an account: email address (account and password reset), child nickname, birth **month and year**, daily goal, the skills the parent ticked (a list of ids), the active track, app activity (progress) - collected, linked to the parent account, encrypted in transit, **deletion available** (see below). Add "app info and performance" only if you add crash reporting (there is none). Purpose for all of it: app functionality and account management; not shared, not used for ads or analytics. |
| Deleting a child's data | Done | Deleting a child profile in the app also hard-deletes the child and all progress on the server (queued and retried if offline). Integration-tested (rows physically removed, sibling untouched) and verified against the live API. |
| Account deletion in-app + a web link | Partly | In-app deletion with password confirmation is built and tested (Settings > Account & sync > Delete account & data; `POST /api/account/delete`). **Owner action:** a draft page exists (`site/delete-account.html`, English + Arabic): have it reviewed, host it over HTTPS and paste its URL in Play Console. |
| Privacy policy URL | Owner action | Required for the store listing. A draft exists (`site/privacy-policy.html`, English + Arabic, covering PDPL, Families Policy and Kids Category): have a lawyer review it, fill the placeholders, host it over HTTPS. |
| Target API level | Done | Flutter's default `targetSdk` (36 at the time of build); keep up to date with Play's yearly requirement. |

## Apple - Kids Category (App Store Review 1.3, 5.1.4)
| Requirement | Status | Evidence / action |
|---|---|---|
| Pick an age band (5 and under / 6-8 / 9-11) | **Owner action (decision)** | **Keep the Kids Category band at "Ages 5 & Under"**: Little Learners is the Kids Category app; Explorers (6-8) is in the same app, available to a parent who chooses it. Apple lets the band be 5 & Under while the app's age rating stays 4+. If you ever want the 6-8 band, the whole app must meet the Kids Category rules for it (it already does: no ads, no analytics, parental gate). |
| No third-party advertising or analytics | Done | None included. |
| Parental gate before links out, purchases, or permission prompts for personal data | Done | Gate in front of the parent area; the app has no links out and no in-app purchases. |
| Privacy "nutrition label" | **Owner action (update)** | Local-only: "Data Not Collected". With an account: Contact Info (email address), Identifiers: none, User Content / Usage Data (progress, the child's nickname, birth month and year, daily goal and the skills list the parent ticked) linked to the user, **not used for tracking**. Update App Privacy in App Store Connect to match. |
| Microphone usage description | Done | `NSMicrophoneUsageDescription` explains on-device record/play-back and immediate deletion. |
| Account deletion in the app (5.1.1(v)) | Done | Same in-app flow as Android. |
| An iOS build | **Not verified** | The `ios/` runner exists but this was developed on Windows: it has never been built or run. Needs a Mac (or a cloud Mac build) before submission. |
| Notes for App Review | Owner action | Explain the offline design, the parental gate (hold + math), and that the account is optional. |

## Children's data handling (COPPA / GDPR-K posture)
- Children never create accounts or enter personal data; only a parent can. The parent account is optional.
- Collected locally: nickname (not a full name, validated), avatar key, birth **year**, track, lesson progress, settings.
  Nothing is sent anywhere unless the parent signs in and taps sync.
- Voice: recorded to a temp file, played back immediately, deleted right after (and on leaving the screen). Never uploaded,
  never scored, no speech recognition. Covered by tests (`record_listen` deletes every created file).
- Server (optional sync): stores the parent email + password hash, children (nickname, avatar, birth year, track) and progress
  records. Parent can delete everything in-app; a single child can be deleted at any time (hard delete of the profile and all its progress, queued if the device is offline); the deletion cascades to children, progress and tokens (integration-tested).
  Logs contain request metadata only, never bodies, passwords, tokens or audio.

## Security review (backend + app)
| Area | State |
|---|---|
| Passwords | ASP.NET Identity hashing; min length 8; lockout after 5 failures for 15 min. Never stored on the device. |
| Sessions | 15-min JWT; refresh tokens are random, stored hashed, **single-use (rotating) with reuse detection** (reuse revokes all of the parent's tokens). App keeps the refresh token in the platform keystore (flutter_secure_storage). |
| Authorization | Every child/progress/summary endpoint checks ownership; another parent gets 404 (integration-tested). |
| Abuse | Per-IP rate limit on auth endpoints (configurable); batch size cap (200) and field limits on progress uploads; idempotent by client record id. |
| Transport | https required in release; Android blocks cleartext by default. HSTS/TLS termination is a deployment task. |
| Secrets | JWT key and DB connection string live in user-secrets/Key Vault/environment, never in the repo (`appsettings.json` is empty for both). Rotate the JWT key if it was ever shared. |
| Dependencies | Only MIT/Apache/BSD/PostgreSQL-licensed libraries except the documented SQL Server exceptions (`licenses.md`). |

## What you must do yourself in the store consoles (checklist, 10 Oct 2026)

**Google Play Console**
1. App content > **Target audience and content**: add the age group **6-8** (keep 5 and under). Do not tick 9-12.
2. App content > **Data safety**: update as in the table above (email, child profile with birth month and year, goal, skills ticked, active track, progress; none shared; encrypted in transit; deletion in the app and on the web page).
3. App content > **Privacy policy**: paste the URL of the hosted `site/privacy-policy.html` (now says ages 3 to 8, the skills list, the password-reset e-mail). Have a lawyer read it first.
4. Store listing: paste the descriptions from `docs/store-listing.md` (Arabic and English).
5. Families Policy: re-check "Designed for Families" after the age change; no ads, no analytics: nothing else to declare.

**Apple App Store Connect**
1. **Kids Category age band: keep "Ages 5 & Under".** Do not change it to 6-8.
2. **App Privacy**: update the nutrition label as in the table above.
3. Privacy policy URL and the account-deletion page URL (same pages as Android).
4. App description and keywords: from `docs/store-listing.md`.
5. Notes for App Review: explain the offline design, the parental gate (hold + math), that the account is optional, and that Explorers content downloads from our server on first use (no purchases).

**Both**
- Host `site/` over HTTPS and use the same URLs.
- The password-reset e-mail needs a real SMTP account in the host's `appsettings` (`Email` section, see `docs/deployment.md`); without it the reset code is only written to the server log.
- Apply the database migration `ChildSkillsGoalAndProfileTime` **before** uploading the new API (`docs/deployment.md`).

## Open items before publishing (not engineering)
1. Host the privacy policy and the account/data-deletion page; add both URLs to the store listings.
2. Fill in Data safety / nutrition labels as above; choose age bands.
3. Build and test on iOS (needs a Mac). Test on a few real low-end Android phones.
4. Decide the production hosting for the API (https, SQL Server licensing beyond Express limits, backups, monitoring).
5. Listen to the phoneme clips and sound-out intros flagged in `asset-decisions.md`; record your own where TTS is wrong.

## Unit certificate (added with units)
- The certificate (child's nickname, unit name, date, Dandoona) is drawn on the device and turned into a PNG there; no service is involved.
- Saving or sharing sits behind the parental gate and uses the system share sheet (`share_plus`): no storage permission, no new Android
  permission (release manifest still has only `RECORD_AUDIO` and `INTERNET`), and the app never sends the picture anywhere itself.
- The picture contains the nickname the parent chose; the parent decides where it goes. Mention this in the privacy policy text before publishing.

## First-launch flow, reminders and the parent redesign (added later)

- The account is optional: "Start without an account" is the default. Sign-up needs two confirmations (parent or guardian aged 18+, and the
  privacy policy and terms, both linked), stored with a time on the server. E-mail verification and password reset use a development
  sender that only logs until a provider is chosen.
- The reminder is a local notification (`flutter_local_notifications`): no push service, no third-party SDK, no exact-alarm permission,
  vibrate removed from the manifest. The permission prompt appears only after a parent taps "Remind me" (or saves a time in Edit child).
- Data collected about a child stays minimal (see privacy-data-map.md). Account deletion sits behind the parental gate in Settings.
- Dandoona's voice lines and the tap chime are bundled audio; the chime is synthesized by `tools/sounds/make-cheer.ps1` (no license).
