using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class AuthAndChildrenTests(ApiFactory factory)
{
    private HttpClient Client() => factory.CreateClient();

    private static async Task<AuthResponse> RegisterAsync(HttpClient c, string? email = null)
    {
        email ??= $"{Guid.NewGuid():N}@test.com";
        var res = await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest(email, "Passw0rd!x", "Parent", true, true));
        res.StatusCode.ShouldBe(HttpStatusCode.OK);
        return (await res.Content.ReadFromJsonAsync<AuthResponse>())!;
    }

    private static HttpClient Authed(HttpClient c, string token)
    {
        c.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return c;
    }

    [Fact]
    public async Task Register_then_login_works_and_bad_password_is_401()
    {
        var c = Client();
        var email = $"{Guid.NewGuid():N}@test.com";
        await RegisterAsync(c, email);

        (await c.PostAsJsonAsync("/api/auth/login", new LoginRequest(email, "Passw0rd!x")))
            .StatusCode.ShouldBe(HttpStatusCode.OK);
        (await c.PostAsJsonAsync("/api/auth/login", new LoginRequest(email, "wrong-password")))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Duplicate_email_is_rejected()
    {
        var c = Client();
        var email = $"{Guid.NewGuid():N}@test.com";
        await RegisterAsync(c, email);
        var res = await c.PostAsJsonAsync("/api/auth/register", new RegisterRequest(email, "Passw0rd!x", "Parent", true, true));
        res.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task Refresh_rotates_and_reuse_is_rejected()
    {
        var c = Client();
        var first = await RegisterAsync(c);

        var ok = await c.PostAsJsonAsync("/api/auth/refresh", new RefreshRequest(first.RefreshToken));
        ok.StatusCode.ShouldBe(HttpStatusCode.OK);
        var second = (await ok.Content.ReadFromJsonAsync<AuthResponse>())!;
        second.RefreshToken.ShouldNotBe(first.RefreshToken);

        (await c.PostAsJsonAsync("/api/auth/refresh", new RefreshRequest(first.RefreshToken)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        // Reuse detection revoked the family, so the newer token is dead too.
        (await c.PostAsJsonAsync("/api/auth/refresh", new RefreshRequest(second.RefreshToken)))
            .StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Children_require_auth()
    {
        (await Client().GetAsync("/api/children")).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
    }

    [Fact]
    public async Task Child_crud_and_ownership_isolation()
    {
        var owner = Authed(Client(), (await RegisterAsync(Client())).AccessToken);
        var other = Authed(Client(), (await RegisterAsync(Client())).AccessToken);

        var create = await owner.PostAsJsonAsync("/api/children",
            new CreateChildRequest("Omar", "fox", DateTime.UtcNow.Year - 4, "little-learners"));
        create.StatusCode.ShouldBe(HttpStatusCode.Created);
        var child = (await create.Content.ReadFromJsonAsync<ChildDto>())!;
        child.Track.ShouldBe("little-learners");

        (await owner.GetFromJsonAsync<List<ChildDto>>("/api/children"))!.Count.ShouldBe(1);

        // Another parent must neither see nor modify this child.
        (await other.GetAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await other.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await other.GetFromJsonAsync<List<ChildDto>>("/api/children"))!.ShouldBeEmpty();

        (await owner.DeleteAsync($"/api/children/{child.Id}")).StatusCode.ShouldBe(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task Unknown_track_is_400()
    {
        var c = Authed(Client(), (await RegisterAsync(Client())).AccessToken);
        var res = await c.PostAsJsonAsync("/api/children", new CreateChildRequest("Omar", "fox", DateTime.UtcNow.Year - 4, "no-such-track"));
        res.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }
}
