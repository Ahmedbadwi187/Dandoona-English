using System.Net;
using System.Text;
using AssetGenerator.Curriculum;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace AssetGenerator;

/// <summary>What to look for at home for one unit, in both languages (content/parent/tips.yaml).</summary>
public class UnitTips
{
    public List<string> En { get; set; } = [];
    public List<string> Ar { get; set; } = [];
}

/// <summary>
/// Printable cards for parents: one self-contained HTML page per unit (its words and 4 things to look for or do at home, in English
/// and Arabic) plus an index. No script, no external file, no form, no tracking: the server only hands out these static files.
/// `AssetGenerator cards` writes them to cards/&lt;track&gt;/, and the API serves that folder at /cards.
/// </summary>
public static class ParentCards
{
    private static readonly IDeserializer Deserializer = new DeserializerBuilder().WithNamingConvention(CamelCaseNamingConvention.Instance).Build();

    /// <summary>content/parent/tips.yaml for Little Learners, content/parent/tips-&lt;track&gt;.yaml for the other tracks.</summary>
    public static string TipsFile(Layout layout, string track = "little-learners") => Path.Combine(layout.Root, "content", "parent", track == "little-learners" ? "tips.yaml" : $"tips-{track}.yaml");
    public static string OutputDir(Layout layout, string track) => Path.Combine(layout.Root, "cards", track.Replace('-', '_'));

    public static IReadOnlyDictionary<string, UnitTips> LoadTips(Layout layout, string track = "little-learners")
    {
        var path = TipsFile(layout, track);
        if (!File.Exists(path)) throw new CurriculumException($"Parent tips not found: {path}");
        return Deserializer.Deserialize<Dictionary<string, UnitTips>>(File.ReadAllText(path));
    }

    /// <summary>Problems with the tips file against the units: every unit has 3-5 tips in each language, no tip is empty or too long.</summary>
    public static IReadOnlyList<string> Check(IReadOnlyDictionary<string, UnitTips> tips, IEnumerable<UnitDef> units)
    {
        var errors = new List<string>();
        foreach (var u in units)
        {
            if (!tips.TryGetValue(u.Id, out var t)) { errors.Add($"unit '{u.Id}' has no parent tips."); continue; }
            foreach (var (lang, list) in new[] { ("en", t.En), ("ar", t.Ar) })
            {
                if (list.Count is < 3 or > 5) errors.Add($"unit '{u.Id}': {lang} needs 3 to 5 tips.");
                if (list.Any(s => string.IsNullOrWhiteSpace(s) || s.Length > 160)) errors.Add($"unit '{u.Id}': a {lang} tip is empty or longer than 160 characters.");
            }
            if (t.En.Count != t.Ar.Count) errors.Add($"unit '{u.Id}': English and Arabic need the same number of tips.");
        }
        return errors;
    }

    /// <summary>Writes the pages and returns the files written.</summary>
    public static IReadOnlyList<string> Write(Layout layout, string track)
    {
        var units = CurriculumReader.LoadUnits(layout.CurriculumDir).Where(u => u.Track == track).OrderBy(u => u.Order).ToList();
        var tips = LoadTips(layout, track).ToDictionary(kv => kv.Key, kv => kv.Value);
        // a unit borrowed from another track (Letters in Explorers) keeps that track's tips unless this track has its own
        foreach (var u in units.Where(u => u.From.Length > 0 && !tips.ContainsKey(u.Id)))
            if (LoadTips(layout, u.From).TryGetValue(u.Id, out var borrowed)) tips[u.Id] = borrowed;
        var errors = Check(tips, units);
        if (errors.Count > 0) throw new CurriculumException("Parent tips: " + string.Join(" ", errors));
        var allLessons = CurriculumReader.LoadAll(layout.CurriculumDir);

        var dir = OutputDir(layout, track);
        Directory.CreateDirectory(dir);
        var written = new List<string>();
        foreach (var u in units)
        {
            var words = allLessons.Where(l => l.Track == u.ContentTrack && l.Unit == u.Id).OrderBy(l => l.ResolvedOrder).SelectMany(l => l.Words).Select(w => w.Word.Trim()).ToList();
            var file = Path.Combine(dir, u.Id + ".html");
            File.WriteAllText(file, UnitPage(u, words, tips[u.Id], units), new UTF8Encoding(false));
            written.Add(file);
        }
        var index = Path.Combine(dir, "index.html");
        File.WriteAllText(index, IndexPage(units), new UTF8Encoding(false));
        written.Add(index);
        return written;
    }

    private static string E(string s) => WebUtility.HtmlEncode(s);

