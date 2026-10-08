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

    [Fact]
    public void Every_animal_has_a_home_and_a_lives_sentence_the_noisy_ones_a_sound_and_every_line_is_planned_as_audio()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "animals").ToList();
        foreach (var l in lessons)
        {
            l.Activities.ShouldContain("animal-sounds");
            l.Activities.ShouldContain("habitat");
            var roles = LessonPlan.Audio(l).Select(a => a.Role).ToList();
            roles.ShouldContain("instr-animal-sounds");
            roles.ShouldContain("instr-habitat");
            foreach (var w in l.Words)
            {
                LessonValidator.Homes.ShouldContain(w.Home!, w.Word);
                roles.ShouldContain(LessonPlan.LivesRole(w.Word));
                if (w.Sound is not null) roles.ShouldContain(LessonPlan.SoundRole(w.Word));
            }
        }
        lessons.SelectMany(l => l.Words).Where(w => w.Sound is null).Select(w => w.Word).ShouldBe(["rabbit", "zebra"]);
    }

    [Fact]
    public void A_habitat_lesson_needs_a_home_for_every_word_and_a_home_needs_its_sentence()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var good = CurriculumReader.LoadAll(layout.CurriculumDir).First(l => l.Id == "animals-1");
        new LessonValidator().Validate(good).IsValid.ShouldBeTrue();

        var noHome = CurriculumReader.LoadAll(layout.CurriculumDir).First(l => l.Id == "animals-1");
        noHome.Words[0].Home = null;
        new LessonValidator().Validate(noHome).IsValid.ShouldBeFalse();

        var noSentence = CurriculumReader.LoadAll(layout.CurriculumDir).First(l => l.Id == "animals-1");
        noSentence.Words[0].Lives = null;
        new LessonValidator().Validate(noSentence).IsValid.ShouldBeFalse();

        var badHome = CurriculumReader.LoadAll(layout.CurriculumDir).First(l => l.Id == "animals-1");
        badHome.Words[0].Home = "moon";
        new LessonValidator().Validate(badHome).IsValid.ShouldBeFalse();

        var oneSound = CurriculumReader.LoadAll(layout.CurriculumDir).First(l => l.Id == "animals-1");
        oneSound.Words[1].Sound = null; // only the cat is left with a sound
        new LessonValidator().Validate(oneSound).IsValid.ShouldBeFalse();
    }
}
