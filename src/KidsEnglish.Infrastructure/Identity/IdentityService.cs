using KidsEnglish.Application.Abstractions;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using IdentityResult = KidsEnglish.Application.Abstractions.IdentityResult;

namespace KidsEnglish.Infrastructure.Identity;

internal class IdentityService(UserManager<ApplicationUser> users) : IIdentityService
{
    public async Task<IdentityResult> CreateUserAsync(string email, string password, CancellationToken ct)
    {
        var user = new ApplicationUser { Id = Guid.NewGuid(), UserName = email, Email = email };
        var result = await users.CreateAsync(user, password);
        return new IdentityResult(result.Succeeded, user.Id, result.Errors.Select(e => e.Description).ToList());
    }

    public async Task<Guid?> ValidateCredentialsAsync(string email, string password, CancellationToken ct)
    {
        var user = await users.FindByEmailAsync(email);
        if (user is null) return null;
        if (await users.IsLockedOutAsync(user)) return null;

        if (await users.CheckPasswordAsync(user, password))
        {
            await users.ResetAccessFailedCountAsync(user);
            return user.Id;
        }
        await users.AccessFailedAsync(user);
        return null;
    }

    public async Task<string?> GetEmailAsync(Guid userId, CancellationToken ct) =>
        (await users.FindByIdAsync(userId.ToString()))?.Email;

    public async Task<string?> CreateEmailConfirmationTokenAsync(Guid userId, CancellationToken ct)
    {
        var user = await users.FindByIdAsync(userId.ToString());
        return user is null ? null : await users.GenerateEmailConfirmationTokenAsync(user);
    }

    public async Task<bool> ConfirmEmailAsync(string email, string token, CancellationToken ct)
    {
        var user = await users.FindByEmailAsync(email);
        return user is not null && (await users.ConfirmEmailAsync(user, token)).Succeeded;
    }

    public async Task<(Guid UserId, string Token)?> CreatePasswordResetTokenAsync(string email, CancellationToken ct)
    {
        var user = await users.FindByEmailAsync(email);
        return user is null ? null : (user.Id, await users.GeneratePasswordResetTokenAsync(user));
    }

    public async Task<IdentityResult> ResetPasswordAsync(string email, string token, string newPassword, CancellationToken ct)
    {
        var user = await users.FindByEmailAsync(email);
        if (user is null) return new IdentityResult(false, Guid.Empty, ["The code is not valid."]);
        var result = await users.ResetPasswordAsync(user, token, newPassword);
        return new IdentityResult(result.Succeeded, user.Id, result.Errors.Select(e => e.Description).ToList());
    }

    public async Task<bool> DeleteUserAsync(Guid userId, CancellationToken ct)
    {
        var user = await users.FindByIdAsync(userId.ToString());
        return user is not null && (await users.DeleteAsync(user)).Succeeded;
    }
}
