# Privacy data map

Every field the system stores. Update this file whenever the schema changes.

| Entity | Field | Purpose | Notes |
|---|---|---|---|
| Identity user (parent) | Email, normalized email, password hash | Login | Parent only. Password hashed by ASP.NET Identity. |
| Identity user | Lockout/access-failed counters | Brute-force protection | |
| Parent | DisplayName | Greeting in parent UI | Parent's own name |
| Parent | PreferredLanguage, SessionLimitMinutes | Settings | |
| RefreshToken | TokenHash, ExpiresAt, CreatedAt, RevokedAt | Session renewal | Only SHA-256 hash stored, never the raw token |
| Child | Name | Display in child UI | Nickname only; the app must not ask for a real/full name |
| Child | AvatarKey | Avatar choice | Opaque key |
| Child | BirthYear | Age-appropriate track | Year only, no full date of birth |
| Child | Track | Learning track code (little-learners, explorers, champions) | |
| ProgressRecord | LessonId, Activity, Stars, Attempts, TimeSpentSeconds, CompletedAt, ClientRecordId | Progress and parent dashboard | LessonId is a curriculum id like letter-a. No free text. **One summary per finished activity**, never individual taps or raw events |
| ChildAchievement | Kind (certificate, chest, review, story, placed), Key (a unit or review id), EarnedAt | The child's certificates, opened treasure chests, passed reviews, read stories and starting point follow them to a new phone | Fixed list of kinds, curriculum ids only, no free text. One row per kind and key; the earliest date any phone reported is kept |

## Not stored

- Children's voice recordings. The app plays a recording back on-device and deletes it; nothing is uploaded.
- Child email, phone, address, photo, device identifiers, location.
- Advertising IDs or behavioral tracking data. No ad SDKs.

## Logging

Serilog structured logs must never include passwords, tokens, API keys, request bodies or audio.

## On-device storage (Flutter app, Phase 2). Nothing leaves the device until the optional backend sync (Phase 4)

| Key (SharedPreferences) | Fields | Purpose | Notes |
|---|---|---|---|
| `children.v1` | id, name (nickname, max 30), avatarKey, birthYear, birthMonth, goalMinutes, track, skills (ids from the skills list), updatedAt, createdAt | Child profiles | No photo, email, full name or exact birth date. Deleted with the profile. |
| `progress.v1` | clientRecordId, childId, lessonId, activity, stars, attempts, timeSpentSeconds, completedAt | Progress and the parent dashboard | Deleted with the child. |
| `meta.v2` | per child: unit id -> date a certificate was earned, and which unit celebrations were already shown | Show the unit certificates and show each celebration once | Deleted with the child. Written by the one-time migration for children who finished Letters before units existed; `progress.v1` is never rewritten. |
| `misses.v1` | per child: the words not found in the "hear it, tap it" games (lesson id, word, how many times, at most 9) | Practice on the map and the parent's "Practice at home" list | Phone only, never sent to the server or anywhere. Deleted with the child. Each word found in Practice takes one off. |
| `settings.v1` | languageCode, sessionMinutes, unlockAll, onboarded | Parent settings | |

The app collects no analytics, advertising identifiers, location or contacts. The microphone is only used by the
record-and-listen activity (Phase 3): recordings are played back locally and deleted when the activity ends.

### Microphone (record-and-listen, Phase 3)
- Permission is requested only when the child taps the record button (Android `RECORD_AUDIO`, iOS `NSMicrophoneUsageDescription` with an explanation).
- The recording is a temporary AAC file in the app's temp folder. It is played back immediately after the original word and **deleted
  right after play-back** (and on leaving the screen). No scoring, no speech recognition, no upload, no copy kept.
- If the permission is denied the activity offers a skip (1 star); nothing is recorded.

### Optional account + sync (Phase 4)
Nothing below is stored or sent unless a parent signs in under Settings > Account & sync and taps "Sync now".

