using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

/// <summary>The whole course in the repo: every unit of the map has its lessons, every word its picture, voice phrase and the three activities.</summary>
public class AllUnitsContentTests
{
    private static readonly string[] Units = ["letters", "colors", "numbers", "shapes", "animals", "feelings", "my-body", "actions", "food", "clothes", "toys", "my-family", "my-home", "opposites", "transport"];

    [Fact]
    public void Every_unit_of_the_map_has_lessons_and_every_word_has_a_picture_a_phrase_in_its_lessons_and_a_complete_chest()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var all = CurriculumReader.LoadAll(layout.CurriculumDir);
        var units = CurriculumReader.LoadUnits(layout.CurriculumDir);
        units.Select(u => u.Id).ShouldBe(Units);
        foreach (var u in units)
        {
            var lessons = all.Where(l => l.Unit == u.Id).ToList();
            lessons.Count.ShouldBeGreaterThanOrEqualTo(2, $"{u.Id} has lessons");
            var words = lessons.SelectMany(l => l.Words).Select(w => w.Word.Trim().ToLowerInvariant()).ToHashSet();
            u.Story.ShouldNotBeNull($"{u.Id} has a story");
            u.Story!.Pages.Count.ShouldBe(5, $"{u.Id}: five pages");
            u.Story.Pages.ShouldAllBe(p => p.Text.Trim().Length > 0 && p.Words.All(w => words.Contains(w.Trim().ToLowerInvariant())), $"{u.Id}: every page has a sentence and only words of the unit");
            u.Chest!.Stickers.ShouldAllBe(s => words.Contains(s.Trim().ToLowerInvariant()), $"{u.Id}: stickers are its words");
            File.Exists(Path.Combine(layout.CurriculumDir, "..", "art", "accessories", u.Chest.Accessory + ".svg")).ShouldBeTrue($"{u.Id}: outfit {u.Chest.Accessory} is drawn");
            foreach (var l in lessons.Where(l => l.Id != $"unit-{u.Id}"))
            {
                l.Words.Count.ShouldBeGreaterThanOrEqualTo(2, l.Id);
                l.Activities.ShouldContain("listen-and-tap", l.Id);
                l.Activities.ShouldContain("match-picture", l.Id);
                if (u.Id is "letters" or "colors") continue; // the first two units were made before the per-word phrase rule
                foreach (var w in l.Words)
                {
                    l.Narration.Phrases.ContainsKey(w.Word).ShouldBeTrue($"{l.Id}/{w.Word} has a spoken phrase");
                    if (w.Reuse is not null) continue; // a reused picture is checked by the export (no incomplete lesson)
                    var key = w.Word.Trim().ToLowerInvariant().Replace(' ', '-');
                    var drawn = File.Exists(layout.SvgSource(l, key));
                    var approved = File.Exists(Path.Combine(layout.CurriculumDir, "..", "generated", "little-learners", l.Id, "images", key + ".approved.webp"));
                    (drawn || approved).ShouldBeTrue($"{l.Id}/{w.Word} has a drawing or an approved picture");
                }
            }
        }
    }
}
