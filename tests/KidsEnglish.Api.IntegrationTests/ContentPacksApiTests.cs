using System.Net;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class ContentPacksApiTests(ApiFactory factory)
{
    private void Write(string rel, string content)
    {
        var path = Path.Combine(factory.PacksRoot, rel);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        File.WriteAllText(path, content);
    }

    [Fact]
    public async Task Packs_are_served_without_an_account_the_index_is_short_lived_and_a_version_folder_is_cached_for_good()
    {
        Write("little_learners/index.json", """{"schemaVersion":1,"track":"little-learners","packs":[]}""");
        Write("little_learners/numbers/v1/manifest.json", """{"unit":"numbers","version":1}""");
        Write("little_learners/numbers/v1/audio/little_learners/number_1/intro.mp3", "MP3");
        var c = factory.CreateClient(); // no token

        var index = await c.GetAsync("/packs/little_learners/index.json");
        index.StatusCode.ShouldBe(HttpStatusCode.OK);
        index.Headers.CacheControl!.MaxAge.ShouldBe(TimeSpan.FromMinutes(5));

        var audio = await c.GetAsync("/packs/little_learners/numbers/v1/audio/little_learners/number_1/intro.mp3");
        audio.StatusCode.ShouldBe(HttpStatusCode.OK);
        audio.Content.Headers.ContentType!.MediaType.ShouldBe("audio/mpeg");
        audio.Headers.CacheControl!.ToString().ShouldContain("immutable");
        (await audio.Content.ReadAsStringAsync()).ShouldBe("MP3");
    }

    [Fact]
    public async Task Half_built_folders_unknown_file_types_and_paths_outside_the_folder_are_not_served()
    {
        Write("little_learners/numbers/_build/manifest.json", "{}");
        Write("little_learners/numbers/v1/notes.exe", "x");
        var c = factory.CreateClient();
        (await c.GetAsync("/packs/little_learners/numbers/_build/manifest.json")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await c.GetAsync("/packs/little_learners/numbers/v1/notes.exe")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await c.GetAsync("/packs/../appsettings.json")).StatusCode.ShouldBe(HttpStatusCode.NotFound);
        (await c.GetAsync("/packs/little_learners/")).StatusCode.ShouldBe(HttpStatusCode.NotFound); // no folder listing
    }
}
