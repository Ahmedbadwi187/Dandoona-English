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
}

public record CreateChildRequest(string Name, string AvatarKey, int BirthYear, string Track, int? BirthMonth = null) : IChildInput;
public record UpdateChildRequest(string Name, string AvatarKey, int BirthYear, string Track, int? BirthMonth = null) : IChildInput;
public record ChildDto(Guid Id, string Name, string AvatarKey, int BirthYear, string Track, int? BirthMonth = null);

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
    }
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
    public async Task<IReadOnlyList<ChildDto>> ListAsync(CancellationToken ct) =>
        await db.Children.AsNoTracking()
            .Where(c => c.ParentId == user.ParentId)
            .OrderBy(c => c.CreatedAt)
            .Select(c => new ChildDto(c.Id, c.Name, c.AvatarKey, c.BirthYear, c.Track, c.BirthMonth))
            .ToListAsync(ct);

    public async Task<ChildDto> GetAsync(Guid id, CancellationToken ct) =>
        await db.Children.AsNoTracking()
            .Where(c => c.Id == id && c.ParentId == user.ParentId)
            .Select(c => new ChildDto(c.Id, c.Name, c.AvatarKey, c.BirthYear, c.Track, c.BirthMonth))
            .FirstOrDefaultAsync(ct)
        ?? throw new NotFoundException("Child not found.");

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
        child.Name = request.Name.Trim();
        child.AvatarKey = request.AvatarKey;
        child.BirthYear = request.BirthYear;
        child.BirthMonth = request.BirthMonth;
        child.Track = request.Track;
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
