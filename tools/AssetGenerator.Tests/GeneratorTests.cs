using System.Text.Json;
using AssetGenerator.Curriculum;
using Shouldly;

namespace AssetGenerator.Tests;

public class CurriculumTests
{
    [Fact]
    public void Repo_curriculum_files_are_valid()
    {
        var layout = Layout.FindFrom(AppContext.BaseDirectory);
        var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Track == "little-learners").ToList(); // Little Learners rules (Explorers has its own tests)
        lessons.Count(l => l.Unit == "letters").ShouldBe(26);
        lessons.Count(l => l.Unit == "colors").ShouldBe(10);
        lessons.First().Id.ShouldBe("letter-a");
        lessons.ShouldAllBe(l => l.Activities.Contains("record-and-listen") && !l.Activities.Contains("say-it"));
        lessons.Where(l => l.Unit == "colors").ShouldAllBe(l => l.Activities.Contains("color-the-object") && l.Narration.Instructions.ContainsKey("color-the-object"));
    }

    [Fact]
    public void Rejects_unknown_activity_bad_id_duplicates_and_typos()
    {
        using var repo = new TestRepo();
        Directory.CreateDirectory(repo.Layout.CurriculumDir);
        File.WriteAllText(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA.Replace("match-picture", "say-it"));
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain("say-it");

        File.WriteAllText(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA + "\nimagePrmpt: oops");
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir));

        File.WriteAllText(Path.Combine(repo.Layout.CurriculumDir, "letter-a.yaml"), TestRepo.LetterA);
        File.WriteAllText(Path.Combine(repo.Layout.CurriculumDir, "copy.yaml"), TestRepo.LetterA);
        Should.Throw<CurriculumException>(() => CurriculumReader.LoadAll(repo.Layout.CurriculumDir)).Message.ShouldContain("Duplicate lesson id");
    }

    [Fact]
    public void Lesson_plan_lists_expected_audio_and_images()
    {
        using var repo = new TestRepo();
        var l = repo.WriteLessonA();
        LessonPlan.Audio(l).Select(a => a.Role).ShouldBe(["intro", "phoneme", "praise-0", "praise-1", "word-apple", "word-ant"]);
        LessonPlan.Audio(l).Single(a => a.IsPhoneme).Role.ShouldBe("phoneme");
        LessonPlan.Images(l).Select(i => (i.Key, i.UsesMascot)).ShouldBe([("apple", false), ("ant", true)]);
    }

    [Fact]
    public void Audio_hash_changes_with_text_voice_settings_and_model()
    {
        var v = new VoiceSettings { VoiceId = "v1" };
        var h = Hashing.AudioHash("hi", v, "m", "f");
        Hashing.AudioHash("hi", v, "m", "f").ShouldBe(h);
        Hashing.AudioHash("hello", v, "m", "f").ShouldNotBe(h);
        Hashing.AudioHash("hi", v, "m2", "f").ShouldNotBe(h);
        Hashing.AudioHash("hi", new VoiceSettings { VoiceId = "v2" }, "m", "f").ShouldNotBe(h);
        Hashing.AudioHash("hi", new VoiceSettings { VoiceId = "v1", Speed = 0.8 }, "m", "f").ShouldNotBe(h);
    }
}

public class AudioRunnerTests
{
    private static VoiceConfig Voices() => new() { Voices = { ["narrator"] = new VoiceSettings { VoiceId = "voice-1" } } };
    private static AudioRunner Runner(TestRepo r, FakeVoice? v, StringWriter w) =>
        new(r.Layout, Voices(), new GenerationConfig(), v, null, w);

