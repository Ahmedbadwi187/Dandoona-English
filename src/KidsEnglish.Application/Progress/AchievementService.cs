using FluentValidation;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Common;
using KidsEnglish.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Progress;

public record AchievementDto(string Kind, string Key, DateTime EarnedAt);
public record SubmitAchievementsRequest(List<AchievementDto> Items);
public record SubmitAchievementsResponse(int Added, int Known);

public class SubmitAchievementsRequestValidator : AbstractValidator<SubmitAchievementsRequest>
{
    public const int MaxBatch = 500;

    public SubmitAchievementsRequestValidator(IClock clock)
    {
        RuleFor(x => x.Items).NotNull().Must(i => i.Count <= MaxBatch).WithMessage($"At most {MaxBatch} items per request.");
        RuleForEach(x => x.Items).ChildRules(i =>
        {
            i.RuleFor(a => a.Kind).Must(k => AchievementKinds.All.Contains(k ?? "")).WithMessage("Unknown kind.");
            i.RuleFor(a => a.Key).NotEmpty().MaximumLength(100).Matches("^[a-z0-9]+(-[a-z0-9]+)*$");
            i.RuleFor(a => a.EarnedAt).Must(t => t <= clock.UtcNow.AddDays(1)).WithMessage("EarnedAt is in the future.");
        });
    }
}

/// <summary>
/// A child's certificates, opened chests, passed reviews, read stories and placement, merged from every phone: the server
/// keeps the union, one row per (kind, key), with the earliest date any phone reported. Sending the same items again
/// changes nothing, so the app can send them on every sync.
/// </summary>
public class AchievementService(IAppDbContext db, ICurrentUser user, IValidator<SubmitAchievementsRequest> validator)
{
    public async Task<SubmitAchievementsResponse> SubmitAsync(Guid childId, SubmitAchievementsRequest request, CancellationToken ct)
    {
        await validator.ValidateAndThrowAsync(request, ct);
        await EnsureOwnChildAsync(childId, ct);

        var incoming = request.Items
            .GroupBy(i => (i.Kind, i.Key))
            .Select(g => new AchievementDto(g.Key.Kind, g.Key.Key, g.Min(x => DateTime.SpecifyKind(x.EarnedAt, DateTimeKind.Utc))))
            .ToList();
        var existing = await db.ChildAchievements.Where(a => a.ChildId == childId).ToListAsync(ct);
        int added = 0, known = 0;
        foreach (var i in incoming)
        {
            var row = existing.FirstOrDefault(a => a.Kind == i.Kind && a.Key == i.Key);
            if (row is null)
            {
                db.ChildAchievements.Add(new ChildAchievement { Id = Guid.NewGuid(), ChildId = childId, Kind = i.Kind, Key = i.Key, EarnedAt = i.EarnedAt });
                added++;
            }
            else
            {
                if (i.EarnedAt < row.EarnedAt) row.EarnedAt = i.EarnedAt; // the first phone to earn it sets the date
                known++;
            }
        }
        await db.SaveChangesAsync(ct);
        return new SubmitAchievementsResponse(added, known);
    }

    public async Task<IReadOnlyList<AchievementDto>> ListAsync(Guid childId, CancellationToken ct)
    {
        await EnsureOwnChildAsync(childId, ct);
        return await db.ChildAchievements.AsNoTracking().Where(a => a.ChildId == childId)
            .OrderBy(a => a.Kind).ThenBy(a => a.Key)
            .Select(a => new AchievementDto(a.Kind, a.Key, a.EarnedAt)).ToListAsync(ct);
    }

    private async Task EnsureOwnChildAsync(Guid childId, CancellationToken ct)
    {
        if (!await db.Children.AnyAsync(c => c.Id == childId && c.ParentId == user.ParentId, ct))
            throw new NotFoundException("Child not found.");
    }
}
