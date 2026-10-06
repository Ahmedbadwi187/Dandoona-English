# Dependency licenses

Hard rule: only free, open-source components with permissive licenses (MIT, Apache-2.0, BSD, and the
equivalents). No paid services, no commercial or dual licenses, no license keys.
Banned: MediatR, AutoMapper, FluentAssertions v8+, MassTransit v9+, SixLabors.ImageSharp.

Licenses below were read from each package's own metadata (NuGet nuspec / pub.dev license tags) for the exact
version listed. **Update this file whenever a package is added or upgraded.**

Last full audit of the restored graph (2026-10-05): 135 NuGet packages. 111 MIT, 19 Apache-2.0, 2 BSD-3-Clause,
`xunit.abstractions` 2.0.3 (xunit project, Apache-2.0, license given as a URL rather than an SPDX id), and the two
exceptions listed under "Accepted exceptions" below.

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
| ffmpeg 9.0.2 (external executable, **dev tool only**) | winget `Gyan.FFmpeg` (gyan.dev full build) | GPL-3.0 build. Run by AssetGenerator as a separate process to re-encode audio/images; never linked, bundled or referenced by the app or the API. Only its output files (MP3/WebP) ship |

## Mobile (`/mobile/kids_english_app`) - pub.dev

In use (versions from pubspec.yaml; licenses read from pub.dev on 2026-10-06):

| Package | Constraint | License |
|---|---|---|
| flutter_riverpod | ^3.4.3 | MIT |
| go_router | ^18.0.2 | BSD-3-Clause |
| flutter_svg | ^2.3.0 | MIT |
| shared_preferences | ^2.5.6 | BSD-3-Clause |
| intl | ^0.20.2 | BSD-3-Clause |
| audioplayers (+ _android, _darwin, _linux, _web, _windows, _platform_interface) | ^6.8.1 | MIT |
| record (+ _android, _ios, _linux, _macos, _web, _windows, _platform_interface) | ^7.1.1 | BSD-3-Clause |
| path_provider (+ _android, _foundation) | ^2.1.6 | BSD-3-Clause |
| http | ^1.5.0 | BSD-3-Clause |
| crypto | ^3.0.6 | BSD-3-Clause |
| flutter_secure_storage (+ _darwin, _linux, _platform_interface, _web, _windows) | ^11.2.0 | BSD-3-Clause |
| Transitive: ffi_leak_tracker, win32 | resolved in pubspec.lock | BSD-3-Clause |
| Transitive build/plugin helpers: code_assets, hooks, jni, jni_flutter, jni_util, objective_c, package_config, pub_semver, record_use | resolved in pubspec.lock | BSD-3-Clause |
| Transitive: synchronized, yaml | resolved in pubspec.lock | MIT |
| flutter_localizations, flutter_test (Flutter SDK) | sdk | BSD-3-Clause |
| flutter_lints (dev) | ^6.0.0 | BSD-3-Clause |

Not code-generating on purpose: no freezed / json_serializable / drift / build_runner (models are hand-written, local storage is
shared_preferences). Planned for later phases, re-check license + exact version when added:

| Package | Latest checked | License |
|---|---|---|
| rive / lottie | 0.14.11 / 3.6.1 | MIT |

Rejected: `hive` (no license recorded on pub.dev). If a database is ever needed: drift (MIT) - `sqlite3_flutter_libs` is end-of-life, resolve
its current SQLite setup when adding it.

## Infrastructure / tooling (not shipped inside the product)

| Item | License |
|---|---|
| SQL Server (Docker image, Express edition) | Microsoft proprietary: free of charge, max 10 GB per database, NOT open source. Accepted exception, see "Accepted exceptions" below |
| dotnet-ef (local tool) | MIT |
| Docker / Docker Compose, Azure DevOps | Hosted/dev tooling, not product components; review terms for your organization |

## Accepted exceptions to the free-components rule

**Decision (project owner, 2026-10-06): the database stays SQL Server.** This is an *accepted exception* to the rule that the
product uses only free, open-source, permissive components. It is recorded here deliberately and is not a gap to be "fixed".

- **SQL Server Express is free of charge, with a size limit of 10 GB per database** (plus limits on CPU and memory). Docker
  Compose uses `MSSQL_PID=Express`. The Developer edition is also free but licensed for development and testing only.
- Staying within Express means no license cost. If one database ever needs to exceed 10 GB (or the CPU/RAM limits), that would
  need a paid edition or a move to another database: until then no payment is involved. Keep an eye on database size.
- The two native packages below ship with the SQL Server driver under Microsoft's own (free-to-use) license terms. They are not
  open source, which is the other half of this exception.

| Item | Terms | Notes |
|---|---|---|
| SQL Server (server) | Microsoft proprietary. Express: free, max 10 GB per database, limited CPU/RAM. Production beyond those limits needs a paid license. | Docker Compose uses `MSSQL_PID=Express`. |
| Microsoft.Data.SqlClient.SNI.runtime 6.0.2 | Microsoft Software License Terms (free to use, not OSI-approved) | Native networking library required by the SQL Server driver. |
| Microsoft.Identity.Client.NativeInterop 0.20.6 | Microsoft Software License Terms (free to use, not OSI-approved) | Transitive via the driver's Entra ID authentication support. Not used (we authenticate with SQL logins). |

The managed drivers themselves (Microsoft.EntityFrameworkCore.SqlServer, Microsoft.Data.SqlClient) are MIT. A PostgreSQL
build (Npgsql, PostgreSQL License) was tried and reverted on request; it remains a technical option if the owner ever
decides the fully-open-source rule should win.
