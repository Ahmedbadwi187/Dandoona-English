using System.Text.Json.Serialization;
using AssetGenerator.Curriculum;

namespace AssetGenerator;

public record StatusLine(string Lesson, string Item, string State);
public record StatusReport(IReadOnlyList<StatusLine> Lines, IReadOnlyList<string> PhonemesWithoutOverride, bool MascotLocked);

/// <summary>`status`: what exists, what is missing, what awaits your pick, and every phoneme still lacking your own recording.</summary>
public class StatusRunner(Layout layout, VoiceConfig voices, string? fallbackVoiceId, TextWriter output)
{
    public StatusReport Build(IEnumerable<Lesson> lessons)
    {
        VoiceSettings? voice = null;
        try { voice = voices.Narrator(fallbackVoiceId); } catch (CurriculumException) { /* stale detection needs a voice id; skip without it */ }

        var lines = new List<StatusLine>();
        var phonemes = new List<string>();
        foreach (var l in lessons)
        {
            var manifest = LessonManifest.Load(layout.ManifestPath(l));
            foreach (var a in LessonPlan.Audio(l))
            {
                string state;
                if (File.Exists(layout.AudioOverride(l, a.Role))) state = "override";
                else if (!File.Exists(layout.AudioGen(l, a.Role))) state = "MISSING";
                else if (voice is not null && manifest.Audio.TryGetValue(a.Role, out var e) &&
                         e.Hash != Hashing.AudioHash(a.Text, voice, voices.Model, voices.OutputFormat)) state = "STALE (text/voice changed)";
                else state = "generated";
                lines.Add(new StatusLine(l.Id, $"audio/{a.Role}", state));
                if (a.IsPhoneme && state != "override") phonemes.Add($"{l.Id} ({l.Phoneme}) - {state}");
            }
            foreach (var i in LessonPlan.Images(l))
            {
                var review = layout.ImageReviewFiles(l, i.Key).Count;
                var state = i.IsSvg ? (File.Exists(layout.SvgSource(l, i.Key)) ? "self-drawn (svg)" : "MISSING SVG")
                    : File.Exists(layout.ImageApproved(l, i.Key)) ? "approved"
                    : review > 0 ? $"awaiting pick ({review} variants)" : "MISSING";
                lines.Add(new StatusLine(l.Id, $"image/{i.Key}{(i.UsesMascot ? " [mascot]" : "")}", state));
            }
        }
        return new StatusReport(lines, phonemes, File.Exists(layout.MascotReference));
    }

    public StatusReport Run(IEnumerable<Lesson> lessons)
    {
        var report = Build(lessons);
        foreach (var g in report.Lines.GroupBy(x => x.Lesson))
        {
            output.WriteLine(g.Key);
            foreach (var x in g) output.WriteLine($"  {x.Item,-28} {x.State}");
        }
        output.WriteLine();
        output.WriteLine($"Mascot reference: {(report.MascotLocked ? "locked" : "NOT locked (run `mascot`)")}");
        output.WriteLine(report.PhonemesWithoutOverride.Count == 0
            ? "All phoneme clips have your own recording."
            : $"Phoneme clips without your own recording ({report.PhonemesWithoutOverride.Count}) - TTS is unreliable for isolated sounds:");
        foreach (var p in report.PhonemesWithoutOverride) output.WriteLine($"  {p}");
        return report;
    }
}

public record ExportDoc(int SchemaVersion, string Track, DateTime GeneratedAt, string? Mascot, List<ExportUnit> Units, List<ExportPlacement>? Placement = null, ExportUnitAudio? App = null, List<ExportReview>? Reviews = null);
public record ExportReview(string Id, List<string> Units);
public record ExportPlacement(int Level, string Key, List<string> DoneUnits, string StartUnit);
public record ExportUnit(string Id, int Order, Dictionary<string, string> Title, string Icon, string Color, ExportUnitAudio? Audio, List<ExportLesson> Lessons, ExportPackRef? Pack = null, ExportChest? Chest = null, ExportStory? Story = null);
public record ExportStory(List<ExportStoryPage> Pages);
public record ExportStoryPage(string Text, string Audio, List<string> Words, string? Pose);
public record ExportChest(string Accessory, List<string> Stickers);
public record ExportUnitAudio(string Title, string? Welcome, string Celebration, Dictionary<string, string>? Lines = null);
public record ExportLesson(string Id, int Order, string Level, string? Letter, string? Phoneme,
    ExportLessonAudio Audio, List<ExportWord> Words, List<string> Activities, ExportColor? Color = null, bool? Counting = null, bool? OwnWordsOnly = null);
