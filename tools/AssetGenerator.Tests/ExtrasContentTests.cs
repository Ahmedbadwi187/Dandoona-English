using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

/// <summary>The extra games (counting, sorting, memory, odd one out, sentences...) are written in the lesson files; every lesson still passes the checks.</summary>
public class ExtrasContentTests
{
    private static List<Lesson> Lessons() => CurriculumReader.LoadAll(Layout.FindFrom(AppContext.BaseDirectory).CurriculumDir).ToList();

    [Fact]
    public void Every_lesson_of_the_course_is_valid_with_its_extra_games()
    {
        foreach (var l in Lessons()) new LessonValidator().Validate(l).IsValid.ShouldBeTrue(l.Id);
    }

    [Fact]
    public void Numbers_count_and_trace_and_colors_mix_and_shapes_build_and_feelings_have_a_story_game()
    {
        var all = Lessons().ToDictionary(l => l.Id);
        foreach (var id in new[] { "number-1-3", "number-4-6", "number-7-10" }) all[id].Activities.ShouldContain("count-along");
        foreach (var id in new[] { "number-1-3", "number-4-6", "number-7-10" }) all[id].Activities.ShouldContain("trace");
        foreach (var id in new[] { "color-orange", "color-green", "color-purple", "color-pink" }) all[id].Activities.ShouldContain("mix-colors");
        foreach (var id in new[] { "shapes-1", "shapes-2", "shapes-3" }) all[id].Activities.ShouldContain("build-picture");
        all["feelings-2"].Activities.ShouldContain("story-feeling");
        all["toys-3"].Activities.ShouldContain("turns");
    }

    [Fact]
    public void Sorting_lessons_have_bins_and_every_group_is_a_bin()
    {
        var all = Lessons();
        foreach (var id in new[] { "my-body-2", "food-4", "clothes-3", "transport-3", "my-home-3", "my-family-3" })
        {
            var l = all.Single(x => x.Id == id);
            l.Activities.ShouldContain("sort");
            l.Bins.Count.ShouldBeGreaterThanOrEqualTo(2);
            var unitWords = all.Where(x => x.Unit == l.Unit).SelectMany(x => x.Words).Where(w => w.Group is not null).ToList();
            unitWords.Select(w => w.Group!).Distinct().Order().ShouldBe(l.Bins.Select(b => b.Key).Order(), id);
        }
    }

    [Fact]
    public void Odd_one_out_uses_words_of_the_letters_unit_that_are_not_words_of_the_theme()
    {
        var all = Lessons();
        var letterWords = all.Where(l => l.Id.StartsWith("letter-")).SelectMany(l => l.Words).Select(w => w.Word).ToHashSet();
        foreach (var l in all.Where(l => l.Odd.Count > 0))
        {
            l.Activities.ShouldContain("odd-one-out");
            var themeWords = all.Where(x => x.Unit == l.Unit).SelectMany(x => x.Words).Select(w => w.Word).ToHashSet();
            foreach (var o in l.Odd)
            {
                letterWords.ShouldContain(o, $"{l.Id}: {o}");
                themeWords.ShouldNotContain(o, $"{l.Id}: {o} belongs to the theme");
            }
        }
    }

    [Fact]
    public void Opposites_are_pairs_of_each_other()
    {
        var words = Lessons().Where(l => l.Unit == "opposites").SelectMany(l => l.Words).ToList();
        foreach (var w in words) words.Single(x => x.Word == w.Opposite).Opposite.ShouldBe(w.Word);
    }

    [Fact]
    public void Every_lesson_with_memory_or_sentences_has_phrases_for_the_sentences_and_no_new_voice_is_needed()
    {
        foreach (var l in Lessons().Where(l => l.Activities.Contains("sentence")))
            l.Words.ShouldAllBe(w => l.Narration.Phrases.Keys.Any(k => k.Equals(w.Word, StringComparison.OrdinalIgnoreCase)), l.Id);
    }
}
