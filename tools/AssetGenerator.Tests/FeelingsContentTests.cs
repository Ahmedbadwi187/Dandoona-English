using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class FeelingsContentTests
{
    [Fact]
    public void The_real_feelings_unit_has_six_feelings_in_two_lessons_each_with_a_drawn_face_and_an_I_am_phrase()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "feelings").OrderBy(l => l.ResolvedOrder).ToList();
        lessons.Select(l => l.Id).ShouldBe(["feelings-1", "feelings-2"]);
        lessons.SelectMany(l => l.Words).Select(w => w.Word).ShouldBe(["happy", "sad", "angry", "sleepy", "scared", "surprised"]);
        foreach (var l in lessons)
            foreach (var w in l.Words)
            {
                File.Exists(layout.SvgSource(l, w.Word)).ShouldBeTrue($"{l.Id}/{w.Word}.svg");
                l.Narration.Phrases[w.Word].ShouldBe($"I am {w.Word}.");
            }
        var chest = CurriculumReader.LoadUnits(layout.CurriculumDir).Single(u => u.Id == "feelings").Chest!;
        chest.Accessory.ShouldBe("heart-glasses");
    }
}
