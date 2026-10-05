using KidsEnglish.Domain.Enums;

namespace KidsEnglish.Domain.Entities;

public class Activity
{
    public Guid Id { get; set; }
    public Guid LessonId { get; set; }
    public ActivityType Type { get; set; }
    public int Order { get; set; }
    public string ConfigJson { get; set; } = "{}";

    public Lesson Lesson { get; set; } = null!;
}
