using System.Diagnostics;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using AssetGenerator.Curriculum;

namespace AssetGenerator;

public interface IVoiceClient
{
    Task<byte[]> SynthesizeAsync(string text, VoiceSettings voice, string model, string outputFormat, CancellationToken ct);
}

public interface IImageClient
{
    Task<IReadOnlyList<byte[]>> GenerateAsync(string prompt, int count, ImageSettings s, CancellationToken ct);
    /// <summary>Generates using a locked reference image (used so the mascot looks identical everywhere).</summary>
    Task<IReadOnlyList<byte[]>> EditAsync(string prompt, byte[] reference, int count, ImageSettings s, CancellationToken ct);
}

public interface IMediaTool
{
    Task EncodeAudioAsync(string input, string output, ExportSettings s, CancellationToken ct);
    Task EncodeImageAsync(string input, string output, ExportSettings s, CancellationToken ct);
}

public class ApiException(string message) : Exception(message);

internal static class ApiErrors
{
    /// <summary>Error text for the user. Never includes request headers (and so never the API key).</summary>
    public static async Task ThrowIfFailedAsync(HttpResponseMessage res, string service, CancellationToken ct)
    {
        if (res.IsSuccessStatusCode) return;
        var body = await res.Content.ReadAsStringAsync(ct);
        if (body.Length > 400) body = body[..400] + "...";
        throw new ApiException($"{service} returned {(int)res.StatusCode} {res.ReasonPhrase}: {body}");
    }
}

/// <summary>POST /v1/text-to-speech/{voice_id}, header xi-api-key, JSON body, audio bytes in the response.</summary>
public sealed class ElevenLabsClient(HttpClient http) : IVoiceClient
{
    public async Task<byte[]> SynthesizeAsync(string text, VoiceSettings v, string model, string outputFormat, CancellationToken ct)
    {
        var body = new
        {
            text,
            model_id = model,
            voice_settings = new
            {
                stability = v.Stability,
                similarity_boost = v.SimilarityBoost,
                style = v.Style,
                speed = v.Speed,
                use_speaker_boost = v.UseSpeakerBoost
            }
        };
        var url = $"v1/text-to-speech/{Uri.EscapeDataString(v.VoiceId)}?output_format={Uri.EscapeDataString(outputFormat)}";
        using var res = await http.PostAsJsonAsync(url, body, ct);
        await ApiErrors.ThrowIfFailedAsync(res, "ElevenLabs", ct);
        var bytes = await res.Content.ReadAsByteArrayAsync(ct);
        if (bytes.Length == 0) throw new ApiException("ElevenLabs returned an empty audio response.");
        return bytes;
    }
}

/// <summary>POST /v1/images/generations (JSON) and /v1/images/edits (multipart, image[]), base64 results.</summary>
public sealed class OpenAiImageClient(HttpClient http) : IImageClient
{
    public async Task<IReadOnlyList<byte[]>> GenerateAsync(string prompt, int count, ImageSettings s, CancellationToken ct)
    {
        var body = new
        {
            model = s.GenerateModel,
            prompt,
            n = count,
            size = s.Size,
            quality = s.Quality,
            output_format = "webp",
            output_compression = s.OutputCompression
        };
        using var res = await http.PostAsJsonAsync("v1/images/generations", body, ct);
        return await ReadImagesAsync(res, ct);
    }

    public async Task<IReadOnlyList<byte[]>> EditAsync(string prompt, byte[] reference, int count, ImageSettings s, CancellationToken ct)
    {
        using var form = new MultipartFormDataContent
        {
            { new StringContent(s.EditModel), "model" },
            { new StringContent(prompt), "prompt" },
            { new StringContent(count.ToString()), "n" },
            { new StringContent(s.Size), "size" },
            { new StringContent(s.Quality), "quality" },
            { new StringContent("webp"), "output_format" },
            { new StringContent(s.OutputCompression.ToString()), "output_compression" }
        };
        var image = new ByteArrayContent(reference);
        image.Headers.ContentType = new MediaTypeHeaderValue("image/webp");
        form.Add(image, "image[]", "mascot.webp");

        using var res = await http.PostAsync("v1/images/edits", form, ct);
        return await ReadImagesAsync(res, ct);
    }

    private static async Task<IReadOnlyList<byte[]>> ReadImagesAsync(HttpResponseMessage res, CancellationToken ct)
    {
        await ApiErrors.ThrowIfFailedAsync(res, "OpenAI", ct);
        var parsed = await res.Content.ReadFromJsonAsync<ImagesResponse>(cancellationToken: ct);
        var images = parsed?.Data?.Where(d => !string.IsNullOrEmpty(d.B64Json)).Select(d => Convert.FromBase64String(d.B64Json!)).ToList();
        if (images is null || images.Count == 0) throw new ApiException("OpenAI returned no images.");
        return images;
    }

    private record ImagesResponse([property: JsonPropertyName("data")] List<ImageData>? Data);
    private record ImageData([property: JsonPropertyName("b64_json")] string? B64Json);
}

/// <summary>Shells out to ffmpeg (external tool, not linked): mono MP3 + loudness normalisation, and WebP resize.</summary>
public sealed class FfmpegTool : IMediaTool
{
    private readonly string _exe = Environment.GetEnvironmentVariable("FFMPEG_PATH") is { Length: > 0 } p ? p : "ffmpeg";

    public Task EncodeAudioAsync(string input, string output, ExportSettings s, CancellationToken ct) =>
        RunAsync(["-y", "-v", "error", "-i", input, "-ac", "1",
                  "-af", $"loudnorm=I={s.LoudnessLufs.ToString(System.Globalization.CultureInfo.InvariantCulture)}:TP=-1.5:LRA=11",
                  "-c:a", "libmp3lame", "-b:a", $"{s.AudioBitrateKbps}k", output], ct);

    public Task EncodeImageAsync(string input, string output, ExportSettings s, CancellationToken ct) =>
        RunAsync(["-y", "-v", "error", "-i", input,
                  "-vf", $"scale={s.ImageSizePx}:{s.ImageSizePx}:flags=lanczos",
                  "-c:v", "libwebp", "-quality", s.ImageQuality.ToString(), output], ct);

    private async Task RunAsync(string[] args, CancellationToken ct)
    {
        var psi = new ProcessStartInfo(_exe) { RedirectStandardError = true, RedirectStandardOutput = true, UseShellExecute = false };
        foreach (var a in args) psi.ArgumentList.Add(a);
        Directory.CreateDirectory(Path.GetDirectoryName(args[^1])!);

        Process proc;
        try { proc = Process.Start(psi)!; }
        catch (System.ComponentModel.Win32Exception)
        {
            throw new ApiException("ffmpeg was not found. Install ffmpeg and add it to PATH (or set FFMPEG_PATH).");
        }
        using (proc)
        {
            var stderr = proc.StandardError.ReadToEndAsync(ct);
            await proc.WaitForExitAsync(ct);
            if (proc.ExitCode != 0) throw new ApiException($"ffmpeg failed ({proc.ExitCode}): {(await stderr).Trim()}");
        }
    }
}
