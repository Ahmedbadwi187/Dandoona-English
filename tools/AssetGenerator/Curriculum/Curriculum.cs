using FluentValidation;
using YamlDotNet.Core;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace AssetGenerator.Curriculum;

/// <summary>One lesson as authored in /content/curriculum/*.yaml (source of truth).</summary>
public class Lesson
{
    public string Id { get; set; } = "";
    public string Track { get; set; } = "";
    public string Level { get; set; } = "";
    /// <summary>The unit this lesson belongs to (an id from content/curriculum/units/*.yaml).</summary>
    public string Unit { get; set; } = "";
    /// <summary>Colors unit only: the color the lesson teaches.</summary>
    public LessonColor? Color { get; set; }
    /// <summary>Numbers unit: each word is a number and its picture shows that many things; the activities then pick wrong pictures from the unit's other counts.</summary>
    public bool Counting { get; set; }
    /// <summary>The wrong pictures of the listen-and-tap game come only from this lesson's own words (objects that must not be mixed with the unit's plain pictures, like "Shapes around us").</summary>
    public bool OwnWordsOnly { get; set; }
    /// <summary>Sorting game: the bins (key + icon name the app knows); words with a `group` equal to a bin key belong in it. Words of the whole unit are used.</summary>
    public List<BinDef> Bins { get; set; } = [];
    /// <summary>Odd one out: words of the Letters unit (bundled pictures) that do not belong to this unit's theme.</summary>
    public List<string> Odd { get; set; } = [];
    /// <summary>True for the synthetic lesson that carries a unit's own audio (title, welcome, celebration). Never read from YAML files.</summary>
    public bool IsUnit { get; set; }
    public int? Order { get; set; }
    public string? Letter { get; set; }
    public string? Phoneme { get; set; }
    public List<LessonWord> Words { get; set; } = [];
    public Narration Narration { get; set; } = new();
    public List<string> Activities { get; set; } = [];

    public int ResolvedOrder => Order ?? (Letter is { Length: 1 } l ? l[0] - 'A' + 1 : int.MaxValue);
}

public class LessonColor
{
    public string Name { get; set; } = "";
    /// <summary>#RRGGBB, must be a color from palette.json.</summary>
    public string Hex { get; set; } = "";
}

public class BinDef
{
    public string Key { get; set; } = "";
    public string Icon { get; set; } = "";
}

public class LessonWord
{
    /// <summary>Sorting game: the key of the bin this word belongs in.</summary>
    public string? Group { get; set; }
    /// <summary>Memory game: the word it is paired with instead of itself (big and small).</summary>
    public string? Opposite { get; set; }
    public string Word { get; set; } = "";
    /// <summary>"lesson-id/key": use the picture of a word in another lesson (copied at export) instead of drawing or generating one.</summary>
    public string? Reuse { get; set; }
    public string ImagePrompt { get; set; } = "";
    /// <summary>True when the scene includes the mascot, so the locked reference image is used.</summary>
    public bool Mascot { get; set; }
    /// <summary>"openai" (generated illustration) or "svg" (self-drawn, content/art/{track}/{lesson}/{key}.svg).</summary>
    public string Source { get; set; } = "openai";
    /// <summary>Animals: what the animal says ("Meow! Meow!"), spoken for the animal-sounds activity.</summary>
    public string? Sound { get; set; }
    /// <summary>Animals: where it lives, one of Homes (house, farm, water, wild); needs `lives` too.</summary>
    public string? Home { get; set; }
    /// <summary>Animals: the sentence said when the animal is put in its home ("A cow lives on the farm.").</summary>
    public string? Lives { get; set; }
    /// <summary>Actions: what Dandoona says for the "Dandoona says" activity ("Dandoona says, jump!").</summary>
    public string? Says { get; set; }
}

public class Narration
{
    public string Intro { get; set; } = "";
    public List<string> Praise { get; set; } = [];
    /// <summary>Spoken instructions, keyed by activity name (shown to the child when the activity starts), plus an optional "hint".</summary>
    public Dictionary<string, string> Instructions { get; set; } = [];
    /// <summary>Colors unit: how the lesson says the color on its own ("red").</summary>
    public string? ColorName { get; set; }
    /// <summary>Spoken phrase per word ("A red apple."), used by record-and-listen in the Colors unit.</summary>
    public Dictionary<string, string> Phrases { get; set; } = [];
}

