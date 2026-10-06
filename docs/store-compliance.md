# Store compliance review (Google Play Families, Apple Kids Category)

Status of each requirement for the Little Learners app (ages 3-5), with the evidence. "Owner action" items need something
that only the account owner can do (publishing accounts, hosting pages, store-console forms). This is an engineering
review, not legal advice: have the privacy policy checked for the markets you ship to (COPPA in the US, GDPR-K in the EU,
and the privacy laws of the Arab countries you target).

## What the shipped app contains (verified on the 2026-10-06 release build)
- **Android release APK:** arm64 24.7 MB, armeabi-v7a 22.4 MB, x86_64 26.2 MB (`flutter build apk --release --split-per-abi`).
  Budget enforced in `azure-pipelines.yml`: arm64 <= 40 MB. About 5.6 MB of that is the bundled lessons (will shrink once the
  asset tool re-encodes audio/images with ffmpeg: mono, loudness-normalised, 768 px WebP).
- **Permissions in the final manifest:** `RECORD_AUDIO` (record-and-listen only, requested on first use) and `INTERNET`
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
| Target audience includes children; choose the right age bands in Play Console | Owner action | Declare "5 and under" (and 6-8/9-12 when those tracks ship). Enrol in the Designed for Families program. |
| No ads, or only Families-certified ad SDKs | Done | No ad SDK present. |
| No personal data collected from children without parental consent; no persistent identifiers | Done | Child profile = nickname, avatar, birth year, stored locally. No advertising ID, no analytics. |
| Parental gate before anything leaving the child experience | Done | Press-and-hold + multiplication before the parent area, settings, and the session time-up override. The child area has no external links, purchases or ads. |
| Only age-appropriate content | Done | Self-drawn and generated illustrations reviewed by hand; no text in images; audio is the developer's reviewed script. |
| Permissions only as needed, with explanation | Done | Microphone prompted on first use of record-and-listen; iOS usage string written. The activity works without it (skip, 1 star). |
| Data safety form | Owner action | Local-only mode: "No data collected". With sync enabled: email address (account), child nickname/birth year, app activity (progress) - collected, linked to the parent account, encrypted in transit, **deletion available** (see below). |
| Deleting a child's data | Done | Deleting a child profile in the app also hard-deletes the child and all progress on the server (queued and retried if offline). Integration-tested (rows physically removed, sibling untouched) and verified against the live API. |
| Account deletion in-app + a web link | Partly | In-app deletion with password confirmation is built and tested (Settings > Account & sync > Delete account & data; `POST /api/account/delete`). **Owner action:** host a web page that explains how to delete an account/data and paste its URL in Play Console. |
| Privacy policy URL | Owner action | Required for the store listing. Use `privacy-data-map.md` as the source of truth; must cover the optional sync and the microphone. |
| Target API level | Done | Flutter's default `targetSdk` (36 at the time of build); keep up to date with Play's yearly requirement. |

## Apple - Kids Category (App Store Review 1.3, 5.1.4)
| Requirement | Status | Evidence / action |
|---|---|---|
| Pick an age band (5 and under / 6-8 / 9-11) | Owner action | "5 and under" for Little Learners. |
| No third-party advertising or analytics | Done | None included. |
| Parental gate before links out, purchases, or permission prompts for personal data | Done | Gate in front of the parent area; the app has no links out and no in-app purchases. |
| Privacy "nutrition label" | Owner action | Local-only: "Data Not Collected". With sync: Contact Info (email), User Content/Usage (progress) linked to the user, not used for tracking. |
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

## Open items before publishing (not engineering)
1. Host the privacy policy and the account/data-deletion page; add both URLs to the store listings.
2. Fill in Data safety / nutrition labels as above; choose age bands.
3. Build and test on iOS (needs a Mac). Test on a few real low-end Android phones.
4. Decide the production hosting for the API (https, SQL Server licensing beyond Express limits, backups, monitoring).
5. Listen to the phoneme clips and sound-out intros flagged in `asset-decisions.md`; record your own where TTS is wrong.
6. Install ffmpeg and run the asset tool's `export --force` to shrink the audio and images.
