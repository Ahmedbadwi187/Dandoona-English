using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

public class UnitsTests
{
    private const string UnitsYaml = """
        track: little-learners
        units:
          - id: letters
            order: 1
            title: { en: "Letters", ar: "الحروف" }
            icon: letters
            color: red
            narration: { title: "Letters", welcome: "Let's learn letters!", celebration: "You finished the letters!" }
          - id: colors
            order: 2
            title: { en: "Colors", ar: "الألوان" }
            icon: colors
            color: orange
            narration: { title: "Colors", welcome: "Let's learn colors!", celebration: "You finished the colors!" }
        """;

    internal const string ColorRed = """
        id: color-red
        unit: colors
        track: little-learners
        level: pre-a1
        order: 1
        color: { name: red, hex: "#E5524A" }
        words:
          - { word: apple, reuse: letter-a/apple }
          - { word: heart, imagePrompt: "a red heart", source: svg }
        narration:
          intro: "This is red! Red, red, red!"
          colorName: "red"
          phrases: { apple: "A red apple.", heart: "A red heart." }
          praise: ["Great job!"]
          instructions: { color-the-object: "Color the apple red!" }
        activities: [listen-and-tap, match-picture, record-and-listen, color-the-object]
        """;

    internal static void WriteUnits(TestRepo repo)
    {
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), UnitsYaml);
    }

    [Fact]
    public void Units_are_read_in_order_and_lessons_must_name_a_known_unit()
    {
        using var repo = new TestRepo();
        WriteUnits(repo);
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        units.Select(u => u.Id).ShouldBe(["letters", "colors"]);
        units[1].Title["ar"].ShouldBe("الألوان");

        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA); // no unit
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain("'unit' is required");

        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA.Replace("level: pre-a1", "level: pre-a1\nunit: nope"));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain("unknown unit 'nope'");

        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA.Replace("level: pre-a1", "level: pre-a1\nunit: letters"));
        CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single().Unit.ShouldBe("letters");
    }

    [Fact]
    public void A_new_unit_needs_only_yaml_duplicate_orders_are_rejected()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), UnitsYaml.Replace("order: 2", "order: 1"));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadUnits(repo.Layout.CurriculumDir)).Message.ShouldContain("share order 1");
    }

    [Fact]
    public void Color_lesson_plans_the_color_name_and_phrases_and_skips_reused_pictures()
    {
        using var repo = new TestRepo();
        WriteUnits(repo);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), ColorRed);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();

        var roles = LessonPlan.Audio(lesson).Select(a => a.Role).ToList();
        roles.ShouldContain("color-name");
        roles.ShouldContain("phrase-apple");
        roles.ShouldContain("phrase-heart");
        roles.ShouldContain("instr-color-the-object");
        LessonPlan.Images(lesson).Select(i => i.Key).ShouldBe(["heart"]); // apple reuses a picture, nothing to draw
        LessonPlan.Reused(lesson).Single().ShouldBe(("apple", "letter-a/apple"));
    }

    [Fact]
    public void A_phrase_for_an_unknown_word_is_rejected()
    {
        using var repo = new TestRepo();
        WriteUnits(repo);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), ColorRed.Replace("heart: \"A red heart.\"", "star: \"A red star.\""));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain("narration.phrases");
    }

    [Fact]
    public async Task Export_groups_lessons_into_units_copies_reused_pictures_and_swatches_and_exports_unit_audio()
    {
        using var repo = new TestRepo();
        WriteUnits(repo);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), ColorRed);
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();

        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "AUDIO");
        repo.Touch(repo.Layout.SvgSource(lesson, "heart"), "<svg/>");
        repo.Touch(repo.Layout.SvgSource(lesson, "swatch"), "<svg id=\"swatch\"/>");
        repo.Touch(repo.Layout.SvgSource(lesson, "colorable"), "<svg id=\"colorable\"/>");
        repo.Touch(repo.Layout.SvgSource(new Lesson { Id = "letter-a", Track = "little-learners" }, "apple"), "<svg id=\"apple\"/>"); // the reused picture
        foreach (var u in units)
        {
            var ul = CurriculumReader.UnitAudioLesson(u);
            foreach (var a in LessonPlan.Audio(ul)) repo.Touch(repo.Layout.AudioGen(ul, a.Role), "UNIT-AUDIO");
        }

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter())
            .RunAsync("little-learners", [lesson], default, units: units);

        result.Exported.ShouldBe(1);
        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var all = doc.RootElement.GetProperty("units").EnumerateArray().ToList();
        all.Select(u => u.GetProperty("id").GetString()).ShouldBe(["letters", "colors"]);
        all[0].GetProperty("lessons").GetArrayLength().ShouldBe(0); // listed so the map can show it as coming soon
        var unit = all[1];
        unit.GetProperty("id").GetString().ShouldBe("colors");
        unit.GetProperty("title").GetProperty("ar").GetString().ShouldBe("الألوان");
        unit.GetProperty("audio").GetProperty("celebration").GetString().ShouldBe("audio/little_learners/unit_colors/instr_celebration.mp3");
        var l = unit.GetProperty("lessons")[0];
        l.GetProperty("color").GetProperty("hex").GetString().ShouldBe("#E5524A");
        l.GetProperty("color").GetProperty("drawing").GetString().ShouldBe("images/little_learners/color_red/colorable.svg");
        l.GetProperty("audio").GetProperty("colorName").GetString().ShouldBe("audio/little_learners/color_red/color_name.mp3");
        var words = l.GetProperty("words");
        words[0].GetProperty("image").GetString().ShouldBe("images/little_learners/color_red/apple.svg");
        words[0].GetProperty("phrase").GetString().ShouldBe("audio/little_learners/color_red/phrase_apple.mp3");
        File.ReadAllText(Path.Combine(repo.Layout.AssetsDir, "images/little_learners/color_red/apple.svg")).ShouldContain("id=\"apple\"");
        File.Exists(Path.Combine(repo.Layout.AssetsDir, "audio/little_learners/unit_colors/title.mp3")).ShouldBeFalse(); // title is exported as instr_title
        File.Exists(Path.Combine(repo.Layout.AssetsDir, "audio/little_learners/unit_colors/instr_title.mp3")).ShouldBeTrue();
    }

    [Fact]
    public async Task A_missing_reused_picture_or_swatch_keeps_the_lesson_out_of_the_export()
    {
        using var repo = new TestRepo();
        WriteUnits(repo);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), ColorRed);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "AUDIO");
        repo.Touch(repo.Layout.SvgSource(lesson, "heart"), "<svg/>");

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter())
            .RunAsync("little-learners", [lesson], default, units: CurriculumReader.LoadUnits(repo.Layout.CurriculumDir));

        result.Exported.ShouldBe(0);
        var why = result.Incomplete.Single(i => i.StartsWith("color-red"));
        why.ShouldContain("reused picture letter-a/apple not found");
        why.ShouldContain("image/swatch");
        why.ShouldContain("image/colorable");
    }
}

