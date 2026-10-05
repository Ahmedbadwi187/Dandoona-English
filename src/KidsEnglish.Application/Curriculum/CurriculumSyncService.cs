using FluentValidation;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Domain.Entities;
using KidsEnglish.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Curriculum;

/// <summary>
/// Syncs /content/curriculum into Lessons, Activities and Draft Assets. All-or-nothing: if any file is
/// invalid, nothing is written. Unchanged lessons are left alone so approved assets are never reset.
/// </summary>
public class CurriculumSyncService(
    IAppDbContext db,
    ICurriculumReader reader,
    IValidator<CurriculumLesson> validator)
{
    public async Task<SyncResult> SyncAsync(string directory, CancellationToken ct)
    {
        var files = await reader.ReadAllAsync(directory, ct);
        await ValidateAllAsync(files, ct);

        var tracks = await db.Tracks.ToDictionaryAsync(t => t.Code, ct);
        int created = 0, updated = 0, unchanged = 0;

        foreach (var (fileName, c) in files)
        {
            var track = tracks[c.Track]; // existence checked in ValidateAllAsync
            var hash = LessonAssetPlanner.Hash(c);

            var lesson = await db.Lessons
                .Include(l => l.Activities)
                .Include(l => l.Assets)
                .FirstOrDefaultAsync(l => l.TrackId == track.Id && l.Code == c.Id, ct);

            if (lesson is null)
            {
                lesson = new Lesson { Id = Guid.NewGuid(), TrackId = track.Id, Code = c.Id, Status = LessonStatus.Draft };
                db.Lessons.Add(lesson);
                created++;
            }
            else if (lesson.CurriculumHash == hash)
            {
                unchanged++;
                continue;
            }
            else updated++;

            lesson.Title = LessonAssetPlanner.Title(c);
            lesson.Order = LessonAssetPlanner.ResolveOrder(c);
            lesson.CurriculumHash = hash;

            if (await SyncAssetsAsync(lesson, c))
                lesson.Status = LessonStatus.Draft;
            await SyncActivitiesAsync(lesson, c, ct);
        }

        await db.SaveChangesAsync(ct);
        return new SyncResult(created, updated, unchanged);
    }

    private async Task ValidateAllAsync(IReadOnlyList<CurriculumFile> files, CancellationToken ct)
    {
        var errors = new List<string>();

        foreach (var dup in files.GroupBy(f => (f.Lesson.Track, f.Lesson.Id)).Where(g => g.Count() > 1))
            errors.Add($"Duplicate lesson id '{dup.Key.Id}' in: {string.Join(", ", dup.Select(f => f.FileName))}");

        var knownTracks = (await db.Tracks.Select(t => t.Code).ToListAsync(ct)).ToHashSet();
        foreach (var (fileName, lesson) in files)
        {
            var result = await validator.ValidateAsync(lesson, ct);
            errors.AddRange(result.Errors.Select(e => $"{fileName}: {e.ErrorMessage}"));
            if (!knownTracks.Contains(lesson.Track))
                errors.Add($"{fileName}: unknown track '{lesson.Track}'.");
        }

        if (errors.Count > 0)
            throw new CurriculumException("Curriculum is invalid:\n" + string.Join("\n", errors));
    }

    /// <returns>True if any asset was added, changed or removed.</returns>
    private Task<bool> SyncAssetsAsync(Lesson lesson, CurriculumLesson c)
    {
        var changed = false;
        var planned = LessonAssetPlanner.Plan(c);

        foreach (var spec in planned)
        {
            var existing = lesson.Assets.FirstOrDefault(a => a.Role == spec.Role);
            if (existing is null)
            {
                lesson.Assets.Add(new Asset
                {
                    Id = Guid.NewGuid(),
                    Kind = spec.Kind,
                    Role = spec.Role,
                    SourceText = spec.SourceText,
                    RequiresHumanReview = spec.RequiresHumanReview,
                    Status = AssetStatus.Draft,
                    Source = AssetSource.Generated
                });
                changed = true;
            }
            else if (existing.SourceText != spec.SourceText || existing.Kind != spec.Kind)
            {
                // Content changed: previous media is stale, so send it back through generation and review.
                existing.Kind = spec.Kind;
                existing.SourceText = spec.SourceText;
                existing.Status = AssetStatus.Draft;
                existing.ContentHash = "";
                existing.BlobPath = null;
                existing.Source = AssetSource.Generated;
                changed = true;
            }
            existing ??= lesson.Assets.First(a => a.Role == spec.Role);
            existing.RequiresHumanReview = spec.RequiresHumanReview;
        }

        var roles = planned.Select(s => s.Role).ToHashSet();
        foreach (var stale in lesson.Assets.Where(a => !roles.Contains(a.Role)).ToList())
        {
            lesson.Assets.Remove(stale);
            changed = true;
        }
        return Task.FromResult(changed);
    }

    private async Task SyncActivitiesAsync(Lesson lesson, CurriculumLesson c, CancellationToken ct)
    {
        var wanted = c.Activities
            .Select((name, i) => (Type: Parse(name), Order: i + 1))
            .ToList();

        foreach (var (type, order) in wanted)
        {
            var existing = lesson.Activities.FirstOrDefault(a => a.Type == type);
            if (existing is null)
                lesson.Activities.Add(new Activity { Id = Guid.NewGuid(), Type = type, Order = order });
            else
                existing.Order = order;
        }

        var types = wanted.Select(w => w.Type).ToHashSet();
        foreach (var stale in lesson.Activities.Where(a => !types.Contains(a.Type)).ToList())
        {
            // Keep activities that already have child progress so history is never orphaned or blocked.
            if (!await db.ProgressRecords.AnyAsync(p => p.ActivityId == stale.Id, ct))
                lesson.Activities.Remove(stale);
        }
    }

    private static ActivityType Parse(string name) =>
        ActivityNames.TryParse(name, out var t) ? t : throw new CurriculumException($"Unknown activity '{name}'.");
}
