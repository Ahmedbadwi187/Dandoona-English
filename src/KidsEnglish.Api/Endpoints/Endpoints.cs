using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using System.Security.Cryptography;
using System.Text;
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
        g.MapPost("/verify-email", async (VerifyEmailRequest r, AuthService s, CancellationToken ct) =>
        {
            await s.VerifyEmailAsync(r, ct);
            return Results.NoContent();
        });
        g.MapPost("/forgot-password", async (ForgotPasswordRequest r, AuthService s, CancellationToken ct) =>
        {
            await s.ForgotPasswordAsync(r, ct);
            return Results.NoContent();
        });
        g.MapPost("/reset-password", async (ResetPasswordRequest r, AuthService s, CancellationToken ct) =>
        {
            await s.ResetPasswordAsync(r, ct);
            return Results.NoContent();
        });
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

    public static void MapAccountEndpoints(this IEndpointRouteBuilder app)
    {
        // POST (not DELETE) so every HTTP client can send the password in a body.
        app.MapPost("/api/account/delete", async (DeleteAccountRequest r, AccountService s, CancellationToken ct) =>
        {
            await s.DeleteAsync(r, ct);
            return Results.NoContent();
        }).WithTags("Account").RequireAuthorization().RequireRateLimiting("auth");
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

        // Certificates, chests, reviews, stories and placement: the union of every phone (idempotent, earliest date kept).
        children.MapPost("/{id:guid}/achievements", async (Guid id, SubmitAchievementsRequest r, AchievementService s, CancellationToken ct) =>
            Results.Ok(await s.SubmitAsync(id, r, ct)));
        children.MapGet("/{id:guid}/achievements", async (Guid id, AchievementService s, CancellationToken ct) =>
            Results.Ok(await s.ListAsync(id, ct)));

        app.MapGet("/api/summary", async (DateOnly? weekStart, ProgressService s, CancellationToken ct) =>
            Results.Ok(await s.WeeklySummariesAsync(weekStart, ct))).WithTags("Progress").RequireAuthorization();
    }

    /// <summary>
    /// Anonymous lesson stats for the content owner (see <see cref="StatsService"/>). Only with the key from Stats:Key
    /// (user-secrets or the server's environment, never in the app) in the X-Stats-Key header; without a configured key
    /// the endpoint answers 404 as if it did not exist.
    /// </summary>
    public static void MapStatsEndpoints(this IEndpointRouteBuilder app, IConfiguration config)
    {
        app.MapGet("/api/admin/stats/lessons", async (HttpRequest req, DateOnly? from, StatsService s, CancellationToken ct) =>
        {
            var key = config["Stats:Key"];
            if (string.IsNullOrEmpty(key)) return Results.NotFound();
            var sent = req.Headers["X-Stats-Key"].ToString();
            if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(sent), Encoding.UTF8.GetBytes(key))) return Results.Unauthorized();
            return Results.Ok(await s.LessonsAsync(from, ct));
        }).WithTags("Admin").AllowAnonymous().RequireRateLimiting("auth");
    }
}
