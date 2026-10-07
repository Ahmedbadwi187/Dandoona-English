using KidsEnglish.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Abstractions;

public interface IAppDbContext
{
    DbSet<Parent> Parents { get; }
    DbSet<Child> Children { get; }
    DbSet<ProgressRecord> ProgressRecords { get; }
    DbSet<ChildAchievement> ChildAchievements { get; }
    DbSet<RefreshToken> RefreshTokens { get; }
    Task<int> SaveChangesAsync(CancellationToken ct);
}

public interface IClock { DateTime UtcNow { get; } }

public record IdentityResult(bool Succeeded, Guid UserId, IReadOnlyList<string> Errors);

/// <summary>Wraps ASP.NET Identity so Application stays framework-free.</summary>
public interface IIdentityService
{
    Task<IdentityResult> CreateUserAsync(string email, string password, CancellationToken ct);
    /// <summary>Returns the user id on valid credentials; null otherwise (including lockout).</summary>
    Task<Guid?> ValidateCredentialsAsync(string email, string password, CancellationToken ct);
    Task<string?> GetEmailAsync(Guid userId, CancellationToken ct);
    /// <summary>A token the parent types or opens from the verification e-mail; null when the user does not exist.</summary>
    Task<string?> CreateEmailConfirmationTokenAsync(Guid userId, CancellationToken ct);
    Task<bool> ConfirmEmailAsync(string email, string token, CancellationToken ct);
    /// <summary>A reset token for the account with this e-mail, or null when there is none (callers must not reveal which).</summary>
    Task<(Guid UserId, string Token)?> CreatePasswordResetTokenAsync(string email, CancellationToken ct);
    Task<IdentityResult> ResetPasswordAsync(string email, string token, string newPassword, CancellationToken ct);
    /// <summary>Deletes the Identity user. The database cascades to the parent profile, children, progress and tokens.</summary>
    Task<bool> DeleteUserAsync(Guid userId, CancellationToken ct);
}

public record EmailMessage(string To, string Subject, string Body);

/// <summary>Sends e-mail. The provider is not chosen yet: development writes the message to the log (see DevEmailSender).</summary>
public interface IEmailSender
{
    Task SendAsync(EmailMessage message, CancellationToken ct);
}

public record AccessToken(string Token, DateTime ExpiresAt);

public interface ITokenService
{
    AccessToken CreateAccessToken(Guid parentId, string email);
    /// <summary>Returns (rawToken, sha256Hash). Only the hash is stored.</summary>
    (string Raw, string Hash) CreateRefreshToken();
    string Hash(string rawToken);
    TimeSpan RefreshTokenLifetime { get; }
}

public interface ICurrentUser { Guid ParentId { get; } }
