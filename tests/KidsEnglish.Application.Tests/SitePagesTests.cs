using System.Text.RegularExpressions;
using Shouldly;

namespace KidsEnglish.Application.Tests;

/// <summary>The static privacy pages must stay self-contained (no trackers, scripts or third-party fonts) and clearly marked as drafts.</summary>
public class SitePagesTests
{
    private static string SiteDir()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "site"))) dir = dir.Parent;
        return Path.Combine(dir!.FullName, "site");
    }

    public static TheoryData<string> Pages => new() { "privacy-policy.html", "delete-account.html", "terms.html" };

    private static string Read(string page) => File.ReadAllText(Path.Combine(SiteDir(), page));

    [Theory, MemberData(nameof(Pages))]
    public void Page_loads_nothing_from_outside_and_has_no_scripts(string page)
    {
        var html = Read(page);
        Regex.IsMatch(html, "<script", RegexOptions.IgnoreCase).ShouldBeFalse("no scripts");
        Regex.IsMatch(html, "<link\\b", RegexOptions.IgnoreCase).ShouldBeFalse("no external stylesheets or font links");
        Regex.IsMatch(html, "<(img|iframe|video|audio|embed|object|source)\\b", RegexOptions.IgnoreCase).ShouldBeFalse("no embedded media");
        html.ShouldNotContain("http://");
        html.ShouldNotContain("https://");
        html.ShouldNotContain("@import");
        html.ShouldNotContain("@font-face");
        Regex.IsMatch(html, "url\\(", RegexOptions.IgnoreCase).ShouldBeFalse("no url() references");
        // the only links are to the sibling page and in-page anchors
        foreach (Match m in Regex.Matches(html, "href=\"([^\"]*)\""))
            (m.Groups[1].Value.StartsWith('#') || m.Groups[1].Value.EndsWith(".html")).ShouldBeTrue(m.Value);
    }

    [Theory, MemberData(nameof(Pages))]
    public void Page_is_bilingual_rtl_aware_responsive_and_marked_as_a_draft(string page)
    {
        var html = Read(page);
        html.ShouldContain("<section id=\"en\" lang=\"en\" dir=\"ltr\">");
        html.ShouldContain("<section id=\"ar\" lang=\"ar\" dir=\"rtl\">");
        html.ShouldContain("name=\"viewport\"");
        html.ShouldContain("DRAFT FOR LEGAL REVIEW");
        html.ShouldContain("مسودة للمراجعة القانونية");
        html.ShouldContain("<mark>"); // placeholders are visibly highlighted
    }

    [Fact]
    public void Privacy_policy_covers_the_required_regimes_and_the_actual_data()
    {
        var html = Read("privacy-policy.html");
        html.ShouldContain("Personal Data Protection Law (PDPL)");
        html.ShouldContain("Google Play Families Policy");
        html.ShouldContain("Apple Kids Category");
        html.ShouldContain("نظام حماية البيانات الشخصية");
        html.ShouldContain("Families Policy");
        html.ShouldContain("Kids Category");
        // what the app really stores / does (docs/privacy-data-map.md)
        foreach (var fact in new[] { "birth <em>year</em>", "Microphone", "deleted immediately", "no advertisements", "parental gate", "SDAIA" })
            html.ShouldContain(fact, Case.Insensitive);
    }

    [Fact]
    public void Deletion_page_describes_account_child_and_offline_deletion()
    {
        var html = Read("delete-account.html");
        foreach (var fact in new[] { "Delete account &amp; data", "Child profiles", "saved and sent automatically", "حذف الحساب وبياناته", "ملفات الأطفال" })
            html.ShouldContain(fact);
    }
}