| Where | Data | Purpose | Notes |
|---|---|---|---|
| Device keystore (flutter_secure_storage) | Refresh token | Stay signed in | Rotating, single-use. The password is never stored on the device. |
| Device (`sync.v1`) | Server address, account email, local-to-server child id map, ids of already-sent progress records, **server ids of children whose deletion is still queued**, last sync time | Make sync resumable and idempotent; remember a delete made while offline | No tokens or passwords. |
| Server | Parent email, password hash, display name; children (nickname, avatar, birth year, track); progress records (lesson, activity, stars, attempts, seconds, completed-at) | Cross-device progress and the weekly summary | **Deleted entirely** by Settings > Account & sync > Delete account & data (password required): cascades to children, progress and tokens. |
| Server logs | Request method/path/status/timing | Operations | No bodies, passwords, tokens or audio. |

### Deleting a child (device and server)
- Deleting a child profile in Parent area > Child profiles removes the profile and all of that child's progress from the device.
- If that child had been synced, the **server copy is hard-deleted as well** (`DELETE /api/children/{id}`): the child row and every
  progress record are physically removed by a database cascade (integration-tested), not flagged or archived.
- If the device is offline (or signed out) at that moment, the deletion is **queued** on the device (only the server child id is
  kept) and sent first on the next sync or when the parent signs in again; a child that is already gone on the server counts as
  deleted. Settings > Account & sync shows how many deletions are still waiting.
- A child that was never synced has no server copy, so there is nothing to delete remotely.
- Deleting the whole account (Settings > Account & sync > Delete account & data) removes every child, all progress and the
  login on the server in one step, and clears the queue.

## First-launch setup and the parent redesign (added later)

Collected only by the parent, only on this phone unless the optional account is used:

| Data | Where | Why | Leaves the device? |
|---|---|---|---|
| Child nickname, avatar | `children.v1` | profile | only with an account (sync) |
| Birth **month and year** (no day) | `children.v1` | age, track | only with an account (server stores the optional month) |
| Daily goal (5, 10, 15 min) | `children.v1`, `settings.v1` | session timer | with sync (goal stays local) |
| Starting level answer | `meta.v2.placed` (units counted done) | where the child starts | no |
| Reminder time (morning/afternoon/evening) | `settings.v1` | one local notification per day | no (local notification, no push service) |
| Parent first name (optional, sign-up) | `settings.v1` and the account | greeting only | server keeps it with the account |
| Consent times (guardian 18+, privacy and terms) | server account | proof of consent | stored on the server at sign-up |

Never collected: phone number, address, location, school, the child's full name, photo, gender, interests.
Deleting a child removes the profile, progress, stars, certificates and the placement from the device and the account.
Signing out or deleting the account also clears the saved parent first name.

## Content packs, sync both ways and anonymous stats (added with the content packs)

### What is stored, where, and for how long

| Data | Where | Why | How long |
|---|---|---|---|
| Downloaded content packs (lesson pictures, audio, lesson JSON) | Phone: app support folder `packs/<unit>/v<version>/`; `packs.v1` (unit -> version, folder) | Units after Colors play offline after one download | Until a newer version replaces it, the app is uninstalled or the phone clears app data. Contains nothing about the child |
| `meta.v2` per child: passed reviews, opened chests, read stories (new) | Phone | Map stations | Until the child profile is deleted |
| Progress summaries (one per finished activity) | Phone (`progress.v1`); server only with an account | Progress, stars, the parent dashboard | Phone: until the child is deleted. Server: until the parent deletes the child or the account |
| Certificates, chests, reviews, stories, starting point (`ChildAchievements`) | Server, only with an account | Restore on a new phone | Until the parent deletes the child or the account (database cascade, integration-tested) |
| Refresh token | Phone keystore; server keeps only its SHA-256 hash | Stay signed in | 30 days, rotated on every use; deleted on sign-out or account deletion |
| Request logs | Server console/hosting logs | Operations | Method, path, status, timing only (no bodies, tokens, passwords). Kept as long as the hosting keeps logs: **set this to 30 days or less when choosing hosting** |

