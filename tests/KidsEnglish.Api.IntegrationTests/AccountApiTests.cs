using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Application.Progress;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Shouldly;
using KidsEnglish.Infrastructure.Persistence;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class AccountApiTests(ApiFactory factory)
{
    private const string Password = "Passw0rd!x";

    private async Task<(HttpClient Client, string Email, AuthResponse Auth, ChildDto Child)> FamilyAsync()
    {
        var c = factory.CreateClient();
        var email = $"{Guid.NewGuid():N}@test.com";
        var auth = (await (await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest(email, Password, "Parent"))).Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var child = (await (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Omar", "star", DateTime.UtcNow.Year - 4, "little-learners")))
            .Content.ReadFromJsonAsync<ChildDto>())!;
        await c.PostAsJsonAsync($"/api/children/{child.Id}/progress", new SubmitProgressRequest(
            [new ProgressItemDto(Guid.NewGuid(), "letter-a", "trace", 3, 1, 30, DateTime.UtcNow.AddMinutes(-2))]));
        return (c, email, auth, child);
    }

    private async Task<(int Children, int Progress, int Tokens, int Parents)> CountsAsync(Guid parentId, Guid childId)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return (await db.Children.CountAsync(c => c.ParentId == parentId),
            await db.ProgressRecords.CountAsync(p => p.ChildId == childId),
            await db.RefreshTokens.CountAsync(t => t.ParentId == parentId),
            await db.Parents.CountAsync(p => p.Id == parentId));
    }

    [Fact]
    public async Task Deleting_the_account_removes_the_parent_children_progress_and_tokens()
    {
        var (c, email, auth, child) = await FamilyAsync();
        (await CountsAsync(auth.ParentId, child.Id)).ShouldBe((1, 1, 1, 1));

        var res = await c.PostAsJsonAsync("/api/account/delete", new DeleteAccountRequest(Password));
        res.StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CountsAsync(auth.ParentId, child.Id)).ShouldBe((0, 0, 0, 0));
        // the account is really gone: neither logging in nor refreshing works any more
        (await factory.CreateClient().PostAsJsonAsync("/api/auth/login", new LoginRequest(email, Password))).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        (await factory.CreateClient().PostAsJsonAsync("/api/auth/refresh", new RefreshRequest(auth.RefreshToken))).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task A_wrong_password_deletes_nothing()
    {
        var (c, _, auth, child) = await FamilyAsync();
        var res = await c.PostAsJsonAsync("/api/account/delete", new DeleteAccountRequest("not-the-password"));
        res.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        (await CountsAsync(auth.ParentId, child.Id)).ShouldBe((1, 1, 1, 1));
    }

    [Fact]
    public async Task Deleting_requires_a_signed_in_user_and_a_password()
    {
        (await factory.CreateClient().PostAsJsonAsync("/api/account/delete", new DeleteAccountRequest(Password))).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        var (c, _, _, _) = await FamilyAsync();
        (await c.PostAsJsonAsync("/api/account/delete", new DeleteAccountRequest(""))).StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task One_familys_deletion_does_not_touch_another()
    {
        var (a, _, authA, childA) = await FamilyAsync();
        var (_, _, authB, childB) = await FamilyAsync();
        (await a.PostAsJsonAsync("/api/account/delete", new DeleteAccountRequest(Password))).StatusCode.ShouldBe(HttpStatusCode.NoContent);
        (await CountsAsync(authA.ParentId, childA.Id)).ShouldBe((0, 0, 0, 0));
        (await CountsAsync(authB.ParentId, childB.Id)).ShouldBe((1, 1, 1, 1));
    }
}