public class ColorsUnitContentTests
{
    [Fact]
    public void Colors_unit_has_ten_lessons_each_with_a_palette_color_swatch_and_drawing_to_color()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var palette = Palette.Load(layout).Values.ToHashSet(StringComparer.OrdinalIgnoreCase);
        var colors = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "colors").OrderBy(l => l.ResolvedOrder).ToList();

        colors.Select(l => l.Color!.Name).ShouldBe(["red", "blue", "yellow", "green", "orange", "purple", "pink", "brown", "black", "white"]);
        foreach (var l in colors)
        {
            palette.ShouldContain(l.Color!.Hex, $"{l.Id} uses a color that is not in palette.json");
            l.Words.Count.ShouldBe(3);
            l.Narration.ColorName.ShouldNotBeNullOrWhiteSpace();
            l.Narration.Phrases.Count.ShouldBe(3);
            File.Exists(layout.SvgSource(l, "swatch")).ShouldBeTrue($"{l.Id} swatch");
            File.ReadAllText(layout.SvgSource(l, "swatch")).ShouldContain(l.Color.Hex, Case.Insensitive);
            File.ReadAllText(layout.SvgSource(l, "colorable")).ShouldContain("#FILLME", customMessage: $"{l.Id} colorable needs the fill placeholder");
            foreach (var (_, reuse) in LessonPlan.Reused(l))
                layout.ReuseSource(l, reuse).ShouldNotBeNull($"{l.Id}: reused picture {reuse} does not exist");
        }
    }

    [Fact]
    public void Every_colors_lesson_speaks_an_instruction_for_each_of_its_activities()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        foreach (var l in CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Unit == "colors"))
            foreach (var a in l.Activities.Where(a => a != "mix-colors")) // the mixing game speaks only the colors, no instruction of its own
                l.Narration.Instructions.ShouldContainKey(a, $"{l.Id} has no spoken instruction for {a}");
    }
}

