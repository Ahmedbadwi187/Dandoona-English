namespace KidsEnglish.Domain.Entities;

/// <summary>
/// Something a child has earned or done on the map, kept so it survives a new phone: a unit certificate, an opened treasure
/// chest, a passed review, a read story, or a unit counted as done by the placement answer. One row per (child, kind, key);
/// when two phones report the same one, the earliest date is kept. No free text.
/// </summary>
public class ChildAchievement
{
    public Guid Id { get; set; }
    public Guid ChildId { get; set; }
    /// <summary>See <see cref="AchievementKinds"/>.</summary>
    public string Kind { get; set; } = "";
    /// <summary>A unit id, a review id or "castle" (curriculum ids only).</summary>
    public string Key { get; set; } = "";
    public DateTime EarnedAt { get; set; }

    public Child Child { get; set; } = null!;
}

public static class AchievementKinds
{
    public const string Certificate = "certificate";
    public const string Chest = "chest";
    public const string Review = "review";
    public const string Story = "story";
    public const string Placed = "placed";

    public static readonly IReadOnlySet<string> All = new HashSet<string> { Certificate, Chest, Review, Story, Placed };
}
