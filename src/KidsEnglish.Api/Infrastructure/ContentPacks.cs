using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.FileProviders;
using Microsoft.Net.Http.Headers;

namespace KidsEnglish.Api.Infrastructure;

/// <summary>
/// Downloadable content packs (the units after Letters and Colors), served as static files from our own API: no blob
/// storage, no CDN. The folder is what `AssetGenerator export` writes to packs/:
/// <c>/packs/&lt;track&gt;/index.json</c> lists the newest version of every pack, and
/// <c>/packs/&lt;track&gt;/&lt;unit&gt;/v&lt;version&gt;/...</c> holds the files with their manifest.
/// A version folder never changes once written, so it is cached for a year; the index is checked again every few minutes.
/// Anonymous: the packs hold lesson pictures and audio only, nothing about any child.
/// </summary>
public static class ContentPacks
{
    public const string RequestPath = "/packs";

    /// <summary>ContentPacks:Root, or the repo's packs/ folder when running from source.</summary>
    public static string? ResolveRoot(IConfiguration config, IWebHostEnvironment env)
    {
        var configured = config["ContentPacks:Root"];
        var root = string.IsNullOrWhiteSpace(configured)
            ? Path.GetFullPath(Path.Combine(env.ContentRootPath, "..", "..", "packs"))
            : Path.GetFullPath(configured, env.ContentRootPath);
        return Directory.Exists(root) ? root : null;
    }

    public static void UseContentPacks(this WebApplication app)
    {
        var root = ResolveRoot(app.Configuration, app.Environment);
        if (root is null)
        {
            app.Logger.LogWarning("No content packs folder (set ContentPacks:Root); /packs is not served.");
            return;
        }

        // Half-built folders (_build) are never served.
        app.Use(async (ctx, next) =>
        {
            if (ctx.Request.Path.StartsWithSegments(RequestPath) && ctx.Request.Path.Value!.Contains("/_", StringComparison.Ordinal))
            {
                ctx.Response.StatusCode = StatusCodes.Status404NotFound;
                return;
            }
            await next();
        });

        // Only what a pack holds; anything else in the folder is not served.
        var types = new FileExtensionContentTypeProvider(new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            [".json"] = "application/json",
            [".mp3"] = "audio/mpeg",
            [".webp"] = "image/webp",
            [".svg"] = "image/svg+xml",
            [".png"] = "image/png",
        });

        app.UseStaticFiles(new StaticFileOptions
        {
            FileProvider = new PhysicalFileProvider(root),
            RequestPath = RequestPath,
            ContentTypeProvider = types,
            ServeUnknownFileTypes = false,
            OnPrepareResponse = ctx =>
            {
                var index = ctx.File.Name == "index.json";
                ctx.Context.Response.Headers[HeaderNames.CacheControl] = index ? "public, max-age=300" : "public, max-age=31536000, immutable";
            },
        });
    }
}
