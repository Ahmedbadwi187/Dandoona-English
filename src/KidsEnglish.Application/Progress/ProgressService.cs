using FluentValidation;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Common;
using KidsEnglish.Domain.Entities;
using KidsEnglish.Domain.Enums;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Progress;

/// <summary>Activity codes as written by the app ("listen-and-tap") and stored as <see cref="ActivityType"/>.</summary>
public static class ActivityCodes
{
    private static readonly Dictionary<string, ActivityType> Map = new()
    {
        ["trace"] = ActivityType.Trace,
        ["listen-and-tap"] = ActivityType.ListenAndTap,
        ["record-and-listen"] = ActivityType.RecordAndListen,
        ["match-picture"] = ActivityType.MatchPicture,
        ["color-the-object"] = ActivityType.ColorTheObject,
        ["trace-small"] = ActivityType.TraceSmall,
        ["animal-sounds"] = ActivityType.AnimalSounds,
        ["habitat"] = ActivityType.Habitat,
        ["dandoona-says"] = ActivityType.DandoonaSays,
        ["sort"] = ActivityType.Sort,
        ["memory"] = ActivityType.Memory,
        ["odd-one-out"] = ActivityType.OddOneOut,
        ["sentence"] = ActivityType.Sentence,
        ["count-along"] = ActivityType.CountAlong,
        ["mix-colors"] = ActivityType.MixColors,
        ["build-picture"] = ActivityType.BuildPicture,
        ["turns"] = ActivityType.Turns,
        ["story-feeling"] = ActivityType.StoryFeeling,
        // Explorers phonics (stored by name, so no migration)
        ["sound-tap"] = ActivityType.SoundTap,
        ["word-builder"] = ActivityType.WordBuilder,
        ["read-and-pick"] = ActivityType.ReadAndPick,
        ["find-the-word"] = ActivityType.FindTheWord,
        ["sentence-builder"] = ActivityType.SentenceBuilder,
        ["fill-the-gap"] = ActivityType.FillTheGap,
        ["spell-it"] = ActivityType.SpellIt
    };

    public static bool TryParse(string? code, out ActivityType type) => Map.TryGetValue(code ?? "", out type);
    public static string ToCode(ActivityType type) => Map.First(kv => kv.Value == type).Key;
}

public record ProgressItemDto(
    Guid ClientRecordId, string LessonId, string Activity, int Stars, int Attempts, int TimeSpentSeconds, DateTime CompletedAt);

public record SubmitProgressRequest(List<ProgressItemDto> Items);
public record SubmitProgressResponse(int Accepted, int Duplicates);

public record DaySummaryDto(DateOnly Date, int Stars, int Activities, int TimeSpentSeconds);

public record WeeklySummaryDto(
    Guid ChildId, string ChildName, DateOnly WeekStart, DateOnly WeekEnd,
    int TotalStars, int ActivitiesCompleted, int LessonsPracticed, int TimeSpentSeconds, int ActiveDays,
    IReadOnlyList<DaySummaryDto> Days);

public class SubmitProgressRequestValidator : AbstractValidator<SubmitProgressRequest>
{
    public const int MaxBatch = 200;

    public SubmitProgressRequestValidator(IClock clock)
    {
        RuleFor(x => x.Items).NotNull().NotEmpty().Must(i => i.Count <= MaxBatch).WithMessage($"At most {MaxBatch} records per request.");
        RuleForEach(x => x.Items).ChildRules(i =>
        {
            i.RuleFor(p => p.ClientRecordId).NotEqual(Guid.Empty);
            i.RuleFor(p => p.LessonId).NotEmpty().MaximumLength(100).Matches("^[a-z0-9]+(-[a-z0-9]+)*$");
            i.RuleFor(p => p.Activity).Must(a => ActivityCodes.TryParse(a, out _)).WithMessage("Unknown activity.");
            i.RuleFor(p => p.Stars).InclusiveBetween(0, 3);
            i.RuleFor(p => p.Attempts).InclusiveBetween(0, 1000);
            i.RuleFor(p => p.TimeSpentSeconds).InclusiveBetween(0, 24 * 60 * 60);
            // allow device clock skew, but not far-future records that would distort weekly summaries
            i.RuleFor(p => p.CompletedAt).Must(t => t <= clock.UtcNow.AddDays(1)).WithMessage("CompletedAt is in the future.");
        });
    }
}

