using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class BodyContentTests
{
    [Fact]
    public void The_real_my_body_unit_has_six_parts_in_two_lessons_each_with_a_drawing_and_a_This_is_my_phrase()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "my-body").OrderBy(l => l.ResolvedOrder).ToList();
        lessons.Select(l => l.Id).ShouldBe(["my-body-1", "my-body-2"]);
        lessons.SelectMany(l => l.Words).Select(w => w.Word).ShouldBe(["eye", "ear", "nose", "mouth", "hand", "foot"]);
        foreach (var l in lessons)
            foreach (var w in l.Words)
            {
                File.Exists(layout.SvgSource(l, w.Word)).ShouldBeTrue($"{l.Id}/{w.Word}.svg");
                l.Narration.Phrases[w.Word].ShouldBe($"This is my {w.Word}.");
            }
        var chest = CurriculumReader.LoadUnits(layout.CurriculumDir).Single(u => u.Id == "my-body").Chest!;
        chest.Accessory.ShouldBe("sweatband");
    }
}
