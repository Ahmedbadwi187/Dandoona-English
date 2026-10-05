namespace KidsEnglish.Domain.Entities;

public class ProgressRecord
{
    public Guid Id { get; set; }
    public Guid ChildId { get; set; }
    public Guid ActivityId { get; set; }
    public int Stars { get; set; }
    public int Attempts { get; set; }
    public int TimeSpentSeconds { get; set; }
    public DateTime CompletedAt { get; set; }
    /// <summary>Client-generated id making offline-queue retries idempotent.</summary>
    public Guid ClientRecordId { get; set; }

    public Child Child { get; set; } = null!;
    public Activity Activity { get; set; } = null!;
}
