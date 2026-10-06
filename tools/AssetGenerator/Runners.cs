using AssetGenerator.Curriculum;

namespace AssetGenerator;

public enum AudioState { Missing, Changed, UpToDate, Overridden }

public record AudioJob(Lesson Lesson, AudioItem Item, AudioState State, string Hash);

/// <summary>`audio`: generate missing or changed lines with ElevenLabs. Skips anything already generated or overridden.</summary>
public class AudioRunner(Layout layout, VoiceConfig voices, GenerationConfig config, IVoiceClient? client, string? fallbackVoiceId, TextWriter output)
{
    public IReadOnlyList<AudioJob> Plan(IEnumerable<Lesson> lessons, bool force)
    {
        var voice = voices.Narrator(fallbackVoiceId);
        var jobs = new List<AudioJob>();
        foreach (var lesson in lessons)
        {
            var manifest = LessonManifest.Load(layout.ManifestPath(lesson));
            foreach (var item in LessonPlan.Audio(lesson))
            {
                var hash = Hashing.AudioHash(item.Text, voice, voices.Model, voices.OutputFormat);
                var state =
                    File.Exists(layout.AudioOverride(lesson, item.Role)) ? AudioState.Overridden :
                    !File.Exists(layout.AudioGen(lesson, item.Role)) || force ? AudioState.Missing :
                    // File exists but nothing recorded about it: adopt it rather than pay to regenerate.
                    !manifest.Audio.TryGetValue(item.Role, out var entry) || entry.Hash == hash ? AudioState.UpToDate :
                    AudioState.Changed;
                jobs.Add(new AudioJob(lesson, item, state, hash));
            }
        }
        return jobs;
    }

    public async Task<int> RunAsync(IEnumerable<Lesson> lessons, bool dryRun, bool force, CancellationToken ct)
    {
        var jobs = Plan(lessons, force);
        var todo = jobs.Where(j => j.State is AudioState.Missing or AudioState.Changed).ToList();

        output.WriteLine($"Audio: {todo.Count} to generate, {jobs.Count(j => j.State == AudioState.UpToDate)} up to date, " +
                         $"{jobs.Count(j => j.State == AudioState.Overridden)} overridden by your recordings.");
        foreach (var j in todo)
            output.WriteLine($"  {(j.State == AudioState.Changed ? "CHANGED" : "NEW    ")} {j.Lesson.Id}/{j.Item.Role}  ({j.Item.Text.Length} chars)  \"{Truncate(j.Item.Text, 50)}\"");

        var chars = todo.Sum(j => j.Item.Text.Length);
        output.WriteLine($"Estimated ElevenLabs usage: {chars} characters ({voices.Model}).");
        if (config.Pricing.ElevenLabsUsdPer1kChars is { } rate)
            output.WriteLine($"Estimated cost: ${chars / 1000m * rate:0.0000} at ${rate}/1k chars.");
        else
            output.WriteLine("Set pricing.elevenLabsUsdPer1kChars in content/style/generation.json for a dollar estimate.");

        if (dryRun || todo.Count == 0) { if (dryRun) output.WriteLine("(dry run: nothing was generated)"); return 0; }
        if (client is null) throw new ApiException("ELEVENLABS_API_KEY is not set (use .env, user-secrets or an environment variable).");

        var voice = voices.Narrator(fallbackVoiceId);
        foreach (var group in todo.GroupBy(j => j.Lesson))
        {
            var manifest = LessonManifest.Load(layout.ManifestPath(group.Key));
            foreach (var j in group)
            {
                ct.ThrowIfCancellationRequested();
                var bytes = await client.SynthesizeAsync(j.Item.Text, voice, voices.Model, voices.OutputFormat, ct);
                var path = layout.AudioGen(j.Lesson, j.Item.Role);
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                await File.WriteAllBytesAsync(path, bytes, ct);
                manifest.Audio[j.Item.Role] = new ManifestEntry { Hash = j.Hash, GeneratedAtUtc = DateTime.UtcNow };
                manifest.Save(layout.ManifestPath(j.Lesson)); // persist progress after every line
                output.WriteLine($"  generated {j.Lesson.Id}/{j.Item.Role}");
            }
        }

        foreach (var p in todo.Where(j => j.Item.IsPhoneme))
            output.WriteLine($"  NOTE: {p.Lesson.Id}/phoneme is TTS of an isolated sound and is often wrong. Listen to it, or record {Path.GetFileName(layout.AudioOverride(p.Lesson, "phoneme"))}.");
        return 0;
    }

    private static string Truncate(string s, int n) => s.Length <= n ? s : s[..n] + "...";
}

public enum ImageState { Missing, AwaitingPick, Approved }

public record ImageJob(Lesson Lesson, ImageItem Item, ImageState State, int ReviewCount);

/// <summary>`images`: generate variants into _review. You pick one by renaming it to {key}.approved.webp.</summary>
public class ImageRunner(Layout layout, GenerationConfig config, IImageClient? client, TextWriter output)
{
    public IReadOnlyList<ImageJob> Plan(IEnumerable<Lesson> lessons, bool force) =>
        lessons.SelectMany(l => LessonPlan.Images(l).Select(i =>
        {
            var review = layout.ImageReviewFiles(l, i.Key).Count;
            var state = File.Exists(layout.ImageApproved(l, i.Key)) ? ImageState.Approved
                : review > 0 && !force ? ImageState.AwaitingPick
                : ImageState.Missing;
            return new ImageJob(l, i, state, review);
        })).ToList();

