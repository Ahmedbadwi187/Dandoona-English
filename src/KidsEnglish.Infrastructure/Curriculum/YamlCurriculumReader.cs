using KidsEnglish.Application.Curriculum;
using YamlDotNet.Core;
using YamlDotNet.Serialization;
using YamlDotNet.Serialization.NamingConventions;

namespace KidsEnglish.Infrastructure.Curriculum;

internal class YamlCurriculumReader : ICurriculumReader
{
    // Strict: unknown keys (typos like "imagePrmpt") fail loudly instead of silently dropping content.
    private static readonly IDeserializer Deserializer = new DeserializerBuilder()
        .WithNamingConvention(CamelCaseNamingConvention.Instance)
        .Build();

    public async Task<IReadOnlyList<CurriculumFile>> ReadAllAsync(string directory, CancellationToken ct)
    {
        if (!Directory.Exists(directory))
            throw new CurriculumException($"Curriculum directory not found: {directory}");

        var paths = Directory.EnumerateFiles(directory, "*.*", SearchOption.TopDirectoryOnly)
            .Where(p => p.EndsWith(".yaml", StringComparison.OrdinalIgnoreCase) || p.EndsWith(".yml", StringComparison.OrdinalIgnoreCase))
            .Order(StringComparer.OrdinalIgnoreCase);

        var result = new List<CurriculumFile>();
        foreach (var path in paths)
        {
            var name = Path.GetFileName(path);
            try
            {
                var lesson = Deserializer.Deserialize<CurriculumLesson>(await File.ReadAllTextAsync(path, ct))
                    ?? throw new CurriculumException($"{name}: file is empty.");
                result.Add(new CurriculumFile(name, lesson));
            }
            catch (YamlException ex)
            {
                throw new CurriculumException($"{name}: {ex.Message}");
            }
        }
        return result;
    }
}
