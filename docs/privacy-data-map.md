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
