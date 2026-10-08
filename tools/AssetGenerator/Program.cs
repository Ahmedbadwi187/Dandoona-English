using System.CommandLine;
using AssetGenerator;
using AssetGenerator.Curriculum;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

// Dev-only tool. It is the only place that talks to ElevenLabs / OpenAI; nothing else may reference it.
LoadDotEnv();
var config = new ConfigurationBuilder()
    .AddEnvironmentVariables()
    .AddUserSecrets(typeof(Program).Assembly, optional: true)
    .Build();

var rootOpt = new Option<string?>("--root") { Description = "Repo root (default: found by walking up to content/curriculum).", Recursive = true };
var lessonOpt = new Option<string?>("--lesson") { Description = "Lesson id, e.g. letter-a." };
var trackOpt = new Option<string?>("--track") { Description = "Track code, e.g. little-learners." };
var dryRunOpt = new Option<bool>("--dry-run") { Description = "Show what would be generated and the estimated usage, without calling any API." };
var wordOpt = new Option<string?>("--word") { Description = "Word key, e.g. apple." };
var variantOpt = new Option<int>("--variant") { Description = "Variant number from _review (1, 2, 3)." };
var reasonOpt = new Option<string?>("--reason") { Description = "One-line reason for the pick (recorded in docs/asset-decisions.md)." };
var forceOpt = new Option<bool>("--force") { Description = "Regenerate even if output already exists." };

var audio = new Command("audio", "Generate missing/changed audio with ElevenLabs.") { lessonOpt, trackOpt, dryRunOpt, forceOpt };
var images = new Command("images", "Generate image variants into _review with OpenAI.") { lessonOpt, trackOpt, dryRunOpt, forceOpt };
var all = new Command("all", "Generate audio and images for a track.") { lessonOpt, trackOpt, dryRunOpt, forceOpt };
var approveOpt = new Option<int?>("--approve") { Description = "Lock concept N as the mascot reference image." };
var mascot = new Command("mascot", "Generate mascot concepts, or lock one with --approve N.") { dryRunOpt, forceOpt, approveOpt, reasonOpt };
var approve = new Command("approve", "Approve a reviewed image variant and record why.") { lessonOpt, wordOpt, variantOpt, reasonOpt };
var decisions = new Command("decisions", "Write docs/asset-decisions.md.");
var status = new Command("status", "Show missing/unapproved assets and phonemes without your own recording.") { lessonOpt, trackOpt };
var review = new Command("review", "Write content/generated/review.html: all candidate images with file names (no API calls).") { lessonOpt, trackOpt };
var cards = new Command("cards", "Write the printable parent cards (cards/<track>/*.html) from content/parent/tips.yaml.") { trackOpt };
var export = new Command("export", "Encode approved assets into the Flutter assets folder and write the lesson JSON.") { trackOpt, forceOpt };

audio.SetAction((pr, ct) => Guard(async () =>
{
    var (layout, lessons) = Load(pr);
    lessons = WithUnitAudio(layout, lessons, pr.GetValue(trackOpt));
    using var sp = Services(config);
    return await new AudioRunner(layout, ConfigLoader.Voices(layout), ConfigLoader.Generation(layout),
        sp.GetService<ElevenLabsClient>(), config["ELEVENLABS_VOICE_ID"], Console.Out)
        .RunAsync(lessons, pr.GetValue(dryRunOpt), pr.GetValue(forceOpt), ct);
}));

images.SetAction((pr, ct) => Guard(async () =>
{
    var (layout, lessons) = Load(pr);
    using var sp = Services(config);
    return await new ImageRunner(layout, ConfigLoader.Generation(layout), sp.GetService<OpenAiImageClient>(), Console.Out)
        .RunAsync(lessons, pr.GetValue(dryRunOpt), pr.GetValue(forceOpt), ct);
}));

all.SetAction((pr, ct) => Guard(async () =>
{
    var (layout, lessons) = Load(pr);
    lessons = WithUnitAudio(layout, lessons, pr.GetValue(trackOpt));
    using var sp = Services(config);
    var gen = ConfigLoader.Generation(layout);
    var a = await new AudioRunner(layout, ConfigLoader.Voices(layout), gen, sp.GetService<ElevenLabsClient>(), config["ELEVENLABS_VOICE_ID"], Console.Out)
        .RunAsync(lessons, pr.GetValue(dryRunOpt), pr.GetValue(forceOpt), ct);
    Console.WriteLine();
    var i = await new ImageRunner(layout, gen, sp.GetService<OpenAiImageClient>(), Console.Out)
        .RunAsync(lessons, pr.GetValue(dryRunOpt), pr.GetValue(forceOpt), ct);
    return a != 0 ? a : i;
}));

