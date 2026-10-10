namespace KidsEnglish.Domain.Entities;

/// <summary>Child profile. No credentials, no email, nickname only, birth year only.</summary>
public class Child
{
    public Guid Id { get; set; }
    public Guid ParentId { get; set; }
    public string Name { get; set; } = "";
    public string AvatarKey { get; set; } = "";
    public int BirthYear { get; set; }
    /// <summary>1-12, optional: with the year it gives the exact age (the first-launch flow asks for it).</summary>
    public int? BirthMonth { get; set; }
    /// <summary>Track code, see <see cref="Tracks"/>.</summary>
    public string Track { get; set; } = Tracks.LittleLearners;
    /// <summary>The daily goal in minutes the parent chose (5, 10 or 15). Null for children made by an older app version.</summary>
    public int? GoalMinutes { get; set; }
    /// <summary>What the parent says the child can already do: skill ids separated by commas (or none / unsure). Null = never asked (older app versions).</summary>
    public string? Skills { get; set; }
    /// <summary>When the profile fields were last changed on a device (the device's clock). The most recent change wins when two devices edit the same child.</summary>
    public DateTime? ProfileUpdatedAt { get; set; }
    public DateTime CreatedAt { get; set; }

    public Parent Parent { get; set; } = null!;
    public List<ProgressRecord> Progress { get; set; } = [];
    public List<ChildAchievement> Achievements { get; set; } = [];
}
