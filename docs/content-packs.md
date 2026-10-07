# Content packs (hybrid delivery)

Letters and Colors are **bundled** in the app: they work offline from the first launch. Every later unit is a
**content pack** that the app downloads from our own API, keeps on the phone and plays offline afterwards.
No blob storage, no CDN, no paid service: the packs are static files served by `KidsEnglish.Api`.

## Where a unit goes

`content/curriculum/units/little-learners.yaml`, per unit:

```yaml
- id: numbers
  delivery: pack      # bundled (the default) or pack
```

A unit's own lines (its name "Numbers!", welcome, celebration) are always bundled, so the map can say the name before
the pack is downloaded.

## What `export` writes

`dotnet run --project tools/AssetGenerator -- export --track little-learners`

| Output | What |
|---|---|
| `mobile/kids_english_app/assets/...` | Bundled units' media and `content/little_learners.json` (the catalog of every unit) |
| `packs/little_learners/<unit>/v<version>/` | A pack: its media at the same relative paths the lesson JSON uses, plus `manifest.json` (lessons + every file with its sha256 and size) |
| `packs/little_learners/index.json` | The newest version of every pack (unit, version, manifest sha256, size, manifest path, lesson ids) |
| `content/packs.lock.json` | Version and content hash per pack (committed): an unchanged pack keeps its version, a changed one gets the next |

In the catalog a pack unit has no lessons, only `pack: { version, sha256, bytes, manifest, lessonIds }`. The lesson ids let
the map tell a finished unit (finished on another phone) from an unfinished one before the pack is downloaded.

Old version folders stay on the server: an app that still knows v1 can fetch v1, and moves to v2 when it reads the index.

## How the API serves them

`/packs/<track>/...` from `ContentPacks:Root` (the repo's `packs/` folder when run from source; the Docker image copies
`packs/` to `/app/packs`). Anonymous. Version folders are cached for a year (`immutable`), `index.json` for five minutes.
Only `.json .mp3 .webp .svg .png` are served, never `_build` folders, no folder listing. Integration-tested.

## What the app does

- When the map opens, it fetches in the background the pack of the unit the child is on and of the next unit
  ("one unit away"), one download at a time per unit.
- It asks `index.json` for a newer version (a pack can change without an app release), downloads the manifest, checks it
  against the sha256 it expects, downloads every file and checks each one, then moves the finished folder into place. A
  file that does not match is refused and nothing is kept. Older versions are deleted after the new one is in place.
- Files live in the app's support folder (`packs/<unit>/v<version>/`), bookkeeping in `packs.v1` (unit -> version, folder).
  If the phone clears that folder, the unit simply downloads again.
- Pictures and audio from a pack are read from those files; bundled ones from the app bundle.
- No connection: the child sees the island open with a small cloud badge; tapping it, Dandoona says "Almost ready!" (never
  an error). The parent area shows "Needs internet to download" under that unit.
- Nothing about the child is sent: these are plain file downloads with no account and no identifiers.

## Server address

`API_BASE_URL` (`--dart-define`), the same address the optional account uses; debug builds default to the emulator's
`http://10.0.2.2:5080`. A release build without it has no packs (the units after Colors stay "Soon").
