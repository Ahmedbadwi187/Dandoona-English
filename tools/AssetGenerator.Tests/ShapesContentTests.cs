using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class ShapesContentTests
{
    [Fact]
    public void The_real_shapes_unit_has_eight_shapes_in_three_lessons_each_with_a_drawn_picture_and_a_phrase()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "shapes").OrderBy(l => l.ResolvedOrder).ToList();
        lessons.Select(l => l.Id).ShouldBe(["shapes-1", "shapes-2", "shapes-3", "shapes-4"]);
        lessons.Where(l => l.Id != "shapes-4").SelectMany(l => l.Words).Select(w => w.Word).ShouldBe(["circle", "square", "triangle", "rectangle", "oval", "diamond", "star", "heart"]);
        lessons.Single(l => l.Id == "shapes-4").Words.Select(w => w.Word).ShouldBe(["ball", "window", "kite", "egg"]); // Shapes around us: real things with those shapes
        lessons.Single(l => l.Id == "shapes-4").OwnWordsOnly.ShouldBeTrue();
        foreach (var l in lessons)
            foreach (var w in l.Words)
            {
                if (w.Reuse is null) File.Exists(layout.SvgSource(l, w.Word)).ShouldBeTrue($"{l.Id}/{w.Word}.svg"); // a reused picture is copied from the lesson it comes from
                l.Narration.Phrases.ContainsKey(w.Word).ShouldBeTrue($"{w.Word} has a spoken phrase");
            }
    }
}
