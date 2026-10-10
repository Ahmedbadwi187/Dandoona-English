using FluentValidation;
using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Common;
using KidsEnglish.Domain;
using KidsEnglish.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace KidsEnglish.Application.Children;

public interface IChildInput
{
    string Name { get; }
    string AvatarKey { get; }
    int BirthYear { get; }
    string Track { get; }
    int? BirthMonth { get; }
    int? GoalMinutes { get; }
    string[]? Skills { get; }
    DateTime? UpdatedAt { get; }
}

// The last three fields are new and optional, so older app versions (which do not send them) keep working.
public record CreateChildRequest(string Name, string AvatarKey, int BirthYear, string Track, int? BirthMonth = null, int? GoalMinutes = null, string[]? Skills = null, DateTime? UpdatedAt = null) : IChildInput;
public record UpdateChildRequest(string Name, string AvatarKey, int BirthYear, string Track, int? BirthMonth = null, int? GoalMinutes = null, string[]? Skills = null, DateTime? UpdatedAt = null) : IChildInput;
public record ChildDto(Guid Id, string Name, string AvatarKey, int BirthYear, string Track, int? BirthMonth = null, int? GoalMinutes = null, string[]? Skills = null, DateTime? UpdatedAt = null);

public abstract class ChildInputValidator<T> : AbstractValidator<T> where T : IChildInput
{
    protected ChildInputValidator(IClock clock)
    {
        RuleFor(x => x.Name).NotEmpty().MaximumLength(30);
        RuleFor(x => x.AvatarKey).NotEmpty().MaximumLength(50);
        RuleFor(x => x.Track).Must(Tracks.IsValid).WithMessage("Unknown track.");
        // Allow slack around the 3-12 target audience.
        RuleFor(x => x.BirthYear)
            .Must(y => y >= clock.UtcNow.Year - 13 && y <= clock.UtcNow.Year - 2)
            .WithMessage("Birth year is outside the supported age range.");
        RuleFor(x => x.BirthMonth).InclusiveBetween(1, 12).When(x => x.BirthMonth.HasValue).WithMessage("Birth month must be 1 to 12.");
        RuleFor(x => x.GoalMinutes).InclusiveBetween(1, 120).When(x => x.GoalMinutes.HasValue).WithMessage("Daily goal must be 1 to 120 minutes.");
        RuleFor(x => x.Skills).Must(s => s!.Length <= 24 && s.All(Skill.IsValid)).When(x => x.Skills is not null).WithMessage("Skills must be up to 24 short ids (letters, digits, hyphens).");
    }
}

/// <summary>A skill id is a short slug from the app's skills list (assets/content/skills.json); the server only checks its shape.</summary>
public static class Skill
{
    public static bool IsValid(string s) => s.Length is > 0 and <= 40 && s.All(c => char.IsAsciiLetterOrDigit(c) || c == '-');
    public static string? Join(string[]? skills) => skills is null ? null : string.Join(',', skills.Distinct().Order());
    public static string[]? Split(string? stored) => stored is null ? null : stored.Length == 0 ? [] : stored.Split(',');
}

public class CreateChildRequestValidator(IClock clock) : ChildInputValidator<CreateChildRequest>(clock);
public class UpdateChildRequestValidator(IClock clock) : ChildInputValidator<UpdateChildRequest>(clock);

public class ChildService(
    IAppDbContext db,
    ICurrentUser user,
    IClock clock,
    IValidator<CreateChildRequest> createValidator,
    IValidator<UpdateChildRequest> updateValidator)
{
    public async Task<IReadOnlyList<ChildDto>> ListAsync(CancellationToken ct)
    {
        var rows = await db.Children.AsNoTracking().Where(c => c.ParentId == user.ParentId).OrderBy(c => c.CreatedAt).ToListAsync(ct);
        return rows.Select(ToDto).ToList();
    }

    private static ChildDto ToDto(Child c) => new(c.Id, c.Name, c.AvatarKey, c.BirthYear, c.Track, c.BirthMonth, c.GoalMinutes, Skill.Split(c.Skills), c.ProfileUpdatedAt);

    public async Task<ChildDto> GetAsync(Guid id, CancellationToken ct)
    {
        var child = await db.Children.AsNoTracking().FirstOrDefaultAsync(c => c.Id == id && c.ParentId == user.ParentId, ct)
            ?? throw new NotFoundException("Child not found.");
        return ToDto(child);
    }

    public async Task<ChildDto> CreateAsync(CreateChildRequest request, CancellationToken ct)
    {
        await createValidator.ValidateAndThrowAsync(request, ct);
        

        var child = new Child
        {
            Id = Guid.NewGuid(),
            ParentId = user.ParentId,
            Name = request.Name.Trim(),
            AvatarKey = request.AvatarKey,
            BirthYear = request.BirthYear,
            BirthMonth = request.BirthMonth,
            Track = request.Track,
            GoalMinutes = request.GoalMinutes,
            Skills = Skill.Join(request.Skills),
            ProfileUpdatedAt = request.UpdatedAt ?? clock.UtcNow,
            CreatedAt = clock.UtcNow
        };
        db.Children.Add(child);
        await db.SaveChangesAsync(ct);
        return await GetAsync(child.Id, ct);
    }

    public async Task<ChildDto> UpdateAsync(Guid id, UpdateChildRequest request, CancellationToken ct)
    {
        await updateValidator.ValidateAndThrowAsync(request, ct);
        

        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == id && c.ParentId == user.ParentId, ct)
            ?? throw new NotFoundException("Child not found.");
        // Two devices edited the same child: the most recent change wins (an older one is ignored and the caller gets what the server has).
        if (request.UpdatedAt is { } sent && child.ProfileUpdatedAt is { } kept && sent < kept) return await GetAsync(id, ct);
        child.Name = request.Name.Trim();
        child.AvatarKey = request.AvatarKey;
        child.BirthYear = request.BirthYear;
        child.BirthMonth = request.BirthMonth;
        child.Track = request.Track;
        // an older app version does not send these: they are left as they are
        if (request.GoalMinutes.HasValue) child.GoalMinutes = request.GoalMinutes;
        if (request.Skills is not null) child.Skills = Skill.Join(request.Skills);
        child.ProfileUpdatedAt = request.UpdatedAt ?? clock.UtcNow;
        await db.SaveChangesAsync(ct);
        return await GetAsync(id, ct);
    }

    public async Task DeleteAsync(Guid id, CancellationToken ct)
    {
        var child = await db.Children.FirstOrDefaultAsync(c => c.Id == id && c.ParentId == user.ParentId, ct)
            ?? throw new NotFoundException("Child not found.");
        db.Children.Remove(child);
        await db.SaveChangesAsync(ct);
    }

}