public record ExportLessonAudio(string Intro, string? Phoneme, List<string> Praise, Dictionary<string, string>? Instructions = null, string? ColorName = null);
public record ExportWord(string Word, string Audio, string Image, string? Phrase = null, string? Sound = null, string? Lives = null, string? Home = null);
public record ExportColor(string Name, string Hex, string Swatch, string Drawing);

public record ExportResult(int Exported, IReadOnlyList<string> Incomplete, long TotalBytes, string? JsonPath);

/// <summary>`export`: encode approved media into the Flutter assets folder and write the lesson JSON the app reads.</summary>
public class ExportRunner(Layout layout, GenerationConfig config, IMediaTool media, TextWriter output, Func<DateTime>? now = null)
{
    public const int SchemaVersion = 2;

    public async Task<ExportResult> RunAsync(string track, IReadOnlyList<Lesson> lessons, CancellationToken ct, bool force = false, IReadOnlyList<UnitDef>? units = null, IReadOnlyList<PlacementDef>? placement = null, UnitDef? app = null, IReadOnlyList<ReviewDef>? reviews = null)
    {
        var exported = new List<(string UnitId, ExportLesson Lesson)>();
        var incomplete = new List<string>();
        long bytes = 0;

        var packUnits = (units ?? []).Where(u => u.Track == track && u.IsPack).Select(u => u.Id).ToHashSet();
        foreach (var id in packUnits)
            if (Directory.Exists(PackBuildDir(track, id))) Directory.Delete(PackBuildDir(track, id), recursive: true);

        foreach (var l in lessons.Where(x => x.Track == track))
        {
            var missing = new List<string>();
            foreach (var a in LessonPlan.Audio(l)) if (layout.AudioForExport(l, a.Role) is null) missing.Add($"audio/{a.Role}");
            foreach (var i in LessonPlan.Images(l))
            {
                if (i.IsSvg && !File.Exists(layout.SvgSource(l, i.Key))) missing.Add($"image/{i.Key} (svg missing)");
                else if (!i.IsSvg && !File.Exists(layout.ImageApproved(l, i.Key))) missing.Add($"image/{i.Key} (not approved)");
            }
            foreach (var (key, reuse) in LessonPlan.Reused(l))
                if (layout.ReuseSource(l, reuse) is null) missing.Add($"image/{key} (reused picture {reuse} not found)");
            if (l.Color is not null)
            {
                if (!File.Exists(layout.SvgSource(l, "swatch"))) missing.Add("image/swatch (svg missing)");
                if (!File.Exists(layout.SvgSource(l, "colorable"))) missing.Add("image/colorable (svg missing)");
            }
            if (missing.Count > 0)
            {
                incomplete.Add($"{l.Id}: {string.Join(", ", missing)}");
                continue;
            }

            // A pack unit's lessons go into its pack (built fresh each export), every other lesson into the app's assets.
            var dir = packUnits.Contains(l.Unit) ? PackBuildDir(track, l.Unit) : layout.AssetsDir;

            foreach (var a in LessonPlan.Audio(l))
                bytes += await EncodeIfNeededAsync(layout.AudioForExport(l, a.Role)!, Path.Combine(dir, Layout.ExportAudioRel(l, a.Role)), audio: true, force, ct);
            foreach (var i in LessonPlan.Images(l))
                bytes += i.IsSvg
                    ? await CopyIfNeededAsync(layout.SvgSource(l, i.Key), Path.Combine(dir, Layout.ExportImageRel(l, i.Key, svg: true)), force)
                    : await EncodeIfNeededAsync(layout.ImageApproved(l, i.Key), Path.Combine(dir, Layout.ExportImageRel(l, i.Key)), audio: false, force, ct);

            // Pictures reused from another lesson are copied into this lesson's folder.
            var reusedSvg = new Dictionary<string, bool>();
            foreach (var (key, reuse) in LessonPlan.Reused(l))
            {
                var src = layout.ReuseSource(l, reuse)!.Value;
                reusedSvg[key] = src.Svg;
                var target = Path.Combine(dir, Layout.ExportImageRel(l, key, src.Svg));
                bytes += src.Svg ? await CopyIfNeededAsync(src.Path, target, force) : await EncodeIfNeededAsync(src.Path, target, audio: false, force, ct);
            }

            ExportColor? color = null;
            if (l.Color is not null)
            {
                bytes += await CopyIfNeededAsync(layout.SvgSource(l, "swatch"), Path.Combine(dir, Layout.ExportImageRel(l, "swatch", svg: true)), force);
                bytes += await CopyIfNeededAsync(layout.SvgSource(l, "colorable"), Path.Combine(dir, Layout.ExportImageRel(l, "colorable", svg: true)), force);
                color = new ExportColor(l.Color.Name, l.Color.Hex, Layout.ExportImageRel(l, "swatch", svg: true), Layout.ExportImageRel(l, "colorable", svg: true));
            }

            string? PhraseFor(LessonWord w) =>
                LessonPlan.Audio(l).Any(a => a.Role == LessonPlan.PhraseRole(w.Word)) ? Layout.ExportAudioRel(l, LessonPlan.PhraseRole(w.Word)) : null;

            exported.Add((l.Unit.Length == 0 ? "main" : l.Unit, new ExportLesson(
                l.Id, l.ResolvedOrder, l.Level, l.Letter, l.Phoneme,
                new ExportLessonAudio(
                    Layout.ExportAudioRel(l, "intro"),
                    string.IsNullOrWhiteSpace(l.Phoneme) ? null : Layout.ExportAudioRel(l, "phoneme"),
                    l.Narration.Praise.Select((_, n) => Layout.ExportAudioRel(l, $"praise-{n}")).ToList(),
                    l.Narration.Instructions.Count == 0 ? null : l.Narration.Instructions.OrderBy(k => k.Key, StringComparer.Ordinal).ToDictionary(k => k.Key, k => Layout.ExportAudioRel(l, LessonPlan.InstructionRole(k.Key))),
                    string.IsNullOrWhiteSpace(l.Narration.ColorName) ? null : Layout.ExportAudioRel(l, "color-name")),
                l.Words.Select(w =>
                {
                    var key = LessonPlan.Slug(w.Word);
                    var svg = w.Reuse is not null ? reusedSvg[key] : w.Source == "svg";
                    return new ExportWord(w.Word.Trim(), Layout.ExportAudioRel(l, $"word-{key}"), Layout.ExportImageRel(l, key, svg), PhraseFor(w), w.Sound is null ? null : Layout.ExportAudioRel(l, LessonPlan.SoundRole(w.Word)), w.Lives is null ? null : Layout.ExportAudioRel(l, LessonPlan.LivesRole(w.Word)), w.Home);
                }).ToList(),
                l.Activities.ToList(),
                color,
                l.Counting ? true : null,
                l.OwnWordsOnly ? true : null)));
        }

        // Units: ordered as in the units file. With a units file every unit is listed, even without lessons yet (the app shows it locked).
        var doc = new List<ExportUnit>();
        var packs = new PackBuilder(layout);
        var packEntries = new List<PackIndexEntry>();
        var defs = units?.Where(u => u.Track == track).OrderBy(u => u.Order).ToList() ?? [];
        if (defs.Count == 0)
            defs = exported.Select(e => e.UnitId).Distinct().Select((id, n) => new UnitDef { Id = id, Track = track, Order = n + 1, Title = new() { ["en"] = id, ["ar"] = id }, Icon = id }).ToList();
        foreach (var u in defs)
        {
            var unitLessons = exported.Where(e => e.UnitId == u.Id).Select(e => e.Lesson).OrderBy(x => x.Order).ToList();
            if (unitLessons.Count == 0 && units is not { Count: > 0 }) continue; // with a units file, empty units still appear (as "coming soon")
            ExportUnitAudio? audio = null;
            if (units is { Count: > 0 })
            {
                var (a, why) = await UnitAudioAsync(CurriculumReader.UnitAudioLesson(u), u.Narration.Welcome, force, ct);
                audio = a;
                if (why is not null) incomplete.Add(why);
            }
            if (u.IsPack && unitLessons.Count > 0)
            {
                // The app gets only what it needs to show and fetch the pack; the lessons travel inside the pack.
                var entry = packs.Build(track, u.Id, unitLessons);
                packEntries.Add(entry);
                doc.Add(new ExportUnit(u.Id, u.Order, u.Title, u.Icon, u.Color, audio, [], new ExportPackRef(entry.Version, entry.Sha256, entry.Bytes, entry.Manifest, entry.LessonIds), ChestOf(u), StoryOf(u)));
                output.WriteLine($"  pack {u.Id}: v{entry.Version}, {entry.Bytes / 1024.0:0.0} KB");
            }
            else doc.Add(new ExportUnit(u.Id, u.Order, u.Title, u.Icon, u.Color, audio, unitLessons, null, ChestOf(u), StoryOf(u)));
        }
        if (units is { Count: > 0 } && units.Any(u => u.Track == track && u.IsPack)) packs.Save(track, packEntries);

        // Dandoona's app-level lines (Who is playing?, the first greeting, Welcome back): same audio pipeline as a unit's lines.
        ExportUnitAudio? appAudio = null;
        if (app is not null)
        {
            var (a, why) = await UnitAudioAsync(CurriculumReader.UnitAudioLesson(app), app.Narration.Welcome, force, ct);
            appAudio = a;
            if (why is not null) incomplete.Add(why);
        }

        string? mascot = null;
        if (File.Exists(layout.MascotReference))
        {
            bytes += await EncodeIfNeededAsync(layout.MascotReference, Path.Combine(layout.AssetsDir, Layout.ExportMascotRel), audio: false, force, ct);
            mascot = Layout.ExportMascotRel;
        }

        // Drawn avatars for the child profile picker.
        if (Directory.Exists(layout.AvatarsDir))
            foreach (var svg in Directory.GetFiles(layout.AvatarsDir, "*.svg").Order(StringComparer.Ordinal))
                bytes += await CopyIfNeededAsync(svg, Path.Combine(layout.AssetsDir, Layout.ExportAvatarRel(Path.GetFileName(svg))), force);

        // Dandoona's other poses (onboarding, celebrations).
        if (Directory.Exists(layout.PosesDir))
            foreach (var pose in Directory.GetFiles(layout.PosesDir, "*.webp").Order(StringComparer.Ordinal))
                bytes += await EncodeIfNeededAsync(pose, Path.Combine(layout.AssetsDir, Layout.ExportPoseRel(Path.GetFileNameWithoutExtension(pose))), audio: false, force, ct);

        // Self-drawn mascot accessories (rewards) ship with the app too.
        if (Directory.Exists(layout.AccessoriesDir))
            foreach (var svg in Directory.GetFiles(layout.AccessoriesDir, "*.svg").Order(StringComparer.Ordinal))
                bytes += await CopyIfNeededAsync(svg, Path.Combine(layout.AssetsDir, Layout.ExportAccessoryRel(Path.GetFileName(svg))), force);

        string? jsonPath = null;
        if (doc.Count > 0)
        {
            jsonPath = Path.Combine(layout.AssetsDir, Layout.ExportJsonRel(track));
            Directory.CreateDirectory(Path.GetDirectoryName(jsonPath)!);
            var json = ConfigLoader.ToJson(new ExportDoc(SchemaVersion, track, (now ?? (() => DateTime.UtcNow))(), mascot, doc,
                placement?.Where(p => p.Track == track).OrderBy(p => p.Level).Select(p => new ExportPlacement(p.Level, p.Key, p.DoneUnits, p.StartUnit)).ToList() is { Count: > 0 } pl ? pl : null, appAudio,
                reviews is { Count: > 0 } ? reviews.Select(r => new ExportReview(r.Id, r.Units)).ToList() : null));
            await File.WriteAllTextAsync(jsonPath, json, ct);
            bytes += new FileInfo(jsonPath).Length;
            UpdatePubspec();
        }

        output.WriteLine($"Export ({track}): {exported.Count} lesson(s) exported in {doc.Count} unit(s), {incomplete.Count} incomplete (skipped).");
        foreach (var i in incomplete) output.WriteLine($"  incomplete: {i}");
        output.WriteLine($"Total exported asset size: {bytes / 1024.0:0.0} KB");
        return new ExportResult(exported.Count, incomplete, bytes, jsonPath);
    }

