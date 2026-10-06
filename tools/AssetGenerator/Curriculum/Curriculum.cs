using FluentValidation;
using YamlDotNet.Core;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace AssetGenerator.Curriculum;

/// <summary>One lesson as authored in /content/curriculum/*.yaml (source of truth).</summary>
public class Lesson
{
    public string Id { get; set; } = "";
    public string Track { get; set; } = "";
    public string Level { get; set; } = "";
    /// <summary>The unit this lesson belongs to (an id from content/curriculum/units/*.yaml).</summary>
    public string Unit { get; set; } = "";
    /// <summary>Colors unit only: the color the lesson teaches.</summary>
    public LessonColor? Color { get; set; }
    /// <summary>True for the synthetic lesson that carries a unit's own audio (title, welcome, celebration). Never read from YAML files.</summary>
    public bool IsUnit { get; set; }
    public int? Order { get; set; }
    public string? Letter { get; set; }
    public string? Phoneme { get; set; }
    public List<LessonWord> Words { get; set; } = [];
    public Narration Narration { get; set; } = new();
    public List<string> Activities { get; set; } = [];

    public int ResolvedOrder => Order ?? (Letter is { Length: 1 } l ? l[0] - 'A' + 1 : int.MaxValue);
}

public class LessonColor
{
    public string Name { get; set; } = "";
    /// <summary>#RRGGBB, must be a color from palette.json.</summary>
    public string Hex { get; set; } = "";
}

public class LessonWord
{
    public string Word { get; set; } = "";
    /// <summary>"lesson-id/key": use the picture of a word in another lesson (copied at export) instead of drawing or generating one.</summary>
    public string? Reuse { get; set; }
    public string ImagePrompt { get; set; } = "";
    /// <summary>True when the scene includes the mascot, so the locked reference image is used.</summary>
    public bool Mascot { get; set; }
    /// <summary>"openai" (generated illustration) or "svg" (self-drawn, content/art/{track}/{lesson}/{key}.svg).</summary>
    public string Source { get; set; } = "openai";
}

public class Narration
{
    public string Intro { get; set; } = "";
    public List<string> Praise { get; set; } = [];
    /// <summary>Spoken instructions, keyed by activity name (shown to the child when the activity starts), plus an optional "hint".</summary>
    public Dictionary<string, string> Instructions { get; set; } = [];
    /// <summary>Colors unit: how the lesson says the color on its own ("red").</summary>
    public string? ColorName { get; set; }
    /// <summary>Spoken phrase per word ("A red apple."), used by record-and-listen in the Colors unit.</summary>
    public Dictionary<string, string> Phrases { get; set; } = [];
}

public class CurriculumException(string message) : Exception(message);

/// <summary>One unit of a track, from content/curriculum/units/&lt;track&gt;.yaml (units are listed in the order they open).</summary>
public class UnitDef
{
    public string Id { get; set; } = "";
    public string Track { get; set; } = "";
    public int Order { get; set; }
    public Dictionary<string, string> Title { get; set; } = [];
    /// <summary>Picture key the app maps to an icon (unknown keys fall back to a star).</summary>
    public string Icon { get; set; } = "";
    /// <summary>Palette color name for the unit tile.</summary>
    public string Color { get; set; } = "";
    public UnitNarration Narration { get; set; } = new();
}

public class UnitNarration
{
    public string Title { get; set; } = "";
    public string Welcome { get; set; } = "";
    public string Celebration { get; set; } = "";
}

public class UnitsFile
{
    public string Track { get; set; } = "";
    public List<UnitDef> Units { get; set; } = [];
}

public class LessonValidator : AbstractValidator<Lesson>
{
    public static readonly string[] ActivityNames = ["trace", "listen-and-tap", "record-and-listen", "match-picture", "color-the-object"];
    private static readonly string[] Levels = ["pre-a1", "a1", "a2"];
    private static readonly string[] Tracks = ["little-learners", "explorers", "champions"];

