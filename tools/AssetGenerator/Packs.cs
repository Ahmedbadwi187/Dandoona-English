using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace AssetGenerator;

/// <summary>One file of a pack, path relative to the pack's version folder (the same path the lesson JSON uses).</summary>
public record PackFile(string Path, string Sha256, long Bytes);

/// <summary>`manifest.json` of one pack version: the unit's lessons and every file with its checksum.
/// Holds no time stamp, so the same content always gives the same manifest (and the same checksum).</summary>
public record PackManifest(int SchemaVersion, string Track, string Unit, int Version, string ContentHash, List<ExportLesson> Lessons, List<PackFile> Files);

/// <summary>What the app needs to know about a pack before downloading it. [Sha256] is the manifest's checksum, [Bytes]
/// everything in the pack, [LessonIds] lets the map tell a finished unit from an unfinished one without the pack.</summary>
public record ExportPackRef(int Version, string Sha256, long Bytes, string Manifest, List<string> LessonIds);

public record PackIndexEntry(string Unit, int Version, string Sha256, long Bytes, string Manifest, List<string> LessonIds);

/// <summary>`packs/&lt;track&gt;/index.json`: the newest version of every pack. The API serves it, so a pack can be updated
/// without an app release.</summary>
public record PackIndex(int SchemaVersion, string Track, List<PackIndexEntry> Packs);

public record PackLockEntry(int Version, string ContentHash);

/// <summary>Builds versioned packs from a unit's exported lessons. A pack keeps its version while its content is unchanged
/// (content/packs.lock.json remembers the hash); any change gives the next version in a new folder, and old versions stay
/// on the server for apps that still ask for them.</summary>
public class PackBuilder(Layout layout)
{
    public const int SchemaVersion = 1;

    private Dictionary<string, Dictionary<string, PackLockEntry>>? _lock;

    private Dictionary<string, Dictionary<string, PackLockEntry>> Lock => _lock ??= File.Exists(layout.PacksLock)
        ? JsonSerializer.Deserialize<Dictionary<string, Dictionary<string, PackLockEntry>>>(File.ReadAllText(layout.PacksLock), new JsonSerializerOptions { PropertyNameCaseInsensitive = true }) ?? []
        : [];

    public static string BuildDir(Layout layout, string track, string unit) => Path.Combine(layout.PackDir(track, unit), "_build");

    public static string Sha256Of(byte[] bytes) => Convert.ToHexString(SHA256.HashData(bytes)).ToLowerInvariant();

    /// <summary>Turns the unit's build folder into a pack version and returns its index entry.</summary>
    public PackIndexEntry Build(string track, string unit, List<ExportLesson> lessons)
    {
        var build = BuildDir(layout, track, unit);
        var files = Directory.EnumerateFiles(build, "*", SearchOption.AllDirectories)
            .Select(f => new PackFile(Path.GetRelativePath(build, f).Replace('\\', '/'), Sha256Of(File.ReadAllBytes(f)), new FileInfo(f).Length))
            .OrderBy(f => f.Path, StringComparer.Ordinal)
            .ToList();
        var contentHash = Sha256Of(Encoding.UTF8.GetBytes(string.Join("\n", files.Select(f => $"{f.Path} {f.Sha256}")) + "\n" + ConfigLoader.ToJson(lessons)));

        var mine = Lock.TryGetValue(track, out var t) ? t : Lock[track] = [];
        var version = mine.TryGetValue(unit, out var known) && known.ContentHash == contentHash ? known.Version : (known?.Version ?? 0) + 1;
        mine[unit] = new PackLockEntry(version, contentHash);

        var versionDir = Path.Combine(layout.PackDir(track, unit), $"v{version}");
        if (Directory.Exists(versionDir)) Directory.Delete(versionDir, recursive: true); // the same version means the same content
        Directory.Move(build, versionDir);

        var manifest = Encoding.UTF8.GetBytes(ConfigLoader.ToJson(new PackManifest(SchemaVersion, track, unit, version, contentHash, lessons, files)));
        File.WriteAllBytes(Path.Combine(versionDir, "manifest.json"), manifest);
        return new PackIndexEntry(unit, version, Sha256Of(manifest), files.Sum(f => f.Bytes) + manifest.Length,
            $"{Layout.Snake(unit)}/v{version}/manifest.json", lessons.Select(l => l.Id).ToList());
    }

    /// <summary>Writes the lock file and the track's index (only the packs built in this export are listed).</summary>
    public void Save(string track, List<PackIndexEntry> entries)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(layout.PacksLock)!);
        File.WriteAllText(layout.PacksLock, ConfigLoader.ToJson(Lock));
        var dir = Path.Combine(layout.PacksDir, Layout.Snake(track));
        Directory.CreateDirectory(dir);
        File.WriteAllText(Path.Combine(dir, "index.json"), ConfigLoader.ToJson(new PackIndex(SchemaVersion, track, entries)));
    }
}