    private string PackBuildDir(string track, string unit) => PackBuilder.BuildDir(layout, track, unit);

    private static readonly string[] CoreUnitRoles = ["intro", LessonPlan.InstructionRole("title"), LessonPlan.InstructionRole("celebration")];

    /// <summary>A unit's (or the app's) own lines, always bundled. Its name, welcome and celebration must all have audio;
    /// the extra lines (locked, coming-soon...) are included when their audio exists and simply left out when it does not
    /// yet, so a new line never silences the ones already made.</summary>
    private async Task<(ExportUnitAudio? Audio, string? Incomplete)> UnitAudioAsync(Lesson ul, string welcome, bool force, CancellationToken ct)
    {
        var plan = LessonPlan.Audio(ul);
        if (plan.Where(a => CoreUnitRoles.Contains(a.Role)).Any(a => layout.AudioForExport(ul, a.Role) is null))
            return (null, $"{ul.Id}: unit audio missing (run audio)");
        var lines = new Dictionary<string, string>();
        var missing = new List<string>();
        foreach (var a in plan)
        {
            var source = layout.AudioForExport(ul, a.Role);
            if (source is null) { missing.Add(a.Role); continue; }
            await EncodeIfNeededAsync(source, Path.Combine(layout.AssetsDir, Layout.ExportAudioRel(ul, a.Role)), audio: true, force, ct);
            if (!CoreUnitRoles.Contains(a.Role)) lines[a.Role["instr-".Length..]] = Layout.ExportAudioRel(ul, a.Role);
        }
        var audio = new ExportUnitAudio(
            Layout.ExportAudioRel(ul, LessonPlan.InstructionRole("title")),
            string.IsNullOrWhiteSpace(welcome) && ul.Id != "unit-app" ? null : Layout.ExportAudioRel(ul, "intro"),
            Layout.ExportAudioRel(ul, LessonPlan.InstructionRole("celebration")),
            lines.Count == 0 ? null : lines.OrderBy(k => k.Key, StringComparer.Ordinal).ToDictionary());
        return (audio, missing.Count == 0 ? null : $"{ul.Id}: no audio yet for {string.Join(", ", missing)} (run audio)");
    }

