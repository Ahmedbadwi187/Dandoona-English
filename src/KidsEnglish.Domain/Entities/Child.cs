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
    public DateTime CreatedAt { get; set; }

    public Parent Parent { get; set; } = null!;
    public List<ProgressRecord> Progress { get; set; } = [];
}
