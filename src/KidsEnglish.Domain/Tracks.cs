namespace KidsEnglish.Domain;

/// <summary>Learning tracks. Lessons and media live in the app's bundled assets, so the backend only needs the code.</summary>
public static class Tracks
{
    public const string LittleLearners = "little-learners";
    public const string Explorers = "explorers";
    public const string Champions = "champions";

    public static readonly IReadOnlyList<string> All = [LittleLearners, Explorers, Champions];

    public static bool IsValid(string? code) => code is not null && All.Contains(code);
}
