namespace KidsEnglish.Domain.Entities;

/// <summary>Child profile. No credentials, no email, nickname only, birth year only.</summary>
public class Child
{
    public Guid Id { get; set; }
    public Guid ParentId { get; set; }
    public string Name { get; set; } = "";
    public string AvatarKey { get; set; } = "";
    public int BirthYear { get; set; }
    public int TrackId { get; set; }
    public DateTime CreatedAt { get; set; }

    public Parent Parent { get; set; } = null!;
    public Track Track { get; set; } = null!;
    public List<ProgressRecord> Progress { get; set; } = [];
}
