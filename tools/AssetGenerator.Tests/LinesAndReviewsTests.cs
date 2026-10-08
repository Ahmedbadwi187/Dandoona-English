using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

public class LinesAndReviewsTests
{
    private const string Yaml = """
        track: little-learners
        app:
          title: "Who is playing?"
          welcome: "Hi!"
          celebration: "Welcome back!"
          lines: { coming-soon: "Coming soon!" }
        reviews:
          - { id: review-1, units: [letters, colors] }
        units:
          - id: letters
            order: 1
            title: { en: "Letters", ar: "الحروف" }
            narration: { title: "Letters", welcome: "Let's learn letters!", celebration: "Done!", lines: { locked: "Finish Letters first!" } }
          - id: colors
            order: 2
            title: { en: "Colors", ar: "الألوان" }
            narration: { title: "Colors", welcome: "Colors!", celebration: "Done!" }
        """;

    private static TestRepo Repo(string yaml = Yaml)
    {
        var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), yaml);
        return repo;
    }

    [Fact]
    public void A_units_extra_lines_are_planned_as_audio_next_to_its_name()
    {
        using var repo = Repo();
        var letters = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir).First();
        var roles = LessonPlan.Audio(CurriculumReader.UnitAudioLesson(letters)).Select(a => (a.Role, a.Text)).ToList();
        roles.ShouldContain(("instr-locked", "Finish Letters first!"));
        roles.ShouldContain(("instr-title", "Letters"));
    }

    [Fact]
    public async Task A_line_without_audio_yet_is_left_out_and_never_silences_the_units_name()
    {
        using var repo = Repo();
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        var app = CurriculumReader.LoadApp(repo.Layout.CurriculumDir).Single();
        // every core line has audio; of the extra lines only Letters' "locked" has
        foreach (var ul in units.Append(app).Select(CurriculumReader.UnitAudioLesson))
            foreach (var a in LessonPlan.Audio(ul).Where(a => !a.Role.StartsWith("instr-") || a.Role is "instr-title" or "instr-celebration"))
                repo.Touch(repo.Layout.AudioGen(ul, a.Role), "A");
        repo.Touch(repo.Layout.AudioGen(CurriculumReader.UnitAudioLesson(units[0]), "instr-locked"), "A");

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter())
            .RunAsync("little-learners", [], default, units: units, app: app,
                reviews: CurriculumReader.LoadReviews(repo.Layout.CurriculumDir).Select(r => r.Review).ToList());

        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var letters = doc.RootElement.GetProperty("units")[0].GetProperty("audio");
        letters.GetProperty("title").GetString().ShouldBe("audio/little_learners/unit_letters/instr_title.mp3");
        letters.GetProperty("lines").GetProperty("locked").GetString().ShouldBe("audio/little_learners/unit_letters/instr_locked.mp3");
        doc.RootElement.GetProperty("units")[1].GetProperty("audio").TryGetProperty("lines", out _).ShouldBeFalse();
        doc.RootElement.GetProperty("app").GetProperty("title").GetString().ShouldNotBeNull(); // still there without "coming-soon"
        doc.RootElement.GetProperty("app").TryGetProperty("lines", out _).ShouldBeFalse();
        result.Incomplete.ShouldContain(i => i.Contains("instr-coming-soon"));

        var review = doc.RootElement.GetProperty("reviews")[0];
        review.GetProperty("id").GetString().ShouldBe("review-1");
        review.GetProperty("units").EnumerateArray().Select(u => u.GetString()).ShouldBe(["letters", "colors"]);
    }

    [Theory]
    [InlineData("units: [letters, music]", "unknown unit 'music'")]
    [InlineData("units: [colors, letters]", "in path order")]
    [InlineData("units: []", "needs units")]
    public void A_review_must_name_known_units_in_path_order(string units, string error)
    {
        using var repo = Repo(Yaml.Replace("units: [letters, colors]", units));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadReviews(repo.Layout.CurriculumDir)).Message.ShouldContain(error);
    }

    [Fact]
    public void The_real_path_has_the_owners_order_with_three_reviews_and_a_locked_line_for_every_unit()
    {
        var curriculum = Path.Combine(Layout.Find(null).Root, "content", "curriculum");
        var units = CurriculumReader.LoadUnits(curriculum).Where(u => u.Track == "little-learners").ToList();
        units.Select(u => u.Id).ShouldBe(["letters", "colors", "numbers", "shapes", "animals", "feelings", "my-body", "actions",
            "food", "clothes", "toys", "my-family", "my-home", "opposites", "transport"]);
        units.ShouldAllBe(u => u.Narration.Lines.ContainsKey("locked"));
        units.Where(u => u.Id is not ("letters" or "colors")).ShouldAllBe(u => u.IsPack);
        CurriculumReader.LoadReviews(curriculum).Where(r => r.Track == "little-learners").Select(r => r.Review.Units.Last()).ShouldBe(["shapes", "actions", "toys"]);
    }
}