/// <summary>Stores a child's activity results (idempotent by client record id) and builds weekly summaries.</summary>
public class ProgressService(IAppDbContext db, ICurrentUser user, IClock clock, IValidator<SubmitProgressRequest> validator)
{
    public async Task<SubmitProgressResponse> SubmitAsync(Guid childId, SubmitProgressRequest request, CancellationToken ct)
    {
        await validator.ValidateAndThrowAsync(request, ct);
        await EnsureOwnChildAsync(childId, ct);

        var incoming = request.Items.GroupBy(i => i.ClientRecordId).Select(g => g.First()).ToList();
        var ids = incoming.Select(i => i.ClientRecordId).ToList();
        var existing = (await db.ProgressRecords.Where(p => p.ChildId == childId && ids.Contains(p.ClientRecordId))
            .Select(p => p.ClientRecordId).ToListAsync(ct)).ToHashSet();

        var fresh = incoming.Where(i => !existing.Contains(i.ClientRecordId)).ToList();
        foreach (var i in fresh)
        {
            ActivityCodes.TryParse(i.Activity, out var activity);
            db.ProgressRecords.Add(new ProgressRecord
            {
                Id = Guid.NewGuid(),
                ChildId = childId,
                ClientRecordId = i.ClientRecordId,
                LessonId = i.LessonId,
                Activity = activity,
                Stars = i.Stars,
                Attempts = i.Attempts,
                TimeSpentSeconds = i.TimeSpentSeconds,
                CompletedAt = DateTime.SpecifyKind(i.CompletedAt, DateTimeKind.Utc)
            });
        }
        await db.SaveChangesAsync(ct);
        return new SubmitProgressResponse(fresh.Count, request.Items.Count - fresh.Count);
    }

    public async Task<IReadOnlyList<ProgressItemDto>> ListAsync(Guid childId, DateTime? since, CancellationToken ct)
    {
        await EnsureOwnChildAsync(childId, ct);
        var rows = await db.ProgressRecords.AsNoTracking()
            .Where(p => p.ChildId == childId && (since == null || p.CompletedAt >= since))
            .OrderBy(p => p.CompletedAt)
            .ToListAsync(ct);
        return rows.Select(p => new ProgressItemDto(
            p.ClientRecordId, p.LessonId, ActivityCodes.ToCode(p.Activity), p.Stars, p.Attempts, p.TimeSpentSeconds, p.CompletedAt)).ToList();
    }

    /// <summary>Weekly summary for one child. [weekStart] is any date; it is moved back to that week's Monday (UTC).</summary>
    public async Task<WeeklySummaryDto> WeeklySummaryAsync(Guid childId, DateOnly? weekStart, CancellationToken ct)
    {
        var child = await db.Children.AsNoTracking().FirstOrDefaultAsync(c => c.Id == childId && c.ParentId == user.ParentId, ct)
                    ?? throw new NotFoundException("Child not found.");
        return await BuildSummaryAsync(child.Id, child.Name, weekStart, ct);
    }

    public async Task<IReadOnlyList<WeeklySummaryDto>> WeeklySummariesAsync(DateOnly? weekStart, CancellationToken ct)
    {
        var children = await db.Children.AsNoTracking().Where(c => c.ParentId == user.ParentId).OrderBy(c => c.CreatedAt)
            .Select(c => new { c.Id, c.Name }).ToListAsync(ct);
        var result = new List<WeeklySummaryDto>();
        foreach (var c in children) result.Add(await BuildSummaryAsync(c.Id, c.Name, weekStart, ct));
        return result;
    }

    public static DateOnly MondayOf(DateOnly date) => date.AddDays(-(((int)date.DayOfWeek + 6) % 7));

    private async Task<WeeklySummaryDto> BuildSummaryAsync(Guid childId, string name, DateOnly? weekStart, CancellationToken ct)
    {
        var monday = MondayOf(weekStart ?? DateOnly.FromDateTime(clock.UtcNow));
        var from = monday.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var to = from.AddDays(7);

        var rows = await db.ProgressRecords.AsNoTracking()
            .Where(p => p.ChildId == childId && p.CompletedAt >= from && p.CompletedAt < to)
            .Select(p => new { p.CompletedAt, p.Stars, p.TimeSpentSeconds, p.LessonId })
            .ToListAsync(ct);

        var days = Enumerable.Range(0, 7).Select(d =>
        {
            var date = monday.AddDays(d);
            var day = rows.Where(r => DateOnly.FromDateTime(r.CompletedAt) == date).ToList();
            return new DaySummaryDto(date, day.Sum(r => r.Stars), day.Count, day.Sum(r => r.TimeSpentSeconds));
        }).ToList();

        return new WeeklySummaryDto(
            childId, name, monday, monday.AddDays(6),
            rows.Sum(r => r.Stars), rows.Count, rows.Select(r => r.LessonId).Distinct().Count(),
            rows.Sum(r => r.TimeSpentSeconds), days.Count(d => d.Activities > 0), days);
    }

    private async Task EnsureOwnChildAsync(Guid childId, CancellationToken ct)
    {
        if (!await db.Children.AnyAsync(c => c.Id == childId && c.ParentId == user.ParentId, ct))
            throw new NotFoundException("Child not found.");
    }
}
