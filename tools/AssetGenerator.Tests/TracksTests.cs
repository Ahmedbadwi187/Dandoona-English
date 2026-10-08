using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

/// <summary>A second track (Explorers) next to Little Learners: it borrows the Letters unit and never writes over the first
/// track's files.</summary>
public class TracksTests
{
    private const string LittleLearners = """
        track: little-learners
        units:
          - id: letters
            order: 1
            title: { en: "Letters", ar: "الحروف" }
            icon: letters
            color: red
            narration: { title: "Letters", welcome: "Let's learn letters!", celebration: "Done!" }
        """;

    private static readonly string Explorers = """
        track: explorers
        placement:
          - { level: 0, key: none, doneUnits: [], startUnit: letters }
          - { level: 2, key: all-letters, doneUnits: [letters], startUnit: sound-builders }
        units:
          - id: letters
            from: little-learners
            order: 1
          - id: sound-builders
            order: 2
            title: { en: "Sound Builders", ar: "تركيب الأصوات" }
            narration: { title: "Sound Builders", welcome: "Let's build words!", celebration: "Great!" }
        """.Replace("\r\n", "\n");

    private static TestRepo Repo()
    {
        var repo = new TestRepo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "little-learners.yaml"), LittleLearners);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "explorers.yaml"), Explorers);
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA.Replace("level: pre-a1", "level: pre-a1\nunit: letters"));
        return repo;
    }

    [Fact]
    public void A_borrowed_unit_takes_everything_from_its_track_but_keeps_its_own_order()
    {
        using var repo = Repo();
        var letters = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir).Single(u => u.Track == "explorers" && u.Id == "letters");
        letters.From.ShouldBe("little-learners");
        letters.ContentTrack.ShouldBe("little-learners");
        letters.Title["en"].ShouldBe("Letters");
        letters.Narration.Welcome.ShouldBe("Let's learn letters!");
        CurriculumReader.UnitAudioLesson(letters).Track.ShouldBe("little-learners"); // its name audio is the Little Learners one
    }

    [Fact]
    public void Borrowing_a_unit_that_does_not_exist_is_an_error()
    {
        using var repo = Repo();
        repo.Touch(Path.Combine(repo.Layout.CurriculumDir, "units", "explorers.yaml"), Explorers.Replace("id: letters\n    from: little-learners", "id: animals\n    from: little-learners"));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadUnits(repo.Layout.CurriculumDir)).Message.ShouldContain("has no unit 'animals'");
    }

    [Fact]
    public async Task The_second_tracks_export_lists_the_borrowed_lessons_with_the_same_paths_and_writes_nothing_of_the_first_track()
    {
        using var repo = Repo();
        var units = CurriculumReader.LoadUnits(repo.Layout.CurriculumDir);
        var lesson = CurriculumReader.LoadAll(repo.Layout.CurriculumDir).Single();
        foreach (var a in LessonPlan.Audio(lesson)) repo.Touch(repo.Layout.AudioGen(lesson, a.Role), "AUDIO");
        foreach (var i in LessonPlan.Images(lesson)) repo.Touch(repo.Layout.ImageApproved(lesson, i.Key), "IMG");
        foreach (var u in units.Where(u => u.Track == "little-learners"))
            foreach (var a in LessonPlan.Audio(CurriculumReader.UnitAudioLesson(u))) repo.Touch(repo.Layout.AudioGen(CurriculumReader.UnitAudioLesson(u), a.Role), "UNIT");
        repo.Touch(repo.Layout.MascotReference, "MASCOT");

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), new StringWriter())
            .RunAsync("explorers", [lesson], default, units: units, placement: CurriculumReader.LoadPlacement(repo.Layout.CurriculumDir), sharedArt: false);

        // nothing written into the app's assets except the new catalog
        Directory.EnumerateFiles(repo.Layout.AssetsDir, "*", SearchOption.AllDirectories).Select(f => Path.GetRelativePath(repo.Layout.AssetsDir, f).Replace('\\', '/'))
            .ShouldBe(["content/explorers.json"]);

        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var letters = doc.RootElement.GetProperty("units")[0];
        letters.GetProperty("id").GetString().ShouldBe("letters");
        letters.GetProperty("lessons")[0].GetProperty("id").GetString().ShouldBe("letter-a"); // the same lesson id: progress carries over
        letters.GetProperty("lessons")[0].GetProperty("audio").GetProperty("intro").GetString().ShouldBe("audio/little_learners/letter_a/intro.mp3");
        letters.GetProperty("audio").GetProperty("title").GetString().ShouldBe("audio/little_learners/unit_letters/instr_title.mp3");
        doc.RootElement.GetProperty("mascot").GetString().ShouldBe(Layout.ExportMascotRel); // pointed at, not copied
        doc.RootElement.GetProperty("placement")[1].GetProperty("startUnit").GetString().ShouldBe("sound-builders");
        doc.RootElement.GetProperty("units")[1].GetProperty("lessons").GetArrayLength().ShouldBe(0); // Soon
    }

    [Fact]
    public void The_real_explorers_track_starts_with_letters_and_sound_builders_and_places_children_as_approved()
    {
        var curriculum = Path.Combine(Layout.Find(null).Root, "content", "curriculum");
        var units = CurriculumReader.LoadUnits(curriculum).Where(u => u.Track == "explorers").ToList();
        units.Select(u => u.Id).Take(3).ShouldBe(["letters", "sound-builders", "digraphs"]);
        units[0].From.ShouldBe("little-learners");
        units[1].IsPack.ShouldBeFalse(); // Sound Builders is in the app
        var placement = CurriculumReader.LoadPlacement(curriculum).Where(p => p.Track == "explorers").ToDictionary(p => p.Key);
        placement["none"].StartUnit.ShouldBe("letters");
        placement["some-letters"].StartUnit.ShouldBe("letters");
        placement["all-letters"].StartUnit.ShouldBe("sound-builders");
        placement["reads-words"].StartUnit.ShouldBe("digraphs");
        placement["reads-words"].DoneUnits.ShouldBe(["letters", "sound-builders"]);
    }
}