    public LessonValidator()
    {
        RuleFor(x => x.Id).NotEmpty().MaximumLength(100).Matches("^[a-z0-9]+(-[a-z0-9]+)*$")
            .WithMessage("'Id' must be lowercase kebab-case.");
        RuleFor(x => x.Track).Must(t => Tracks.Contains(t)).WithMessage("'Track' must be one of: " + string.Join(", ", Tracks));
        RuleFor(x => x.Level).Must(l => Levels.Contains(l)).WithMessage("'Level' must be one of: " + string.Join(", ", Levels));
        RuleFor(x => x.Unit).Matches("^[a-z0-9]+(-[a-z0-9]+)*$").When(x => x.Unit.Length > 0).WithMessage("'Unit' must be lowercase kebab-case.");
        RuleFor(x => x.Color!.Hex).Matches("^#[0-9A-Fa-f]{6}$").When(x => x.Color is not null).WithMessage("'Color.Hex' must look like #RRGGBB.");
        RuleFor(x => x.Color!.Name).NotEmpty().MaximumLength(20).When(x => x.Color is not null);
        RuleFor(x => x.Order).GreaterThan(0).When(x => x.Order.HasValue);
        RuleFor(x => x.Letter).Matches("^[A-Z]$").When(x => x.Letter is not null).WithMessage("'Letter' must be a single uppercase A-Z.");
        RuleFor(x => x.Phoneme).NotEmpty().MaximumLength(20).When(x => x.Phoneme is not null);

        RuleFor(x => x.Words).NotEmpty();
        RuleForEach(x => x.Words).ChildRules(w =>
        {
            w.RuleFor(i => i.Word).NotEmpty().MaximumLength(30).Matches("^[A-Za-z' -]+$");
            w.RuleFor(i => i.ImagePrompt).NotEmpty().MaximumLength(500).When(i => i.Reuse is null);
            w.RuleFor(i => i.Reuse).Matches("^[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9-]+$").When(i => i.Reuse is not null).WithMessage("'Reuse' must look like lesson-id/word-key.");
            w.RuleFor(i => i.Source).Must(s => s is "openai" or "svg").WithMessage("Word source must be openai or svg.");
        });
        RuleFor(x => x.Words)
            .Must(ws => ws.Select(w => w.Word.Trim().ToLowerInvariant()).Distinct().Count() == ws.Count)
            .WithMessage("Duplicate words in lesson.");

        RuleFor(x => x.Narration.Intro).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Narration.Praise).NotEmpty();
        RuleForEach(x => x.Narration.Praise).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Narration.ColorName).MaximumLength(30);
        RuleFor(x => x).Must(l => l.Narration.Phrases.Keys.All(k => l.Words.Any(w => w.Word.Trim().Equals(k, StringComparison.OrdinalIgnoreCase))))
            .WithMessage("Every key of narration.phrases must be one of the lesson's words.");
        RuleForEach(x => x.Narration.Instructions).Must(kv => (ActivityNames.Contains(kv.Key) || kv.Key == "hint") && !string.IsNullOrWhiteSpace(kv.Value) && kv.Value.Length <= 100)
            .WithMessage("Instructions must be keyed by an activity name or 'hint' and be 1-100 characters.");

        RuleFor(x => x.Activities).NotEmpty();
        RuleForEach(x => x.Activities).Must(a => ActivityNames.Contains(a))
            .WithMessage("Unknown activity '{PropertyValue}'. Use: " + string.Join(", ", ActivityNames));
        RuleFor(x => x.Activities).Must(a => a.Distinct().Count() == a.Count).WithMessage("Duplicate activities in lesson.");
    }
}

public static class CurriculumReader
{
    // Strict: unknown keys (typos like "imagePrmpt") fail loudly instead of silently dropping content.
    private static readonly IDeserializer Deserializer = new DeserializerBuilder()
        .WithNamingConvention(CamelCaseNamingConvention.Instance)
        .Build();

