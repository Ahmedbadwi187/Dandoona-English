using FluentValidation;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Common;

namespace KidsEnglish.Application.Auth;

public record DeleteAccountRequest(string Password);

public class DeleteAccountRequestValidator : AbstractValidator<DeleteAccountRequest>
{
    public DeleteAccountRequestValidator() => RuleFor(x => x.Password).NotEmpty().MaximumLength(128);
}

/// <summary>
/// Permanent account deletion (required by Google Play and the App Store for apps with accounts).
/// Needs the password again, so a stolen access token alone cannot erase a family's data.
/// </summary>
public class AccountService(IIdentityService identity, ICurrentUser user, IValidator<DeleteAccountRequest> validator)
{
    public async Task DeleteAsync(DeleteAccountRequest request, CancellationToken ct)
    {
        await validator.ValidateAndThrowAsync(request, ct);

        var email = await identity.GetEmailAsync(user.ParentId, ct) ?? throw new AuthenticationFailedException("Account not found.");
        var verified = await identity.ValidateCredentialsAsync(email, request.Password, ct);
        if (verified != user.ParentId) throw new AuthenticationFailedException("Password is incorrect.");

        if (!await identity.DeleteUserAsync(user.ParentId, ct))
            throw new ConflictException("The account could not be deleted. Please try again.");
    }
}
