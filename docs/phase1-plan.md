# Phase 1 Plan: Foundation

Approved decisions (defaults taken where not answered):
.NET 10 LTS, Shouldly for assertions, no MediatR/AutoMapper, Blazor Server for ContentStudio (Phase 2),
Admin role in the same Identity store, HS256 JWT (key from user-secrets / Key Vault), default `dbo` schema,
only the three `Track` rows seeded (lessons come with the Phase 2 YAML loader), no auto-commits.

## Solution layout

```
/src
  KidsEnglish.Domain            no dependencies
  KidsEnglish.Application       -> Domain   (use cases, DTOs, validators, abstractions)
  KidsEnglish.Infrastructure    -> Application (EF Core, Identity, JWT)
  KidsEnglish.Api               -> Application, Infrastructure (composition root)
  KidsEnglish.ContentStudio     Phase 2
/tests
  KidsEnglish.Application.Tests
  KidsEnglish.Api.IntegrationTests   (Testcontainers SQL Server)
/mobile/kids_english_app            Phase 3
/content/curriculum, /content/style
/docs
```

## Packages

NuGet: FluentValidation, Microsoft.EntityFrameworkCore(.SqlServer/.Design), Identity.EntityFrameworkCore,
JwtBearer, Serilog.AspNetCore, Microsoft.AspNetCore.OpenApi, xUnit, Shouldly, NSubstitute,
Testcontainers.MsSql, Mvc.Testing.

pub.dev (Phase 3, to be approved then): flutter_riverpod, go_router, dio, drift, flutter_secure_storage,
just_audio, rive/lottie, intl, freezed, json_serializable.

## Domain model

- Parent (Id = Identity user id): DisplayName, PreferredLanguage, SessionLimitMinutes (15), CreatedAt; 1-* Child, 1-* RefreshToken
- RefreshToken: ParentId, TokenHash, ExpiresAt, CreatedAt, RevokedAt, ReplacedByTokenId
- Track (data, not enum): Code, Name, MinAge, MaxAge, CefrFrom, CefrTo; seeded little-learners, explorers, champions
- Child: ParentId, Name (nickname), AvatarKey, BirthYear (year only), TrackId, CreatedAt
- Lesson: TrackId, Code, Order, Title, CurriculumHash, Status; 1-* Activity, 1-* Asset
- Activity: LessonId, Type (Trace|ListenAndTap|SayIt|MatchPicture), Order, ConfigJson
- Asset: LessonId, ActivityId?, Kind, Role, Status (Draft->Generated->Approved->Published), ContentHash, BlobPath, Source, RequiresHumanReview
- ContentPack: TrackId, Version (monotonic per track), ManifestBlobPath, PublishedAt, PublishedBy; *-* Lesson via ContentPackLesson
- ProgressRecord: ChildId, ActivityId, Stars, Attempts, TimeSpentSeconds, CompletedAt, ClientRecordId (unique per child, idempotent offline sync)

Privacy: children have no credentials/email; only BirthYear is stored; no audio storage.

## Auth (Phase 1 scope)

Register / login / refresh (rotating, hashed refresh tokens with reuse detection) / logout.
Child CRUD scoped to the owning parent. ProblemDetails errors, FluentValidation, Serilog.

## Deliverables

Solution skeleton, Docker Compose (API + SQL Server + Azurite), EF Core model + initial migration,
auth + child endpoints, unit tests (Application), integration tests (Testcontainers), docs/privacy-data-map.md.
