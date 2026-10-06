using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Application.Progress;

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

    public static void MapProgressEndpoints(this IEndpointRouteBuilder app)
    {
        var children = app.MapGroup("/api/children").WithTags("Progress").RequireAuthorization();

        // Offline-first sync: the app posts batches (max 200); resubmitting the same client record id is harmless.
        children.MapPost("/{id:guid}/progress", async (Guid id, SubmitProgressRequest r, ProgressService s, CancellationToken ct) =>
            Results.Ok(await s.SubmitAsync(id, r, ct)));
        children.MapGet("/{id:guid}/progress", async (Guid id, DateTime? since, ProgressService s, CancellationToken ct) =>
            Results.Ok(await s.ListAsync(id, since, ct)));
        children.MapGet("/{id:guid}/summary", async (Guid id, DateOnly? weekStart, ProgressService s, CancellationToken ct) =>
            Results.Ok(await s.WeeklySummaryAsync(id, weekStart, ct)));

        app.MapGet("/api/summary", async (DateOnly? weekStart, ProgressService s, CancellationToken ct) =>
            Results.Ok(await s.WeeklySummariesAsync(weekStart, ct))).WithTags("Progress").RequireAuthorization();
    }
}
