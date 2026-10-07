using AssetGenerator.Curriculum;
using Shouldly;
using Xunit;

namespace AssetGenerator.Tests;

public class NumbersContentTests
{
    [Fact]
    public void The_real_numbers_unit_counts_one_to_ten_in_three_lessons_with_a_balloon_picture_for_each_number()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "numbers").OrderBy(l => l.ResolvedOrder).ToList();
        lessons.Select(l => l.Id).ShouldBe(["number-1-3", "number-4-6", "number-7-10"]);
        lessons.ShouldAllBe(l => l.Counting);
        var words = lessons.SelectMany(l => l.Words).Select(w => w.Word).ToList();
        words.ShouldBe(["one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]);
        foreach (var l in lessons)
            foreach (var w in l.Words)
            {
                File.Exists(layout.SvgSource(l, w.Word)).ShouldBeTrue($"{l.Id}/{w.Word}.svg");
                l.Narration.Phrases.ContainsKey(w.Word).ShouldBeTrue($"{w.Word} has a spoken phrase");
            }
    }

    [Fact]
    public void A_counting_lesson_without_the_flag_in_older_files_reads_as_not_counting()
    {
        new Lesson().Counting.ShouldBeFalse();
    }
}
