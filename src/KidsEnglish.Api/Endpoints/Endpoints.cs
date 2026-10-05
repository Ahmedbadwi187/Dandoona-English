using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;

namespace KidsEnglish.Api.Endpoints;

public static class Endpoints
{
    public static void MapAuthEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/auth").WithTags("Auth").RequireRateLimiting("auth").AllowAnonymous();

        g.MapPost("/register", async (RegisterRequest r, AuthService s, CancellationToken ct) =>
            Results.Ok(await s.RegisterAsync(r, ct)));
        g.MapPost("/login", async (LoginRequest r, AuthService s, CancellationToken ct) =>
            Results.Ok(await s.LoginAsync(r, ct)));
        g.MapPost("/refresh", async (RefreshRequest r, AuthService s, CancellationToken ct) =>
            Results.Ok(await s.RefreshAsync(r, ct)));
        g.MapPost("/logout", async (LogoutRequest r, AuthService s, CancellationToken ct) =>
        {
            await s.LogoutAsync(r, ct);
            return Results.NoContent();
        });
    }

    public static void MapChildEndpoints(this IEndpointRouteBuilder app)
    {
        var g = app.MapGroup("/api/children").WithTags("Children").RequireAuthorization();

        g.MapGet("/", async (ChildService s, CancellationToken ct) => Results.Ok(await s.ListAsync(ct)));
        g.MapGet("/{id:guid}", async (Guid id, ChildService s, CancellationToken ct) => Results.Ok(await s.GetAsync(id, ct)));
        g.MapPost("/", async (CreateChildRequest r, ChildService s, CancellationToken ct) =>
        {
            var child = await s.CreateAsync(r, ct);
            return Results.Created($"/api/children/{child.Id}", child);
        });
        g.MapPut("/{id:guid}", async (Guid id, UpdateChildRequest r, ChildService s, CancellationToken ct) =>
            Results.Ok(await s.UpdateAsync(id, r, ct)));
        g.MapDelete("/{id:guid}", async (Guid id, ChildService s, CancellationToken ct) =>
        {
            await s.DeleteAsync(id, ct);
            return Results.NoContent();
        });
    }
}