public class CurriculumException(string message) : Exception(message);

/// <summary>One unit of a track, from content/curriculum/units/&lt;track&gt;.yaml (units are listed in the order they open).</summary>
public class UnitDef
{
    public string Id { get; set; } = "";
    public string Track { get; set; } = "";
    public int Order { get; set; }
    public Dictionary<string, string> Title { get; set; } = [];
    /// <summary>Picture key the app maps to an icon (unknown keys fall back to a star).</summary>
    public string Icon { get; set; } = "";
    /// <summary>Palette color name for the unit tile.</summary>
    public string Color { get; set; } = "";
    /// <summary>"bundled" (inside the app, works offline from the first launch; the default) or "pack" (a downloadable
    /// content pack served by our API). The unit's own lines (its name, welcome, celebration) are always bundled.</summary>
    public string Delivery { get; set; } = "";
    public UnitNarration Narration { get; set; } = new();
    /// <summary>The treasure chest after this unit: an outfit for Dandoona and stickers of this unit's words. Fixed, never random.</summary>
    public UnitChest? Chest { get; set; }
    /// <summary>The picture story after this unit: a few pages, each a sentence Dandoona reads and some of the unit's own pictures.</summary>
    public StoryDef? Story { get; set; }

    /// <summary>Another track whose unit with the same id is used here unchanged (title, lines, chest, lessons and their
    /// files): Explorers starts with the Little Learners Letters unit. Empty for a unit of its own.</summary>
    public string From { get; set; } = "";

    public bool IsPack => Delivery == "pack";

    /// <summary>The track whose lessons and files this unit uses.</summary>
    public string ContentTrack => From.Length > 0 ? From : Track;
}

/// <summary>A unit's story: pages in order.</summary>
public class StoryDef
{
    public List<StoryPage> Pages { get; set; } = [];
}

/// <summary>One page: the sentence (spoken), the unit's words whose pictures are shown, and Dandoona's pose (optional).</summary>
public class StoryPage
{
    public string Text { get; set; } = "";
    public List<string> Words { get; set; } = [];
    public string? Pose { get; set; }
}

/// <summary>What a chest holds: the accessory id (an SVG in content/art/accessories) and 3-4 words of its unit that become stickers.</summary>
public class UnitChest
{
    public string Accessory { get; set; } = "";
    public List<string> Stickers { get; set; } = [];
}

public class UnitNarration
{
    public string Title { get; set; } = "";
    public string Welcome { get; set; } = "";
    public string Celebration { get; set; } = "";
    /// <summary>Extra short lines, keyed kebab-case: a unit's "locked" ("Finish Letters first!"); the app's "coming-soon",
    /// "puzzle-first", "almost-ready". Optional: a line without audio yet is simply left out of the export.</summary>
    public Dictionary<string, string> Lines { get; set; } = [];
}

/// <summary>A review stop on the map: a quick game with the words of [Units]; it sits after the last of them and must be
/// passed before the next unit opens.</summary>
public class ReviewDef
{
    public string Id { get; set; } = "";
    public List<string> Units { get; set; } = [];
}

public class UnitsFile
{
    public string Track { get; set; } = "";
    public List<UnitDef> Units { get; set; } = [];
    /// <summary>What each answer to "how much English does your child know?" means for the starting point.</summary>
    public List<PlacementDef> Placement { get; set; } = [];
    /// <summary>Dandoona's own lines outside any unit: Title = "Who is playing?", Welcome = the first greeting, Celebration = "Welcome back!".</summary>
    public UnitNarration? App { get; set; }
    /// <summary>Review stops on the map, in path order.</summary>
    public List<ReviewDef> Reviews { get; set; } = [];
}

/// <summary>One answer of the placement question: the units that count as done by placement, and where the child starts.</summary>
public class PlacementDef
{
    public int Level { get; set; }
    /// <summary>A short stable name (none, some-letters, all-letters, reads-words).</summary>
    public string Key { get; set; } = "";
    public List<string> DoneUnits { get; set; } = [];
    public string StartUnit { get; set; } = "";
    public string Track { get; set; } = "";
}

public class LessonValidator : AbstractValidator<Lesson>
{
    public static readonly string[] ActivityNames = ["trace", "listen-and-tap", "record-and-listen", "match-picture", "color-the-object", "trace-small", "animal-sounds", "habitat", "dandoona-says", "sort", "memory", "odd-one-out", "sentence", "count-along", "mix-colors", "build-picture", "turns", "story-feeling"];
    public static readonly string[] Homes = ["house", "farm", "water", "wild"];
    private static readonly string[] Levels = ["pre-a1", "a1", "a2"];
    private static readonly string[] Tracks = ["little-learners", "explorers", "champions"];

