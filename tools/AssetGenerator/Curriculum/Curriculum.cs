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
    public int? Order { get; set; }
    public string? Letter { get; set; }
    public string? Phoneme { get; set; }
    public List<LessonWord> Words { get; set; } = [];
    public Narration Narration { get; set; } = new();
    public List<string> Activities { get; set; } = [];

    public int ResolvedOrder => Order ?? (Letter is { Length: 1 } l ? l[0] - 'A' + 1 : int.MaxValue);
}

public class LessonWord
{
    public string Word { get; set; } = "";
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
}

public class CurriculumException(string message) : Exception(message);

public class LessonValidator : AbstractValidator<Lesson>
{
    public static readonly string[] ActivityNames = ["trace", "listen-and-tap", "record-and-listen", "match-picture"];
    private static readonly string[] Levels = ["pre-a1", "a1", "a2"];
    private static readonly string[] Tracks = ["little-learners", "explorers", "champions"];

    public LessonValidator()
    {
        RuleFor(x => x.Id).NotEmpty().MaximumLength(100).Matches("^[a-z0-9]+(-[a-z0-9]+)*$")
            .WithMessage("'Id' must be lowercase kebab-case.");
        RuleFor(x => x.Track).Must(t => Tracks.Contains(t)).WithMessage("'Track' must be one of: " + string.Join(", ", Tracks));
        RuleFor(x => x.Level).Must(l => Levels.Contains(l)).WithMessage("'Level' must be one of: " + string.Join(", ", Levels));
        RuleFor(x => x.Order).GreaterThan(0).When(x => x.Order.HasValue);
        RuleFor(x => x.Letter).Matches("^[A-Z]$").When(x => x.Letter is not null).WithMessage("'Letter' must be a single uppercase A-Z.");
        RuleFor(x => x.Phoneme).NotEmpty().MaximumLength(20).When(x => x.Phoneme is not null);

        RuleFor(x => x.Words).NotEmpty();
        RuleForEach(x => x.Words).ChildRules(w =>
        {
            w.RuleFor(i => i.Word).NotEmpty().MaximumLength(30).Matches("^[A-Za-z' -]+$");
            w.RuleFor(i => i.ImagePrompt).NotEmpty().MaximumLength(500);
            w.RuleFor(i => i.Source).Must(s => s is "openai" or "svg").WithMessage("Word source must be openai or svg.");
        });
        RuleFor(x => x.Words)
            .Must(ws => ws.Select(w => w.Word.Trim().ToLowerInvariant()).Distinct().Count() == ws.Count)
            .WithMessage("Duplicate words in lesson.");

        RuleFor(x => x.Narration.Intro).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Narration.Praise).NotEmpty();
        RuleForEach(x => x.Narration.Praise).NotEmpty().MaximumLength(100);
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

        foreach (var dup in lessons.GroupBy(l => l.Lesson.Id).Where(g => g.Count() > 1))
            errors.Add($"Duplicate lesson id '{dup.Key}' in: {string.Join(", ", dup.Select(l => l.File))}");

        if (errors.Count > 0) throw new CurriculumException("Curriculum is invalid:\n" + string.Join("\n", errors));

        return lessons.Select(l => l.Lesson).OrderBy(l => l.Track).ThenBy(l => l.ResolvedOrder).ThenBy(l => l.Id).ToList();
    }

    /// <summary>Selects lessons by --lesson id and/or --track; throws if nothing matches.</summary>
    public static IReadOnlyList<Lesson> Select(IReadOnlyList<Lesson> all, string? lessonId, string? track)
    {
        var picked = all.Where(l => (lessonId is null || l.Id == lessonId) && (track is null || l.Track == track)).ToList();
        if (picked.Count == 0)
            throw new CurriculumException($"No lessons match (lesson: {lessonId ?? "any"}, track: {track ?? "any"}).");
        return picked;
    }
}
