using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

/// <summary>Explorers phase 3: sight words (said aloud, no picture) and sentences with a picture of one of the lesson's words, for
/// Find the Word, Sentence Builder and Fill the Gap.</summary>
public class ExplorersSentencesTests
{
    private const string Units = """
        track: explorers
        units:
          - id: my-sentences
            order: 1
            title: { en: "My Sentences", ar: "جملي" }
            narration: { title: "My Sentences", welcome: "Let's read!", celebration: "Great!" }
        """;

    private const string Lesson = """
        id: my-sentences-1
        unit: my-sentences
        track: explorers
        level: a1
        words:
          - { word: cat, reuse: "little-learners:letter-c/cat" }
          - { word: hen, source: svg, imagePrompt: "a hen" }
        sightWords: [the, is, are]
        sentences:
          - { text: "The cat is big.", picture: cat, gap: is, choices: [is, are] }
          - { text: "The cats are big.", picture: cat, two: true, gap: are, choices: [is, are] }
          - { text: "The hen is red.", picture: hen, gap: is, choices: [is, are] }
        narration:
          intro: "Let's read sentences!"
          praise: ["Great!"]
          instructions: { find-the-word: "Listen. Tap the word!", sentence-builder: "Build the sentence!", fill-the-gap: "Which word fits?" }
        activities: [find-the-word, sentence-builder, fill-the-gap]
        """;

