using System.Text.Json;
using System.Text.RegularExpressions;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

public class ArtAndLedgerTests
{
    private const string Svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 512 512\"><rect fill=\"#FDF8E6\" width=\"512\" height=\"512\"/></svg>";
    private const string AppleSvgYaml = "{ word: apple, imagePrompt: \"a red apple\", source: svg }";
    private const string AppleOpenAiYaml = "{ word: apple, imagePrompt: \"a shiny red apple\" }";

    [Fact]
    public void Every_self_drawn_svg_uses_only_palette_colors_and_has_no_text()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var palette = Palette.Load(layout).Values.ToHashSet(StringComparer.OrdinalIgnoreCase);
        palette.Count.ShouldBeGreaterThan(5);

        var files = Directory.GetFiles(layout.ArtDir, "*.svg", SearchOption.AllDirectories);
        files.Length.ShouldBeGreaterThan(0);
        foreach (var f in files)
        {
            var svg = File.ReadAllText(f);
            var name = Path.GetRelativePath(layout.ArtDir, f);
            svg.ShouldContain("viewBox=\"0 0 512 512\"", customMessage: name);
            svg.ShouldNotContain("<text", customMessage: name + " must not contain text (the app draws all text)");
            svg.Length.ShouldBeLessThan(8000, name);
            foreach (Match m in Regex.Matches(svg, "#[0-9A-Fa-f]{6}"))
                palette.ShouldContain(m.Value, $"{name} uses {m.Value}, which is not in palette.json");
        }
    }

    [Fact]
    public void Every_svg_word_has_a_drawing_and_every_drawing_has_a_word()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir);
        var expected = lessons.SelectMany(l => LessonPlan.Images(l).Where(i => i.IsSvg).Select(i => Path.GetFullPath(layout.SvgSource(l, i.Key)))).ToList();
        expected.ShouldAllBe(p => File.Exists(p));
        var actual = Directory.GetFiles(layout.ArtDir, "*.svg", SearchOption.AllDirectories).Select(Path.GetFullPath).ToList();
        actual.ShouldBe(expected, ignoreOrder: true);
    }

    [Fact]
    public void Curriculum_covers_26_letters_and_every_word_has_a_valid_source()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir);
        lessons.Select(l => l.Letter).ShouldBe("ABCDEFGHIJKLMNOPQRSTUVWXYZ".Select(c => c.ToString()));
        lessons.SelectMany(l => l.Words).ShouldAllBe(w => w.Source == "openai" || w.Source == "svg");
    }

    [Fact]
    public async Task Svg_words_are_never_sent_to_openai()
    {
        using var repo = new TestRepo();
        var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace(AppleOpenAiYaml, AppleSvgYaml));
        repo.WriteStyleFiles();
        repo.Touch(repo.Layout.SvgSource(lesson, "apple"), Svg);
        repo.Touch(repo.Layout.MascotReference);
        var client = new FakeImages();
        var w = new StringWriter();
        await new ImageRunner(repo.Layout, new GenerationConfig(), client, w).RunAsync([lesson], false, false, default);
        (client.Generated.Count + client.Edited.Count).ShouldBe(1); // only the ant (mascot scene)
        w.ToString().ShouldContain("self-drawn");
    }

    [Fact]
    public async Task Missing_svg_is_reported_not_generated()
    {
        using var repo = new TestRepo();
        var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace(AppleOpenAiYaml, AppleSvgYaml));
        var w = new StringWriter();
        await new ImageRunner(repo.Layout, new GenerationConfig(), new FakeImages(), w).RunAsync([lesson], true, false, default);
        w.ToString().ShouldContain("MISSING SVG letter-a/apple");
    }

    [Fact]
    public void Ledger_totals_and_refuses_over_budget()
    {
        using var repo = new TestRepo();
        var ledger = new CostLedger(repo.Layout.LedgerPath, 1.00m);
        ledger.Add("ElevenLabs", "x", 0.60m);
        ledger.Total.ShouldBe(0.60m);
        ledger.EnsureWithinBudget(0.40m); // exactly at the limit is fine
        Should.Throw<ApiException>(() => ledger.EnsureWithinBudget(0.41m)).Message.ShouldContain("Budget guard");
        new CostLedger(repo.Layout.LedgerPath, 1.00m).Total.ShouldBe(0.60m); // persisted
    }

    [Fact]
    public async Task Generation_is_blocked_before_any_api_call_when_over_budget()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        new CostLedger(repo.Layout.LedgerPath, 25m).Add("OpenAI", "earlier", 24.99m);
        var voice = new FakeVoice();
        var runner = new AudioRunner(repo.Layout,
            new VoiceConfig { Voices = { ["narrator"] = new VoiceSettings { VoiceId = "v" } } },
            new GenerationConfig { Pricing = { ElevenLabsUsdPer1kChars = 5m } }, voice, null, new StringWriter());
        await Should.ThrowAsync<ApiException>(() => runner.RunAsync([lesson], false, false, default));
        voice.Texts.ShouldBeEmpty();
    }

    [Fact]
    public async Task Image_run_records_actual_usage_cost_in_the_ledger()
    {
        using var repo = new TestRepo();
        var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace(", mascot: true", ""));
        repo.WriteStyleFiles();
        await new ImageRunner(repo.Layout, new GenerationConfig(), new FakeImages(), new StringWriter()).RunAsync([lesson], false, false, default);
        var ledger = new CostLedger(repo.Layout.LedgerPath, 25m);
        ledger.Entries.Count.ShouldBe(2);
        ledger.Entries.ShouldAllBe(e => !e.Estimated && e.Service == "OpenAI");
        ledger.Total.ShouldBe(2 * (100 * 5m + 1000 * 30m) / 1_000_000m); // FakeImages reports 100 text + 1000 output tokens
    }

    [Fact]
    public void Approve_copies_the_variant_and_records_the_reason_and_decisions_doc_lists_it()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        repo.Touch(repo.Layout.ImageReview(lesson, "apple", 2), "VARIANT-2");
        ApproveCommand.Run(repo.Layout, lesson, "apple", 2, "clearest single apple", new StringWriter());
        File.ReadAllText(repo.Layout.ImageApproved(lesson, "apple")).ShouldBe("VARIANT-2");

        var doc = DecisionsDoc.Build(repo.Layout, [lesson]);
        doc.ShouldContain("| letter-a | apple | **OpenAI** | v2 | clearest single apple |");
        doc.ShouldContain("| letter-a | ant | **OpenAI** | _not approved yet_ |");
        doc.ShouldContain("Needs human listening");
        doc.ShouldContain("`/æ/`");
    }

    [Fact]
    public void Approving_a_self_drawn_word_or_a_missing_variant_is_an_error()
    {
        using var repo = new TestRepo();
        var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace(AppleOpenAiYaml, AppleSvgYaml));
        Should.Throw<CurriculumException>(() => ApproveCommand.Run(repo.Layout, lesson, "apple", 1, "r", new StringWriter())).Message.ShouldContain("self-drawn");
        Should.Throw<CurriculumException>(() => ApproveCommand.Run(repo.Layout, lesson, "ant", 9, "r", new StringWriter())).Message.ShouldContain("No such variant");
    }

    [Fact]
    public async Task Export_copies_svg_unchanged_and_points_the_json_at_it()
    {
        using var repo = new TestRepo();
        var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace(AppleOpenAiYaml, AppleSvgYaml));
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role));
        repo.Touch(repo.Layout.SvgSource(lesson, "apple"), Svg);
        repo.Touch(repo.Layout.ImageApproved(lesson, "ant"), "ANT");

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter()).RunAsync("little-learners", [lesson], default);

        result.Exported.ShouldBe(1);
        File.ReadAllText(Path.Combine(repo.Layout.AssetsDir, "images/little_learners/letter_a/apple.svg")).ShouldBe(Svg);
        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var words = doc.RootElement.GetProperty("lessons")[0].GetProperty("words");
        words[0].GetProperty("image").GetString().ShouldBe("images/little_learners/letter_a/apple.svg");
        words[1].GetProperty("image").GetString().ShouldBe("images/little_learners/letter_a/ant.webp");
    }
}
