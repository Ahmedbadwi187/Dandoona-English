using KidsEnglish.Domain.Enums;

namespace KidsEnglish.Domain.Entities;

/// <summary>Account holder profile. Id equals the Identity user id (shared primary key).</summary>
public class Parent
{
    public Guid Id { get; set; }
    public string DisplayName { get; set; } = "";
    public Language PreferredLanguage { get; set; } = Language.Arabic;
    public int SessionLimitMinutes { get; set; } = 15;
    public DateTime CreatedAt { get; set; }

    public List<Child> Children { get; set; } = [];
    public List<RefreshToken> RefreshTokens { get; set; } = [];
}
