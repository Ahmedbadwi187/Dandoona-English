# AssetGenerator (`/tools/AssetGenerator`)

Dev-only console tool. It is the **only** code that talks to ElevenLabs (voice) and OpenAI (images). It writes ordinary
`.mp3`/`.webp` files; the app and API never see AI. It has its own solution (`tools/AssetGenerator.slnx`), is not in
`KidsEnglish.slnx`, is referenced by no project, and must stay out of build/deploy pipelines.

## Setup
- Keys: `ELEVENLABS_API_KEY`, `ELEVENLABS_VOICE_ID`, `OPENAI_API_KEY` from git-ignored `.env`, `dotnet user-secrets`
  (UserSecretsId `kidsenglish-assetgenerator`) or environment variables. Never printed or logged.
- ffmpeg on PATH (or `FFMPEG_PATH`) for `export` (mono MP3 + loudness normalisation, WebP resize). Use a build with
  libmp3lame and libwebp.
- Config in `/content/style`: `voices.json`, `generation.json`, `art-style.md` (prefix on every image prompt),
  `mascot.md`. `generation.json` has `pricing` rates (blank by default; the API docs list no prices).
- API shapes were taken from the official docs on 2026-10-05: ElevenLabs `POST /v1/text-to-speech/{voice_id}`
  (`eleven_multilingual_v2`), OpenAI `/v1/images/generations` and `/v1/images/edits` (`gpt-image-2.5-flare`
  for generation, `gpt-image-2.5-sunburst` for edits with the mascot reference). Model names are configurable.

## Commands (run from anywhere inside the repo)
```
dotnet run --project tools/AssetGenerator -- audio   --lesson letter-a [--dry-run] [--force]
dotnet run --project tools/AssetGenerator -- images  --lesson letter-a [--dry-run] [--force]
dotnet run --project tools/AssetGenerator -- all     --track little-learners [--dry-run]
dotnet run --project tools/AssetGenerator -- mascot  [--dry-run]       # 4 concepts into _review
dotnet run --project tools/AssetGenerator -- mascot  --approve 2       # lock concept 2 as the reference
dotnet run --project tools/AssetGenerator -- status  --track little-learners
dotnet run --project tools/AssetGenerator -- export  --track little-learners
```
`--dry-run` calls no API: it lists what would be generated and the usage (characters / images), plus dollars once
rates are set in `generation.json`.

## Workflow
1. `mascot`, look at `content/generated/mascot/_review/mascot.v1..v4.webp`, then `mascot --approve N`. This copies the
   pick to `content/style/mascot.reference.webp`. Scenes with `mascot: true` in the YAML use it via the edits API;
   `images` refuses to run those until it exists.
2. `audio` then listen. Phoneme clips are flagged; record your own and save it as `phoneme.override.mp3` next to the
   generated one. `status` lists every phoneme without your recording.
3. `images`, then in `images/_review/` rename the best variant to `images/{key}.approved.webp`.
4. `export` copies only approved images and audio into `mobile/kids_english_app/assets/` and writes
   `assets/content/little_learners.json`. It prints lessons exported, incomplete lessons (with what is missing) and
   total size, and registers the asset folders in `pubspec.yaml` once that file exists.

## File naming
```
content/generated/{track}/{lesson}/audio/{role}.gen.mp3         generated, as returned by ElevenLabs
content/generated/{track}/{lesson}/audio/{role}.override.mp3    your recording; wins on export, never regenerated
content/generated/{track}/{lesson}/images/_review/{key}.v{n}.webp   candidates (git-ignored)
content/generated/{track}/{lesson}/images/{key}.approved.webp   your pick (rename the variant)
content/generated/{track}/{lesson}/manifest.json                hash of text+voice+settings+model per audio line
content/style/mascot.reference.webp                              locked mascot reference (committed)
```
`role`: `intro`, `phoneme`, `praise-N`, `word-{word}`. `key`: the word slug. Only `_review` is git-ignored.
Skip rules: an existing `.gen` file whose hash matches is skipped; a changed text/voice/settings/model regenerates just
that line; a file with no manifest entry is adopted, not re-billed; `.override` files are never regenerated.

Exported names are stable snake_case, relative to `assets/`:
`audio/little_learners/letter_a/{intro|phoneme|praise_0|word_apple}.mp3`,
`images/little_learners/letter_a/apple.webp` (single 768 px WebP), `images/mascot/mascot.webp`.

## `little_learners.json` (schemaVersion 1)
```json
{
  "schemaVersion": 1,
  "track": "little-learners",
  "generatedAt": "2026-10-05T00:00:00Z",
  "mascot": "images/mascot/mascot.webp",
  "lessons": [{
    "id": "letter-a", "order": 1, "level": "pre-a1", "letter": "A", "phoneme": "/æ/",
    "audio": {
      "intro": "audio/little_learners/letter_a/intro.mp3",
      "phoneme": "audio/little_learners/letter_a/phoneme.mp3",
      "praise": ["audio/little_learners/letter_a/praise_0.mp3", "..."]
    },
    "words": [{ "word": "apple",
                "audio": "audio/little_learners/letter_a/word_apple.mp3",
                "image": "images/little_learners/letter_a/apple.webp" }],
    "activities": ["trace", "listen-and-tap", "record-and-listen", "match-picture"]
  }]
}
```
Optional fields (`mascot`, `letter`, `phoneme`) are omitted when absent. Letters and words are drawn by the app, so
images contain no text.
