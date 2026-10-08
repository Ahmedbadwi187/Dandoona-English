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

    public string ArtDir => Path.Combine(Root, "content", "art");
    /// <summary>Downloadable content packs, served as static files by the API (see docs/content-packs.md).</summary>
    public string PacksDir => Path.Combine(Root, "packs");
    /// <summary>The version and content hash of every pack, so an unchanged pack keeps its version (committed).</summary>
    public string PacksLock => Path.Combine(Root, "content", "packs.lock.json");
    public string PackDir(string track, string unit) => Path.Combine(PacksDir, Snake(track), Snake(unit));
    public string AccessoriesDir => Path.Combine(ArtDir, "accessories");
    /// <summary>Drawn avatars a parent picks for a child (friends of Dandoona), exported next to the accessories.</summary>
    public string AvatarsDir => Path.Combine(ArtDir, "avatars");
    /// <summary>Dandoona in other poses (waving, thinking...): the owner's own art, exported next to the mascot.</summary>
    public string PosesDir => Path.Combine(ArtDir, "dandoona");
    public string PalettePath => Path.Combine(StyleDir, "palette.json");
    public string SvgSource(Lesson l, string key) => Path.Combine(ArtDir, l.Track, l.Id, $"{key}.svg");
    public string PicksPath => Path.Combine(GeneratedDir, "picks.json");
    public string LedgerPath => Path.Combine(GeneratedDir, "cost-ledger.json");
    public string DecisionsDoc => Path.Combine(Root, "docs", "asset-decisions.md");

    /// <summary>Candidate files for a key that already exist in _review.</summary>
    public IReadOnlyList<string> ImageReviewFiles(Lesson l, string key) =>
        Directory.Exists(ImageReviewDir(l))
            ? Directory.GetFiles(ImageReviewDir(l), $"{key}.v*.webp").Order().ToList()
            : [];

    /// <summary>Where a reused picture lives: another lesson's self-drawn SVG, else its approved image. Null when neither exists.</summary>
    public (string Path, bool Svg)? ReuseSource(Lesson l, string reuse)
    {
        // "lesson/key" in the same track, or "track:lesson/key" from another one (Explorers reuses Little Learners pictures)
        var track = l.Track;
        if (reuse.Contains(':')) { track = reuse[..reuse.IndexOf(':')]; reuse = reuse[(reuse.IndexOf(':') + 1)..]; }
        var parts = reuse.Split('/');
        var other = new Lesson { Id = parts[0], Track = track };
        if (File.Exists(SvgSource(other, parts[1]))) return (SvgSource(other, parts[1]), true);
        if (File.Exists(ImageApproved(other, parts[1]))) return (ImageApproved(other, parts[1]), false);
        return null;
    }

    /// <summary>The audio file export would use: your override if present, else the generated file.</summary>
    public string? AudioForExport(Lesson l, string role) =>
        File.Exists(AudioOverride(l, role)) ? AudioOverride(l, role) :
        File.Exists(AudioGen(l, role)) ? AudioGen(l, role) : null;

    // Exported (Flutter) names: stable, snake_case, no suffixes. Paths in JSON are relative to assets/.
    public static string Snake(string s) => s.Replace('-', '_');
    public static string ExportAudioRel(Lesson l, string role) => $"audio/{Snake(l.Track)}/{Snake(l.Id)}/{Snake(role)}.mp3";
    public static string ExportImageRel(Lesson l, string key, bool svg = false) => $"images/{Snake(l.Track)}/{Snake(l.Id)}/{Snake(key)}.{(svg ? "svg" : "webp")}";
    public const string ExportMascotRel = "images/mascot/mascot.webp";
    public static string ExportAccessoryRel(string fileName) => $"images/accessories/{fileName}";
    public static string ExportAvatarRel(string fileName) => $"images/avatars/{fileName}";
    public static string ExportPoseRel(string name) => $"images/mascot/poses/{name}.webp";
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
public record ImageItem(string Key, string Prompt, bool UsesMascot, bool IsSvg = false);

