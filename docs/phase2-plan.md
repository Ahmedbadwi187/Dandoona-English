# Phase 2 Plan: Content pipeline (letters A-C first)

Approved packages: YamlDotNet, Azure.Storage.Blobs, Microsoft.Extensions.Http.Resilience,
SixLabors.ImageSharp, ffmpeg CLI (loudness normalization).
Keys (ElevenLabs, OpenAI) come from environment variables / `.env` (git-ignored), never the repo or logs.
Before writing the ElevenLabs and OpenAI clients, read their current official API docs.

## Step 1: Curriculum loader (DONE)
- `/content/curriculum/*.yaml` -> strict YAML reader (unknown keys rejected) -> FluentValidation -> sync.
- `CurriculumSyncService`: all-or-nothing; upserts Lesson + Activities, plans Draft Assets
  (intro, phoneme [human review], praise-N, word-X, image-X). Unchanged lessons are skipped
  so Approved assets are never reset; edited text resets only that asset to Draft.
- `Asset.SourceText` + unique (LessonId, Role) added (migration `AddAssetSourceText`).
- Seed files: letter-a, letter-b, letter-c.

## Step 2: ContentStudio + storage
- Blazor Server, Admin-role login, lesson review screen (Approve / Regenerate / Upload override).
- `IBlobStore` (Azurite locally, Azure Blob in production).
- Status transitions enforced; lesson publishable only when every asset is Approved.

## Step 3: Generators
- `IVoiceGenerator` (ElevenLabs) and `IImageGenerator` (OpenAI), cache by hash of inputs.
- MP3 normalized; WebP @1x/@2x/@3x; `/content/style/voices.json` and `art-style.md`.

## Step 4: Publishing
- Versioned content-pack manifest; API endpoint for latest pack and deltas.

## Open items
- Phoneme audio: TTS on "/z/" style input is unreliable; manual upload override is supported by design.
- Intro narration avoids IPA slashes (TTS would read them literally); wording is reviewed by a human.