Without an account nothing in this table leaves the phone, except plain pack downloads (below).

### Pack downloads
- Anonymous file downloads from our own API (`/packs/...`): no account, no child id, no device id, no cookies.
  The server sees what any web server sees (IP address and the file path) in its request log.
- Each file is checked against its SHA-256 before it is used; a pack that does not match is thrown away.
- No connection: nothing is reported anywhere; the parent area shows "Needs internet to download".

### Sync (only with an account)
- The phone keeps everything locally and works offline. With an account, the server is the source of truth: each sync
  sends new progress summaries and the achievements above; sign-in, "Sync now" and the first background sync after the
  app starts also read them back, so the family's other phones get the same results.
- Conflicts: every per-activity summary is kept, so the **best result per lesson** counts everywhere; achievements are a
  union (nothing earned is lost), with the earliest date.
- A new phone restores children, progress and achievements when the parent signs in.

### Anonymous stats for the content owner
- `GET /api/admin/stats/lessons` (owner's key only): per lesson activity the number of results and children, average
  tries, stars and time, and the share of one-star results.
- **Nothing new is collected**: computed on request from the summaries parents with an account already sync; nothing is
  stored. Phones without an account contribute nothing.
- No child, parent or record ids, no names, no dates. A row is shown only when **at least 5 different children** are in it.

### Open decision
- Inactive accounts are not deleted automatically today. A retention period (for example deleting accounts with no
  sign-in for 24 months, after an e-mail warning) needs the owner's decision and a line in the privacy policy.

## Explorers track (ages 6-8)

No new data leaves the phone and no new server table: the child's `track` was already stored (`explorers` now has lessons), and
results of the new games sync as before (activity codes `sound-tap`, `word-builder`, `read-and-pick`; one summary per finished
activity). New keys **on the phone only**:

| Key | What | Why | How long |
|---|---|---|---|
| `asks.v1` | child ids whose parent answered the birth-month question and the Explorers offer | ask each only once | until the app is removed |
| `demos.v1` | per child, the games whose hand demo was already shown | show a game's demo once by itself | until the app is removed |
| `activeDays.v1` | per child, the last active-day milestone celebrated (a number) | celebrate each milestone once | until the app is removed |

Active days are counted from the progress already on the phone (days with a finished activity); there is no streak, nothing is
reset and a missed day is never shown. The birth month is now required for new children (it was already asked); children saved
with the year alone keep working, and the parent is asked once to add the month.

## Skills, active tracks and automatic sync (10 Oct 2026)

Ages 3 to 8, two released tracks (Little Learners 3-5, Explorers 6-8; Champions not built). What the parent answers in "What can your child already do?"
is stored as a list of skill ids (`assets/content/skills.json`; or `none` / `unsure`). It is the parent's answer, never a test of the child, and it decides
only the track suggestion and the starting unit.

| Where | What | Notes |
|---|---|---|
| Phone: `children.v1` | + `skills`, `goalMinutes`, `updatedAt` (when the profile was last changed) | deleted with the profile |
| Phone: `skipahead.v1` | per child: the unit being suggested, the units already suggested, refusals in a row, switched off | for the "seems to know this already, skip ahead?" card; no data leaves the phone |
| Phone: `sync.v1` | + `profilePushed` (which version of each profile the server has) | |
| Server: `Children` table | + `GoalMinutes`, `Skills` (ids joined by commas), `ProfileUpdatedAt` (all nullable; migration `ChildSkillsGoalAndProfileTime`) | only for parents who chose an account; deleted with the child |

**Automatic sync** (accounts only): sends changes by itself; with no account nothing is ever sent. The status line in settings shows
saved / saving / waiting. Conflicts: best result per lesson, union of rewards, most recent profile fields and skills.
**Password reset**: the parent's e-mail address and a 6-digit code go through the SMTP provider the owner configures (`Email` section of appsettings);
the code works once for a few minutes. The provider is a data processor: name it in the privacy policy when chosen.