    private static TestRepo Repo(string lesson = Lesson)
    {
        var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "explorers.yaml"), Units);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "my-sentences-1.yaml"), lesson);
        return repo;
    }

    [Fact]
    public void Sight_words_and_sentences_are_read_and_each_is_one_line_of_audio()
    {
        using var repo = Repo();
        var l = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        l.SightWords.ShouldBe(["the", "is", "are"]);
        l.Sentences[1].Tokens().ShouldBe(["The", "cats", "are", "big"]);
        var audio = LessonPlan.Audio(l).Select(a => (a.Role, a.Text)).ToList();
        audio.ShouldContain(("sight-the", "the"));
        audio.ShouldContain(("sentence-2", "The cats are big."));
        audio.ShouldContain(("instr-fill-the-gap", "Which word fits?"));
    }

    [Theory]
    [InlineData("picture: hen, gap", "picture: dog, gap", "'picture' must be one of the lesson's words")]
    [InlineData("{ text: \"The hen is red.\", picture: hen, gap: is, choices: [is, are] }", "{ text: \"The hen is red.\", picture: hen, gap: was, choices: [was, are] }", "'gap' must be one of its words")]
    [InlineData("gap: is, choices: [is, are] }\n  - { text: \"The cats", "gap: is, choices: [are, was] }\n  - { text: \"The cats", "one of them the gap")]
    [InlineData("\"The hen is red.\"", "\"the hen is red\"", "starts with a capital letter")]
    [InlineData("sightWords: [the, is, are]", "sightWords: [the, is]", "find-the-word needs at least 3 sight words")]
    [InlineData("{ text: \"The hen is red.\", picture: hen, gap: is, choices: [is, are] }", "{ text: \"The hen is red.\", picture: hen }", "fill-the-gap needs at least 2 sentences, each with a gap")]
    public void Sentences_are_checked(string from, string to, string error)
    {
        using var repo = Repo(Lesson.Replace(from, to));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain(error);
    }

    [Fact]
    public async Task Export_lists_the_sight_words_and_the_sentences_with_their_word_picture()
    {
        using var repo = Repo();
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "A");
        foreach (var i in LessonPlan.Images(lesson)) repo.Touch(repo.Layout.SvgSource(lesson, i.Key), "<svg/>");
        repo.Touch(repo.Layout.ImageApproved(new Lesson { Id = "letter-c", Track = "little-learners" }, "cat"), "CAT");
        foreach (var u in units) foreach (var a in LessonPlan.Audio(CurriculumReader.UnitAudioLesson(u))) repo.Touch(repo.Layout.AudioGen(CurriculumReader.UnitAudioLesson(u), a.Role), "U");

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter())
            .RunAsync("explorers", [lesson], default, units: units, sharedArt: false);

        result.Exported.ShouldBe(1);
        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var l = doc.RootElement.GetProperty("units")[0].GetProperty("lessons")[0];
        l.GetProperty("sightWords")[0].GetProperty("audio").GetString().ShouldBe("audio/explorers/my_sentences_1/sight_the.mp3");
        var cats = l.GetProperty("sentences")[1];
        cats.GetProperty("text").GetString().ShouldBe("The cats are big.");
        cats.GetProperty("image").GetString().ShouldBe("images/explorers/my_sentences_1/cat.webp");
        cats.GetProperty("two").GetBoolean().ShouldBeTrue();
        cats.GetProperty("gap").GetString().ShouldBe("are");
        cats.GetProperty("choices").EnumerateArray().Select(c => c.GetString()).ShouldBe(["is", "are"]);
        l.GetProperty("sentences")[2].GetProperty("image").GetString().ShouldBe("images/explorers/my_sentences_1/hen.svg");
        l.GetProperty("sentences")[0].TryGetProperty("two", out _).ShouldBeFalse();
    }

    [Fact]
    public void Phase_three_reads_only_taught_words_and_shows_is_are_and_a_an_by_the_picture()
    {
        var curriculum = Path.Combine(Layout.Find(null).Root, "content", "curriculum");
        var all = CurriculumReader.LoadAll(curriculum).Where(l => l.Track == "explorers").ToList();
        var order = CurriculumReader.LoadUnits(curriculum).Where(u => u.Track == "explorers").ToDictionary(u => u.Id, u => u.Order);
        var ordered = all.OrderBy(l => order[l.Unit]).ThenBy(l => l.ResolvedOrder).ToList();
        foreach (var (unit, count) in new[] { ("sight-words-1", 3), ("sight-words-2", 3), ("my-sentences", 3) })
        {
            ordered.Count(l => l.Unit == unit).ShouldBe(count, unit);
            var u = CurriculumReader.LoadUnits(curriculum).Single(x => x.Track == "explorers" && x.Id == unit);
            u.IsPack.ShouldBeTrue();
            u.Chest.ShouldNotBeNull();
            u.Story!.Pages.Count.ShouldBe(5);
        }

        // Every word of every sentence was met before or in its lesson: a sight word, or a word of an Explorers lesson (read by
        // its sounds), or an ending of one (-s). A few joining words are decodable on their own.
        var decodable = new HashSet<string> { "a", "an", "at", "has", "big", "hot", "red", "up", "hop", "pink", "wet", "yum", "fun", "rock", "dish", "mom" };
        var known = new HashSet<string>(decodable);
        foreach (var l in ordered)
        {
            foreach (var w in l.Words) { known.Add(w.Word.ToLowerInvariant()); if (w.Plural is not null) known.Add(w.Plural); }
            foreach (var w in l.SightWords) known.Add(w.ToLowerInvariant());
            foreach (var s in l.Sentences)
                foreach (var t in s.Tokens().Select(t => t.Trim(',').ToLowerInvariant()))
                    (known.Contains(t) || known.Contains(t.TrimEnd('s'))).ShouldBeTrue($"{l.Id}: '{t}' in \"{s.Text}\" is not taught yet");
        }

        // is/are: one thing with "is", two with "are"; a/an: "an" before a vowel sound
        var ms = ordered.Where(l => l.Unit == "my-sentences").SelectMany(l => l.Sentences).ToList();
        ms.ShouldAllBe(s => s.Gap != null);
        ms.Where(s => s.Gap == "is").ShouldAllBe(s => !s.Two);
        ms.Where(s => s.Gap == "are").ShouldAllBe(s => s.Two);
        ms.Where(s => s.Gap!.ToLowerInvariant() is "a" or "an").ShouldAllBe(s =>
            (s.Gap!.ToLowerInvariant() == "an") == "aeiou".Contains(s.Tokens()[s.Tokens().ToList().FindIndex(t => t.Equals(s.Gap, StringComparison.OrdinalIgnoreCase)) + 1].ToLowerInvariant()[0]));
        CurriculumReader.LoadReviews(curriculum).Where(r => r.Track == "explorers").Select(r => r.Review.Id).ShouldContain("review-3");
    }
}