    public LessonValidator()
    {
        RuleFor(x => x.Id).NotEmpty().MaximumLength(100).Matches("^[a-z0-9]+(-[a-z0-9]+)*$")
            .WithMessage("'Id' must be lowercase kebab-case.");
        RuleFor(x => x.Track).Must(t => Tracks.Contains(t)).WithMessage("'Track' must be one of: " + string.Join(", ", Tracks));
        RuleFor(x => x.Level).Must(l => Levels.Contains(l)).WithMessage("'Level' must be one of: " + string.Join(", ", Levels));
        RuleFor(x => x.Unit).Matches("^[a-z0-9]+(-[a-z0-9]+)*$").When(x => x.Unit.Length > 0).WithMessage("'Unit' must be lowercase kebab-case.");
        RuleFor(x => x.Color!.Hex).Matches("^#[0-9A-Fa-f]{6}$").When(x => x.Color is not null).WithMessage("'Color.Hex' must look like #RRGGBB.");
        RuleFor(x => x.Color!.Name).NotEmpty().MaximumLength(20).When(x => x.Color is not null);
        RuleFor(x => x.Order).GreaterThan(0).When(x => x.Order.HasValue);
        RuleFor(x => x.Letter).Matches("^[A-Z]$").When(x => x.Letter is not null).WithMessage("'Letter' must be a single uppercase A-Z.");
        RuleFor(x => x.Phoneme).NotEmpty().MaximumLength(20).When(x => x.Phoneme is not null);

        RuleFor(x => x.Words).NotEmpty();
        RuleForEach(x => x.Words).ChildRules(w =>
        {
            w.RuleFor(i => i.Word).NotEmpty().MaximumLength(30).Matches("^[A-Za-z' -]+$");
            w.RuleFor(i => i.ImagePrompt).NotEmpty().MaximumLength(500).When(i => i.Reuse is null);
            w.RuleFor(i => i.Reuse).Matches("^[a-z0-9]+(-[a-z0-9]+)*/[a-z0-9-]+$").When(i => i.Reuse is not null).WithMessage("'Reuse' must look like lesson-id/word-key.");
            w.RuleFor(i => i.Source).Must(s => s is "openai" or "svg").WithMessage("Word source must be openai or svg.");
            w.RuleFor(i => i.Says).MaximumLength(60).Must(s => !string.IsNullOrWhiteSpace(s)).When(i => i.Says is not null);
            w.RuleFor(i => i.Sound).MaximumLength(40).Must(s => !string.IsNullOrWhiteSpace(s)).When(i => i.Sound is not null);
            w.RuleFor(i => i.Home).Must(h => Homes.Contains(h!)).When(i => i.Home is not null).WithMessage("Word home must be one of: " + string.Join(", ", Homes));
            w.RuleFor(i => i.Lives).NotEmpty().MaximumLength(80).When(i => i.Home is not null).WithMessage("A word with a home needs a `lives` sentence.");
        });
        RuleFor(x => x.Words)
            .Must(ws => ws.Select(w => w.Word.Trim().ToLowerInvariant()).Distinct().Count() == ws.Count)
            .WithMessage("Duplicate words in lesson.");

        RuleFor(x => x.Narration.Intro).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Narration.Praise).NotEmpty();
        RuleForEach(x => x.Narration.Praise).NotEmpty().MaximumLength(100);
        RuleFor(x => x.Narration.ColorName).MaximumLength(30);
        RuleFor(x => x).Must(l => l.Narration.Phrases.Keys.All(k => l.Words.Any(w => w.Word.Trim().Equals(k, StringComparison.OrdinalIgnoreCase))))
            .WithMessage("Every key of narration.phrases must be one of the lesson's words.");
        RuleForEach(x => x.Narration.Instructions).Must(kv => (ActivityNames.Contains(kv.Key) || kv.Key is "hint" or "capital" or "small") && !string.IsNullOrWhiteSpace(kv.Value) && kv.Value.Length <= 100)
            .WithMessage("Instructions must be keyed by an activity name or 'hint' and be 1-100 characters.");