    private static ExportStory? StoryOf(UnitDef u) => u.Story is null ? null : new ExportStory(Enumerable.Range(0, u.Story.Pages.Count).Select(i =>
        new ExportStoryPage(u.Story.Pages[i].Text.Trim(), Layout.ExportAudioRel(CurriculumReader.UnitAudioLesson(u), LessonPlan.InstructionRole($"story-{i + 1}")), u.Story.Pages[i].Words.Select(w => w.Trim()).ToList(), u.Story.Pages[i].Pose)).ToList());

    private static ExportChest? ChestOf(UnitDef u) => u.Chest is null ? null : new ExportChest(u.Chest.Accessory, u.Chest.Stickers.Select(s => s.Trim()).ToList());

    private async Task<long> CopyIfNeededAsync(string source, string target, bool force)
    {
        if (force || !File.Exists(target) || File.GetLastWriteTimeUtc(source) > File.GetLastWriteTimeUtc(target))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            File.Copy(source, target, overwrite: true);
        }
        return new FileInfo(target).Length;
    }

    private async Task<long> EncodeIfNeededAsync(string source, string target, bool audio, bool force, CancellationToken ct)
    {
        // Incremental: re-encode only when forced or the source is newer than the exported file.
        if (force || !File.Exists(target) || File.GetLastWriteTimeUtc(source) > File.GetLastWriteTimeUtc(target))
        {
            if (audio) await media.EncodeAudioAsync(source, target, config.Export, ct);
            else await media.EncodeImageAsync(source, target, config.Export, ct);
        }
        return new FileInfo(target).Length;
    }

    private void UpdatePubspec()
    {
        if (!File.Exists(layout.Pubspec))
        {
            output.WriteLine("  note: mobile/kids_english_app/pubspec.yaml does not exist yet; re-run export after the Flutter app is created so every asset folder is registered.");
            return;
        }
        var text = File.ReadAllText(layout.Pubspec);
        // Flutter does not include subfolders of a listed asset folder, so every folder that holds files is registered.
        var folders = new[] { "audio", "images", "content" }
            .Select(r => Path.Combine(layout.AssetsDir, r))
            .Where(Directory.Exists)
            .SelectMany(r => Directory.EnumerateDirectories(r, "*", SearchOption.AllDirectories).Prepend(r))
            .Where(d => Directory.EnumerateFiles(d).Any())
            .Select(d => "assets/" + Path.GetRelativePath(layout.AssetsDir, d).Replace('\\', '/') + "/")
            .Order(StringComparer.Ordinal)
            .ToList();
        var (updated, changed) = PubspecUpdater.EnsureAssets(text, folders);
        if (changed) { File.WriteAllText(layout.Pubspec, updated); output.WriteLine("  pubspec.yaml: registered asset folders."); }
    }
}

