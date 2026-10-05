using KidsEnglish.Domain.Enums;

namespace KidsEnglish.Domain.Entities;

public class Lesson
{
    public Guid Id { get; set; }
    public int TrackId { get; set; }
    public string Code { get; set; } = "";
    public int Order { get; set; }
    public string Title { get; set; } = "";
    public string CurriculumHash { get; set; } = "";
    public LessonStatus Status { get; set; }

    public Track Track { get; set; } = null!;
    public List<Activity> Activities { get; set; } = [];
    public List<Asset> Assets { get; set; } = [];
}