    [Fact]
    public async Task Dry_run_calls_nothing_and_reports_character_count()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        var voice = new FakeVoice(); var w = new StringWriter();
        await Runner(repo, voice, w).RunAsync([lesson], dryRun: true, force: false, default);
        voice.Texts.ShouldBeEmpty();
        w.ToString().ShouldContain("6 to generate");
        w.ToString().ShouldContain("dry run");
    }

    [Fact]
    public async Task Generates_once_then_skips_unchanged_lines()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        var voice = new FakeVoice();
        await Runner(repo, voice, new StringWriter()).RunAsync([lesson], false, false, default);
        voice.Texts.Count.ShouldBe(6);
        File.Exists(repo.Layout.AudioGen(lesson, "word-apple")).ShouldBeTrue();

        await Runner(repo, voice, new StringWriter()).RunAsync([lesson], false, false, default);
        voice.Texts.Count.ShouldBe(6); // nothing billed twice
    }

    [Fact]
    public async Task Changed_text_regenerates_only_that_line()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        var voice = new FakeVoice();
        await Runner(repo, voice, new StringWriter()).RunAsync([lesson], false, false, default);

        var edited = repo.WriteLessonA(TestRepo.LetterA.Replace("This is the letter A.", "A is for apple."));
        await Runner(repo, voice, new StringWriter()).RunAsync([edited], false, false, default);
        voice.Texts.Count.ShouldBe(7);
        voice.Texts.Last().ShouldBe("A is for apple.");
    }

    [Fact]
    public async Task Override_recording_is_never_regenerated_even_with_force()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        repo.Touch(repo.Layout.AudioOverride(lesson, "phoneme"));
        var voice = new FakeVoice();
        await Runner(repo, voice, new StringWriter()).RunAsync([lesson], false, force: true, default);
        voice.Texts.ShouldNotContain("/æ/");
        voice.Texts.Count.ShouldBe(5);
    }

    [Fact]
    public async Task Existing_file_without_manifest_is_adopted_not_billed()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        repo.Touch(repo.Layout.AudioGen(lesson, "intro"));
        var voice = new FakeVoice();
        await Runner(repo, voice, new StringWriter()).RunAsync([lesson], false, false, default);
        voice.Texts.ShouldNotContain("This is the letter A.");
    }

    [Fact]
    public async Task Missing_key_is_a_clear_error_not_a_crash()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        await Should.ThrowAsync<ApiException>(() => Runner(repo, null, new StringWriter()).RunAsync([lesson], false, false, default));
    }

    [Fact]
    public void Missing_voice_id_is_a_clear_error()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        var runner = new AudioRunner(repo.Layout, new VoiceConfig(), new GenerationConfig(), null, null, new StringWriter());
        Should.Throw<CurriculumException>(() => runner.Plan([lesson], false)).Message.ShouldContain("voice id");
    }
}

public class ImageAndMascotTests
{
    [Fact]
    public async Task Generates_variants_into_review_and_skips_pending_or_approved()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace(", mascot: true", ""));
        repo.WriteStyleFiles();
        var client = new FakeImages();
        var runner = new ImageRunner(repo.Layout, new GenerationConfig(), client, new StringWriter());

        await runner.RunAsync([lesson], false, false, default);
        client.Generated.Count.ShouldBe(2);
        client.Generated[0].ShouldStartWith("STYLE"); // art style prefix on every prompt
        repo.Layout.ImageReviewFiles(lesson, "apple").Count.ShouldBe(3);

        await runner.RunAsync([lesson], false, false, default);
        client.Generated.Count.ShouldBe(2); // awaiting your pick: not regenerated

        File.Move(repo.Layout.ImageReview(lesson, "apple", 2), repo.Layout.ImageApproved(lesson, "apple"));
        runner.Plan([lesson], false).Single(j => j.Item.Key == "apple").State.ShouldBe(ImageState.Approved);
    }

    [Fact]
    public async Task Mascot_scenes_are_blocked_until_a_reference_is_locked_then_use_the_reference()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        repo.WriteStyleFiles();
        var client = new FakeImages(); var w = new StringWriter();
        var runner = new ImageRunner(repo.Layout, new GenerationConfig(), client, w);

        (await runner.RunAsync([lesson], false, false, default)).ShouldBe(1);
        w.ToString().ShouldContain("BLOCKED");
        client.Generated.ShouldBeEmpty();

        repo.Touch(repo.Layout.MascotReference);
        await runner.RunAsync([lesson], false, false, default);
        client.Edited.Count.ShouldBe(1);   // the mascot scene
        client.Generated.Count.ShouldBe(1); // the plain scene
    }

    [Fact]
    public async Task Mascot_concepts_then_approve_locks_the_reference()
    {
        using var repo = new TestRepo(); repo.WriteStyleFiles();
        var client = new FakeImages();
        var runner = new MascotRunner(repo.Layout, new GenerationConfig(), client, new StringWriter());

        await runner.RunAsync(false, false, null, null, default);
        Directory.GetFiles(repo.Layout.MascotReviewDir).Length.ShouldBe(4);
        File.Exists(repo.Layout.MascotReference).ShouldBeFalse();

        await runner.RunAsync(false, false, approve: 3, reason: "friendly", default);
        File.Exists(repo.Layout.MascotReference).ShouldBeTrue();

        client.Generated.Count.ShouldBe(1);
        await runner.RunAsync(false, false, null, null, default); // locked: no new spend without --force
        client.Generated.Count.ShouldBe(1);
    }
}