    private const string Style = """
        :root{color-scheme:light}
        *{box-sizing:border-box}
        body{font-family:system-ui,-apple-system,"Segoe UI",Tahoma,Arial,sans-serif;margin:0;background:#f4f9fc;color:#1f2a44;line-height:1.5}
        main{max-width:820px;margin:0 auto;padding:20px 16px 40px}
        h1{font-size:1.9rem;margin:.2em 0}
        h2{font-size:1.2rem;margin:1.2em 0 .4em}
        .brand{color:#6b3fa0;font-weight:800}
        .words{display:flex;flex-wrap:wrap;gap:8px;margin:.5em 0}
        .words span{background:#fff;border:3px solid #1f2a44;border-radius:14px;padding:6px 14px;font-weight:800;font-size:1.2rem}
        .cols{display:grid;grid-template-columns:1fr 1fr;gap:16px}
        .col{background:#fff;border-radius:18px;padding:12px 18px;border:2px solid #d5e3ee}
        .col h2{margin-top:.3em}
        ol{padding-inline-start:1.3em;margin:.3em 0}
        li{margin:.5em 0;font-size:1.05rem}
        .ar{direction:rtl;text-align:right}
        a{color:#6b3fa0;font-weight:700}
        .grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));gap:12px;margin-top:16px}
        .grid a{display:block;background:#fff;border:3px solid #1f2a44;border-radius:18px;padding:14px;text-decoration:none;color:#1f2a44}
        .grid small{display:block;font-weight:600;color:#55637d}
        footer{margin-top:28px;font-size:.85rem;color:#55637d}
                @media (max-width:640px){.cols{grid-template-columns:1fr}}
        @media print{body{background:#fff}.noprint{display:none}.col{break-inside:avoid;border:1px solid #999}main{padding:0}}
        """;

    private static string Head(string title) =>
        $"""
        <!doctype html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta name="referrer" content="no-referrer">
        <title>{E(title)}</title>
        <style>{Style}</style>
        </head>
        <body>
        <main>

        """;

    private const string Footer = """
        <footer>Dandoona English, Little Learners. This page is the same for everyone: it collects nothing and has no scripts.
        <span class="ar" dir="rtl"> هذه الصفحة واحدة للجميع: لا تجمع أي معلومات ولا تحتوي على سكربتات.</span></footer>
        </main>
        </body>
        </html>
        """;

    private static string UnitPage(UnitDef u, IReadOnlyList<string> words, UnitTips tips, IReadOnlyList<UnitDef> all)
    {
        var en = u.Title.GetValueOrDefault("en", u.Id);
        var ar = u.Title.GetValueOrDefault("ar", en);
        var sb = new StringBuilder(Head($"{en} - Dandoona English"));
        sb.AppendLine($"<p class=\"brand\">Dandoona English <span class=\"ar\" dir=\"rtl\">· دندونة</span></p>");
        sb.AppendLine($"<h1>{E(en)} <span class=\"ar\" dir=\"rtl\">· {E(ar)}</span></h1>");
        sb.AppendLine("<p class=\"noprint\">Use your browser's Print (Ctrl+P) to print this card. <span class=\"ar\" dir=\"rtl\">للطباعة استخدموا أمر الطباعة في المتصفح.</span></p>");
        sb.AppendLine("<h2>Words in this unit <span class=\"ar\" dir=\"rtl\">· كلمات الوحدة</span></h2>");
        sb.AppendLine("<div class=\"words\">" + string.Join("", words.Select(w => $"<span>{E(w)}</span>")) + "</div>");
        sb.AppendLine("<div class=\"cols\">");
        sb.AppendLine("<section class=\"col\"><h2>At home</h2><ol>" + string.Join("", tips.En.Select(t => $"<li>{E(t)}</li>")) + "</ol></section>");
        sb.AppendLine("<section class=\"col ar\" dir=\"rtl\" lang=\"ar\"><h2>في البيت</h2><ol>" + string.Join("", tips.Ar.Select(t => $"<li>{E(t)}</li>")) + "</ol></section>");
        sb.AppendLine("</div>");
        sb.AppendLine("<p class=\"noprint\"><a href=\"index.html\">All units · كل الوحدات</a></p>");
        sb.AppendLine(Footer);
        return sb.ToString();
    }

    private static string IndexPage(IReadOnlyList<UnitDef> units)
    {
        var sb = new StringBuilder(Head("Cards for home - Dandoona English"));
        sb.AppendLine("<p class=\"brand\">Dandoona English <span class=\"ar\" dir=\"rtl\">· دندونة</span></p>");
        sb.AppendLine("<h1>Cards for home <span class=\"ar\" dir=\"rtl\">· بطاقات للبيت</span></h1>");
        sb.AppendLine("<p>One page for every unit: its words and four easy things to look for or do together. Print the ones you like.</p>");
        sb.AppendLine("<p class=\"ar\" dir=\"rtl\">صفحة لكل وحدة: كلماتها وأربعة أشياء سهلة تفعلونها معًا. اطبعوا ما يعجبكم.</p>");
        sb.AppendLine("<div class=\"grid\">");
        foreach (var u in units)
            sb.AppendLine($"<a href=\"{E(u.Id)}.html\">{E(u.Title.GetValueOrDefault("en", u.Id))}<small class=\"ar\" dir=\"rtl\">{E(u.Title.GetValueOrDefault("ar", ""))}</small></a>");
        sb.AppendLine("</div>");
        sb.AppendLine(Footer);
        return sb.ToString();
    }
}
