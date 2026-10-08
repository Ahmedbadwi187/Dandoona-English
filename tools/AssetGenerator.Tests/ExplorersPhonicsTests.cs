using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

/// <summary>Explorers phonics: the phoneme table, words split into graphemes, the three new games, pictures from Little Learners.</summary>
public class ExplorersPhonicsTests
{
    private const string Units = """
        track: explorers
        phonemes:
          - { key: c, ipa: "/k/", say: "kuh" }
          - { key: a, ipa: "/æ/", say: "aa" }
          - { key: t, ipa: "/t/", say: "tuh" }
        units:
          - id: sound-builders
            order: 1
            title: { en: "Sound Builders", ar: "تركيب الأصوات" }
            narration: { title: "Sound Builders", welcome: "Let's build!", celebration: "Great!" }
        """;

    private const string Lesson = """
        id: sound-builders-a
        unit: sound-builders
        track: explorers
        level: a1
        words:
          - { word: cat, graphemes: [c, a, t], reuse: "little-learners:letter-c/cat" }
          - { word: act, graphemes: [a, c, t], source: svg, imagePrompt: "act" }
          - { word: tac, graphemes: [t, a, c], source: svg, imagePrompt: "tac" }
        narration:
          intro: "Short a!"
          praise: ["Great!"]
          instructions: { sound-tap: "Tap each box.", word-builder: "Build it!", read-and-pick: "Read it!" }
        activities: [sound-tap, word-builder, read-and-pick]
        """;

