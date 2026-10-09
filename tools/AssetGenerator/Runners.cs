using System.Text.Json;
using AssetGenerator.Curriculum;

namespace AssetGenerator;

public enum AudioState { Missing, Changed, UpToDate, Overridden }

public record AudioJob(Lesson Lesson, AudioItem Item, AudioState State, string Hash);

/// <summary>The shared colour palette (content/style/palette.json), used by self-drawn SVGs and added to image prompts.</summary>
public static class Palette
{
    public static Dictionary<string, string> Load(Layout layout)
    {
        if (!File.Exists(layout.PalettePath)) return [];
        using var doc = JsonDocument.Parse(File.ReadAllText(layout.PalettePath), new JsonDocumentOptions { CommentHandling = JsonCommentHandling.Skip, AllowTrailingCommas = true });
        return doc.RootElement.GetProperty("colors").EnumerateObject().ToDictionary(p => p.Name, p => p.Value.GetString()!.ToUpperInvariant());
    }

    public static string PromptSuffix(Layout layout)
    {
        var colors = Load(layout);
        return colors.Count == 0 ? "" : "\n\nPrefer this color palette: " + string.Join(", ", colors.Select(c => $"{c.Key} {c.Value}")) + ".";
    }
}

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
                    !File.Exists(Spoken(lesson, item)) || force ? AudioState.Missing :
                    // File exists but nothing recorded about it: adopt it rather than pay to regenerate.
                    !manifest.Audio.TryGetValue(item.Role, out var entry) || entry.Hash == hash ? AudioState.UpToDate :
                    AudioState.Changed;
                jobs.Add(new AudioJob(lesson, item, state, hash));
            }
        }
        return jobs;
    }

    /// <summary>The file the voice writes: the line itself, or just its spoken first part when the line is composed.</summary>
    private string Spoken(Lesson lesson, AudioItem item) => item.ComposeWord is null ? layout.AudioGen(lesson, item.Role) : layout.AudioPart(lesson, item.Role);

    /// <summary>Builds the composed lines (name, sound, sound, word) from their parts. Free, so it always re-runs: a new recording of a sound or word is picked up.</summary>
    private async Task ComposeAsync(IEnumerable<AudioJob> jobs, CancellationToken ct)
    {
        foreach (var j in jobs.Where(j => j.Item.ComposeWord is not null && j.State != AudioState.Overridden))
        {
            var parts = new[] { Spoken(j.Lesson, j.Item), layout.AudioForExport(j.Lesson, "phoneme"), layout.AudioForExport(j.Lesson, "phoneme"), layout.AudioForExport(j.Lesson, j.Item.ComposeWord!) };
            if (parts.Any(p => p is null || !File.Exists(p)))
            {
                output.WriteLine($"  cannot build {j.Lesson.Id}/{j.Item.Role}: a part is missing (needs the spoken line, the phoneme clip and {j.Item.ComposeWord}).");
                continue;
            }
            await AudioStitcher.JoinAsync(parts!, AudioStitcher.LetterIntroPauses, layout.AudioGen(j.Lesson, j.Item.Role), ct);
            output.WriteLine($"  built {j.Lesson.Id}/{j.Item.Role} from {parts.Length} parts");
        }
    }

    public async Task<int> RunAsync(IEnumerable<Lesson> lessons, bool dryRun, bool force, CancellationToken ct)
    {
        var jobs = Plan(lessons, force);
        var todo = jobs.Where(j => j.State is AudioState.Missing or AudioState.Changed).ToList();
        var rate = config.Pricing.ElevenLabsUsdPer1kChars;
        var ledger = new CostLedger(layout.LedgerPath, config.Pricing.BudgetUsd);

        output.WriteLine($"Audio: {todo.Count} to generate, {jobs.Count(j => j.State == AudioState.UpToDate)} up to date, " +
                         $"{jobs.Count(j => j.State == AudioState.Overridden)} overridden by your recordings.");
        if (dryRun) foreach (var j in todo)
            output.WriteLine($"  {(j.State == AudioState.Changed ? "CHANGED" : "NEW    ")} {j.Lesson.Id}/{j.Item.Role}  ({j.Item.Text.Length} chars)  \"{Truncate(j.Item.Text, 50)}\"");

        var chars = todo.Sum(j => j.Item.Text.Length);
        var planned = chars / 1000m * rate;
        output.WriteLine($"Estimated ElevenLabs usage: {chars} characters ({voices.Model}) = ${planned:0.0000} at ${rate}/1k chars. {ledger.Summary()}");

        if (dryRun) { output.WriteLine("(dry run: nothing was generated)"); return 0; }
        if (todo.Count == 0) { await ComposeAsync(jobs, ct); return 0; }
        if (client is null) throw new ApiException("ELEVENLABS_API_KEY is not set (use .env, user-secrets or an environment variable).");
        ledger.EnsureWithinBudget(planned);

        var voice = voices.Narrator(fallbackVoiceId);
        foreach (var group in todo.GroupBy(j => j.Lesson))
        {
            var manifest = LessonManifest.Load(layout.ManifestPath(group.Key));
            foreach (var j in group)
            {
                ct.ThrowIfCancellationRequested();
                var bytes = await client.SynthesizeAsync(j.Item.Text, voice, voices.Model, voices.OutputFormat, ct);
                var path = Spoken(j.Lesson, j.Item);
                Directory.CreateDirectory(Path.GetDirectoryName(path)!);
                await File.WriteAllBytesAsync(path, bytes, ct);
                manifest.Audio[j.Item.Role] = new ManifestEntry { Hash = j.Hash, GeneratedAtUtc = DateTime.UtcNow };
                manifest.Save(layout.ManifestPath(j.Lesson)); // persist progress after every line
                ledger.Add("ElevenLabs", $"{j.Lesson.Id}/{j.Item.Role} ({j.Item.Text.Length} chars)", j.Item.Text.Length / 1000m * rate);
            }
            output.WriteLine($"  generated {group.Key.Id}: {group.Count()} line(s)");
        }
        await ComposeAsync(jobs, ct);
        output.WriteLine(ledger.Summary());
        return 0;
    }

    private static string Truncate(string s, int n) => s.Length <= n ? s : s[..n] + "...";
}

