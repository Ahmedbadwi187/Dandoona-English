using System.Diagnostics;
using System.Globalization;

namespace AssetGenerator;

/// <summary>
/// Joins clips with silence into one mp3 (ffmpeg). Each clip is first trimmed of its own leading/trailing silence,
/// so the pauses between parts are exactly the requested length and not "natural gap + pause".
/// </summary>
public static class AudioStitcher
{
    /// <summary>Pauses (seconds) of a letter intro: name | 0.7 | sound | 0.5 | sound | 0.7 | word.</summary>
    public static readonly double[] LetterIntroPauses = [0.7, 0.5, 0.7];

    public static async Task JoinAsync(IReadOnlyList<string> clips, IReadOnlyList<double> pauses, string output, CancellationToken ct)
    {
        if (pauses.Count != clips.Count - 1) throw new ArgumentException("Need one pause between each pair of clips.");
        var args = new List<string> { "-y", "-v", "error" };
        foreach (var c in clips) { args.Add("-i"); args.Add(c); }
        var graph = new List<string>();
        var labels = new List<string>();
        const string trim = "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse,silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02,areverse";
        for (var i = 0; i < clips.Count; i++)
        {
            graph.Add($"[{i}:a]aformat=sample_rates=44100:channel_layouts=mono,{trim}[c{i}]");
            labels.Add($"[c{i}]");
            if (i < pauses.Count)
            {
                graph.Add($"anullsrc=r=44100:cl=mono,atrim=duration={pauses[i].ToString(CultureInfo.InvariantCulture)}[p{i}]");
                labels.Add($"[p{i}]");
            }
        }
        graph.Add($"{string.Concat(labels)}concat=n={labels.Count}:v=0:a=1[out]");
        args.AddRange(["-filter_complex", string.Join(";", graph), "-map", "[out]", "-c:a", "libmp3lame", "-b:a", "128k", output]);

        var exe = Environment.GetEnvironmentVariable("FFMPEG_PATH") is { Length: > 0 } p ? p : "ffmpeg";
        var psi = new ProcessStartInfo(exe) { RedirectStandardError = true, RedirectStandardOutput = true, UseShellExecute = false };
        foreach (var a in args) psi.ArgumentList.Add(a);
        Directory.CreateDirectory(Path.GetDirectoryName(output)!);
        Process proc;
        try { proc = Process.Start(psi)!; }
        catch (System.ComponentModel.Win32Exception) { throw new ApiException("ffmpeg was not found. Install ffmpeg and add it to PATH (or set FFMPEG_PATH)."); }
        using (proc)
        {
            var stderr = proc.StandardError.ReadToEndAsync(ct);
            await proc.WaitForExitAsync(ct);
            if (proc.ExitCode != 0) throw new ApiException($"ffmpeg failed ({proc.ExitCode}): {(await stderr).Trim()}");
        }
    }
}
