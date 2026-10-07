using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Application.Progress;
using Microsoft.AspNetCore.Hosting;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

/// <summary>Anonymous lesson stats for the content owner: aggregated, no identifiers, small groups hidden.</summary>
[Collection("api")]
public class StatsApiTests(ApiFactory factory)
{
    /// <summary>A parent with one child who finished [lesson] with the given attempts and stars.</summary>
    private async Task<Guid> ChildPlayedAsync(string lesson, int attempts, int stars)
    {
        var c = factory.CreateClient();
        var auth = (await (await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest($"{Guid.NewGuid():N}@test.com", "Passw0rd!x", "Parent", true, true))).Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var child = (await (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Omar", "star", DateTime.UtcNow.Year - 4, "little-learners"))).Content.ReadFromJsonAsync<ChildDto>())!;
        await c.PostAsJsonAsync($"/api/children/{child.Id}/progress", new SubmitProgressRequest([new(Guid.NewGuid(), lesson, "trace", stars, attempts, 30, DateTime.UtcNow.AddMinutes(-5))]));
        return child.Id;
    }

    private HttpClient Admin(string? key = ApiFactory.StatsKey)
    {
        var c = factory.CreateClient();
        if (key is not null) c.DefaultRequestHeaders.Add("X-Stats-Key", key);
        return c;
    }

    [Fact]
    public async Task Lessons_with_enough_children_show_tries_and_stars_without_any_identifier_and_small_groups_are_hidden()
    {
        var lesson = $"stats-{Guid.NewGuid():N}"[..20];
        var few = $"few-{Guid.NewGuid():N}"[..20];
        var ids = new List<Guid>();
        for (var i = 0; i < 5; i++) ids.Add(await ChildPlayedAsync(lesson, attempts: i < 3 ? 6 : 2, stars: i < 3 ? 1 : 3));
        for (var i = 0; i < 2; i++) await ChildPlayedAsync(few, 1, 3);

        var res = await Admin().GetAsync("/api/admin/stats/lessons");
        res.StatusCode.ShouldBe(HttpStatusCode.OK);
        var body = await res.Content.ReadAsStringAsync();
        foreach (var id in ids) body.ShouldNotContain(id.ToString()); // no child ids anywhere
        body.ShouldNotContain("Omar");

        var stats = (await res.Content.ReadFromJsonAsync<LessonStatsDto>())!;
        var row = stats.Lessons.Single(l => l.LessonId == lesson);
        row.Children.ShouldBe(5);
        row.Results.ShouldBe(5);
        row.AverageAttempts.ShouldBe(4.4); // (3*6 + 2*2) / 5
        row.OneStarShare.ShouldBe(0.6);
        stats.Lessons.ShouldNotContain(l => l.LessonId == few); // only 2 children: not shown
        stats.RowsHidden.ShouldBeGreaterThan(0);
        stats.MinChildren.ShouldBe(5);
    }

    [Fact]
    public async Task Without_the_key_there_is_nothing_to_see()
    {
        (await Admin(key: null).GetAsync("/api/admin/stats/lessons")).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        (await Admin(key: "wrong").GetAsync("/api/admin/stats/lessons")).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);

        // a server with no key configured does not offer the endpoint at all
        using var noKey = factory.WithWebHostBuilder(b => b.UseSetting("Stats:Key", ""));
        var c = noKey.CreateClient();
        c.DefaultRequestHeaders.Add("X-Stats-Key", "");
        (await c.GetAsync("/api/admin/stats/lessons")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }
}