mascot.SetAction((pr, ct) => Guard(async () =>
{
    var layout = Layout.Find(pr.GetValue(rootOpt));
    using var sp = Services(config);
    return await new MascotRunner(layout, ConfigLoader.Generation(layout), sp.GetService<OpenAiImageClient>(), Console.Out)
        .RunAsync(pr.GetValue(dryRunOpt), pr.GetValue(forceOpt), pr.GetValue(approveOpt), pr.GetValue(reasonOpt), ct);
}));

status.SetAction((pr, ct) => Guard(() =>
{
    var (layout, lessons) = Load(pr);
    new StatusRunner(layout, ConfigLoader.Voices(layout), config["ELEVENLABS_VOICE_ID"], Console.Out).Run(lessons);
    return Task.FromResult(0);
}));

approve.SetAction((pr, ct) => Guard(() =>
{
    var layout = Layout.Find(pr.GetValue(rootOpt));
    var id = pr.GetValue(lessonOpt) ?? throw new CurriculumException("approve requires --lesson.");
    var word = pr.GetValue(wordOpt) ?? throw new CurriculumException("approve requires --word.");
    var reason = pr.GetValue(reasonOpt);
    if (string.IsNullOrWhiteSpace(reason)) throw new CurriculumException("approve requires --reason (one line, recorded in asset-decisions.md).");
    var lesson = CurriculumReader.Select(CurriculumReader.LoadAll(layout.CurriculumDir), id, null).Single();
    ApproveCommand.Run(layout, lesson, word, pr.GetValue(variantOpt), reason, Console.Out);
    return Task.FromResult(0);
}));

decisions.SetAction((pr, ct) => Guard(() =>
{
    var layout = Layout.Find(pr.GetValue(rootOpt));
    var lessons = CurriculumReader.LoadAll(layout.CurriculumDir);
    Console.WriteLine("Wrote " + DecisionsDoc.Write(layout, lessons));
    return Task.FromResult(0);
}));

cards.SetAction((pr, ct) => Guard(() =>
{
    var layout = Layout.Find(pr.GetValue(rootOpt));
    var files = ParentCards.Write(layout, pr.GetValue(trackOpt) ?? "little-learners");
    Console.WriteLine($"Wrote {files.Count} card page(s) to {ParentCards.OutputDir(layout, pr.GetValue(trackOpt) ?? "little-learners")}");
    return Task.FromResult(0);
}));

review.SetAction((pr, ct) => Guard(() =>
{
    var (layout, lessons) = Load(pr);
    Console.WriteLine("Wrote " + ReviewPage.Write(layout, lessons));
    return Task.FromResult(0);
}));

export.SetAction((pr, ct) => Guard(async () =>
{
    var layout = Layout.Find(pr.GetValue(rootOpt));
    var track = pr.GetValue(trackOpt) ?? throw new CurriculumException("export requires --track.");
    var units = CurriculumReader.LoadUnits(layout.CurriculumDir);
    // the track's own lessons, and the lessons of units it borrows from another track (Explorers' Letters)
    var borrowed = units.Where(u => u.Track == track && u.From.Length > 0).Select(u => (u.From, u.Id)).ToHashSet();
    var lessons = CurriculumReader.LoadAll(layout.CurriculumDir).Where(l => l.Track == track || borrowed.Contains((l.Track, l.Unit))).ToList();
    if (lessons.Count == 0) throw new CurriculumException($"No lessons for track '{track}'.");
    await new ExportRunner(layout, ConfigLoader.Generation(layout), MediaTools.Create(Console.Out), Console.Out)
        .RunAsync(track, lessons, ct, pr.GetValue(forceOpt), CurriculumReader.LoadUnits(layout.CurriculumDir), CurriculumReader.LoadPlacement(layout.CurriculumDir), CurriculumReader.LoadApp(layout.CurriculumDir).FirstOrDefault(u => u.Track == track),
            CurriculumReader.LoadReviews(layout.CurriculumDir).Where(r => r.Track == track).Select(r => r.Review).ToList(),
            sharedArt: track == "little-learners",
            phonemes: CurriculumReader.LoadPhonemes(layout.CurriculumDir).Where(p => p.Track == track).Select(p => p.Phoneme).ToList());
    return 0;
}));

