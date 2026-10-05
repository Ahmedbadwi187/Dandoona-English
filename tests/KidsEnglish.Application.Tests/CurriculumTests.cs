using KidsEnglish.Application.Curriculum;
using KidsEnglish.Domain.Enums;
using Shouldly;

namespace KidsEnglish.Application.Tests;

public class CurriculumTests
{
    internal static CurriculumLesson Valid() => new()
    {
        Id = "letter-a", Track = "little-learners", Level = "pre-a1", Letter = "A", Phoneme = "/æ/",
        Words = [new() { Word = "apple", ImagePrompt = "a red apple" }, new() { Word = "ant", ImagePrompt = "an ant" }],
        Narration = new() { Intro = "This is the letter A.", Praise = ["Great job!", "Well done!"] },
        Activities = ["trace", "listen-and-tap", "say-it", "match-picture"]
    };

    private static readonly CurriculumLessonValidator Validator = new();

    [Fact]
    public void Valid_lesson_passes() => Validator.Validate(Valid()).IsValid.ShouldBeTrue();

    [Fact]
    public void Rejects_bad_fields()
    {
        var l = Valid();
        l.Id = "Letter A";
        l.Level = "c2";
        l.Letter = "ab";
        l.Activities = ["trace", "dance"];
        l.Words.Add(new() { Word = "APPLE", ImagePrompt = "dup" });
        var errors = Validator.Validate(l).Errors.Select(e => e.PropertyName).ToList();
        errors.ShouldContain("Id");
        errors.ShouldContain("Level");
        errors.ShouldContain("Letter");
        errors.ShouldContain("Words");
        errors.ShouldContain(e => e.StartsWith("Activities"));
    }

    [Fact]
    public void Plan_creates_expected_assets_and_flags_phoneme_for_review()
    {
        var plan = LessonAssetPlanner.Plan(Valid());

        plan.Count(a => a.Kind == AssetKind.Image).ShouldBe(2);
        plan.Select(a => a.Role).ShouldBe(
            ["intro", "phoneme", "praise-0", "praise-1", "word-apple", "image-apple", "word-ant", "image-ant"], ignoreOrder: true);
        plan.Single(a => a.Role == "phoneme").RequiresHumanReview.ShouldBeTrue();
        plan.Where(a => a.Role != "phoneme").ShouldAllBe(a => !a.RequiresHumanReview);
        plan.Select(a => a.Role).Distinct().Count().ShouldBe(plan.Count);
    }

    [Fact]
    public void Hash_is_stable_and_changes_with_content()
    {
        LessonAssetPlanner.Hash(Valid()).ShouldBe(LessonAssetPlanner.Hash(Valid()));
        var changed = Valid();
        changed.Narration.Intro = "Different";
        LessonAssetPlanner.Hash(changed).ShouldNotBe(LessonAssetPlanner.Hash(Valid()));
    }

    [Fact]
    public void Order_derives_from_letter_unless_set()
    {
        LessonAssetPlanner.ResolveOrder(Valid()).ShouldBe(1);
        var c = Valid(); c.Letter = "C";
        LessonAssetPlanner.ResolveOrder(c).ShouldBe(3);
        c.Order = 10;
        LessonAssetPlanner.ResolveOrder(c).ShouldBe(10);
    }
}