public class AvatarsExportTests
{
    [Fact]
    public async Task Drawn_avatars_are_copied_for_the_profile_picker()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.AvatarsDir, "bunny.svg"), "<svg id=\"bunny\"/>");
        await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter()).RunAsync("little-learners", [], default);
        File.ReadAllText(Path.Combine(repo.Layout.AssetsDir, "images/avatars/bunny.svg")).ShouldContain("bunny");
    }

    [Fact]
    public void The_real_repo_has_the_friend_avatars_in_palette_colors()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        foreach (var name in new[] { "bunny", "cat", "bear", "owl", "fish", "puppy", "penguin", "frog" })
            File.Exists(Path.Combine(layout.AvatarsDir, name + ".svg")).ShouldBeTrue(name);
    }
}

public class PosesExportTests
{
    [Fact]
    public async Task Dandoonas_other_poses_are_exported_next_to_the_mascot()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.PosesDir, "waving.webp"), "WAVING");
        repo.Touch(Path.Combine(repo.Layout.PosesDir, "thinking.webp"), "THINKING");
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "placeholder.txt"));

        await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter()).RunAsync("little-learners", [], default);

        File.ReadAllText(Path.Combine(repo.Layout.AssetsDir, "images/mascot/poses/waving.webp")).ShouldBe("WAVING");
        File.Exists(Path.Combine(repo.Layout.AssetsDir, "images/mascot/poses/thinking.webp")).ShouldBeTrue();
    }

    [Fact]
    public void The_real_repo_has_the_five_poses()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        foreach (var pose in new[] { "waving", "jumping", "clapping", "thinking", "pointing-up" })
            File.Exists(Path.Combine(layout.PosesDir, pose + ".webp")).ShouldBeTrue(pose);
    }
}

public class PlacementTests
{
    private const string Units = """
        track: little-learners
        placement:
          - { level: 0, key: none, doneUnits: [], startUnit: letters }
          - { level: 2, key: all-letters, doneUnits: [letters], startUnit: colors }
        units:
          - { id: letters, order: 1, title: { en: "Letters", ar: "الحروف" }, icon: letters, color: red, narration: { title: "Letters", celebration: "Done!" } }
          - { id: colors, order: 2, title: { en: "Colors", ar: "الألوان" }, icon: colors, color: orange, narration: { title: "Colors", celebration: "Done!" } }
        """;

