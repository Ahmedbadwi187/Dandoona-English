# Dependency licenses

Hard rule: only free, open-source components with permissive licenses (MIT, Apache-2.0, BSD, and the
equivalents). No paid services, no commercial or dual licenses, no license keys.
Banned: MediatR, AutoMapper, FluentAssertions v8+, MassTransit v9+, SixLabors.ImageSharp.

Licenses below were read from each package's own metadata (NuGet nuspec / pub.dev license tags) for the exact
version listed. **Update this file whenever a package is added or upgraded.**

Last full audit of the restored graph (2026-10-05): 135 NuGet packages. 111 MIT, 19 Apache-2.0, 2 BSD-3-Clause,
`xunit.abstractions` 2.0.3 (xunit project, Apache-2.0, license given as a URL rather than an SPDX id), and the two
exceptions listed under "Known exceptions" below.

## Backend (`/src`) - NuGet

| Package | Version | License |
|---|---|---|
| Microsoft.EntityFrameworkCore (+ .Design, .Relational) | 10.0.12 | MIT |
| Microsoft.EntityFrameworkCore.SqlServer (+ Microsoft.Data.SqlClient 6.1.6) | 10.0.12 | MIT |
| Microsoft.AspNetCore.Identity.EntityFrameworkCore | 10.0.12 | MIT |
| Microsoft.AspNetCore.Authentication.JwtBearer | 10.0.12 | MIT |
| Microsoft.AspNetCore.OpenApi | 10.0.12 | MIT |
| Microsoft.Extensions.DependencyInjection.Abstractions | 10.0.12 | MIT |
| System.IdentityModel.Tokens.Jwt | 8.23.0 | MIT |
| FluentValidation (+ DependencyInjectionExtensions) | 12.1.1 | Apache-2.0 |
| Serilog.AspNetCore (+ Extensions, Sinks.Console/File/Debug, Settings.Configuration, Formatting.Compact) | 10.0.0 (sinks 3.0-7.0) | Apache-2.0 |

## Tests (`/tests`) - NuGet

| Package | Version | License |
|---|---|---|
| xunit, xunit.runner.visualstudio | 2.9.3 / 3.1.4 | Apache-2.0 |
| Microsoft.NET.Test.Sdk | 17.14.1 | MIT |
| Microsoft.AspNetCore.Mvc.Testing | 10.0.12 | MIT |
| Shouldly | 4.3.0 | BSD-3-Clause |
| NSubstitute | 6.2.0 | BSD-3-Clause |
| Testcontainers.MsSql (+ Testcontainers) | 4.15.0 | MIT |
| coverlet.collector | 6.0.4 | MIT |

## Dev-only tool (`/tools/AssetGenerator`) - planned, not yet added

May call the ElevenLabs and OpenAI APIs because it is a dev-only tool outside the product. It uses only free libraries:

| Package / tool | Version (checked 2026-10-05) | License |
|---|---|---|
| YamlDotNet | 18.1.0 | MIT |
| System.CommandLine | 2.0.12 | MIT |
| Microsoft.Extensions.Hosting / Configuration.UserSecrets | 10.0.12 | MIT |
| Microsoft.Extensions.Http.Resilience (+ Polly.Core 8.8.0) | 10.10.0 | MIT / BSD-3-Clause |
| FluentValidation | 12.1.1 | Apache-2.0 |
| ffmpeg (external executable, not linked or shipped) | user-installed | LGPL/GPL depending on build; use an LGPL build with libmp3lame (LGPL) and libwebp (BSD) |

## Mobile (`/mobile/kids_english_app`) - pub.dev

In use (versions from pubspec.yaml; licenses read from pub.dev on 2026-10-06):

| Package | Constraint | License |
|---|---|---|
| flutter_riverpod | ^3.4.3 | MIT |
| go_router | ^18.0.2 | BSD-3-Clause |
| flutter_svg | ^2.3.0 | MIT |
| shared_preferences | ^2.5.6 | BSD-3-Clause |
| intl | ^0.20.2 | BSD-3-Clause |
| flutter_localizations, flutter_test (Flutter SDK) | sdk | BSD-3-Clause |
| flutter_lints (dev) | ^6.0.0 | BSD-3-Clause |

Not code-generating on purpose: no freezed / json_serializable / drift / build_runner yet (models are hand-written, local storage is
shared_preferences). Planned for later phases, re-check license + exact version when added:

| Package | Latest checked | License |
|---|---|---|
| audioplayers / just_audio | 6.8.1 / 0.10.6 | MIT / Apache-2.0 + MIT |
| record | 7.1.1 | BSD-3-Clause |
| permission_handler | 13.0.2 | MIT |
| drift | 2.35.1 | MIT |
| dio | 5.11.1 | MIT |
| flutter_secure_storage | 11.2.0 | BSD-3-Clause |
| rive / lottie | 0.14.11 / 3.6.1 | MIT |

Rejected: `hive` (no license recorded on pub.dev; use drift). `sqlite3_flutter_libs` is end-of-life; resolve
drift's current SQLite setup when adding it.

## Infrastructure / tooling (not shipped inside the product)

| Item | License |
|---|---|
| SQL Server (Docker image, Express edition) | Microsoft proprietary: free of charge (Express/Developer), NOT open source. Decision by the project owner, overriding the PostgreSQL switch |
| dotnet-ef (local tool) | MIT |
| Docker / Docker Compose, Azure DevOps | Hosted/dev tooling, not product components; review terms for your organization |

## Known exceptions to the permissive-license rule

All come from the project owner's decision to use SQL Server (2026-10-05):

| Item | Terms | Notes |
|---|---|---|
| SQL Server (server) | Microsoft proprietary. Express and Developer editions are free of charge; Express is limited (10 GB database, limited CPU/RAM). Production beyond those limits needs a paid license. | Docker Compose uses `MSSQL_PID=Express`. |
| Microsoft.Data.SqlClient.SNI.runtime 6.0.2 | Microsoft Software License Terms (free to use, not OSI-approved) | Native networking library required by the SQL Server driver. |
| Microsoft.Identity.Client.NativeInterop 0.20.6 | Microsoft Software License Terms (free to use, not OSI-approved) | Transitive via the driver's Entra ID authentication support. Not used (we authenticate with SQL logins). |

The managed drivers themselves (Microsoft.EntityFrameworkCore.SqlServer, Microsoft.Data.SqlClient) are MIT. A PostgreSQL
build (Npgsql, PostgreSQL License) was tried and reverted on request; the PostgreSQL option remains available if the
fully-open-source rule should win.
