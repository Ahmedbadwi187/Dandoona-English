using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.FileProviders;
using Microsoft.Net.Http.Headers;

namespace KidsEnglish.Api.Infrastructure;

/// <summary>
/// The printable parent cards (one HTML page per unit, written by `AssetGenerator cards` to cards/) served as static files at
/// <c>/cards/&lt;track&gt;/&lt;unit&gt;.html</c>. Anonymous and the same for everyone: no cookie, no script, no tracking, and the page
/// is not allowed to load anything from anywhere (Content-Security-Policy), only its own inline style.
/// </summary>
public static class ContentCards
{
    public const string RequestPath = "/cards";

    /// <summary>ContentCards:Root, or the repo's cards/ folder when running from source.</summary>
    public static string? ResolveRoot(IConfiguration config, IWebHostEnvironment env)
    {
        var configured = config["ContentCards:Root"];
        // The setting wins; otherwise a "cards" folder next to the API files (a hosted site), otherwise the repo's cards/ (running from source).
        var candidates = new List<string>();
        if (!string.IsNullOrWhiteSpace(configured)) candidates.Add(Path.GetFullPath(configured, env.ContentRootPath));
        candidates.Add(Path.GetFullPath(Path.Combine(env.ContentRootPath, "cards")));
        candidates.Add(Path.GetFullPath(Path.Combine(env.ContentRootPath, "..", "..", "cards")));
        var root = candidates.FirstOrDefault(Directory.Exists);
        return root;
    }

    public static void UseContentCards(this WebApplication app)
    {
        var root = ResolveRoot(app.Configuration, app.Environment);
        if (root is null)
        {
            app.Logger.LogWarning("No cards folder (set ContentCards:Root); /cards is not served.");
            return;
        }

        // /cards and /cards/<track> land on the index of the track.
        app.MapGet("/cards", () => Results.Redirect("/cards/index.html", permanent: false));
        // (a fixed list: a {track} pattern would also catch /cards/index.html, and a matched route stops the static file from being served)
        foreach (var track in new[] { "little_learners", "explorers" })
            app.MapGet($"/cards/{track}", () => Results.Redirect($"/cards/{track}/index.html", permanent: false));

        app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = new PhysicalFileProvider(root),
            RequestPath = RequestPath,
            ContentTypeProvider = new FileExtensionContentTypeProvider(new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase) { [".html"] = "text/html; charset=utf-8" }),
            ServeUnknownFileTypes = false,
            OnPrepareResponse = ctx =>
            {
                var h = ctx.Context.Response.Headers;
                h[HeaderNames.CacheControl] = "public, max-age=3600";
                h["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'";
                h["X-Content-Type-Options"] = "nosniff";
                h["Referrer-Policy"] = "no-referrer";
            },
        });
    }
}
