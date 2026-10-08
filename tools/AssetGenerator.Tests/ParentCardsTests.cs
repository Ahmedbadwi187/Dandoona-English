using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class ParentCardsTests
{
    private static Layout Real() => Layout.FindFrom(AppContext.BaseDirectory);

    [Fact]
    public void Every_unit_of_the_course_has_four_tips_in_English_and_in_Arabic()
    {
        var units = CurriculumReader.LoadUnits(Real().CurriculumDir).Where(u => u.Track == "little-learners").ToList();
        var tips = ParentCards.LoadTips(Real());
        ParentCards.Check(tips, units).ShouldBeEmpty();
        units.Count.ShouldBe(15);
        foreach (var u in units)
        {
            tips[u.Id].En.Count.ShouldBe(4, u.Id);
            tips[u.Id].Ar.Count.ShouldBe(4, u.Id);
        }
    }

    [Fact]
    public void Missing_or_uneven_or_overlong_tips_are_reported()
    {
        var unit = new UnitDef { Id = "x", Track = "t" };
        ParentCards.Check(new Dictionary<string, UnitTips>(), [unit]).ShouldContain(e => e.Contains("no parent tips"));
        ParentCards.Check(new Dictionary<string, UnitTips> { ["x"] = new() { En = ["a", "b", "c"], Ar = ["a", "b"] } }, [unit]).ShouldNotBeEmpty();
        ParentCards.Check(new Dictionary<string, UnitTips> { ["x"] = new() { En = ["a", "b", new string('x', 200)], Ar = ["a", "b", "c"] } }, [unit]).ShouldContain(e => e.Contains("longer than 160"));
        ParentCards.Check(new Dictionary<string, UnitTips> { ["x"] = new() { En = ["a", "b", "c"], Ar = ["a", "b", "c"] } }, [unit]).ShouldBeEmpty();
    }

    [Fact]
    public void The_pages_are_written_for_every_unit_with_its_words_and_tips_and_load_nothing_from_anywhere()
    {
        var temp = Directory.CreateTempSubdirectory("cards-test").FullName;
        try
        {
            // a copy of the real content folders the writer reads, with the real output going to the temp root
            CopyDir(Path.Combine(Real().Root, "content", "curriculum"), Path.Combine(temp, "content", "curriculum"));
            CopyDir(Path.Combine(Real().Root, "content", "parent"), Path.Combine(temp, "content", "parent"));
            CopyDir(Path.Combine(Real().Root, "content", "art", "accessories"), Path.Combine(temp, "content", "art", "accessories")); // the validator checks the chest drawings exist
            var written = ParentCards.Write(new Layout(temp), "little-learners");
            written.Count.ShouldBe(16);
            foreach (var file in written)
            {
                var html = File.ReadAllText(file);
                html.ShouldStartWith("<!doctype html>");
                html.ShouldNotContain("<script", Case.Insensitive);
                html.ShouldNotContain("onclick", Case.Insensitive);
                html.ShouldNotContain("http://");
                html.ShouldNotContain("https://");
                html.ShouldNotContain("<img", Case.Insensitive);
                html.ShouldNotContain("<link", Case.Insensitive);
                html.ShouldNotContain("<form", Case.Insensitive);
            }
            var animals = File.ReadAllText(Path.Combine(temp, "cards", "little_learners", "animals.html"));
            animals.ShouldContain("<span>cat</span>");
            animals.ShouldContain("<span>zebra</span>");
            animals.ShouldContain("lang=\"ar\"");
            animals.ShouldContain("الحيوانات");
            animals.Split("<li>").Length.ShouldBe(9); // 4 + 4 tips
            var index = File.ReadAllText(Path.Combine(temp, "cards", "little_learners", "index.html"));
            index.Split("<a href=").Length.ShouldBe(16); // 15 units
        }
        finally { Directory.Delete(temp, true); }
    }

    private static void CopyDir(string from, string to)
    {
        Directory.CreateDirectory(to);
        foreach (var f in Directory.EnumerateFiles(from, "*", SearchOption.AllDirectories))
        {
            var target = Path.Combine(to, Path.GetRelativePath(from, f));
            Directory.CreateDirectory(Path.GetDirectoryName(target)!);
            File.Copy(f, target, true);
        }
    }
}
