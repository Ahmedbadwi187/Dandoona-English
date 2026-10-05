namespace KidsEnglish.Domain.Entities;

public class ContentPack
{
    public Guid Id { get; set; }
    public int TrackId { get; set; }
    public int Version { get; set; }
    public string ManifestBlobPath { get; set; } = "";
    public DateTime PublishedAt { get; set; }
    public string PublishedBy { get; set; } = "";

    public Track Track { get; set; } = null!;
    public List<ContentPackLesson> Lessons { get; set; } = [];
}

public class ContentPackLesson
{
    public Guid ContentPackId { get; set; }
    public Guid LessonId { get; set; }
    public string CurriculumHash { get; set; } = "";
}