    [Fact]
    public void Placement_answers_are_read_in_level_order()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), Units);
        var placement = CurriculumReader.LoadPlacement(repo.Layout.CurriculumDir);
        placement.Select(p => p.Key).ShouldBe(["none", "all-letters"]);
        placement[1].DoneUnits.ShouldBe(["letters"]);
        placement[1].StartUnit.ShouldBe("colors");
    }

    [Fact]
    public void A_placement_that_names_an_unknown_unit_is_rejected()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), Units.Replace("startUnit: colors", "startUnit: nope"));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadPlacement(repo.Layout.CurriculumDir)).Message.ShouldContain("unknown unit 'nope'");
    }

    [Fact]
    public void Dandoonas_app_lines_are_read_as_one_pseudo_unit_and_all_three_lines_are_required()
    {
        using var repo = new TestRepo();
        var withApp = Units + "\napp: { title: \"Who is playing?\", welcome: \"Hi!\", celebration: \"Welcome back!\" }\n";
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), withApp);
        var app = CurriculumReader.LoadApp(repo.Layout.CurriculumDir).Single();
        app.Id.ShouldBe("app");
        app.Track.ShouldBe("little-learners");
        var lesson = CurriculumReader.UnitAudioLesson(app);
        lesson.Id.ShouldBe("unit-app");
        LessonPlan.Audio(lesson).Select(a => a.Text).ShouldContain("Who is playing?");
        CurriculumReader.LoadUnits(repo.Layout.CurriculumDir).ShouldNotContain(u => u.Id == "app"); // not an island on the map

        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), Units + "\napp: { title: \"Who is playing?\" }\n");
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadApp(repo.Layout.CurriculumDir)).Message.ShouldContain("app needs");
    }

    [Fact]
    public async Task Export_writes_the_app_audio_into_the_lesson_json()
    {
        using var repo = new TestRepo();
        UnitsTests.WriteUnits(repo);
        var app = new UnitDef { Id = "app", Track = "little-learners", Narration = new UnitNarration { Title = "Who is playing?", Welcome = "Hi!", Celebration = "Welcome back!" } };
        var al = CurriculumReader.UnitAudioLesson(app);
        foreach (var a in LessonPlan.Audio(al)) repo.Touch(repo.Layout.AudioGen(al, a.Role), "APP-AUDIO");
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), UnitsTests.ColorRed);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "AUDIO");
        repo.Touch(repo.Layout.SvgSource(lesson, "heart"), "<svg/>");
        repo.Touch(repo.Layout.SvgSource(lesson, "swatch"), "<svg/>");
        repo.Touch(repo.Layout.SvgSource(lesson, "colorable"), "<svg/>");
        repo.Touch(repo.Layout.SvgSource(new Lesson { Id = "letter-a", Track = "little-learners" }, "apple"), "<svg/>");
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        foreach (var u in units) { var ul = CurriculumReader.UnitAudioLesson(u); foreach (var a in LessonPlan.Audio(ul)) repo.Touch(repo.Layout.AudioGen(ul, a.Role), "U"); }

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter()).RunAsync("little-learners", [lesson], default, units: units, app: app);

        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var audio = doc.RootElement.GetProperty("app");
        audio.GetProperty("title").GetString().ShouldBe("audio/little_learners/unit_app/instr_title.mp3");
        audio.GetProperty("welcome").GetString().ShouldBe("audio/little_learners/unit_app/intro.mp3");
        audio.GetProperty("celebration").GetString().ShouldBe("audio/little_learners/unit_app/instr_celebration.mp3");
        File.Exists(Path.Combine(repo.Layout.AssetsDir, "audio/little_learners/unit_app/intro.mp3")).ShouldBeTrue();
    }

    [Fact]
    public void The_real_content_maps_all_four_answers_and_letters_known_means_start_at_colors()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var placement = CurriculumReader.LoadPlacement(layout.CurriculumDir).Where(p => p.Track == "little-learners").ToList(); // Little Learners placement
        placement.Select(p => p.Level).ShouldBe([0, 1, 2, 3]);
        placement.Single(p => p.Key == "all-letters").DoneUnits.ShouldBe(["letters"]);
        placement.Single(p => p.Key == "all-letters").StartUnit.ShouldBe("colors");
        placement.Single(p => p.Key == "none").StartUnit.ShouldBe("letters");
    }
}
