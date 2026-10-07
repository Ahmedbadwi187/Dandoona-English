using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Application.Progress;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class ProgressApiTests(ApiFactory factory)
{
    private async Task<(HttpClient Client, ChildDto Child)> ParentWithChildAsync()
    {
        var c = factory.CreateClient();
        var res = await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest($"{Guid.NewGuid():N}@test.com", "Passw0rd!x", "Parent", true, true));
        var auth = (await res.Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        var created = await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Omar", "star", DateTime.UtcNow.Year - 4, "little-learners"));
        return (c, (await created.Content.ReadFromJsonAsync<ChildDto>())!);
    }

    private static ProgressItemDto Item(DateTime at, string lesson = "letter-a", string activity = "trace", int stars = 3, int seconds = 60, Guid? id = null) =>
        new(id ?? Guid.NewGuid(), lesson, activity, stars, 1, seconds, at);

    private static DateTime ThisMonday()
    {
        var today = DateTime.UtcNow.Date;
        return today.AddDays(-(((int)today.DayOfWeek + 6) % 7));
    }

    [Fact]
    public async Task Submit_is_idempotent_by_client_record_id()
    {
        var (c, child) = await ParentWithChildAsync();
        var sameId = Guid.NewGuid();
        var batch = new SubmitProgressRequest([Item(DateTime.UtcNow.AddMinutes(-5), id: sameId), Item(DateTime.UtcNow.AddMinutes(-4))]);

        var first = await c.PostAsJsonAsync($"/api/children/{child.Id}/progress", batch);
        first.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await first.Content.ReadFromJsonAsync<SubmitProgressResponse>()).ShouldBe(new SubmitProgressResponse(2, 0));

        // the app retries the same batch after a dropped connection: nothing is stored twice
        var again = await c.PostAsJsonAsync($"/api/children/{child.Id}/progress", batch);
        (await again.Content.ReadFromJsonAsync<SubmitProgressResponse>()).ShouldBe(new SubmitProgressResponse(0, 2));

        var all = await c.GetFromJsonAsync<List<ProgressItemDto>>($"/api/children/{child.Id}/progress");
        all!.Count.ShouldBe(2);
        all.ShouldContain(x => x.ClientRecordId == sameId && x.Activity == "trace");
    }

    [Fact]
    public async Task The_color_the_object_activity_of_the_Colors_unit_is_accepted_and_read_back_by_its_code()
    {
        var (c, child) = await ParentWithChildAsync();
        var id = Guid.NewGuid();
        var res = await c.PostAsJsonAsync($"/api/children/{child.Id}/progress",
            new SubmitProgressRequest([Item(DateTime.UtcNow.AddMinutes(-1), "color-red", "color-the-object", id: id)]));
        res.StatusCode.ShouldBe(HttpStatusCode.OK);
        (await res.Content.ReadFromJsonAsync<SubmitProgressResponse>()).ShouldBe(new SubmitProgressResponse(1, 0));

        var all = await c.GetFromJsonAsync<List<ProgressItemDto>>($"/api/children/{child.Id}/progress");
        all!.ShouldContain(x => x.ClientRecordId == id && x.LessonId == "color-red" && x.Activity == "color-the-object");
    }

    [Fact]
    public async Task Duplicate_ids_inside_one_batch_are_stored_once()
    {
        var (c, child) = await ParentWithChildAsync();
        var id = Guid.NewGuid();
        var res = await c.PostAsJsonAsync($"/api/children/{child.Id}/progress",
            new SubmitProgressRequest([Item(DateTime.UtcNow.AddMinutes(-1), id: id), Item(DateTime.UtcNow.AddMinutes(-1), id: id)]));
        (await res.Content.ReadFromJsonAsync<SubmitProgressResponse>()).ShouldBe(new SubmitProgressResponse(1, 1));
    }

    [Fact]
    public async Task Invalid_records_are_rejected_with_400_and_nothing_is_saved()
    {
        var (c, child) = await ParentWithChildAsync();
        var res = await c.PostAsJsonAsync($"/api/children/{child.Id}/progress",
            new SubmitProgressRequest([Item(DateTime.UtcNow.AddMinutes(-1)), Item(DateTime.UtcNow.AddMinutes(-1), stars: 9)]));
        res.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await c.GetFromJsonAsync<List<ProgressItemDto>>($"/api/children/{child.Id}/progress"))!.ShouldBeEmpty();
    }

    [Fact]
    public async Task Another_parent_cannot_read_or_write_a_childs_progress()
    {
        var (owner, child) = await ParentWithChildAsync();
        var (stranger, _) = await ParentWithChildAsync();
        await owner.PostAsJsonAsync($"/api/children/{child.Id}/progress", new SubmitProgressRequest([Item(DateTime.UtcNow.AddMinutes(-1))]));

        (await stranger.PostAsJsonAsync($"/api/children/{child.Id}/progress", new SubmitProgressRequest([Item(DateTime.UtcNow.AddMinutes(-1))])))
            .StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await stranger.GetAsync($"/api/children/{child.Id}/progress")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await stranger.GetAsync($"/api/children/{child.Id}/summary")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
    }

    [Fact]
    public async Task Progress_requires_authentication()
    {
        var res = await factory.CreateClient().GetAsync($"/api/children/{Guid.NewGuid()}/progress");
        res.StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Weekly_summary_totals_per_day_and_ignores_other_weeks()
    {
        var (c, child) = await ParentWithChildAsync();
        var monday = ThisMonday();
        var items = new List<ProgressItemDto>
        {
            Item(monday.AddHours(9), "letter-a", "trace", 3, 60),
            Item(monday.AddHours(10), "letter-a", "listen-and-tap", 2, 90),
            Item(monday.AddDays(2).AddHours(8), "letter-b", "match-picture", 1, 30),
            Item(monday.AddDays(-3), "letter-z", "trace", 3, 500),     // previous week: excluded
        };
        // only records not in the future relative to the server clock are valid, so keep the week's later days out of the test
        if (monday.AddDays(2).AddHours(8) > DateTime.UtcNow) items.RemoveAt(2);
        await c.PostAsJsonAsync($"/api/children/{child.Id}/progress", new SubmitProgressRequest(items.Where(i => i.CompletedAt <= DateTime.UtcNow).ToList()));

        var s = (await c.GetFromJsonAsync<WeeklySummaryDto>($"/api/children/{child.Id}/summary?weekStart={monday:yyyy-MM-dd}"))!;
        s.ChildName.ShouldBe("Omar");
        s.WeekStart.ShouldBe(DateOnly.FromDateTime(monday));
        s.WeekEnd.ShouldBe(DateOnly.FromDateTime(monday).AddDays(6));
        s.Days.Count.ShouldBe(7);
        var expected = items.Where(i => i.CompletedAt >= monday && i.CompletedAt <= DateTime.UtcNow).ToList();
        s.ActivitiesCompleted.ShouldBe(expected.Count);
        s.TotalStars.ShouldBe(expected.Sum(i => i.Stars));
        s.TimeSpentSeconds.ShouldBe(expected.Sum(i => i.TimeSpentSeconds));
        s.LessonsPracticed.ShouldBe(expected.Select(i => i.LessonId).Distinct().Count());
        s.ActiveDays.ShouldBe(expected.Select(i => i.CompletedAt.Date).Distinct().Count());
        s.Days[0].Stars.ShouldBe(5); // Monday: 3 + 2
    }

    [Fact]
    public async Task Any_date_in_the_week_resolves_to_that_weeks_Monday_and_all_children_summary_works()
    {
        var (c, child) = await ParentWithChildAsync();
        var monday = ThisMonday();
        var wednesday = monday.AddDays(2);
        var s = (await c.GetFromJsonAsync<WeeklySummaryDto>($"/api/children/{child.Id}/summary?weekStart={wednesday:yyyy-MM-dd}"))!;
        s.WeekStart.ShouldBe(DateOnly.FromDateTime(monday));
        s.TotalStars.ShouldBe(0);

        var all = await c.GetFromJsonAsync<List<WeeklySummaryDto>>("/api/summary");
        all!.Single().ChildId.ShouldBe(child.Id);
    }
}