    /// <summary>Reads and validates every *.yaml/*.yml in the directory, ordered by track then lesson order.</summary>
    public static IReadOnlyList<Lesson> LoadAll(string directory)
    {
        if (!Directory.Exists(directory)) throw new CurriculumException($"Curriculum directory not found: {directory}");

        var validator = new LessonValidator();
        var errors = new List<string>();
        var lessons = new List<(string File, Lesson Lesson)>();

        var files = Directory.EnumerateFiles(directory)
            .Where(p => p.EndsWith(".yaml", StringComparison.OrdinalIgnoreCase) || p.EndsWith(".yml", StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.OrdinalIgnoreCase);

        foreach (var path in files)
        {
            var name = Path.GetFileName(path);
            try
            {
                var lesson = Deserializer.Deserialize<Lesson>(File.ReadAllText(path));
                if (lesson is null) { errors.Add($"{name}: file is empty."); continue; }
                errors.AddRange(validator.Validate(lesson).Errors.Select(e => $"{name}: {e.ErrorMessage}"));
                lessons.Add((name, lesson));
            }
            catch (YamlException ex)
            {
                errors.Add($"{name}: {ex.Message}");
            }
        }

        var units = LoadUnits(directory);
        if (units.Count > 0)
            foreach (var (file, lesson) in lessons)
            {
                if (lesson.Unit.Length == 0) errors.Add($"{file}: 'unit' is required (units are defined in curriculum/units).");
                else if (!units.Any(u => u.Track == lesson.Track && u.Id == lesson.Unit)) errors.Add($"{file}: unknown unit '{lesson.Unit}' for track '{lesson.Track}'.");
            }

        foreach (var dup in lessons.GroupBy(l => l.Lesson.Id).Where(g => g.Count() > 1))
            errors.Add($"Duplicate lesson id '{dup.Key}' in: {string.Join(", ", dup.Select(l => l.File))}");

        if (errors.Count > 0) throw new CurriculumException("Curriculum is invalid:\n" + string.Join("\n", errors));

        return lessons.Select(l => l.Lesson).OrderBy(l => l.Track).ThenBy(l => l.ResolvedOrder).ThenBy(l => l.Id).ToList();
    }

    /// <summary>Reads curriculum/units/*.yaml (optional folder). Units are ordered by track then order.</summary>
    public static IReadOnlyList<UnitDef> LoadUnits(string curriculumDirectory)
    {
        var dir = Path.Combine(curriculumDirectory, "units");
        if (!Directory.Exists(dir)) return [];
        var result = new List<UnitDef>();
        var errors = new List<string>();
        foreach (var path in Directory.EnumerateFiles(dir, "*.yaml").Order(StringComparer.OrdinalIgnoreCase))
        {
            var name = Path.GetFileName(path);
            try
            {
                var file = Deserializer.Deserialize<UnitsFile>(File.ReadAllText(path));
                if (file is null || file.Track.Length == 0) { errors.Add($"{name}: needs a track and a units list."); continue; }
                foreach (var u in file.Units)
                {
                    u.Track = file.Track;
                    if (!System.Text.RegularExpressions.Regex.IsMatch(u.Id, "^[a-z0-9]+(-[a-z0-9]+)*$")) errors.Add($"{name}: unit id '{u.Id}' must be lowercase kebab-case.");
                    if (u.Order <= 0) errors.Add($"{name}: unit '{u.Id}' needs a positive order.");
                    if (!u.Title.ContainsKey("en") || !u.Title.ContainsKey("ar")) errors.Add($"{name}: unit '{u.Id}' needs title.en and title.ar.");
                    if (string.IsNullOrWhiteSpace(u.Narration.Title) || string.IsNullOrWhiteSpace(u.Narration.Celebration)) errors.Add($"{name}: unit '{u.Id}' needs narration.title and narration.celebration.");
                    result.Add(u);
                }
            }
            catch (YamlException ex) { errors.Add($"{name}: {ex.Message}"); }
        }
        foreach (var dup in result.GroupBy(u => (u.Track, u.Id)).Where(g => g.Count() > 1)) errors.Add($"Duplicate unit '{dup.Key.Id}' in track '{dup.Key.Track}'.");
        foreach (var dup in result.GroupBy(u => (u.Track, u.Order)).Where(g => g.Count() > 1)) errors.Add($"Two units share order {dup.Key.Order} in track '{dup.Key.Track}'.");
        if (errors.Count > 0) throw new CurriculumException("Units are invalid:\n" + string.Join("\n", errors));
        return result.OrderBy(u => u.Track).ThenBy(u => u.Order).ToList();
    }

    /// <summary>The synthetic lesson that carries a unit's own audio lines so the audio runner and export treat them like any lesson.</summary>
    public static Lesson UnitAudioLesson(UnitDef u) => new()
    {
        Id = $"unit-{u.Id}", Track = u.Track, Unit = u.Id, Level = "pre-a1", IsUnit = true, Order = u.Order,
        Narration = new Narration
        {
            Intro = string.IsNullOrWhiteSpace(u.Narration.Welcome) ? u.Narration.Title : u.Narration.Welcome,
            Instructions = new Dictionary<string, string> { ["title"] = u.Narration.Title, ["celebration"] = u.Narration.Celebration },
        },
    };

    /// <summary>Selects lessons by --lesson id and/or --track; throws if nothing matches.</summary>
    public static IReadOnlyList<Lesson> Select(IReadOnlyList<Lesson> all, string? lessonId, string? track)
    {
        var picked = all.Where(l => (lessonId is null || l.Id == lessonId) && (track is null || l.Track == track)).ToList();
        if (picked.Count == 0)
            throw new CurriculumException($"No lessons match (lesson: {lessonId ?? "any"}, track: {track ?? "any"}).");
        return picked;
    }
}
