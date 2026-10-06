using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using AssetGenerator.Curriculum;

namespace AssetGenerator;

public class VoiceSettings
{
    public string VoiceId { get; set; } = "";
    public double Stability { get; set; } = 0.5;
    public double SimilarityBoost { get; set; } = 0.75;
    public double Style { get; set; } = 0.0;
    public double Speed { get; set; } = 1.0;
    public bool UseSpeakerBoost { get; set; } = true;
}

/// <summary>/content/style/voices.json. voiceId may be left empty to fall back to ELEVENLABS_VOICE_ID.</summary>
public class VoiceConfig
{
    public string Model { get; set; } = "eleven_multilingual_v2";
    public string OutputFormat { get; set; } = "mp3_44100_128";
    public Dictionary<string, VoiceSettings> Voices { get; set; } = new() { ["narrator"] = new() };

    public VoiceSettings Narrator(string? fallbackVoiceId)
    {
        var v = Voices.TryGetValue("narrator", out var found) ? found : new VoiceSettings();
        if (string.IsNullOrWhiteSpace(v.VoiceId)) v.VoiceId = fallbackVoiceId ?? "";
        if (string.IsNullOrWhiteSpace(v.VoiceId))
            throw new CurriculumException("No narrator voice id: set voices.narrator.voiceId in content/style/voices.json or ELEVENLABS_VOICE_ID.");
        return v;
    }
}

public class ImageSettings
{
    public string GenerateModel { get; set; } = "gpt-image-2.5-flare";
    public string EditModel { get; set; } = "gpt-image-2.5-sunburst";
    public string Size { get; set; } = "1024x1024";
    public string Quality { get; set; } = "medium";
    public int Variants { get; set; } = 3;
    public int MascotVariants { get; set; } = 4;
    public int OutputCompression { get; set; } = 90;
}

public class ExportSettings
{
    public int ImageSizePx { get; set; } = 768;
    public int ImageQuality { get; set; } = 80;
    public int AudioBitrateKbps { get; set; } = 64;
    public double LoudnessLufs { get; set; } = -16;
}

/// <summary>Prices are not published in the API docs we read; fill these in to get a dollar estimate in --dry-run.</summary>
public class PricingSettings
{
    public decimal? ElevenLabsUsdPer1kChars { get; set; }
    public decimal? ImageUsdEach { get; set; }
}

/// <summary>/content/style/generation.json (all optional; defaults apply).</summary>
public class GenerationConfig
{
    public ImageSettings Images { get; set; } = new();
    public ExportSettings Export { get; set; } = new();
    public PricingSettings Pricing { get; set; } = new();
}

public static class ConfigLoader
{
    private static readonly JsonSerializerOptions Json = new()
    {
        PropertyNameCaseInsensitive = true,
        ReadCommentHandling = JsonCommentHandling.Skip,
        AllowTrailingCommas = true,
        WriteIndented = true,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase
    };

    public static VoiceConfig Voices(Layout l) => Load<VoiceConfig>(l.VoicesJson, required: false);
    public static GenerationConfig Generation(Layout l) => Load<GenerationConfig>(l.GenerationJson, required: false);

    private static T Load<T>(string path, bool required) where T : new()
    {
        if (!File.Exists(path))
            return required ? throw new CurriculumException($"Missing config file: {path}") : new T();
        try { return JsonSerializer.Deserialize<T>(File.ReadAllText(path), Json) ?? new T(); }
        catch (JsonException ex) { throw new CurriculumException($"{Path.GetFileName(path)}: {ex.Message}"); }
    }

    public static string ToJson<T>(T value) => JsonSerializer.Serialize(value, Json);
}

public static class Hashing
{
    /// <summary>Identity of a generated line: any change to text, voice, settings or model produces a new hash.</summary>
    public static string AudioHash(string text, VoiceSettings v, string model, string outputFormat)
    {
        var payload = $"{text}|{v.VoiceId}|{model}|{outputFormat}|{v.Stability:R}|{v.SimilarityBoost:R}|{v.Style:R}|{v.Speed:R}|{v.UseSpeakerBoost}";
        return Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(payload))).ToLowerInvariant();
    }
}

public class ManifestEntry
{
    public string Hash { get; set; } = "";
    public DateTime GeneratedAtUtc { get; set; }
}

/// <summary>Per-lesson record of what the generated audio files were made from, so unchanged lines are never billed twice.</summary>
public class LessonManifest
{
    public Dictionary<string, ManifestEntry> Audio { get; set; } = [];

    public static LessonManifest Load(string path) =>
        File.Exists(path) ? JsonSerializer.Deserialize<LessonManifest>(File.ReadAllText(path), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? new() : new();

    public void Save(string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, ConfigLoader.ToJson(this));
    }
}
