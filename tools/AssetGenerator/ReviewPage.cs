using System.Net;
using System.Text;
using AssetGenerator.Curriculum;

namespace AssetGenerator;

/// <summary>`review`: writes a static HTML page (no API calls) showing every candidate image with its file name.</summary>
public static class ReviewPage
{
    public static string OutputPath(Layout layout) => Path.Combine(layout.GeneratedDir, "review.html");

    public static string Build(Layout layout, IEnumerable<Lesson> lessons)
    {
        var sb = new StringBuilder();
        sb.Append("""
            <!doctype html>
            <html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
            <title>Image review</title>
            <style>
              body { font-family: system-ui, sans-serif; margin: 0; padding: 1.5rem; background: #f6f4ee; color: #222; }
              h1 { margin: 0 0 .25rem; } h2 { margin: 2rem 0 .25rem; border-bottom: 2px solid #ddd; padding-bottom: .25rem; }
              h3 { margin: 1.25rem 0 .5rem; } .hint { color: #666; margin: 0 0 1rem; }
              .row { display: flex; gap: 1rem; flex-wrap: wrap; }
              figure { margin: 0; background: #fff; border-radius: 10px; padding: .5rem; box-shadow: 0 1px 4px rgba(0,0,0,.15); width: 300px; }
              figure.approved { outline: 3px solid #2e9e5b; }
              img { width: 100%; height: auto; display: block; border-radius: 6px; background: #eee; }
              figcaption { font: 13px ui-monospace, Consolas, monospace; padding-top: .4rem; word-break: break-all; }
              .tag { display: inline-block; background: #2e9e5b; color: #fff; border-radius: 4px; padding: 0 .4rem; margin-left: .4rem; font-size: 12px; }
              .none { color: #a33; }
            </style></head><body>
            <h1>Image review</h1>
            <p class="hint">Tell me your pick per word, e.g. "letter-a apple v2". Variants are in each folder's <code>_review</code>;
            to approve, rename a file to <code>{word}.approved.webp</code> in the <code>images</code> folder above it.</p>
            """);

        var mascot = Enumerable.Range(1, 9).Select(layout.MascotReview).Where(File.Exists).ToList();
        if (mascot.Count > 0)
        {
            sb.Append("<h2>Mascot concepts</h2>");
            if (File.Exists(layout.MascotReference)) sb.Append("<p class=\"hint\">A mascot reference is already locked.</p>");
            sb.Append("<div class=\"row\">");
            foreach (var f in mascot) Figure(sb, layout, f, approved: false);
            sb.Append("</div>");
        }

        foreach (var lesson in lessons)
        {
            sb.Append($"<h2>{Esc(lesson.Id)}{(lesson.Letter is null ? "" : $" &middot; letter {Esc(lesson.Letter)}")}</h2>");
            foreach (var image in LessonPlan.Images(lesson))
            {
                var approvedFile = layout.ImageApproved(lesson, image.Key);
                var variants = layout.ImageReviewFiles(lesson, image.Key);
                sb.Append($"<h3>{Esc(image.Key)}</h3><p class=\"hint\">{Esc(image.Prompt)}</p><div class=\"row\">");
                if (image.IsSvg)
                {
                    var svg = layout.SvgSource(lesson, image.Key);
                    if (File.Exists(svg)) Figure(sb, layout, svg, approved: true, "self-drawn");
                    else sb.Append("<span class=\"none\">MISSING SVG: draw it in content/art.</span>");
                    sb.Append("</div>");
                    continue;
                }
                if (File.Exists(approvedFile)) Figure(sb, layout, approvedFile, approved: true);
                foreach (var f in variants) Figure(sb, layout, f, approved: false);
                if (variants.Count == 0 && !File.Exists(approvedFile)) sb.Append("<span class=\"none\">No images yet. Run the images command.</span>");
                sb.Append("</div>");
            }
        }
        return sb.Append("</body></html>").ToString();
    }

    public static string Write(Layout layout, IEnumerable<Lesson> lessons)
    {
        var path = OutputPath(layout);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, Build(layout, lessons), new UTF8Encoding(false));
        return path;
    }

    private static void Figure(StringBuilder sb, Layout layout, string file, bool approved, string tag = "approved")
    {
        var rel = Path.GetRelativePath(layout.GeneratedDir, file).Replace('\\', '/');
        var src = string.Join('/', rel.Split('/').Select(Uri.EscapeDataString)); // safe for file:// and spaces
        sb.Append($"<figure{(approved ? " class=\"approved\"" : "")}><img src=\"{src}\" alt=\"{Esc(Path.GetFileName(file))}\" loading=\"lazy\">")
          .Append($"<figcaption>{Esc(Path.GetFileName(file))}{(approved ? $"<span class=\"tag\">{Esc(tag)}</span>" : "")}</figcaption></figure>");
    }

    private static string Esc(string s) => WebUtility.HtmlEncode(s);
}