        RuleFor(x => x.Activities).NotEmpty();
        RuleForEach(x => x.Activities).Must(a => ActivityNames.Contains(a))
            .WithMessage("Unknown activity '{PropertyValue}'. Use: " + string.Join(", ", ActivityNames));
        RuleFor(x => x).Must(l => !l.Activities.Contains("habitat") || l.Words.All(w => w.Home is not null)).WithMessage("Every word of a habitat lesson needs a home.");
        RuleForEach(x => x.Bins).ChildRules(b => { b.RuleFor(i => i.Key).NotEmpty().MaximumLength(20); b.RuleFor(i => i.Icon).NotEmpty().MaximumLength(30); });
        RuleFor(x => x).Must(l => !l.Activities.Contains("sort") || (l.Bins.Count >= 2 && l.Words.Any(w => l.Bins.Any(b => b.Key == w.Group)))).WithMessage("A sort lesson needs at least two bins and words with a group.");
        RuleFor(x => x).Must(l => l.Words.All(w => w.Group is null || l.Bins.Any(b => b.Key == w.Group)) || l.Bins.Count == 0).WithMessage("A word group must be one of the lesson bins.");
        RuleFor(x => x).Must(l => !l.Activities.Contains("odd-one-out") || l.Odd.Count >= 3).WithMessage("An odd-one-out lesson needs at least three odd words.");
        RuleFor(x => x).Must(l => !l.Activities.Contains("dandoona-says") || l.Words.All(w => w.Says is not null)).WithMessage("Every word of a Dandoona-says lesson needs a `says` line.");
        RuleFor(x => x).Must(l => !l.Activities.Contains("animal-sounds") || l.Words.Count(w => w.Sound is not null) >= 2).WithMessage("An animal-sounds lesson needs at least two words with a sound.");
        RuleFor(x => x.Activities).Must(a => a.Distinct().Count() == a.Count).WithMessage("Duplicate activities in lesson.");
    }
}

public static class CurriculumReader
{
    // Strict: unknown keys (typos like "imagePrmpt") fail loudly instead of silently dropping content.
    private static readonly IDeserializer Deserializer = new DeserializerBuilder()
        .WithNamingConvention(CamelCaseNamingConvention.Instance)
        .Build();

