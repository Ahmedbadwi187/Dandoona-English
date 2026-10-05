using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Curriculum;
using KidsEnglish.Domain.Enums;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class CurriculumSyncTests(ApiFactory factory) : IDisposable
{
    private readonly string _dir = Directory.CreateTempSubdirectory("curriculum").FullName;
    public void Dispose() => Directory.Delete(_dir, true);

    private static string RepoCurriculum()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir is not null && !Directory.Exists(Path.Combine(dir.FullName, "content", "curriculum"))) dir = dir.Parent;
        return Path.Combine(dir!.FullName, "content", "curriculum");
    }

    private static string Yaml(string id, string intro = "This is the letter Z.") => $$"""
        id: {{id}}
        track: little-learners
        level: pre-a1
        letter: Z
        phoneme: "/z/"
        order: 100
        words:
          - { word: zebra, imagePrompt: "a friendly zebra" }
        narration:
          intro: "{{intro}}"
          praise: ["Great job!"]
        activities: [trace, say-it]
        """;

    private async Task<T> WithScope<T>(Func<IServiceProvider, Task<T>> action)
    {
        using var scope = factory.Services.CreateScope();
        return await action(scope.ServiceProvider);
    }

    private Task<SyncResult> Sync(string dir) =>
        WithScope(sp => sp.GetRequiredService<CurriculumSyncService>().SyncAsync(dir, CancellationToken.None));

    [Fact]
    public async Task Repo_curriculum_a_to_c_syncs_and_is_idempotent()
    {
        var first = await Sync(RepoCurriculum());
        first.Created.ShouldBeGreaterThanOrEqualTo(0);
        var second = await Sync(RepoCurriculum());
        second.Created.ShouldBe(0);
        second.Updated.ShouldBe(0);
        second.Unchanged.ShouldBeGreaterThanOrEqualTo(3);

        await WithScope(async sp =>
        {
            var db = sp.GetRequiredService<IAppDbContext>();
            var a = await db.Lessons.Include(l => l.Activities).Include(l => l.Assets).SingleAsync(l => l.Code == "letter-a");
            a.Order.ShouldBe(1);
            a.Activities.Count.ShouldBe(4);
            a.Assets.Count.ShouldBe(1 + 1 + 3 + 3 * 2); // intro, phoneme, praise x3, (word + image) x3
            a.Assets.ShouldAllBe(x => x.Status == AssetStatus.Draft);
            return 0;
        });
    }

    [Fact]
    public async Task Unchanged_lesson_keeps_approved_assets_but_edited_text_resets_only_that_asset()
    {
        await File.WriteAllTextAsync(Path.Combine(_dir, "z.yaml"), Yaml("letter-z-keep"));
        (await Sync(_dir)).Created.ShouldBe(1);

        await WithScope(async sp =>
        {
            var db = sp.GetRequiredService<AppDbContext>();
            foreach (var a in db.Assets.Where(a => a.Lesson.Code == "letter-z-keep")) a.Status = AssetStatus.Approved;
            await db.SaveChangesAsync();
            return 0;
        });

        (await Sync(_dir)).Unchanged.ShouldBe(1);

        await File.WriteAllTextAsync(Path.Combine(_dir, "z.yaml"), Yaml("letter-z-keep", intro: "Z is for zebra."));
        (await Sync(_dir)).Updated.ShouldBe(1);

        await WithScope(async sp =>
        {
            var assets = await sp.GetRequiredService<IAppDbContext>().Assets
                .Where(a => a.Lesson.Code == "letter-z-keep").ToListAsync();
            assets.Single(a => a.Role == "intro").Status.ShouldBe(AssetStatus.Draft);
            assets.Single(a => a.Role == "word-zebra").Status.ShouldBe(AssetStatus.Approved);
            return 0;
        });
    }

    [Fact]
    public async Task Invalid_file_blocks_the_whole_sync()
    {
        await File.WriteAllTextAsync(Path.Combine(_dir, "good.yaml"), Yaml("letter-z-good"));
        await File.WriteAllTextAsync(Path.Combine(_dir, "bad.yaml"), Yaml("Bad Id"));

        var ex = await Should.ThrowAsync<CurriculumException>(() => Sync(_dir));
        ex.Message.ShouldContain("bad.yaml");

        (await WithScope(sp => sp.GetRequiredService<IAppDbContext>().Lessons.AnyAsync(l => l.Code == "letter-z-good")))
            .ShouldBeFalse();
    }

    [Fact]
    public async Task Unknown_yaml_key_is_rejected()
    {
        await File.WriteAllTextAsync(Path.Combine(_dir, "typo.yaml"), Yaml("letter-z-typo") + "\nimagePrmpt: oops");
        await Should.ThrowAsync<CurriculumException>(() => Sync(_dir));
    }
}