/// <summary>Minimal, idempotent text edit of pubspec.yaml so comments and formatting are preserved.</summary>
public static class PubspecUpdater
{
    public static (string Text, bool Changed) EnsureAssets(string text, IReadOnlyList<string> entries)
    {
        var nl = text.Contains("\r\n") ? "\r\n" : "\n";
        var lines = text.Split(["\r\n", "\n"], StringSplitOptions.None).ToList();

        var flutter = lines.FindIndex(l => l.TrimEnd() == "flutter:");
        if (flutter < 0)
        {
            if (lines.Count > 0 && lines[^1].Length == 0) lines.RemoveAt(lines.Count - 1);
            lines.Add("");
            lines.Add("flutter:");
            lines.Add("  assets:");
            lines.AddRange(entries.Select(e => $"    - {e}"));
            lines.Add("");
            return (string.Join(nl, lines), true);
        }

        var end = flutter + 1;
        while (end < lines.Count && (lines[end].Length == 0 || lines[end][0] == ' ' || lines[end][0] == '#')) end++;

        var assets = lines.FindIndex(flutter + 1, end - flutter - 1, l => l.TrimEnd() == "  assets:");
        if (assets < 0)
        {
            lines.InsertRange(flutter + 1, new[] { "  assets:" }.Concat(entries.Select(e => $"    - {e}")));
            return (string.Join(nl, lines), true);
        }

        var last = assets;
        var existing = new HashSet<string>();
        for (var i = assets + 1; i < lines.Count && lines[i].TrimStart().StartsWith("- "); i++)
        {
            existing.Add(lines[i].Trim()[2..].Trim());
            last = i;
        }
        var missing = entries.Where(e => !existing.Contains(e)).ToList();
        if (missing.Count == 0) return (text, false);
        lines.InsertRange(last + 1, missing.Select(e => $"    - {e}"));
        return (string.Join(nl, lines), true);
    }
}
