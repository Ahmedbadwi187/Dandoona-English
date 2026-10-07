using KidsEnglish.Application.Abstractions;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Progress;

/// <summary>One lesson activity across all children: how often it was finished, how many tries it took, how many stars and
/// seconds it gave. No child, parent or record ids, no names, no dates.</summary>
public record LessonStatDto(
    string LessonId, string Activity, int Results, int Children,
    double AverageAttempts, double AverageStars, double AverageSeconds, double OneStarShare);

public record LessonStatsDto(int MinChildren, int RowsHidden, IReadOnlyList<LessonStatDto> Lessons);

/// <summary>
/// Anonymous, aggregated numbers for improving the content (which lessons need the most retries). Computed on request from
/// the per-activity summaries that parents with an account already sync; nothing new is collected from any phone, and
/// nothing is stored. A row is shown only when at least <see cref="MinChildren"/> different children are in it, so no
/// single child can be picked out.
/// </summary>
public class StatsService(IAppDbContext db)
{
    public const int MinChildren = 5;

    public async Task<LessonStatsDto> LessonsAsync(DateOnly? from, CancellationToken ct)
    {
        var since = from?.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc);
        var rows = await db.ProgressRecords.AsNoTracking()
            .Where(p => since == null || p.CompletedAt >= since)
            .GroupBy(p => new { p.LessonId, p.Activity })
            .Select(g => new
            {
                g.Key.LessonId,
                g.Key.Activity,
                Results = g.Count(),
                Children = g.Select(x => x.ChildId).Distinct().Count(),
                Attempts = g.Average(x => (double)x.Attempts),
                Stars = g.Average(x => (double)x.Stars),
                Seconds = g.Average(x => (double)x.TimeSpentSeconds),
                OneStar = g.Count(x => x.Stars <= 1),
            })
            .ToListAsync(ct);

        var shown = rows.Where(r => r.Children >= MinChildren)
            .Select(r => new LessonStatDto(r.LessonId, ActivityCodes.ToCode(r.Activity), r.Results, r.Children,
                Math.Round(r.Attempts, 2), Math.Round(r.Stars, 2), Math.Round(r.Seconds, 1), Math.Round((double)r.OneStar / r.Results, 3)))
            .OrderByDescending(r => r.AverageAttempts).ThenBy(r => r.LessonId).ThenBy(r => r.Activity)
            .ToList();
        return new LessonStatsDto(MinChildren, rows.Count - shown.Count, shown);
    }
}
