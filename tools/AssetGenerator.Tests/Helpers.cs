using AssetGenerator.Curriculum;

namespace AssetGenerator.Tests;

public sealed class TestRepo : IDisposable
{
    public string Root { get; } = Directory.CreateTempSubdirectory("assetgen").FullName;
    public Layout Layout => new(Root);
    public void Dispose() => Directory.Delete(Root, true);

    public const string LetterA = """
        id: letter-a
        track: little-learners
        level: pre-a1
        letter: A
        phoneme: "/æ/"
        words:
          - { word: apple, imagePrompt: "a shiny red apple" }
          - { word: ant, imagePrompt: "a small friendly ant", mascot: true }
        narration:
          intro: "This is the letter A."
          praise: ["Great job!", "Well done!"]
        activities: [trace, listen-and-tap, record-and-listen, match-picture]
        """;

    public Lesson WriteLessonA(string yaml = LetterA)
    {
        Directory.CreateDirectory(Layout.CurriculumDir);
        File.WriteAllText(Path.Combine(Layout.CurriculumDir, "letter-a.yaml"), yaml);
        return CurriculumReader.LoadAll(Layout.CurriculumDir).Single();
    }

    public void WriteStyleFiles()
    {
        Directory.CreateDirectory(Layout.StyleDir);
        File.WriteAllText(Layout.ArtStyleMd, "STYLE");
        File.WriteAllText(Layout.MascotMd, "MASCOT");
    }

    public void Touch(string path, string content = "x")
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
    }
}

public class FakeVoice : IVoiceClient
{
    public List<string> Texts { get; } = [];
    public Task<byte[]> SynthesizeAsync(string text, VoiceSettings voice, string model, string outputFormat, CancellationToken ct)
    {
        Texts.Add(text);
        return Task.FromResult(new byte[] { 1, 2, 3 });
    }
}

public class FakeImages : IImageClient
{
    public List<string> Generated { get; } = [];
    public List<string> Edited { get; } = [];
    public Task<ImageBatch> GenerateAsync(string prompt, int count, ImageSettings s, CancellationToken ct)
    {
        Generated.Add(prompt);
        return Task.FromResult(new ImageBatch(Enumerable.Range(0, count).Select(i => new byte[] { (byte)i }).ToList(), new ImageUsage(100, 0, 1000)));
    }
    public Task<ImageBatch> EditAsync(string prompt, byte[] reference, int count, ImageSettings s, CancellationToken ct)
    {
        Edited.Add(prompt);
        return Task.FromResult(new ImageBatch(Enumerable.Range(0, count).Select(i => new byte[] { (byte)i }).ToList(), new ImageUsage(100, 0, 1000)));
    }
}

public class FakeMedia : IMediaTool
{
    public int Encoded { get; private set; }
    public Task EncodeAudioAsync(string input, string output, ExportSettings s, CancellationToken ct) => Copy(input, output);
    public Task EncodeImageAsync(string input, string output, ExportSettings s, CancellationToken ct) => Copy(input, output);
    private Task Copy(string input, string output)
    {
        Encoded++;
        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        File.Copy(input, output, overwrite: true);
        return Task.CompletedTask;
    }
}