public class StatusAndExportTests
{
    [Fact]
    public void Status_lists_every_phoneme_without_an_override()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        var status = new StatusRunner(repo.Layout, new VoiceConfig { Voices = { ["narrator"] = new() { VoiceId = "v" } } }, null, new StringWriter());
        status.Build([lesson]).PhonemesWithoutOverride.ShouldHaveSingleItem().ShouldContain("letter-a");

        repo.Touch(repo.Layout.AudioOverride(lesson, "phoneme"));
        var report = status.Build([lesson]);
        report.PhonemesWithoutOverride.ShouldBeEmpty();
        report.Lines.Single(l => l.Item == "audio/phoneme").State.ShouldBe("override");
    }

    private static void MakeComplete(TestRepo repo, Lesson l)
    {
        foreach (var a in LessonPlan.Audio(l)) repo.Touch(repo.Layout.AudioGen(l, a.Role), a.Role);
        foreach (var i in LessonPlan.Images(l)) repo.Touch(repo.Layout.ImageApproved(l, i.Key), i.Key);
    }

    [Fact]
    public async Task Export_skips_incomplete_lessons_and_reports_what_is_missing()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        repo.Touch(repo.Layout.AudioGen(lesson, "intro"));
        var w = new StringWriter();
        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), new FakeMedia(), w).RunAsync("little-learners", [lesson], default);
        result.Exported.ShouldBe(0);
        result.Incomplete.Single().ShouldContain("image/apple (not approved)");
        result.JsonPath.ShouldBeNull();
    }

    [Fact]
    public async Task Export_writes_json_with_stable_paths_and_prefers_override()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        MakeComplete(repo, lesson);
        repo.Touch(repo.Layout.AudioOverride(lesson, "phoneme"), "MY-RECORDING");
        var media = new FakeMedia();
        var when = new DateTime(2026, 1, 2, 3, 4, 5, DateTimeKind.Utc);

        var result = await new ExportRunner(repo.Layout, new GenerationConfig(), media, new StringWriter(), () => when)
            .RunAsync("little-learners", [lesson], default);

        result.Exported.ShouldBe(1);
        File.ReadAllText(Path.Combine(repo.Layout.AssetsDir, "audio/little_learners/letter_a/phoneme.mp3")).ShouldBe("MY-RECORDING");

        using var doc = JsonDocument.Parse(File.ReadAllText(result.JsonPath!));
        var root = doc.RootElement;
        root.GetProperty("schemaVersion").GetInt32().ShouldBe(2);
        root.GetProperty("track").GetString().ShouldBe("little-learners");
        var l = root.GetProperty("units")[0].GetProperty("lessons")[0];
        l.GetProperty("id").GetString().ShouldBe("letter-a");
        l.GetProperty("letter").GetString().ShouldBe("A");
        l.GetProperty("audio").GetProperty("intro").GetString().ShouldBe("audio/little_learners/letter_a/intro.mp3");
        l.GetProperty("audio").GetProperty("praise").GetArrayLength().ShouldBe(2);
        l.GetProperty("words")[0].GetProperty("image").GetString().ShouldBe("images/little_learners/letter_a/apple.webp");
        l.GetProperty("activities").EnumerateArray().Select(x => x.GetString()).ShouldContain("record-and-listen");
        root.TryGetProperty("mascot", out _).ShouldBeFalse(); // no mascot locked yet
    }

    [Fact]
    public async Task Export_is_incremental()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        MakeComplete(repo, lesson);
        var media = new FakeMedia();
        var runner = new ExportRunner(repo.Layout, new GenerationConfig(), media, new StringWriter());
        await runner.RunAsync("little-learners", [lesson], default);
        var first = media.Encoded;
        await runner.RunAsync("little-learners", [lesson], default);
        media.Encoded.ShouldBe(first); // unchanged sources are not re-encoded
    }
}

