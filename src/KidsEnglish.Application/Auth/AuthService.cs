using FluentValidation;
using FluentValidation.Results;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Common;
using KidsEnglish.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Auth;

public class AuthService(
    IAppDbContext db,
    IIdentityService identity,
    ITokenService tokens,
    IClock clock,
    IEmailSender email,
    IValidator<RegisterRequest> registerValidator,
    IValidator<LoginRequest> loginValidator,
    IValidator<RefreshRequest> refreshValidator,
    IValidator<LogoutRequest> logoutValidator,
    IValidator<VerifyEmailRequest> verifyValidator,
    IValidator<ForgotPasswordRequest> forgotValidator,
    IValidator<ResetPasswordRequest> resetValidator)
{
    public async Task<AuthResponse> RegisterAsync(RegisterRequest request, CancellationToken ct)
    {
        await registerValidator.ValidateAndThrowAsync(request, ct);

        var created = await identity.CreateUserAsync(request.Email, request.Password, ct);
        if (!created.Succeeded)
            throw new ValidationException(created.Errors.Select(e => new ValidationFailure("Email", e)));

        db.Parents.Add(new Parent
        {
            Id = created.UserId,
            DisplayName = string.IsNullOrWhiteSpace(request.DisplayName) ? "Parent" : request.DisplayName.Trim(),
            CreatedAt = clock.UtcNow,
            GuardianConfirmedAt = clock.UtcNow,
            TermsAcceptedAt = clock.UtcNow
        });
        await db.SaveChangesAsync(ct);

        await SendVerificationAsync(created.UserId, request.Email, ct);

        return await IssueAsync(created.UserId, request.Email, ct);
    }

    /// <summary>The account works at once; verifying the e-mail is a courtesy. A failed send never fails the sign-up.</summary>
    private async Task SendVerificationAsync(Guid userId, string address, CancellationToken ct)
    {
        try
        {
            var token = await identity.CreateEmailConfirmationTokenAsync(userId, ct);
            if (token is null) return;
            await email.SendAsync(new EmailMessage(address, "Verify your email for Dandoona English",
                $"Welcome to Dandoona English!\n\nYour verification code:\n{token}\n\nIf you did not create this account you can ignore this message."), ct);
        }
        catch (Exception)
        {
            // not worth failing the registration
        }
    }

    public async Task VerifyEmailAsync(VerifyEmailRequest request, CancellationToken ct)
    {
        await verifyValidator.ValidateAndThrowAsync(request, ct);
        if (!await identity.ConfirmEmailAsync(request.Email, request.Token, ct))
            throw new ValidationException([new ValidationFailure("Token", "The code is not valid.")]);
    }

    /// <summary>Always succeeds from the caller's point of view, so nobody can find out which e-mails have accounts.</summary>
    public async Task ForgotPasswordAsync(ForgotPasswordRequest request, CancellationToken ct)
    {
        await forgotValidator.ValidateAndThrowAsync(request, ct);
        var reset = await identity.CreatePasswordResetTokenAsync(request.Email, ct);
        if (reset is null) return;
        await email.SendAsync(new EmailMessage(request.Email, "Reset your Dandoona English password",
            $"Your password reset code:\n{reset.Value.Token}\n\nType it in the app within a few minutes. If you did not ask for this you can ignore this message; your password stays the same."), ct);
    }

    public async Task ResetPasswordAsync(ResetPasswordRequest request, CancellationToken ct)
    {
        await resetValidator.ValidateAndThrowAsync(request, ct);
        var result = await identity.ResetPasswordAsync(request.Email, request.Token, request.NewPassword, ct);
        if (!result.Succeeded)
            throw new ValidationException(result.Errors.Select(e => new ValidationFailure("Token", e)));
        // every device signed in with the old password is signed out
        await RevokeAllAsync(result.UserId, clock.UtcNow, ct);
    }

    public async Task<AuthResponse> LoginAsync(LoginRequest request, CancellationToken ct)
    {
        await loginValidator.ValidateAndThrowAsync(request, ct);

        var userId = await identity.ValidateCredentialsAsync(request.Email, request.Password, ct)
            ?? throw new AuthenticationFailedException("Invalid email or password.");
        return await IssueAsync(userId, request.Email, ct);
    }

    public async Task<AuthResponse> RefreshAsync(RefreshRequest request, CancellationToken ct)
    {
        await refreshValidator.ValidateAndThrowAsync(request, ct);

        var hash = tokens.Hash(request.RefreshToken);
        var existing = await db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct)
            ?? throw new AuthenticationFailedException("Invalid refresh token.");

        var now = clock.UtcNow;
        if (existing.RevokedAt is not null)
        {
            // Reuse of a rotated token suggests theft: revoke every active token for this parent.
            await RevokeAllAsync(existing.ParentId, now, ct);
            throw new AuthenticationFailedException("Invalid refresh token.");
        }
        if (!existing.IsActive(now)) throw new AuthenticationFailedException("Invalid refresh token.");

        var email = await identity.GetEmailAsync(existing.ParentId, ct)
            ?? throw new AuthenticationFailedException("Invalid refresh token.");

        return await IssueAsync(existing.ParentId, email, ct, existing);
    }

    public async Task LogoutAsync(LogoutRequest request, CancellationToken ct)
    {
        await logoutValidator.ValidateAndThrowAsync(request, ct);
        var hash = tokens.Hash(request.RefreshToken);
        var token = await db.RefreshTokens.FirstOrDefaultAsync(t => t.TokenHash == hash, ct);
        if (token is { RevokedAt: null })
        {
            token.RevokedAt = clock.UtcNow;
            await db.SaveChangesAsync(ct);
        }
    }

    private async Task<AuthResponse> IssueAsync(Guid parentId, string email, CancellationToken ct, RefreshToken? rotatedFrom = null)
    {
        var now = clock.UtcNow;
        var access = tokens.CreateAccessToken(parentId, email);
        var (raw, hash) = tokens.CreateRefreshToken();

        var refresh = new RefreshToken
        {
            Id = Guid.NewGuid(),
            ParentId = parentId,
            TokenHash = hash,
            CreatedAt = now,
            ExpiresAt = now + tokens.RefreshTokenLifetime
        };
        db.RefreshTokens.Add(refresh);
        if (rotatedFrom is not null)
        {
            rotatedFrom.RevokedAt = now;
            rotatedFrom.ReplacedByTokenId = refresh.Id;
        }
        await db.SaveChangesAsync(ct);

        return new AuthResponse(access.Token, access.ExpiresAt, raw, parentId);
    }

    private async Task RevokeAllAsync(Guid parentId, DateTime now, CancellationToken ct)
    {
        var active = await db.RefreshTokens.Where(t => t.ParentId == parentId && t.RevokedAt == null).ToListAsync(ct);
        foreach (var t in active) t.RevokedAt = now;
        await db.SaveChangesAsync(ct);
    }
}
