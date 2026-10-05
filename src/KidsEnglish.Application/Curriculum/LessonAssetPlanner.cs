using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using KidsEnglish.Domain.Enums;

namespace KidsEnglish.Application.Curriculum;

public record AssetSpec(AssetKind Kind, string Role, string SourceText, bool RequiresHumanReview);

/// <summary>Derives the media assets a lesson needs from its curriculum definition.</summary>
public static class LessonAssetPlanner
{
    public static IReadOnlyList<AssetSpec> Plan(CurriculumLesson c)
    {
        var specs = new List<AssetSpec> { new(AssetKind.Audio, "intro", c.Narration.Intro.Trim(), false) };

        if (!string.IsNullOrWhiteSpace(c.Phoneme))
            // TTS often mispronounces isolated phonemes, so every phoneme clip needs human review.
            specs.Add(new(AssetKind.Audio, "phoneme", c.Phoneme.Trim(), true));

        for (var i = 0; i < c.Narration.Praise.Count; i++)
            specs.Add(new(AssetKind.Audio, $"praise-{i}", c.Narration.Praise[i].Trim(), false));

        foreach (var w in c.Words)
        {
            var key = Slug(w.Word);
            specs.Add(new(AssetKind.Audio, $"word-{key}", w.Word.Trim(), false));
            specs.Add(new(AssetKind.Image, $"image-{key}", w.ImagePrompt.Trim(), false));
        }
        return specs;
    }

    public static int ResolveOrder(CurriculumLesson c) =>
        c.Order ?? (c.Letter is { Length: 1 } l ? l[0] - 'A' + 1 : int.MaxValue);

    public static string Title(CurriculumLesson c) => c.Letter is null ? c.Id : $"Letter {c.Letter}";

    /// <summary>Stable hash of the lesson definition, used to detect curriculum edits.</summary>
    public static string Hash(CurriculumLesson c) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(c)))).ToLowerInvariant();

    private static string Slug(string word) =>
        new string(word.Trim().ToLowerInvariant().Select(ch => char.IsLetterOrDigit(ch) ? ch : '-').ToArray());
}
