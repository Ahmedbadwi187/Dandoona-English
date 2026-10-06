using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Application.Progress;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

/// <summary>Deleting a child on the server is a hard delete: the profile and all of that child's progress are gone.</summary>
[Collection("api")]
public class ChildDeletionApiTests(ApiFactory factory)
{
    private async Task<(HttpClient Client, ChildDto Child, ChildDto Sibling)> FamilyAsync()
    {
        var c = factory.CreateClient();
        var auth = (await (await c.PostAsJsonAsync("/api/auth/register",
            new RegisterRequest($"{Guid.NewGuid():N}@test.com", "Passw0rd!x", "Parent"))).Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);

        async Task<ChildDto> AddAsync(string name)
        {
            var child = (await (await c.PostAsJsonAsync("/api/children",
                new CreateChildRequest(name, "star", DateTime.UtcNow.Year - 4, "little-learners"))).Content.ReadFromJsonAsync<ChildDto>())!;
            await c.PostAsJsonAsync($"/api/children/{child.Id}/progress", new SubmitProgressRequest(
            [
                new ProgressItemDto(Guid.NewGuid(), "letter-a", "trace", 3, 1, 30, DateTime.UtcNow.AddMinutes(-3)),
                new ProgressItemDto(Guid.NewGuid(), "letter-a", "match-picture", 2, 2, 40, DateTime.UtcNow.AddMinutes(-2)),
            ]));
            return child;
        }
        return (c, await AddAsync("Omar"), await AddAsync("Sara"));
    }

    private async Task<(int Children, int Progress)> CountsAsync(Guid childId)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        return (await db.Children.CountAsync(c => c.Id == childId), await db.ProgressRecords.CountAsync(p => p.ChildId == childId));
    }

    [Fact]
    public async Task Deleting_a_child_hard_deletes_the_profile_and_all_its_progress_but_not_a_siblings()
    {
        var (c, child, sibling) = await FamilyAsync();
        (await CountsAsync(child.Id)).ShouldBe((1, 2));

        (await c.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await CountsAsync(child.Id)).ShouldBe((0, 0)); // rows are really gone, not flagged
        (await CountsAsync(sibling.Id)).ShouldBe((1, 2)); // the sibling is untouched
        (await c.GetAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await c.GetAsync($"/api/children/{child.Id}/progress")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Another_parent_cannot_delete_the_child()
    {
        var (_, child, _) = await FamilyAsync();
        var (stranger, _, _) = await FamilyAsync();
        (await stranger.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await CountsAsync(child.Id)).ShouldBe((1, 2));
    }

    [Fact]
    public async Task Deleting_again_is_404_so_a_retried_delete_from_the_app_can_be_treated_as_done()
    {
        var (c, child, _) = await FamilyAsync();
        (await c.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NoContent);
        (await c.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Deleting_requires_authentication()
    {
        (await factory.CreateClient().DeleteAsync($"/api/children/{Guid.NewGuid()}")).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }
}
