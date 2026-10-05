using FluentValidation;

namespace KidsEnglish.Application.Curriculum;

public class CurriculumLessonValidator : AbstractValidator<CurriculumLesson>
{
    private static readonly string[] Levels = ["pre-a1", "a1", "a2"];

    public CurriculumLessonValidator()
    {
        RuleFor(x => x.Id).NotEmpty().MaximumLength(100).Matches("^[a-z0-9]+(-[a-z0-9]+)*$")
            .WithMessage("'Id' must be lowercase kebab-case.");
        RuleFor(x => x.Track).NotEmpty().MaximumLength(50);
        RuleFor(x => x.Level).Must(l => Levels.Contains(l)).WithMessage("'Level' must be one of: " + string.Join(", ", Levels));
        RuleFor(x => x.Order).GreaterThan(0).When(x => x.Order.HasValue);
        RuleFor(x => x.Letter).Matches("^[A-Z]$").When(x => x.Letter is not null).WithMessage("'Letter' must be a single uppercase A-Z.");
        RuleFor(x => x.Phoneme).NotEmpty().MaximumLength(20).When(x => x.Phoneme is not null);

        RuleFor(x => x.Words).NotEmpty();
        RuleForEach(x => x.Words).ChildRules(w =>
        {
            w.RuleFor(i => i.Word).NotEmpty().MaximumLength(30).Matches("^[A-Za-z' -]+$");
            w.RuleFor(i => i.ImagePrompt).NotEmpty().MaximumLength(500);
        });
        RuleFor(x => x.Words)
            .Must(ws => ws.Select(w => w.Word.Trim().ToLowerInvariant()).Distinct().Count() == ws.Count)
            .WithMessage("Duplicate words in lesson.");

        RuleFor(x => x.Narration.Intro).NotEmpty().MaximumLength(500);
        RuleFor(x => x.Narration.Praise).NotEmpty();
        RuleForEach(x => x.Narration.Praise).NotEmpty().MaximumLength(100);

        RuleFor(x => x.Activities).NotEmpty();
        RuleForEach(x => x.Activities)
            .Must(a => ActivityNames.TryParse(a, out _))
            .WithMessage("Unknown activity '{PropertyValue}'. Use trace, listen-and-tap, say-it, match-picture.");
        RuleFor(x => x.Activities)
            .Must(a => a.Select(n => n.ToLowerInvariant()).Distinct().Count() == a.Count)
            .WithMessage("Duplicate activities in lesson.");
    }
}
