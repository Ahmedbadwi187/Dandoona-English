# Deployment: the API, the database and its migrations

How the hosted API (SmarterASP / any IIS or container host) and its SQL Server database are updated. Written for the owner, who applies the
migration on the host when releasing.

## What a release contains

| Part | Where it comes from | Notes |
|---|---|---|
| The API | `dotnet publish src/KidsEnglish.Api -c Release` (or `dist/site`) | upload over the old one; stop the site first on IIS |
| `packs/` and `cards/` | `scripts/prepare-host-content.ps1` (writes `dist/host-content`) | `/health` says `"packs":true,"cards":true` when found |
| The database | EF Core migrations in `src/KidsEnglish.Infrastructure/Persistence/Migrations` | see below |
| Secrets | the host's `appsettings.json` or environment variables | never in the repository: `ConnectionStrings__Default`, `Jwt__Key`, `Email__*` |

## The migration of 10 Oct 2026: `ChildSkillsGoalAndProfileTime`

Adds three **nullable** columns to `Children`: `GoalMinutes int`, `Skills nvarchar(500)`, `ProfileUpdatedAt datetime2`.

- Backward compatible: older app versions do not send these fields; the API leaves them as they are (tests: `ChildProfileSyncTests`).
- Safe to apply while the old API is running: adding nullable columns does not break the old code (it never reads them).
- Release order: apply the migration **first**, then upload the new API, then publish the new app.

### 1. Back up the database first

Pick one:

- **SmarterASP control panel**: Databases, MS SQL, your database, **Backup** (download the `.bak`), or **Restore points** if your plan has them.
- **SSMS**: right-click the database, Tasks, **Back Up…**, Full, to a file you keep.
- **T-SQL**: `BACKUP DATABASE [db_name] TO DISK = N'C:\backups\dandoona-before-skills.bak' WITH COPY_ONLY, INIT;`
  (on a shared host you can usually only do this from the panel).

Check the backup file exists and is not empty before going on.

### 2. Apply the migration

The hosted API applies migrations itself at start-up when `Database:MigrateOnStartup` is `true` (it is in `appsettings.Production.json`).
So the simplest way is: upload the new API and start it. To do it by hand instead (and read what will run first):

```powershell
# the SQL it will run (read it; nothing changes yet)
dotnet ef migrations script 20261007150135_ChildAchievements 20261010111627_ChildSkillsGoalAndProfileTime `
  --project src/KidsEnglish.Infrastructure --startup-project src/KidsEnglish.Api --output skills-migration.sql

# apply it to the hosted database (the design-time factory has a fixed local connection, so pass the host's)
dotnet ef database update --project src/KidsEnglish.Infrastructure --startup-project src/KidsEnglish.Api `
  --connection "<the host connection string>"
```

Or run `skills-migration.sql` in the host's SQL console / SSMS (it is a transaction: it either all applies or not at all). It is:

```sql
BEGIN TRANSACTION;
ALTER TABLE [Children] ADD [GoalMinutes] int NULL;
ALTER TABLE [Children] ADD [ProfileUpdatedAt] datetime2 NULL;
ALTER TABLE [Children] ADD [Skills] nvarchar(500) NULL;
INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion]) VALUES (N'20261010111627_ChildSkillsGoalAndProfileTime', N'10.0.12');
COMMIT;
```

### 3. Check

- `https://<host>/health` answers `{"status":"ok",...}`.
- In SQL: `SELECT TOP 1 GoalMinutes, Skills, ProfileUpdatedAt FROM Children;` does not error.
- Sign in from the app and add or edit a child: no error in the host's log (`logs/` or the panel's log viewer).

### 4. Roll back, if needed

The new columns are unused by older code, so the easiest rollback is **the API only**: upload the previous API build (the columns stay, harmlessly).

To remove the columns as well:

```powershell
dotnet ef database update 20261007150135_ChildAchievements --project src/KidsEnglish.Infrastructure --startup-project src/KidsEnglish.Api --connection "<host connection string>"
```

or in SQL (this deletes what was stored in them: skills, goals, profile times, which the app sends again at its next sync):

```sql
BEGIN TRANSACTION;
ALTER TABLE [Children] DROP COLUMN [GoalMinutes];
ALTER TABLE [Children] DROP COLUMN [ProfileUpdatedAt];
ALTER TABLE [Children] DROP COLUMN [Skills];
DELETE FROM [__EFMigrationsHistory] WHERE [MigrationId] = N'20261010111627_ChildSkillsGoalAndProfileTime';
COMMIT;
```

If something else went wrong, restore the `.bak` from step 1 (this loses everything written since the backup).

## E-mail (forgot password)

Section `Email` of the host's `appsettings.json` (or `Email__Host`, `Email__Port`, `Email__UserName`, `Email__Password`, `Email__FromAddress`
environment variables). With `Host` empty the API only writes the message to its log. Test: ask for a reset code from the app with your own address.

## Habit for every future migration

1. Make the new columns nullable (or give a default), so the previous API and app versions keep working.
2. `dotnet ef migrations add <Name>`; read the `Up` and `Down`; run the integration tests (`docs/handoff.md`, "Integration tests without Docker").
3. Document it here: what it adds, the release order, the SQL, and how to roll back.
