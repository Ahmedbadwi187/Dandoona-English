using AssetGenerator.Curriculum;

namespace AssetGenerator;

/// <summary>
/// All file locations and naming rules in one place.
///   content/generated/{track}/{lesson}/audio/{role}.gen.mp3        generated (as returned by the API)
///   content/generated/{track}/{lesson}/audio/{role}.override.mp3   your own recording, wins on export
///   content/generated/{track}/{lesson}/images/_review/{key}.v{n}.webp   candidates (git-ignored)
///   content/generated/{track}/{lesson}/images/{key}.approved.webp  the variant you picked (rename it)
///   content/generated/{track}/{lesson}/manifest.json               hashes of what was generated
/// </summary>
public sealed class Layout(string root)
{
    public string Root { get; } = root;
    public string CurriculumDir => Path.Combine(Root, "content", "curriculum");
    public string StyleDir => Path.Combine(Root, "content", "style");
    public string GeneratedDir => Path.Combine(Root, "content", "generated");
    public string MobileDir => Path.Combine(Root, "mobile", "kids_english_app");
    public string AssetsDir => Path.Combine(MobileDir, "assets");
    public string Pubspec => Path.Combine(MobileDir, "pubspec.yaml");

    public string VoicesJson => Path.Combine(StyleDir, "voices.json");
    public string GenerationJson => Path.Combine(StyleDir, "generation.json");
    public string ArtStyleMd => Path.Combine(StyleDir, "art-style.md");
    public string MascotMd => Path.Combine(StyleDir, "mascot.md");
    public string MascotReference => Path.Combine(StyleDir, "mascot.reference.webp");
    public string MascotReviewDir => Path.Combine(GeneratedDir, "mascot", "_review");
    public string MascotReview(int n) => Path.Combine(MascotReviewDir, $"mascot.v{n}.webp");

    public string LessonDir(Lesson l) => Path.Combine(GeneratedDir, l.Track, l.Id);
    public string ManifestPath(Lesson l) => Path.Combine(LessonDir(l), "manifest.json");

    public string AudioGen(Lesson l, string role) => Path.Combine(LessonDir(l), "audio", $"{role}.gen.mp3");
    public string AudioOverride(Lesson l, string role) => Path.Combine(LessonDir(l), "audio", $"{role}.override.mp3");

    public string ImageReviewDir(Lesson l) => Path.Combine(LessonDir(l), "images", "_review");
    public string ImageReview(Lesson l, string key, int n) => Path.Combine(ImageReviewDir(l), $"{key}.v{n}.webp");
    public string ImageApproved(Lesson l, string key) => Path.Combine(LessonDir(l), "images", $"{key}.approved.webp");

    /// <summary>Candidate files for a key that already exist in _review.</summary>
    public IReadOnlyList<string> ImageReviewFiles(Lesson l, string key) =>
        Directory.Exists(ImageReviewDir(l))
            ? Directory.GetFiles(ImageReviewDir(l), $"{key}.v*.webp").Order().ToList()
            : [];

    /// <summary>The audio file export would use: your override if present, else the generated file.</summary>
    public string? AudioForExport(Lesson l, string role) =>
        File.Exists(AudioOverride(l, role)) ? AudioOverride(l, role) :
        File.Exists(AudioGen(l, role)) ? AudioGen(l, role) : null;

    // Exported (Flutter) names: stable, snake_case, no suffixes. Paths in JSON are relative to assets/.
    public static string Snake(string s) => s.Replace('-', '_');
    public static string ExportAudioRel(Lesson l, string role) => $"audio/{Snake(l.Track)}/{Snake(l.Id)}/{Snake(role)}.mp3";
    public static string ExportImageRel(Lesson l, string key) => $"images/{Snake(l.Track)}/{Snake(l.Id)}/{Snake(key)}.webp";
    public const string ExportMascotRel = "images/mascot/mascot.webp";
    public static string ExportJsonRel(string track) => $"content/{Snake(track)}.json";

    /// <summary>Finds the repo root by walking up until content/curriculum exists.</summary>
    public static Layout Find(string? explicitRoot = null)
    {
        if (explicitRoot is not null) return new Layout(Path.GetFullPath(explicitRoot));
        return FindFrom(Directory.GetCurrentDirectory());
    }

    public static Layout FindFrom(string start)
    {
        for (var dir = new DirectoryInfo(start); dir is not null; dir = dir.Parent)
            if (Directory.Exists(Path.Combine(dir.FullName, "content", "curriculum"))) return new Layout(dir.FullName);
        throw new CurriculumException("Could not find the repo root (a folder containing content/curriculum). Use --root.");
    }
}

/// <summary>What a lesson needs, derived from its curriculum definition.</summary>
public record AudioItem(string Role, string Text, bool IsPhoneme);
public record ImageItem(string Key, string Prompt, bool UsesMascot);

public static class LessonPlan
{
    public static IReadOnlyList<AudioItem> Audio(Lesson l)
    {
        var items = new List<AudioItem> { new("intro", l.Narration.Intro.Trim(), false) };
        if (!string.IsNullOrWhiteSpace(l.Phoneme)) items.Add(new("phoneme", l.Phoneme.Trim(), true));
        for (var i = 0; i < l.Narration.Praise.Count; i++) items.Add(new($"praise-{i}", l.Narration.Praise[i].Trim(), false));
        foreach (var w in l.Words) items.Add(new($"word-{Slug(w.Word)}", w.Word.Trim(), false));
        return items;
    }

    public static IReadOnlyList<ImageItem> Images(Lesson l) =>
        l.Words.Select(w => new ImageItem(Slug(w.Word), w.ImagePrompt.Trim(), w.Mascot)).ToList();

    public static string Slug(string word) =>
        new(word.Trim().ToLowerInvariant().Select(ch => char.IsLetterOrDigit(ch) ? ch : '-').ToArray());
}
