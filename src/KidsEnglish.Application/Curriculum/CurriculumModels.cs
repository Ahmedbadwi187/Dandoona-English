using KidsEnglish.Domain.Enums;

namespace KidsEnglish.Application.Curriculum;

/// <summary>One lesson as authored in /content/curriculum/*.yaml (source of truth).</summary>
public class CurriculumLesson
{
    public string Id { get; set; } = "";
    public string Track { get; set; } = "";
    public string Level { get; set; } = "";
    public int? Order { get; set; }
    public string? Letter { get; set; }
    public string? Phoneme { get; set; }
    public List<CurriculumWord> Words { get; set; } = [];
    public CurriculumNarration Narration { get; set; } = new();
    public List<string> Activities { get; set; } = [];
}

public class CurriculumWord
{
    public string Word { get; set; } = "";
    public string ImagePrompt { get; set; } = "";
}

public class CurriculumNarration
{
    public string Intro { get; set; } = "";
    public List<string> Praise { get; set; } = [];
}

public record CurriculumFile(string FileName, CurriculumLesson Lesson);

public interface ICurriculumReader
{
    /// <summary>Reads every *.yaml/*.yml in the directory. Throws <see cref="CurriculumException"/> on malformed files.</summary>
    Task<IReadOnlyList<CurriculumFile>> ReadAllAsync(string directory, CancellationToken ct);
}

public class CurriculumException(string message) : Exception(message);

public record SyncResult(int Created, int Updated, int Unchanged);

public static class ActivityNames
{
    private static readonly Dictionary<string, ActivityType> Map = new(StringComparer.OrdinalIgnoreCase)
    {
        ["trace"] = ActivityType.Trace,
        ["listen-and-tap"] = ActivityType.ListenAndTap,
        ["say-it"] = ActivityType.SayIt,
        ["match-picture"] = ActivityType.MatchPicture
    };

    public static bool TryParse(string name, out ActivityType type) => Map.TryGetValue(name, out type);
}
