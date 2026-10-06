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
| ProgressRecord | LessonId, Activity, Stars, Attempts, TimeSpentSeconds, CompletedAt, ClientRecordId | Progress and parent dashboard | LessonId is a curriculum id like letter-a. No free text |

## Not stored

- Children's voice recordings. The app plays a recording back on-device and deletes it; nothing is uploaded.
- Child email, phone, address, photo, device identifiers, location.
- Advertising IDs or behavioral tracking data. No ad SDKs.

## Logging

Serilog structured logs must never include passwords, tokens, API keys, request bodies or audio.

## On-device storage (Flutter app, Phase 2). Nothing leaves the device until the optional backend sync (Phase 4)

| Key (SharedPreferences) | Fields | Purpose | Notes |
|---|---|---|---|
| `children.v1` | id, name (nickname, max 30), avatarKey, birthYear, track, createdAt | Child profiles | No photo, email, full name or exact birth date. Deleted with the profile. |
| `progress.v1` | clientRecordId, childId, lessonId, activity, stars, attempts, timeSpentSeconds, completedAt | Progress and the parent dashboard | Deleted with the child. |
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
| Device (`sync.v1`) | Server address, account email, local-to-server child id map, ids of already-sent progress records, last sync time | Make sync resumable and idempotent | No tokens or passwords. |
| Server | Parent email, password hash, display name; children (nickname, avatar, birth year, track); progress records (lesson, activity, stars, attempts, seconds, completed-at) | Cross-device progress and the weekly summary | **Deleted entirely** by Settings > Account & sync > Delete account & data (password required): cascades to children, progress and tokens. |
| Server logs | Request method/path/status/timing | Operations | No bodies, passwords, tokens or audio. |