    private static TestRepo Repo(string lesson = Lesson, string units = Units)
    {
        var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "explorers.yaml"), units);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "sound-builders-a.yaml"), lesson);
        return repo;
    }

    [Fact]
    public void The_new_games_and_graphemes_are_read()
    {
        using var repo = Repo();
        var l = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        l.Activities.ShouldBe(["sound-tap", "word-builder", "read-and-pick"]);
        l.Words[0].Graphemes.ShouldBe(["c", "a", "t"]);
    }

    [Theory]
    [InlineData("graphemes: [c, a, t], reuse", "graphemes: [c, t], reuse", "spell the word")]
    [InlineData("graphemes: [c, a, t], reuse", "graphemes: [c, at], reuse", "not in the explorers phoneme table")]
    [InlineData("  - { word: cat, graphemes: [c, a, t], reuse: \"little-learners:letter-c/cat\" }", "  - { word: cat, reuse: \"little-learners:letter-c/cat\" }", "need 'graphemes'")]
    [InlineData("graphemes: [c, a, t], reuse", "graphemes: [c, \"a:ay\", t], reuse", "the sound 'ay', which is not in the explorers phoneme table")]
    [InlineData("graphemes: [c, a, t], reuse", "graphemes: [c, \"a:\", t], reuse", "spell the word")]
    public void Graphemes_must_spell_the_word_with_sounds_of_the_table(string from, string to, string error)
    {
        using var repo = Repo(Lesson.Replace(from, to));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain(error);
    }

    [Fact]
    public void A_letter_can_say_another_sound_of_the_table_or_be_silent()
    {
        using var repo = Repo(Lesson.Replace("{ word: act, graphemes: [a, c, t]", "{ word: cate, graphemes: [c, \"a:t\", t, \"e:-\"]"));
        var w = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single().Words[1];
        w.Graphemes.ShouldBe(["c", "a:t", "t", "e:-"]);
        w.Graphemes!.Select(LessonValidator.GraphemeText).ShouldBe(["c", "a", "t", "e"]);
        w.Graphemes!.Select(LessonValidator.GraphemeSound).ShouldBe(["c", "t", "t", "-"]);
    }

    [Fact]
    public void Every_phoneme_is_one_clip_flagged_as_a_phoneme()
    {
        using var repo = Repo();
        var table = CurriculumReader.LoadPhonemes(repo.Layout.CurriculumDir).Select(p => p.Phoneme).ToList();
        var plan = LessonPlan.Audio(CurriculumReader.PhonemesLesson("explorers", table));
        plan.Select(a => (a.Role, a.Text, a.IsPhoneme)).ShouldBe([("phoneme-c", "kuh", true), ("phoneme-a", "aa", true), ("phoneme-t", "tuh", true)]);
    }

    [Fact]
    public void A_phoneme_needs_a_short_key_and_a_say_text()
    {
        using var repo = Repo(units: Units.Replace("say: \"kuh\"", "say: \"\""));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadPhonemes(repo.Layout.CurriculumDir)).Message.ShouldContain("needs a 'say' text");
    }

    [Fact]
    public async Task Export_writes_the_phoneme_table_and_each_words_graphemes_and_copies_a_little_learners_picture()
    {
        using var repo = Repo();
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        var table = CurriculumReader.LoadPhonemes(repo.Layout.CurriculumDir).Select(p => p.Phoneme).ToList();
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "A");
        foreach (var i in LessonPlan.Images(lesson)) repo.Touch(repo.Layout.SvgSource(lesson, i.Key), "<svg/>");
        repo.Touch(repo.Layout.ImageApproved(new Lesson { Id = "letter-c", Track = "little-learners" }, "cat"), "CAT"); // the Little Learners picture
        foreach (var u in units) foreach (var a in LessonPlan.Audio(CurriculumReader.UnitAudioLesson(u))) repo.Touch(repo.Layout.AudioGen(CurriculumReader.UnitAudioLesson(u), a.Role), "U");
        var pl = CurriculumReader.PhonemesLesson("explorers", table);
        foreach (var a in LessonPlan.Audio(pl).Take(2)) repo.Touch(repo.Layout.AudioGen(pl, a.Role), "P"); // "t" has no audio yet

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter())
            .RunAsync("explorers", [lesson], default, units: units, sharedArt: false, phonemes: table);

        result.Exported.ShouldBe(1);
        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var phonemes = doc.RootElement.GetProperty("phonemes");
        phonemes.GetProperty("c").GetString().ShouldBe("audio/explorers/phonemes/phoneme_c.mp3");
        phonemes.TryGetProperty("t", out _).ShouldBeFalse();
        result.Incomplete.ShouldContain(i => i.Contains("phoneme-t"));
        var cat = doc.RootElement.GetProperty("units")[0].GetProperty("lessons")[0].GetProperty("words")[0];
        cat.GetProperty("graphemes").EnumerateArray().Select(g => g.GetString()).ShouldBe(["c", "a", "t"]);
        cat.GetProperty("image").GetString().ShouldBe("images/explorers/sound_builders_a/cat.webp");
        File.ReadAllText(Path.Combine(repo.Layout.AssetsDir, "images/explorers/sound_builders_a/cat.webp")).ShouldBe("CAT");
    }

    [Fact]
    public void The_real_sound_builders_unit_has_five_short_vowel_lessons_of_everyday_words_with_every_sound_in_the_table()
    {
        var curriculum = Path.Combine(Layout.Find(null).Root, "content", "curriculum");
        var lessons = CurriculumReader.LoadAll(curriculum).Where(l => l.Track == "explorers" && l.Unit == "sound-builders").ToList();
        lessons.Select(l => l.Id).ShouldBe(["sound-builders-a", "sound-builders-e", "sound-builders-i", "sound-builders-o", "sound-builders-u"]);
        lessons.ShouldAllBe(l => l.Words.Count == 4 && l.Activities.SequenceEqual(new[] { "sound-tap", "word-builder", "read-and-pick" }));
        lessons.ShouldAllBe(l => l.Activities.All(a => l.Narration.Instructions.ContainsKey(a)));
        // every word is three sounds with the lesson's vowel in the middle
        foreach (var l in lessons)
        {
            var vowel = l.Id.Substring(l.Id.Length - 1);
            l.Words.ShouldAllBe(w => w.Graphemes!.Count == 3 && w.Graphemes[1] == vowel);
        }
        var units = CurriculumReader.LoadUnits(curriculum).Single(u => u.Track == "explorers" && u.Id == "sound-builders");
        units.Chest!.Accessory.ShouldBe("explorer-hat");
        units.Story!.Pages.Count.ShouldBe(5);
    }

    [Fact]
    public void Phase_two_has_digraphs_blends_magic_e_and_vowel_teams_with_a_chest_a_story_and_two_reviews()
    {
        var curriculum = Path.Combine(Layout.Find(null).Root, "content", "curriculum");
        var lessons = CurriculumReader.LoadAll(curriculum).Where(l => l.Track == "explorers").ToList();
        var phonemes = CurriculumReader.LoadPhonemes(curriculum).Where(p => p.Track == "explorers").Select(p => p.Phoneme.Key).ToHashSet();
        foreach (var (unit, count) in new[] { ("digraphs", 4), ("blends", 3), ("magic-e", 3), ("vowel-teams", 4) })
        {
            var ls = lessons.Where(l => l.Unit == unit).ToList();
            ls.Count.ShouldBe(count, unit);
            ls.ShouldAllBe(l => l.Words.Count == 4 && l.Activities.SequenceEqual(new[] { "sound-tap", "word-builder", "read-and-pick" }));
            var u = CurriculumReader.LoadUnits(curriculum).Single(x => x.Track == "explorers" && x.Id == unit);
            u.IsPack.ShouldBeTrue();
            u.Chest.ShouldNotBeNull();
            u.Story!.Pages.Count.ShouldBe(5);
        }
        // every sound of every word is in the table, and every sound in the table is used
        var used = lessons.SelectMany(l => l.Words).SelectMany(w => w.Graphemes ?? []).Select(LessonValidator.GraphemeSound).Where(g => g != "-").ToHashSet();
        used.ShouldBe(phonemes, ignoreOrder: true);
        // a magic-e word ends in a silent e, and the vowel before it says its name
        lessons.Where(l => l.Unit == "magic-e").SelectMany(l => l.Words).ShouldAllBe(w => w.Graphemes!.Contains("e:-") && w.Graphemes.Any(g => g.EndsWith(":ay") || g.EndsWith(":ie") || g.EndsWith(":oa") || g.EndsWith(":ue")));
        CurriculumReader.LoadReviews(curriculum).Where(r => r.Track == "explorers").Select(r => r.Review.Units.Last()).ShouldBe(["blends", "vowel-teams"]);
    }
}
