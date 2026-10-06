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

public record ExportDoc(int SchemaVersion, string Track, DateTime GeneratedAt, string? Mascot, List<ExportLesson> Lessons);
public record ExportLesson(string Id, int Order, string Level, string? Letter, string? Phoneme,
    ExportLessonAudio Audio, List<ExportWord> Words, List<string> Activities);
public record ExportLessonAudio(string Intro, string? Phoneme, List<string> Praise);
public record ExportWord(string Word, string Audio, string Image);

public record ExportResult(int Exported, IReadOnlyList<string> Incomplete, long TotalBytes, string? JsonPath);

/// <summary>`export`: encode approved media into the Flutter assets folder and write the lesson JSON the app reads.</summary>
public class ExportRunner(Layout layout, GenerationConfig config, IMediaTool media, TextWriter output, Func<DateTime>? now = null)
{
    public const int SchemaVersion = 1;

    public async Task<ExportResult> RunAsync(string track, IReadOnlyList<Lesson> lessons, CancellationToken ct, bool force = false)
    {
        var doc = new List<ExportLesson>();
        var incomplete = new List<string>();
        long bytes = 0;

        foreach (var l in lessons.Where(x => x.Track == track))
        {
            var missing = new List<string>();
            foreach (var a in LessonPlan.Audio(l)) if (layout.AudioForExport(l, a.Role) is null) missing.Add($"audio/{a.Role}");
            foreach (var i in LessonPlan.Images(l))
            {
                if (i.IsSvg && !File.Exists(layout.SvgSource(l, i.Key))) missing.Add($"image/{i.Key} (svg missing)");
                else if (!i.IsSvg && !File.Exists(layout.ImageApproved(l, i.Key))) missing.Add($"image/{i.Key} (not approved)");
            }
            if (missing.Count > 0)
            {
                incomplete.Add($"{l.Id}: {string.Join(", ", missing)}");
                continue;
            }

            foreach (var a in LessonPlan.Audio(l))
                bytes += await EncodeIfNeededAsync(layout.AudioForExport(l, a.Role)!, Path.Combine(layout.AssetsDir, Layout.ExportAudioRel(l, a.Role)), audio: true, force, ct);
            foreach (var i in LessonPlan.Images(l))
                bytes += i.IsSvg
                    ? await CopyIfNeededAsync(layout.SvgSource(l, i.Key), Path.Combine(layout.AssetsDir, Layout.ExportImageRel(l, i.Key, svg: true)), force)
                    : await EncodeIfNeededAsync(layout.ImageApproved(l, i.Key), Path.Combine(layout.AssetsDir, Layout.ExportImageRel(l, i.Key)), audio: false, force, ct);

            doc.Add(new ExportLesson(
                l.Id, l.ResolvedOrder, l.Level, l.Letter, l.Phoneme,
                new ExportLessonAudio(
                    Layout.ExportAudioRel(l, "intro"),
                    string.IsNullOrWhiteSpace(l.Phoneme) ? null : Layout.ExportAudioRel(l, "phoneme"),
                    l.Narration.Praise.Select((_, n) => Layout.ExportAudioRel(l, $"praise-{n}")).ToList()),
                l.Words.Select(w => new ExportWord(w.Word.Trim(), Layout.ExportAudioRel(l, $"word-{LessonPlan.Slug(w.Word)}"), Layout.ExportImageRel(l, LessonPlan.Slug(w.Word), w.Source == "svg"))).ToList(),
                l.Activities.ToList()));
        }

        string? mascot = null;
        if (File.Exists(layout.MascotReference))
        {
            bytes += await EncodeIfNeededAsync(layout.MascotReference, Path.Combine(layout.AssetsDir, Layout.ExportMascotRel), audio: false, force, ct);
            mascot = Layout.ExportMascotRel;
        }

        // Self-drawn mascot accessories (rewards) ship with the app too.
        if (Directory.Exists(layout.AccessoriesDir))
            foreach (var svg in Directory.GetFiles(layout.AccessoriesDir, "*.svg").Order(StringComparer.Ordinal))
                bytes += await CopyIfNeededAsync(svg, Path.Combine(layout.AssetsDir, Layout.ExportAccessoryRel(Path.GetFileName(svg))), force);

        string? jsonPath = null;
        if (doc.Count > 0)
        {
            jsonPath = Path.Combine(layout.AssetsDir, Layout.ExportJsonRel(track));
            Directory.CreateDirectory(Path.GetDirectoryName(jsonPath)!);
            var json = ConfigLoader.ToJson(new ExportDoc(SchemaVersion, track, (now ?? (() => DateTime.UtcNow))(), mascot, doc));
            await File.WriteAllTextAsync(jsonPath, json, ct);
            bytes += new FileInfo(jsonPath).Length;
            UpdatePubspec();
        }

        output.WriteLine($"Export ({track}): {doc.Count} lesson(s) exported, {incomplete.Count} incomplete (skipped).");
        foreach (var i in incomplete) output.WriteLine($"  incomplete: {i}");
        output.WriteLine($"Total exported asset size: {bytes / 1024.0:0.0} KB");
        return new ExportResult(doc.Count, incomplete, bytes, jsonPath);
    }

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
