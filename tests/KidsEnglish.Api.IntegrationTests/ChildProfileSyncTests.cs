using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

/// <summary>The profile fields added for skills, tracks and automatic sync: optional (older apps keep working) and the newest change wins.</summary>
[Collection("api")]
public class ChildProfileSyncTests(ApiFactory factory)
{
    private async Task<HttpClient> ParentAsync()
    {
        var c = factory.CreateClient();
        var auth = (await (await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest($"{Guid.NewGuid():N}@test.com", "Passw0rd!x", "Parent", true, true))).Content.ReadFromJsonAsync<AuthResponse>())!;
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", auth.AccessToken);
        return c;
    }

    private static readonly int Year = DateTime.UtcNow.Year - 7;
    private static readonly DateTime T0 = new(2026, 10, 1, 9, 0, 0, DateTimeKind.Utc);

    [Fact]
    public async Task Skills_goal_and_track_are_stored_and_come_back_to_another_phone()
    {
        var c = await ParentAsync();
        var created = (await (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Lina", "fox", Year, "explorers", 2, 10, ["all-letters", "letter-sounds", "some-letters"], T0))).Content.ReadFromJsonAsync<ChildDto>())!;
        created.GoalMinutes.ShouldBe(10);
        created.Skills.ShouldBe(["all-letters", "letter-sounds", "some-letters"], ignoreOrder: true);
        created.UpdatedAt.ShouldBe(T0);

        var list = (await c.GetFromJsonAsync<List<ChildDto>>("/api/children"))!;
        list.Single().Track.ShouldBe("explorers");
        list.Single().Skills!.Length.ShouldBe(3);
    }

    [Fact]
    public async Task An_older_app_that_sends_none_of_the_new_fields_still_works_and_does_not_wipe_them()
    {
        var c = await ParentAsync();
        var created = (await (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Lina", "fox", Year, "explorers", 2, 15, ["colors"], T0))).Content.ReadFromJsonAsync<ChildDto>())!;

        // a body exactly as the old app wrote it: no goal, no skills, no time
        var old = new StringContent("""{"name":"Lina B","avatarKey":"cat","birthYear":%YEAR%,"track":"explorers","birthMonth":3}""".Replace("%YEAR%", Year.ToString()), System.Text.Encoding.UTF8, "application/json");
        var res = await c.PutAsync($"/api/children/{created.Id}", old);
        res.StatusCode.ShouldBe(HttpStatusCode.OK);
        var after = (await res.Content.ReadFromJsonAsync<ChildDto>())!;
        after.Name.ShouldBe("Lina B");
        after.GoalMinutes.ShouldBe(15);
        after.Skills.ShouldBe(["colors"]);

        // and an old app can create a child with only the old fields
        var plain = new StringContent("""{"name":"Omar","avatarKey":"star","birthYear":%YEAR%,"track":"little-learners"}""".Replace("%YEAR%", Year.ToString()), System.Text.Encoding.UTF8, "application/json");
        var made = (await c.PostAsync("/api/children", plain));
        made.StatusCode.ShouldBe(HttpStatusCode.Created);
        var dto = (await made.Content.ReadFromJsonAsync<ChildDto>())!;
        dto.Skills.ShouldBeNull();
        dto.GoalMinutes.ShouldBeNull();
    }

    [Fact]
    public async Task The_most_recent_profile_change_wins_and_an_older_one_is_ignored()
    {
        var c = await ParentAsync();
        var created = (await (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Lina", "fox", Year, "explorers", 2, 10, ["colors"], T0))).Content.ReadFromJsonAsync<ChildDto>())!;

        var newer = (await (await c.PutAsJsonAsync($"/api/children/{created.Id}", new UpdateChildRequest("Lina", "fox", Year, "explorers", 2, 15, ["colors", "counting"], T0.AddHours(2)))).Content.ReadFromJsonAsync<ChildDto>())!;
        newer.GoalMinutes.ShouldBe(15);

        // the other phone changed it earlier (offline) and syncs late: ignored, and it learns what the server has
        var late = (await (await c.PutAsJsonAsync($"/api/children/{created.Id}", new UpdateChildRequest("Lina Z", "cat", Year, "little-learners", 2, 5, ["animals"], T0.AddHours(1)))).Content.ReadFromJsonAsync<ChildDto>())!;
        late.Name.ShouldBe("Lina");
        late.GoalMinutes.ShouldBe(15);
        late.Skills!.ShouldBe(["colors", "counting"], ignoreOrder: true);
        late.Track.ShouldBe("explorers");
    }

    [Fact]
    public async Task Bad_skills_or_goal_are_refused()
    {
        var c = await ParentAsync();
        (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Lina", "fox", Year, "explorers", 2, 0, null, T0))).StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        (await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Lina", "fox", Year, "explorers", 2, 10, ["has space"], T0))).StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }
}
