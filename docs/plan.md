# Project plan

## Architecture rules
- **No AI inside the product.** The Flutter app and the API contain no AI features or SDKs. ElevenLabs and OpenAI are
  used only by the offline dev tool `/tools/AssetGenerator`, which writes ordinary `.mp3`/`.webp` files.
- Approved media is committed inside the Flutter project under `assets/` and bundled with the app. No cloud storage.
- The API holds accounts, child profiles and progress only. It handles no media.
- No runtime pronunciation scoring or speech recognition. "Record and listen" plays the child's recording back
  locally; recordings never leave the device and are deleted when the activity ends.
- Free, permissive-license dependencies only: see [licenses.md](licenses.md).
- Database: SQL Server (EF Core). Owner decision; see the exceptions section in licenses.md.

## Phases (current order)
1. **AssetGenerator** (`/tools/AssetGenerator`, see [assetgenerator.md](assetgenerator.md); DONE: live-verified, 26 letters exported): curriculum YAML loader, `mascot` concept command, ElevenLabs +
   OpenAI generation with skip-if-exists, review/approve flow, `status`, `export` into Flutter assets. Letters A-C first.
2. **Mobile shell** (DONE, tested on an emulator): Flutter app, parent area (Arabic RTL), parental gate, child profiles, local storage, 26-letter map. See mobile/kids_english_app/README.md.
3. **Learning activities** (DONE, tested on an Android emulator): trace, listen-and-tap, match-picture, record-and-listen, with stars saved to local progress.
4. **Backend** (DONE): API (auth, children, idempotent progress sync, weekly summaries, account deletion), Docker Compose, EF Core on SQL Server; optional account + sync in the app, verified against the live API.
5. **Gamification and dashboard** (DONE): stars, 5 mascot accessories unlocked by stars with a wardrobe, weekly summary for parents.
6. **Hardening** (DONE except real-device/iOS testing): see [store-compliance.md](store-compliance.md), [performance.md](performance.md), and `azure-pipelines.yml` (CI with an app-size budget).

## Backend status
Foundation exists (cleanup commit): ASP.NET Core Clean Architecture on .NET 10, Identity + JWT with rotating hashed
refresh tokens, child profile CRUD scoped per parent, EF Core model Parent / Child / ProgressRecord / RefreshToken,
Docker Compose (API + SQL Server Express), unit and integration tests (Testcontainers SQL Server, or `KIDS_TEST_SQL` for a
throwaway local database such as LocalDB). Progress endpoints and the weekly summary arrive in Phase 4.

## Conventions
- Curriculum source of truth: `/content/curriculum/*.yaml`. Activities: trace, listen-and-tap, record-and-listen,
  match-picture.
- Secrets live only in git-ignored `.env`, user-secrets or environment variables.
