namespace KidsEnglish.Domain.Entities;

public class RefreshToken
{
    public Guid Id { get; set; }
    public Guid ParentId { get; set; }
    public string TokenHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public Guid? ReplacedByTokenId { get; set; }

    public bool IsActive(DateTime utcNow) => RevokedAt is null && ExpiresAt > utcNow;
}
