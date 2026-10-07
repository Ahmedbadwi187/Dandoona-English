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

/// <summary>Certificates, chests, reviews, stories and placement follow the family to a new phone.</summary>
[Collection("api")]
public class AchievementsApiTests(ApiFactory factory)
{
    private async Task<(HttpClient Client, ChildDto Child, string Email)> ParentWithChildAsync()
    {
        var c = factory.CreateClient();
        var email = $"{Guid.NewGuid():N}@test.com";
        var auth = (await (await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest(email, "Passw0rd!x", "Parent", true, true))).Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var child = (await (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Omar", "star", DateTime.UtcNow.Year - 4, "little-learners"))).Content.ReadFromJsonAsync<ChildDto>())!;
        return (c, child, email);
    }

    private static readonly DateTime Sep1 = new(2026, 9, 1, 10, 0, 0, DateTimeKind.Utc);

    [Fact]
    public async Task Two_phones_merge_into_one_set_with_the_earliest_date_and_sending_again_changes_nothing()
    {
        var (c, child, _) = await ParentWithChildAsync();
        var url = $"/api/children/{child.Id}/achievements";

        var phoneA = new SubmitAchievementsRequest([new("certificate", "letters", Sep1.AddDays(2)), new("chest", "letters", Sep1.AddDays(2))]);
        var phoneB = new SubmitAchievementsRequest([new("certificate", "letters", Sep1), new("review", "review-1", Sep1.AddDays(5))]);
        (await (await c.PostAsJsonAsync(url, phoneA)).Content.ReadFromJsonAsync<SubmitAchievementsResponse>())!.Added.ShouldBe(2);
        var b = (await (await c.PostAsJsonAsync(url, phoneB)).Content.ReadFromJsonAsync<SubmitAchievementsResponse>())!;
        b.Added.ShouldBe(1);
        b.Known.ShouldBe(1);
        (await (await c.PostAsJsonAsync(url, phoneB)).Content.ReadFromJsonAsync<SubmitAchievementsResponse>())!.Added.ShouldBe(0);

        var all = (await c.GetFromJsonAsync<List<AchievementDto>>(url))!;
        all.Select(a => $"{a.Kind}:{a.Key}").ShouldBe(["certificate:letters", "chest:letters", "review:review-1"]);
        all.Single(a => a.Kind == "certificate").EarnedAt.ShouldBe(Sep1); // phone B earned it first
    }

    [Fact]
    public async Task Unknown_kinds_and_free_text_keys_are_refused()
    {
        var (c, child, _) = await ParentWithChildAsync();
        var url = $"/api/children/{child.Id}/achievements";
        (await c.PostAsJsonAsync(url, new SubmitAchievementsRequest([new("badge", "letters", Sep1)]))).StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await c.PostAsJsonAsync(url, new SubmitAchievementsRequest([new("chest", "My Letters!", Sep1)]))).StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Another_parent_cannot_read_or_write_them()
    {
        var (_, child, _) = await ParentWithChildAsync();
        var (stranger, _, _) = await ParentWithChildAsync();
        var url = $"/api/children/{child.Id}/achievements";
        (await stranger.GetAsync(url)).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await stranger.PostAsJsonAsync(url, new SubmitAchievementsRequest([new("chest", "letters", Sep1)]))).StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task They_are_deleted_with_the_child()
    {
        var (c, child, _) = await ParentWithChildAsync();
        await c.PostAsJsonAsync($"/api/children/{child.Id}/achievements", new SubmitAchievementsRequest([new("chest", "letters", Sep1)]));
        (await c.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NoContent);
        using var scope = factory.Services.CreateScope();
        (await scope.ServiceProvider.GetRequiredService<AppDbContext>().ChildAchievements.CountAsync(a => a.ChildId == child.Id)).ShouldBe(0);
    }

    [Fact]
    public async Task A_new_phone_gets_every_result_and_the_best_one_per_lesson_wins()
    {
        // Two phones played the same lesson: 1 star on one, 3 on the other. The server keeps both summaries; the best counts.
        var (c, child, _) = await ParentWithChildAsync();
        var url = $"/api/children/{child.Id}/progress";
        await c.PostAsJsonAsync(url, new SubmitProgressRequest([new(Guid.NewGuid(), "letter-a", "trace", 1, 4, 50, Sep1)]));
        await c.PostAsJsonAsync(url, new SubmitProgressRequest([new(Guid.NewGuid(), "letter-a", "trace", 3, 1, 20, Sep1.AddHours(1))]));
        var restored = (await c.GetFromJsonAsync<List<ProgressItemDto>>(url))!;
        restored.Count.ShouldBe(2);
        restored.Where(r => r.LessonId == "letter-a" && r.Activity == "trace").Max(r => r.Stars).ShouldBe(3);
    }
}
