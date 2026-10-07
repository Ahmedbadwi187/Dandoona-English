using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class AnimalsContentTests
{
    [Fact]
    public void The_real_animals_unit_has_fifteen_animals_in_five_lessons_that_reuse_the_pictures_of_the_letters()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "animals").OrderBy(l => l.ResolvedOrder).ToList();
        lessons.Select(l => l.Id).ShouldBe(["animals-1", "animals-2", "animals-3", "animals-4", "animals-5"]);
        lessons.SelectMany(l => l.Words).Select(w => w.Word).ShouldBe(["cat", "dog", "rabbit", "cow", "pig", "horse", "duck", "fish", "frog", "lion", "elephant", "monkey", "bear", "tiger", "zebra"]);
        foreach (var l in lessons)
            foreach (var w in l.Words)
            {
                w.Reuse.ShouldNotBeNull($"{w.Word} reuses a picture that already exists");
                l.Narration.Phrases.ContainsKey(w.Word).ShouldBeTrue($"{w.Word} has a spoken phrase");
            }
        var chest = CurriculumReader.LoadUnits(layout.CurriculumDir).Single(u => u.Id == "animals").Chest!;
        chest.Accessory.ShouldBe("animal-ears");
        chest.Stickers.ShouldBe(["cat", "dog", "duck", "fish"]);
    }
}