    public async Task<int> RunAsync(IEnumerable<Lesson> lessons, bool dryRun, bool force, CancellationToken ct)
    {
        var jobs = Plan(lessons, force);
        var todo = jobs.Where(j => j.State == ImageState.Missing).ToList();
        var needsMascot = todo.Where(j => j.Item.UsesMascot).ToList();

        output.WriteLine($"Images: {todo.Count} prompts to generate x {config.Images.Variants} variants = {todo.Count * config.Images.Variants} images; " +
                         $"{jobs.Count(j => j.State == ImageState.AwaitingPick)} awaiting your pick, {jobs.Count(j => j.State == ImageState.Approved)} approved.");
        foreach (var j in todo)
            output.WriteLine($"  NEW {j.Lesson.Id}/{j.Item.Key}{(j.Item.UsesMascot ? "  [mascot reference]" : "")}");
        if (config.Pricing.ImageUsdEach is { } each)
            output.WriteLine($"Estimated cost: ${todo.Count * config.Images.Variants * each:0.00} at ${each}/image.");
        else
            output.WriteLine("Set pricing.imageUsdEach in content/style/generation.json for a dollar estimate.");

        if (needsMascot.Count > 0 && !File.Exists(layout.MascotReference))
        {
            output.WriteLine($"BLOCKED: {needsMascot.Count} image(s) use the mascot but {Path.GetRelativePath(layout.Root, layout.MascotReference)} does not exist. " +
                             "Run `mascot`, pick a concept, then `mascot --approve N`.");
            if (!dryRun) return 1;
        }
        if (dryRun || todo.Count == 0) { if (dryRun) output.WriteLine("(dry run: nothing was generated)"); return 0; }
        if (client is null) throw new ApiException("OPENAI_API_KEY is not set (use .env, user-secrets or an environment variable).");
        if (!File.Exists(layout.ArtStyleMd)) throw new CurriculumException($"Missing {layout.ArtStyleMd}.");

        var style = (await File.ReadAllTextAsync(layout.ArtStyleMd, ct)).Trim();
        byte[]? mascot = File.Exists(layout.MascotReference) ? await File.ReadAllBytesAsync(layout.MascotReference, ct) : null;

        foreach (var j in todo)
        {
            ct.ThrowIfCancellationRequested();
            var prompt = $"{style}\n\n{j.Item.Prompt}";
            var images = j.Item.UsesMascot
                ? await client.EditAsync(prompt + "\n\nThe mascot from the reference image appears in this scene. Keep it identical.", mascot!, config.Images.Variants, config.Images, ct)
                : await client.GenerateAsync(prompt, config.Images.Variants, config.Images, ct);

            Directory.CreateDirectory(layout.ImageReviewDir(j.Lesson));
            if (force) foreach (var old in layout.ImageReviewFiles(j.Lesson, j.Item.Key)) File.Delete(old);
            for (var n = 0; n < images.Count; n++)
                await File.WriteAllBytesAsync(layout.ImageReview(j.Lesson, j.Item.Key, n + 1), images[n], ct);
            output.WriteLine($"  generated {j.Lesson.Id}/{j.Item.Key} ({images.Count} variants in _review)");
        }
        output.WriteLine("Pick the best variant per image and rename it to {key}.approved.webp in the images folder.");
        return 0;
    }
}

/// <summary>`mascot`: generate concept variants, then `mascot --approve N` locks one as the reference image.</summary>
public class MascotRunner(Layout layout, GenerationConfig config, IImageClient? client, TextWriter output)
{
    public async Task<int> RunAsync(bool dryRun, bool force, int? approve, CancellationToken ct)
    {
        if (approve is { } n)
        {
            var src = layout.MascotReview(n);
            if (!File.Exists(src)) throw new CurriculumException($"No such concept: {src}");
            Directory.CreateDirectory(layout.StyleDir);
            File.Copy(src, layout.MascotReference, overwrite: true);
            output.WriteLine($"Locked mascot reference: {Path.GetRelativePath(layout.Root, layout.MascotReference)}");
            return 0;
        }

        if (File.Exists(layout.MascotReference) && !force)
        {
            output.WriteLine("Mascot is already locked. Use --force to generate new concepts.");
            return 0;
        }
        output.WriteLine($"Mascot: {config.Images.MascotVariants} concept variants into {Path.GetRelativePath(layout.Root, layout.MascotReviewDir)}.");
        if (config.Pricing.ImageUsdEach is { } each)
            output.WriteLine($"Estimated cost: ${config.Images.MascotVariants * each:0.00}.");
        if (dryRun) { output.WriteLine("(dry run: nothing was generated)"); return 0; }

        if (client is null) throw new ApiException("OPENAI_API_KEY is not set (use .env, user-secrets or an environment variable).");
        foreach (var f in new[] { layout.ArtStyleMd, layout.MascotMd })
            if (!File.Exists(f)) throw new CurriculumException($"Missing {f}.");

        var prompt = $"{(await File.ReadAllTextAsync(layout.ArtStyleMd, ct)).Trim()}\n\n{(await File.ReadAllTextAsync(layout.MascotMd, ct)).Trim()}";
        var images = await client.GenerateAsync(prompt, config.Images.MascotVariants, config.Images, ct);
        Directory.CreateDirectory(layout.MascotReviewDir);
        for (var i = 0; i < images.Count; i++) await File.WriteAllBytesAsync(layout.MascotReview(i + 1), images[i], ct);
        output.WriteLine($"Generated {images.Count} concepts. Look at them, then run: mascot --approve N");
        return 0;
    }
}