public static class LessonPlan
{
    public static IReadOnlyList<AudioItem> Audio(Lesson l)
    {
        // a track's phoneme table: one clip per sound, every one flagged as a phoneme to listen to
        if (l.PhonemeSet is not null) return l.PhonemeSet.Select(p => new AudioItem(PhonemeRole(p.Key), p.Say.Trim(), true)).ToList();
        var items = new List<AudioItem> { new("intro", l.Narration.Intro.Trim(), false) };
        if (!string.IsNullOrWhiteSpace(l.Phoneme)) items.Add(new("phoneme", l.Phoneme.Trim(), true));
        for (var i = 0; i < l.Narration.Praise.Count; i++) items.Add(new($"praise-{i}", l.Narration.Praise[i].Trim(), false));
        foreach (var w in l.Words) items.Add(new($"word-{Slug(w.Word)}", w.Word.Trim(), false));
        if (!string.IsNullOrWhiteSpace(l.Narration.ColorName)) items.Add(new("color-name", l.Narration.ColorName.Trim(), false));
        foreach (var w in l.Words)
        {
            if (!string.IsNullOrWhiteSpace(w.Sound)) items.Add(new(SoundRole(w.Word), w.Sound.Trim(), false));
            if (!string.IsNullOrWhiteSpace(w.Lives)) items.Add(new(LivesRole(w.Word), w.Lives.Trim(), false));
            if (!string.IsNullOrWhiteSpace(w.Says)) items.Add(new(SaysRole(w.Word), w.Says.Trim(), false));
            if (!string.IsNullOrWhiteSpace(w.Plural)) items.Add(new(PluralRole(w.Word), PluralLine(w), false));
        }
        foreach (var w in l.Words)
            if (l.Narration.Phrases.FirstOrDefault(p => p.Key.Trim().Equals(w.Word.Trim(), StringComparison.OrdinalIgnoreCase)) is { Value: { Length: > 0 } phrase })
                items.Add(new(PhraseRole(w.Word), phrase.Trim(), false));
        foreach (var w in l.SightWords) items.Add(new(SightRole(w), w.Trim(), false));
        for (var i = 0; i < l.Sentences.Count; i++) items.Add(new(SentenceRole(i), l.Sentences[i].Text.Trim(), false));
        foreach (var (key, text) in l.Narration.Instructions.OrderBy(k => k.Key, StringComparer.Ordinal)) items.Add(new(InstructionRole(key), text.Trim(), false));
        return items;
    }

    /// <summary>Pictures that must be drawn or generated for this lesson (words that reuse another lesson's picture are not included).</summary>
    public static IReadOnlyList<ImageItem> Images(Lesson l) =>
        l.Words.Where(w => w.Reuse is null).Select(w => new ImageItem(Slug(w.Word), w.ImagePrompt.Trim(), w.Mascot, w.Source == "svg")).ToList();

    public static string InstructionRole(string key) => $"instr-{key}";
    public static string PhonemeRole(string key) => $"phoneme-{key}";
    public static string SoundRole(string word) => $"sound-{Slug(word)}";
    public static string SaysRole(string word) => $"says-{Slug(word)}";
    public static string LivesRole(string word) => $"lives-{Slug(word)}";
    public static string PhraseRole(string word) => $"phrase-{Slug(word)}";
    public static string PluralRole(string word) => $"plural-{Slug(word)}";
    public static string SightRole(string word) => $"sight-{Slug(word)}";
    public static string SentenceRole(int index) => $"sentence-{index + 1}";

    /// <summary>The line that shows a plural: "One cat. Two cats!"</summary>
    public static string PluralLine(LessonWord w) => $"One {w.Word.Trim()}. Two {w.Plural!.Trim()}!";

    /// <summary>Words that reuse a picture from another lesson: (word key, "lesson-id/key").</summary>
    public static IReadOnlyList<(string Key, string Reuse)> Reused(Lesson l) =>
        l.Words.Where(w => w.Reuse is not null).Select(w => (Slug(w.Word), w.Reuse!)).ToList();

    public static string Slug(string word) =>
        new(word.Trim().ToLowerInvariant().Select(ch => char.IsLetterOrDigit(ch) ? ch : '-').ToArray());
}
