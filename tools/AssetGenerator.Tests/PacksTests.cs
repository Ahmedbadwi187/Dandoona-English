using System.Security.Cryptography;
using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

public class PacksTests
{
    // Letters stays in the app; Colors is a downloadable pack.
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
            delivery: pack
            title: { en: "Colors", ar: "الألوان" }
            icon: colors
            color: orange
            narration: { title: "Colors", welcome: "Let's learn colors!", celebration: "You finished the colors!" }
        """;

    private static (TestRepo Repo, Lesson Lesson, IReadOnlyList<UnitDef> Units) Setup()
    {
        var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), UnitsYaml);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "color-red.yaml"), UnitsTests.ColorRed);
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "AUDIO-" + a.Role);
        repo.Touch(repo.Layout.SvgSource(lesson, "heart"), "<svg id=\"heart\"/>");
        repo.Touch(repo.Layout.SvgSource(lesson, "swatch"), "<svg id=\"swatch\"/>");
        repo.Touch(repo.Layout.SvgSource(lesson, "colorable"), "<svg id=\"colorable\"/>");
        repo.Touch(repo.Layout.SvgSource(new Lesson { Id = "letter-a", Track = "little-learners" }, "apple"), "<svg id=\"apple\"/>");
        foreach (var u in units)
        {
            var ul = CurriculumReader.UnitAudioLesson(u);
            foreach (var a in LessonPlan.Audio(ul)) repo.Touch(repo.Layout.AudioGen(ul, a.Role), "UNIT-AUDIO");
        }
        return (repo, lesson, units);
    }

    private static Task<ExportResult> Export(TestRepo repo, Lesson lesson, IReadOnlyList<UnitDef> units) =>
        new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter()).RunAsync("little-learners", [lesson], default, units: units);

    private static string Hex(byte[] b) => Convert.ToHexString(SHA256.HashData(b)).ToLowerInvariant();

    [Fact]
    public async Task A_pack_units_lessons_go_into_a_versioned_pack_and_the_app_gets_only_its_reference()
    {
        var (repo, lesson, units) = Setup();
        using var _ = repo;
        var result = await Export(repo, lesson, units);

        // nothing of the lesson in the app's assets; the unit's own lines (its name) stay bundled
        File.Exists(Path.Combine(repo.Layout.AssetsDir, "images/little_learners/color_red/heart.svg")).ShouldBeFalse();
        File.Exists(Path.Combine(repo.Layout.AssetsDir, "audio/little_learners/unit_colors/instr_title.mp3")).ShouldBeTrue();

        using var catalog = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var colors = catalog.RootElement.GetProperty("units").EnumerateArray().Single(u => u.GetProperty("id").GetString() == "colors");
        colors.GetProperty("lessons").GetArrayLength().ShouldBe(0);
        var pack = colors.GetProperty("pack");
        pack.GetProperty("version").GetInt32().ShouldBe(1);
        pack.GetProperty("manifest").GetString().ShouldBe("colors/v1/manifest.json");
        pack.GetProperty("lessonIds").EnumerateArray().Select(x => x.GetString()).ShouldBe(["color-red"]);
        colors.GetProperty("audio").GetProperty("title").GetString().ShouldBe("audio/little_learners/unit_colors/instr_title.mp3");

        // the pack: files at the same relative paths the lesson JSON uses, each with its checksum
        var dir = Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "v1");
        File.ReadAllText(Path.Combine(dir, "images/little_learners/color_red/heart.svg")).ShouldContain("heart");
        var manifestBytes = File.ReadAllBytes(Path.Combine(dir, "manifest.json"));
        Hex(manifestBytes).ShouldBe(pack.GetProperty("sha256").GetString());
        using var manifest = JsonDocument.Parse(manifestBytes);
        manifest.RootElement.GetProperty("lessons")[0].GetProperty("id").GetString().ShouldBe("color-red");
        foreach (var f in manifest.RootElement.GetProperty("files").EnumerateArray())
            Hex(File.ReadAllBytes(Path.Combine(dir, f.GetProperty("path").GetString()!))).ShouldBe(f.GetProperty("sha256").GetString());
        Directory.Exists(Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "_build")).ShouldBeFalse();

        // the index the API serves lists the same version
        using var index = JsonDocument.Parse(File.ReadAllText(Path.Combine(repo.Layout.PacksDir, "little_learners", "index.json")));
        var entry = index.RootElement.GetProperty("packs").EnumerateArray().Single();
        entry.GetProperty("unit").GetString().ShouldBe("colors");
        entry.GetProperty("sha256").GetString().ShouldBe(pack.GetProperty("sha256").GetString());
    }

    [Fact]
    public async Task An_unchanged_pack_keeps_its_version_and_a_changed_one_gets_the_next_version_next_to_the_old()
    {
        var (repo, lesson, units) = Setup();
        using var _ = repo;
        await Export(repo, lesson, units);
        var first = File.ReadAllText(Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "v1", "manifest.json"));

        await Export(repo, lesson, units);
        File.ReadAllText(Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "v1", "manifest.json")).ShouldBe(first);
        Directory.Exists(Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "v2")).ShouldBeFalse();

        repo.Touch(repo.Layout.SvgSource(lesson, "heart"), "<svg id=\"heart\" fill=\"red\"/>"); // a redrawn picture
        var result = await Export(repo, lesson, units);
        Directory.Exists(Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "v1")).ShouldBeTrue(); // older apps may still ask for it
        File.ReadAllText(Path.Combine(repo.Layout.PacksDir, "little_learners", "colors", "v2", "images/little_learners/color_red/heart.svg")).ShouldContain("fill");
        File.ReadAllText(result.JsonPath!).ShouldContain("colors/v2/manifest.json");
        File.ReadAllText(repo.Layout.PacksLock).ShouldContain("\"version\": 2");
    }

    [Fact]
    public void Delivery_must_be_bundled_or_pack()
    {
        using var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), UnitsYaml.Replace("delivery: pack", "delivery: cloud"));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadUnits(repo.Layout.CurriculumDir)).Message.ShouldContain("delivery must be bundled or pack");
    }
}
