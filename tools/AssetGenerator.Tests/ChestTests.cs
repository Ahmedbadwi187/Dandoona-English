using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class ChestTests
{
    [Fact]
    public void Every_unit_in_the_real_content_has_a_chest_with_an_accessory_and_three_or_four_stickers_and_no_accessory_repeats()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var units = CurriculumReader.LoadUnits(layout.CurriculumDir);
        units.Count.ShouldBeGreaterThanOrEqualTo(15);
        foreach (var u in units)
        {
            u.Chest.ShouldNotBeNull(u.Id);
            u.Chest!.Stickers.Count.ShouldBeInRange(3, 4);
        }
        units.Select(u => u.Chest!.Accessory).Distinct().Count().ShouldBe(units.Count, "one outfit per chest, never the same twice");
    }

    [Fact]
    public void Units_with_lessons_have_the_drawing_of_their_accessory_and_stickers_that_are_their_words()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir); // validates stickers and drawings of every unit that has lessons
        foreach (var unit in CurriculumReader.LoadUnits(layout.CurriculumDir).Where(u => lessons.Any(l => l.Unit == u.Id)))
            File.Exists(Path.Combine(layout.CurriculumDir, "..", "art", "accessories", unit.Chest!.Accessory + ".svg")).ShouldBeTrue(unit.Id);
    }

    [Fact]
    public void A_chest_with_a_sticker_that_is_not_a_word_of_its_unit_is_rejected()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), """
            track: little-learners
            units:
              - id: colors
                order: 1
                title: { en: "Colors", ar: "الألوان" }
                icon: colors
                color: orange
                chest: { accessory: beret, stickers: [apple, nope, heart] }
                narration: { title: "Colors", welcome: "Hi", celebration: "Yay" }
            """);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), UnitsTests.ColorRed);
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain("sticker 'nope' is not a word of the unit");
    }
}
