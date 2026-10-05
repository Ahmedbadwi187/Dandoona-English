using KidsEnglish.Domain.Enums;

namespace KidsEnglish.Domain.Entities;

public class Asset
{
    public Guid Id { get; set; }
    public Guid LessonId { get; set; }
    public Guid? ActivityId { get; set; }
    public AssetKind Kind { get; set; }
    /// <summary>Stable key within a lesson, e.g. "intro", "praise-0", "word-apple", "image-apple", "phoneme".</summary>
    public string Role { get; set; } = "";
    /// <summary>Narration text for audio, or the image prompt for images (from the curriculum).</summary>
    public string SourceText { get; set; } = "";
    public AssetStatus Status { get; set; }
    public string ContentHash { get; set; } = "";
    public string? BlobPath { get; set; }
    public AssetSource Source { get; set; }
    public bool RequiresHumanReview { get; set; }

    public Lesson Lesson { get; set; } = null!;

    /// <summary>Allowed transitions: forward one step, or back to Draft (regenerate).</summary>
    public bool CanTransitionTo(AssetStatus next) =>
        next == AssetStatus.Draft || (int)next == (int)Status + 1;
}