public enum ImageState { Missing, AwaitingPick, Approved, SelfDrawn, MissingSvg }

public record ImageJob(Lesson Lesson, ImageItem Item, ImageState State, int ReviewCount);

/// <summary>`images`: generate variants into _review for OpenAI-sourced words. Self-drawn (svg) words are never sent to OpenAI.</summary>
public class ImageRunner(Layout layout, GenerationConfig config, IImageClient? client, TextWriter output)
{
    public IReadOnlyList<ImageJob> Plan(IEnumerable<Lesson> lessons, bool force) =>
        lessons.SelectMany(l => LessonPlan.Images(l).Select(i =>
        {
            if (i.IsSvg) return new ImageJob(l, i, File.Exists(layout.SvgSource(l, i.Key)) ? ImageState.SelfDrawn : ImageState.MissingSvg, 0);
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
        var ledger = new CostLedger(layout.LedgerPath, config.Pricing.BudgetUsd);
        var count = todo.Count * config.Images.Variants;
        var planned = count * config.Pricing.ImageFallbackUsdEach;

        output.WriteLine($"Images: {todo.Count} prompts x {config.Images.Variants} variants = {count} images to generate; " +
                         $"{jobs.Count(j => j.State == ImageState.AwaitingPick)} awaiting pick, {jobs.Count(j => j.State == ImageState.Approved)} approved, " +
                         $"{jobs.Count(j => j.State == ImageState.SelfDrawn)} self-drawn (never sent to OpenAI).");
        foreach (var j in jobs.Where(j => j.State == ImageState.MissingSvg))
            output.WriteLine($"  MISSING SVG {j.Lesson.Id}/{j.Item.Key}: expected {Path.GetRelativePath(layout.Root, layout.SvgSource(j.Lesson, j.Item.Key))}");
        if (dryRun) foreach (var j in todo)
            output.WriteLine($"  NEW {j.Lesson.Id}/{j.Item.Key}{(j.Item.UsesMascot ? "  [mascot reference]" : "")}");
        output.WriteLine($"Estimated cost: ~${planned:0.00} (${config.Pricing.ImageFallbackUsdEach}/image; actual cost is taken from API usage). {ledger.Summary()}");

        if (needsMascot.Count > 0 && !File.Exists(layout.MascotReference))
        {
            output.WriteLine($"BLOCKED: {needsMascot.Count} image(s) use the mascot but {Path.GetRelativePath(layout.Root, layout.MascotReference)} does not exist. " +
                             "Run `mascot`, then `mascot --approve N`.");
            if (!dryRun) return 1;
        }
        if (dryRun || todo.Count == 0) { if (dryRun) output.WriteLine("(dry run: nothing was generated)"); return 0; }
        if (client is null) throw new ApiException("OPENAI_API_KEY is not set (use .env, user-secrets or an environment variable).");
        if (!File.Exists(layout.ArtStyleMd)) throw new CurriculumException($"Missing {layout.ArtStyleMd}.");
        ledger.EnsureWithinBudget(planned);

        var style = (await File.ReadAllTextAsync(layout.ArtStyleMd, ct)).Trim() + Palette.PromptSuffix(layout);
        byte[]? mascot = File.Exists(layout.MascotReference) ? await File.ReadAllBytesAsync(layout.MascotReference, ct) : null;

        foreach (var j in todo)
        {
            ct.ThrowIfCancellationRequested();
            var prompt = $"{style}\n\n{j.Item.Prompt}";
            var batch = j.Item.UsesMascot
                ? await client.EditAsync(prompt + "\n\nThe mascot from the reference image appears in this scene. Keep it identical.", mascot!, config.Images.Variants, config.Images, ct)
                : await client.GenerateAsync(prompt, config.Images.Variants, config.Images, ct);

            Directory.CreateDirectory(layout.ImageReviewDir(j.Lesson));
            if (force) foreach (var old in layout.ImageReviewFiles(j.Lesson, j.Item.Key)) File.Delete(old);
            for (var n = 0; n < batch.Images.Count; n++)
                await File.WriteAllBytesAsync(layout.ImageReview(j.Lesson, j.Item.Key, n + 1), batch.Images[n], ct);

            var usd = batch.Usage?.Cost(config.Pricing) ?? batch.Images.Count * config.Pricing.ImageFallbackUsdEach;
            ledger.Add("OpenAI", $"{j.Lesson.Id}/{j.Item.Key} x{batch.Images.Count}", usd, estimated: batch.Usage is null);
            output.WriteLine($"  generated {j.Lesson.Id}/{j.Item.Key} ({batch.Images.Count} variants, ${usd:0.000})");
        }
        output.WriteLine(ledger.Summary());
        return 0;
    }
}

/// <summary>`mascot`: generate concept variants, then `mascot --approve N` locks one as the reference image.</summary>
public class MascotRunner(Layout layout, GenerationConfig config, IImageClient? client, TextWriter output)
{
    public async Task<int> RunAsync(bool dryRun, bool force, int? approve, string? reason, CancellationToken ct)
    {
        if (approve is { } n)
        {
            var src = layout.MascotReview(n);
            if (!File.Exists(src)) throw new CurriculumException($"No such concept: {src}");
            Directory.CreateDirectory(layout.StyleDir);
            File.Copy(src, layout.MascotReference, overwrite: true);
            Picks.Record(layout, new Pick("mascot", "mascot", "OpenAI", $"v{n}", reason ?? "", DateTime.UtcNow));
            output.WriteLine($"Locked mascot reference: {Path.GetRelativePath(layout.Root, layout.MascotReference)}");
            return 0;
        }

        if (File.Exists(layout.MascotReference) && !force)
        {
            output.WriteLine("Mascot is already locked. Use --force to generate new concepts.");
            return 0;
        }
        var ledger = new CostLedger(layout.LedgerPath, config.Pricing.BudgetUsd);
        var planned = config.Images.MascotVariants * config.Pricing.ImageFallbackUsdEach;
        output.WriteLine($"Mascot: {config.Images.MascotVariants} concept variants into {Path.GetRelativePath(layout.Root, layout.MascotReviewDir)}. Estimated ~${planned:0.00}. {ledger.Summary()}");
        if (dryRun) { output.WriteLine("(dry run: nothing was generated)"); return 0; }

        if (client is null) throw new ApiException("OPENAI_API_KEY is not set (use .env, user-secrets or an environment variable).");
        foreach (var f in new[] { layout.ArtStyleMd, layout.MascotMd })
            if (!File.Exists(f)) throw new CurriculumException($"Missing {f}.");
        ledger.EnsureWithinBudget(planned);

        var prompt = $"{(await File.ReadAllTextAsync(layout.ArtStyleMd, ct)).Trim()}{Palette.PromptSuffix(layout)}\n\n{(await File.ReadAllTextAsync(layout.MascotMd, ct)).Trim()}";
        var batch = await client.GenerateAsync(prompt, config.Images.MascotVariants, config.Images, ct);
        Directory.CreateDirectory(layout.MascotReviewDir);
        for (var i = 0; i < batch.Images.Count; i++) await File.WriteAllBytesAsync(layout.MascotReview(i + 1), batch.Images[i], ct);
        ledger.Add("OpenAI", $"mascot concepts x{batch.Images.Count}", batch.Usage?.Cost(config.Pricing) ?? batch.Images.Count * config.Pricing.ImageFallbackUsdEach, estimated: batch.Usage is null);
        output.WriteLine($"Generated {batch.Images.Count} concepts. Look at them, then run: mascot --approve N --reason \"...\"");
        return 0;
    }
}

public record Pick(string Lesson, string Key, string Source, string Variant, string Reason, DateTime DecidedAtUtc);

/// <summary>Every approval (and its one-line reason) is stored so docs/asset-decisions.md can be regenerated and picks swapped later.</summary>
public static class Picks
{
    public static List<Pick> Load(Layout layout) =>
        File.Exists(layout.PicksPath)
            ? JsonSerializer.Deserialize<List<Pick>>(File.ReadAllText(layout.PicksPath), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? []
            : [];

    public static void Record(Layout layout, Pick pick)
    {
        var all = Load(layout);
        all.RemoveAll(p => p.Lesson == pick.Lesson && p.Key == pick.Key);
        all.Add(pick);
        Directory.CreateDirectory(Path.GetDirectoryName(layout.PicksPath)!);
        File.WriteAllText(layout.PicksPath, ConfigLoader.ToJson(all.OrderBy(p => p.Lesson).ThenBy(p => p.Key).ToList()));
    }
}

/// <summary>`approve`: copy a reviewed variant to {key}.approved.webp and record why.</summary>
public static class ApproveCommand
{
    public static void Run(Layout layout, Lesson lesson, string key, int variant, string reason, TextWriter output)
    {
        var img = LessonPlan.Images(lesson).FirstOrDefault(i => i.Key == key) ?? throw new CurriculumException($"{lesson.Id} has no word '{key}'.");
        if (img.IsSvg) throw new CurriculumException($"{lesson.Id}/{key} is self-drawn; there is nothing to approve.");
        var src = layout.ImageReview(lesson, key, variant);
        if (!File.Exists(src)) throw new CurriculumException($"No such variant: {Path.GetRelativePath(layout.Root, src)}");
        Directory.CreateDirectory(Path.GetDirectoryName(layout.ImageApproved(lesson, key))!);
        File.Copy(src, layout.ImageApproved(lesson, key), overwrite: true);
        Picks.Record(layout, new Pick(lesson.Id, key, "OpenAI", $"v{variant}", reason, DateTime.UtcNow));
        output.WriteLine($"Approved {lesson.Id}/{key} v{variant}.");
    }
}