public class PubspecUpdaterTests
{
    private static readonly string[] Entries = ["assets/audio/", "assets/images/", "assets/content/"];

    [Fact]
    public void Adds_assets_section_and_is_idempotent()
    {
        var src = "name: app\nflutter:\n  uses-material-design: true\n";
        var (text, changed) = PubspecUpdater.EnsureAssets(src, Entries);
        changed.ShouldBeTrue();
        text.ShouldContain("  assets:\n    - assets/audio/\n    - assets/images/\n    - assets/content/");
        text.ShouldContain("uses-material-design: true");
        PubspecUpdater.EnsureAssets(text, Entries).Changed.ShouldBeFalse();
    }

    [Fact]
    public void Appends_only_missing_entries_to_an_existing_list()
    {
        var src = "flutter:\n  assets:\n    - assets/images/\n    - assets/fonts/\n  fonts: []\n";
        var (text, changed) = PubspecUpdater.EnsureAssets(src, Entries);
        changed.ShouldBeTrue();
        text.Split('\n').Count(l => l.Contains("assets/images/")).ShouldBe(1);
        text.ShouldContain("assets/audio/");
        text.ShouldContain("  fonts: []");
    }

    [Fact]
    public void Creates_flutter_section_when_absent_and_keeps_crlf()
    {
        var (text, changed) = PubspecUpdater.EnsureAssets("name: app\r\n", Entries);
        changed.ShouldBeTrue();
        text.ShouldContain("flutter:\r\n  assets:");
    }
}

public class ReviewPageTests
{
    [Fact]
    public void Shows_every_variant_with_its_file_name_and_marks_approved()
    {
        using var repo = new TestRepo(); var lesson = repo.WriteLessonA();
        foreach (var n in new[] { 1, 2, 3 }) repo.Touch(repo.Layout.ImageReview(lesson, "apple", n));
        repo.Touch(repo.Layout.ImageApproved(lesson, "ant"));
        repo.Touch(repo.Layout.MascotReview(1));

        var html = ReviewPage.Build(repo.Layout, [lesson]);

        foreach (var name in new[] { "apple.v1.webp", "apple.v2.webp", "apple.v3.webp", "ant.approved.webp", "mascot.v1.webp" })
            html.ShouldContain(name);
        html.ShouldContain("src=\"little-learners/letter-a/images/_review/apple.v2.webp\"");
        html.ShouldContain("src=\"mascot/_review/mascot.v1.webp\"");
        html.ShouldContain("class=\"approved\"");
    }

    [Fact]
    public void Escapes_prompt_text_and_notes_words_without_images()
    {
        using var repo = new TestRepo();
        var lesson = repo.WriteLessonA(TestRepo.LetterA.Replace("a shiny red apple", "a <b>bold</b> apple"));
        var html = ReviewPage.Build(repo.Layout, [lesson]);
        html.ShouldContain("a &lt;b&gt;bold&lt;/b&gt; apple");
        html.ShouldNotContain("<b>bold</b>");
        html.ShouldContain("No images yet");
    }
}