var root = new RootCommand("Kids English AssetGenerator (dev-only: produces static .mp3/.webp files; never part of the app or API).")
{
    audio, images, all, mascot, approve, status, review, decisions, cards, export
};
root.Add(rootOpt);
return await root.Parse(args).InvokeAsync();

// With --track, the units' own audio lines (title, welcome, celebration) are generated together with the lessons.
IReadOnlyList<Lesson> WithUnitAudio(Layout layout, IReadOnlyList<Lesson> lessons, string? track) =>
    // a borrowed unit's lines belong to its own track (Explorers' Letters are the Little Learners files): never made again here
    track is null ? lessons : lessons.Concat(CurriculumReader.LoadUnits(layout.CurriculumDir).Where(u => u.Track == track && u.From.Length == 0).Concat(CurriculumReader.LoadApp(layout.CurriculumDir).Where(u => u.Track == track)).Select(CurriculumReader.UnitAudioLesson))
        // the track's phoneme clips (Explorers), when it has a table
        .Concat(CurriculumReader.LoadPhonemes(layout.CurriculumDir).Where(p => p.Track == track).Select(p => p.Phoneme).ToList() is { Count: > 0 } ph ? [CurriculumReader.PhonemesLesson(track, ph)] : []).ToList();

(Layout, IReadOnlyList<Lesson>) Load(ParseResult pr)
{
    var layout = Layout.Find(pr.GetValue(rootOpt));
    var lessonId = pr.GetValue(lessonOpt);
    var track = pr.GetValue(trackOpt);
    if (lessonId is null && track is null) throw new CurriculumException("Specify --lesson <id> or --track <track>.");
    return (layout, CurriculumReader.Select(CurriculumReader.LoadAll(layout.CurriculumDir), lessonId, track));
}

// API clients are only created when their key exists, so `--dry-run` and `status` work with no keys at all.
// Retries are limited (2) because a retried POST that already succeeded server-side would be billed twice.
ServiceProvider Services(IConfiguration cfg)
{
    var services = new ServiceCollection();
    if (cfg["ELEVENLABS_API_KEY"] is { Length: > 0 } eleven)
        services.AddHttpClient<ElevenLabsClient>(c =>
        {
            c.BaseAddress = new Uri("https://api.elevenlabs.io/");
            c.DefaultRequestHeaders.Add("xi-api-key", eleven);
        }).AddStandardResilienceHandler(Tune);
    if (cfg["OPENAI_API_KEY"] is { Length: > 0 } openai)
        services.AddHttpClient<OpenAiImageClient>(c =>
        {
            c.BaseAddress = new Uri("https://api.openai.com/");
            c.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", openai);
        }).AddStandardResilienceHandler(Tune);
    return services.BuildServiceProvider();
}

void Tune(Microsoft.Extensions.Http.Resilience.HttpStandardResilienceOptions o)
{
    o.Retry.MaxRetryAttempts = 2;
    o.AttemptTimeout.Timeout = TimeSpan.FromMinutes(3);
    o.TotalRequestTimeout.Timeout = TimeSpan.FromMinutes(8);
    o.CircuitBreaker.SamplingDuration = TimeSpan.FromMinutes(7);
}

async Task<int> Guard(Func<Task<int>> action)
{
    try { return await action(); }
    catch (Exception ex) when (ex is CurriculumException or ApiException)
    {
        Console.Error.WriteLine("Error: " + ex.Message);
        return 1;
    }
}

// Loads the git-ignored .env (searching upward) into environment variables. Existing variables win. Values are never printed.
static void LoadDotEnv()
{
    for (var dir = new DirectoryInfo(Directory.GetCurrentDirectory()); dir is not null; dir = dir.Parent)
    {
        var file = Path.Combine(dir.FullName, ".env");
        if (!File.Exists(file)) continue;
        foreach (var raw in File.ReadAllLines(file))
        {
            var line = raw.Trim();
            if (line.Length == 0 || line[0] == '#') continue;
            var eq = line.IndexOf('=');
            if (eq <= 0) continue;
            var key = line[..eq].Trim();
            var value = line[(eq + 1)..].Trim().Trim('"', '\'');
            if (value.Length > 0 && Environment.GetEnvironmentVariable(key) is null) Environment.SetEnvironmentVariable(key, value);
        }
        return;
    }
}
