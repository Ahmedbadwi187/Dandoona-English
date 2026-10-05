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
}