    /// <summary>Reads and validates every *.yaml/*.yml in the directory, ordered by track then lesson order.</summary>
    public static IReadOnlyList<Lesson> LoadAll(string directory)
    {
        if (!Directory.Exists(directory)) throw new CurriculumException($"Curriculum directory not found: {directory}");

        var validator = new LessonValidator();
        var errors = new List<string>();
        var lessons = new List<(string File, Lesson Lesson)>();

        var files = Directory.EnumerateFiles(directory)
            .Where(p => p.EndsWith(".yaml", StringComparison.OrdinalIgnoreCase) || p.EndsWith(".yml", StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.OrdinalIgnoreCase);

        foreach (var path in files)
        {
            var name = Path.GetFileName(path);
            try
            {
                var lesson = Deserializer.Deserialize<Lesson>(File.ReadAllText(path));
                if (lesson is null) { errors.Add($"{name}: file is empty."); continue; }
                errors.AddRange(validator.Validate(lesson).Errors.Select(e => $"{name}: {e.ErrorMessage}"));
                lessons.Add((name, lesson));
            }
            catch (YamlException ex)
            {
                errors.Add($"{name}: {ex.Message}");
            }
        }

        var units = LoadUnits(directory);
        if (units.Count > 0)
            foreach (var (file, lesson) in lessons)
            {
                if (lesson.Unit.Length == 0) errors.Add($"{file}: 'unit' is required (units are defined in curriculum/units).");
                else if (!units.Any(u => u.Track == lesson.Track && u.Id == lesson.Unit)) errors.Add($"{file}: unknown unit '{lesson.Unit}' for track '{lesson.Track}'.");
            }

        // A chest: its accessory is a kebab-case id, it has 3-4 stickers; once a unit has lessons, the stickers are words of those
        // lessons and the accessory's drawing exists.
        foreach (var u in units)
        {
            if (u.Chest is null) continue; // the real content file gives every unit a chest (tested); older test fixtures have none
            if (!System.Text.RegularExpressions.Regex.IsMatch(u.Chest.Accessory, "^[a-z0-9]+(-[a-z0-9]+)*$")) errors.Add($"unit '{u.Id}': chest accessory must be a kebab-case id.");
            if (u.Chest.Stickers.Count is < 3 or > 4) errors.Add($"unit '{u.Id}': a chest has 3 or 4 stickers.");
            var words = lessons.Where(l => l.Lesson.Track == u.ContentTrack && l.Lesson.Unit == u.Id).SelectMany(l => l.Lesson.Words).Select(w => w.Word.Trim().ToLowerInvariant()).ToHashSet();
            if (u.Story is { } story)
            {
                if (story.Pages.Count is < 3 or > 8) errors.Add($"unit '{u.Id}': a story has 3 to 8 pages.");
                foreach (var (page, n) in story.Pages.Select((p, n) => (p, n + 1)))
                {
                    if (page.Text.Trim().Length is 0 or > 140) errors.Add($"unit '{u.Id}': story page {n} needs a sentence of 1-140 characters.");
                    if (page.Pose is not null and not ("waving" or "jumping" or "clapping" or "thinking" or "pointing-up" or "base")) errors.Add($"unit '{u.Id}': story page {n} has an unknown pose '{page.Pose}'.");
                    if (page.Words.Count > 3) errors.Add($"unit '{u.Id}': story page {n} shows at most 3 pictures.");
                    if (words.Count > 0)
                        foreach (var w in page.Words.Where(w => !words.Contains(w.Trim().ToLowerInvariant()))) errors.Add($"unit '{u.Id}': story page {n} shows '{w}', which is not a word of the unit.");
                }
            }
            if (words.Count == 0) continue;
            foreach (var st in u.Chest.Stickers.Where(st => !words.Contains(st.Trim().ToLowerInvariant()))) errors.Add($"unit '{u.Id}': sticker '{st}' is not a word of the unit.");
            if (!File.Exists(Path.Combine(directory, "..", "art", "accessories", u.Chest.Accessory + ".svg"))) errors.Add($"unit '{u.Id}': the chest accessory '{u.Chest.Accessory}' has no drawing in content/art/accessories.");
        }

        foreach (var dup in lessons.GroupBy(l => l.Lesson.Id).Where(g => g.Count() > 1))
            errors.Add($"Duplicate lesson id '{dup.Key}' in: {string.Join(", ", dup.Select(l => l.File))}");

        if (errors.Count > 0) throw new CurriculumException("Curriculum is invalid:\n" + string.Join("\n", errors));

        int UnitOrder(Lesson l) => units.FirstOrDefault(u => u.Track == l.Track && u.Id == l.Unit)?.Order ?? 0;
        return lessons.Select(l => l.Lesson).OrderBy(l => l.Track).ThenBy(UnitOrder).ThenBy(l => l.ResolvedOrder).ThenBy(l => l.Id).ToList();
    }

    /// <summary>Reads curriculum/units/*.yaml (optional folder). Units are ordered by track then order.</summary>
    public static IReadOnlyList<UnitDef> LoadUnits(string curriculumDirectory)
    {
        var dir = Path.Combine(curriculumDirectory, "units");
        if (!Directory.Exists(dir)) return [];
        var result = new List<UnitDef>();
        var errors = new List<string>();
        foreach (var path in Directory.EnumerateFiles(dir, "*.yaml").Order(StringComparer.OrdinalIgnoreCase))
        {
            var name = Path.GetFileName(path);
            try
            {
                var file = Deserializer.Deserialize<UnitsFile>(File.ReadAllText(path));
                if (file is null || file.Track.Length == 0) { errors.Add($"{name}: needs a track and a units list."); continue; }
                foreach (var u in file.Units)
                {
                    u.Track = file.Track;
                    if (!System.Text.RegularExpressions.Regex.IsMatch(u.Id, "^[a-z0-9]+(-[a-z0-9]+)*$")) errors.Add($"{name}: unit id '{u.Id}' must be lowercase kebab-case.");
                    if (u.Order <= 0) errors.Add($"{name}: unit '{u.Id}' needs a positive order.");
                    if (u.From.Length > 0) { result.Add(u); continue; } // filled from its own track below
                    if (!u.Title.ContainsKey("en") || !u.Title.ContainsKey("ar")) errors.Add($"{name}: unit '{u.Id}' needs title.en and title.ar.");
                    if (string.IsNullOrWhiteSpace(u.Narration.Title) || string.IsNullOrWhiteSpace(u.Narration.Celebration)) errors.Add($"{name}: unit '{u.Id}' needs narration.title and narration.celebration.");
                    if (u.Delivery is not ("" or "bundled" or "pack")) errors.Add($"{name}: unit '{u.Id}' delivery must be bundled or pack.");
                    errors.AddRange(LineErrors(u.Narration.Lines).Select(e => $"{name}: unit '{u.Id}' {e}"));
                    result.Add(u);
                }
            }
            catch (YamlException ex) { errors.Add($"{name}: {ex.Message}"); }
        }
        // A unit borrowed from another track takes everything from there (its own order stays).
        foreach (var u in result.Where(u => u.From.Length > 0))
        {
            var source = result.FirstOrDefault(x => x.Track == u.From && x.Id == u.Id && x.From.Length == 0);
            if (source is null) { errors.Add($"unit '{u.Id}' of track '{u.Track}' comes from '{u.From}', which has no unit '{u.Id}'."); continue; }
            u.Title = source.Title; u.Icon = source.Icon; u.Color = source.Color; u.Delivery = source.Delivery;
            u.Narration = source.Narration; u.Chest = source.Chest; u.Story = source.Story;
        }
        foreach (var dup in result.GroupBy(u => (u.Track, u.Id)).Where(g => g.Count() > 1)) errors.Add($"Duplicate unit '{dup.Key.Id}' in track '{dup.Key.Track}'.");
        foreach (var dup in result.GroupBy(u => (u.Track, u.Order)).Where(g => g.Count() > 1)) errors.Add($"Two units share order {dup.Key.Order} in track '{dup.Key.Track}'.");
        if (errors.Count > 0) throw new CurriculumException("Units are invalid:\n" + string.Join("\n", errors));
        return result.OrderBy(u => u.Track).ThenBy(u => u.Order).ToList();
    }

    private static IEnumerable<string> LineErrors(Dictionary<string, string> lines) =>
        lines.Where(kv => !System.Text.RegularExpressions.Regex.IsMatch(kv.Key, "^[a-z0-9]+(-[a-z0-9]+)*$") || string.IsNullOrWhiteSpace(kv.Value) || kv.Value.Length > 100)
            .Select(kv => $"line '{kv.Key}' needs a kebab-case key and 1-100 characters.");

    /// <summary>The review stops of a track, checked against its units: known units, in path order, the same unit in only
    /// one review.</summary>
    public static IReadOnlyList<(string Track, ReviewDef Review)> LoadReviews(string curriculumDirectory)
    {
        var dir = Path.Combine(curriculumDirectory, "units");
        if (!Directory.Exists(dir)) return [];
        var result = new List<(string, ReviewDef)>();
        var errors = new List<string>();
        foreach (var path in Directory.EnumerateFiles(dir, "*.yaml").Order(StringComparer.OrdinalIgnoreCase))
        {
            var file = Deserializer.Deserialize<UnitsFile>(File.ReadAllText(path));
            if (file is null) continue;
            var name = Path.GetFileName(path);
            var order = file.Units.ToDictionary(u => u.Id, u => u.Order);
            var seen = new HashSet<string>();
            foreach (var r in file.Reviews)
            {
                if (!System.Text.RegularExpressions.Regex.IsMatch(r.Id, "^[a-z0-9]+(-[a-z0-9]+)*$")) errors.Add($"{name}: review id '{r.Id}' must be lowercase kebab-case.");
                if (r.Units.Count == 0) errors.Add($"{name}: review '{r.Id}' needs units.");
                foreach (var u in r.Units)
                {
                    if (!order.ContainsKey(u)) errors.Add($"{name}: review '{r.Id}' names unknown unit '{u}'.");
                    else if (!seen.Add(u)) errors.Add($"{name}: unit '{u}' is in more than one review.");
                }
                if (r.Units.Where(order.ContainsKey).Select(u => order[u]).Zip(r.Units.Where(order.ContainsKey).Select(u => order[u]).Skip(1)).Any(p => p.Second <= p.First))
                    errors.Add($"{name}: review '{r.Id}' must list its units in path order.");
                result.Add((file.Track, r));
            }
            if (file.Reviews.GroupBy(r => r.Id).Any(g => g.Count() > 1)) errors.Add($"{name}: two reviews share an id.");
        }
        if (errors.Count > 0) throw new CurriculumException("Reviews are invalid:\n" + string.Join("\n", errors));
        return result;
    }

    /// <summary>Dandoona's app-level lines (curriculum/units/*.yaml `app:`) as one pseudo unit with id "app" (not shown on the map).</summary>
    public static IReadOnlyList<UnitDef> LoadApp(string curriculumDirectory)
    {
        var dir = Path.Combine(curriculumDirectory, "units");
        if (!Directory.Exists(dir)) return [];
        var result = new List<UnitDef>();
        foreach (var path in Directory.EnumerateFiles(dir, "*.yaml").Order(StringComparer.OrdinalIgnoreCase))
        {
            var file = Deserializer.Deserialize<UnitsFile>(File.ReadAllText(path));
            if (file?.App is not { } app) continue;
            if (string.IsNullOrWhiteSpace(app.Title) || string.IsNullOrWhiteSpace(app.Welcome) || string.IsNullOrWhiteSpace(app.Celebration))
                throw new CurriculumException($"{Path.GetFileName(path)}: app needs title, welcome and celebration lines.");
            if (LineErrors(app.Lines).FirstOrDefault() is { } bad) throw new CurriculumException($"{Path.GetFileName(path)}: app {bad}");
            result.Add(new UnitDef { Id = "app", Track = file.Track, Order = 0, Narration = app });
        }
        return result;
    }

    /// <summary>The placement answers of a track (curriculum/units/*.yaml), validated against that track's units.</summary>
    public static IReadOnlyList<PlacementDef> LoadPlacement(string curriculumDirectory)
    {
        var dir = Path.Combine(curriculumDirectory, "units");
        if (!Directory.Exists(dir)) return [];
        var result = new List<PlacementDef>();
        var errors = new List<string>();
        foreach (var path in Directory.EnumerateFiles(dir, "*.yaml").Order(StringComparer.OrdinalIgnoreCase))
        {
            var file = Deserializer.Deserialize<UnitsFile>(File.ReadAllText(path));
            if (file is null) continue;
            var ids = file.Units.Select(u => u.Id).ToHashSet();
            foreach (var p in file.Placement)
            {
                p.Track = file.Track;
                if (p.Key.Length == 0) errors.Add($"{Path.GetFileName(path)}: a placement level needs a key.");
                foreach (var u in p.DoneUnits.Append(p.StartUnit))
                    if (!ids.Contains(u)) errors.Add($"{Path.GetFileName(path)}: placement '{p.Key}' names unknown unit '{u}'.");
                result.Add(p);
            }
            if (file.Placement.GroupBy(p => p.Level).Any(g => g.Count() > 1)) errors.Add($"{Path.GetFileName(path)}: two placement answers share a level.");
        }
        if (errors.Count > 0) throw new CurriculumException("Placement is invalid:\n" + string.Join("\n", errors));
        return result.OrderBy(p => p.Track).ThenBy(p => p.Level).ToList();
    }

    /// <summary>The synthetic lesson that carries a unit's own audio lines so the audio runner and export treat them like any lesson.</summary>
    public static Lesson UnitAudioLesson(UnitDef u) => new()
    {
        Id = $"unit-{u.Id}", Track = u.ContentTrack, Unit = u.Id, Level = "pre-a1", IsUnit = true, Order = u.Order,
        Narration = new Narration
        {
            Intro = string.IsNullOrWhiteSpace(u.Narration.Welcome) ? u.Narration.Title : u.Narration.Welcome,
            Instructions = StoryLines(u, new Dictionary<string, string>(u.Narration.Lines) { ["title"] = u.Narration.Title, ["celebration"] = u.Narration.Celebration }),
        },
    };

    /// <summary>The story sentences are spoken like the unit's other lines: `story-1`, `story-2`...</summary>
    private static Dictionary<string, string> StoryLines(UnitDef u, Dictionary<string, string> lines)
    {
        for (var i = 0; i < (u.Story?.Pages.Count ?? 0); i++) lines[$"story-{i + 1}"] = u.Story!.Pages[i].Text.Trim();
        return lines;
    }

    /// <summary>Selects lessons by --lesson id and/or --track; throws if nothing matches.</summary>
    public static IReadOnlyList<Lesson> Select(IReadOnlyList<Lesson> all, string? lessonId, string? track)
    {
        var picked = all.Where(l => (lessonId is null || l.Id == lessonId) && (track is null || l.Track == track)).ToList();
        if (picked.Count == 0)
            throw new CurriculumException($"No lessons match (lesson: {lessonId ?? "any"}, track: {track ?? "any"}).");
        return picked;
    }
}
