using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Progress;
using KidsEnglish.Domain.Enums;
using NSubstitute;
using Shouldly;

namespace KidsEnglish.Application.Tests;

public class ProgressTests
{
    private static readonly DateTime Now = new(2026, 10, 7, 12, 0, 0, DateTimeKind.Utc); // a Wednesday

    private static SubmitProgressRequestValidator Validator()
    {
        var clock = Substitute.For<IClock>();
        clock.UtcNow.Returns(Now);
        return new SubmitProgressRequestValidator(clock);
    }

    private static ProgressItemDto Item(string lesson = "letter-a", string activity = "trace", int stars = 3, int attempts = 1,
        int seconds = 30, DateTime? at = null, Guid? id = null) =>
        new(id ?? Guid.NewGuid(), lesson, activity, stars, attempts, seconds, at ?? Now.AddHours(-1));

    [Fact]
    public void A_normal_batch_is_valid() =>
        Validator().Validate(new SubmitProgressRequest([Item(), Item(activity: "listen-and-tap", stars: 0)])).IsValid.ShouldBeTrue();

    [Theory]
    [InlineData("dance")]
    [InlineData("")]
    [InlineData("Trace")] // codes are the app's kebab-case strings
    public void Unknown_activity_is_rejected(string activity) =>
        Validator().Validate(new SubmitProgressRequest([Item(activity: activity)])).IsValid.ShouldBeFalse();

    [Theory]
    [InlineData(-1)]
    [InlineData(4)]
    public void Stars_must_be_0_to_3(int stars) =>
        Validator().Validate(new SubmitProgressRequest([Item(stars: stars)])).IsValid.ShouldBeFalse();

    [Fact]
    public void Rejects_empty_oversized_bad_ids_and_far_future_records()
    {
        var v = Validator();
        v.Validate(new SubmitProgressRequest([])).IsValid.ShouldBeFalse();
        v.Validate(new SubmitProgressRequest(Enumerable.Range(0, 201).Select(_ => Item()).ToList())).IsValid.ShouldBeFalse();
        v.Validate(new SubmitProgressRequest(Enumerable.Range(0, 200).Select(_ => Item()).ToList())).IsValid.ShouldBeTrue();
        v.Validate(new SubmitProgressRequest([Item(id: Guid.Empty)])).IsValid.ShouldBeFalse();
        v.Validate(new SubmitProgressRequest([Item(lesson: "Letter A")])).IsValid.ShouldBeFalse();
        v.Validate(new SubmitProgressRequest([Item(seconds: 90_000)])).IsValid.ShouldBeFalse();
        v.Validate(new SubmitProgressRequest([Item(at: Now.AddDays(3))])).IsValid.ShouldBeFalse();
        v.Validate(new SubmitProgressRequest([Item(at: Now.AddHours(5))])).IsValid.ShouldBeTrue(); // device clock skew is tolerated
    }

    [Fact]
    public void Activity_codes_round_trip_for_every_activity()
    {
        foreach (var type in Enum.GetValues<ActivityType>())
        {
            ActivityCodes.TryParse(ActivityCodes.ToCode(type), out var back).ShouldBeTrue();
            back.ShouldBe(type);
        }
    }

    [Theory]
    [InlineData(2026, 10, 5, 2026, 10, 5)]   // Monday stays
    [InlineData(2026, 10, 7, 2026, 10, 5)]   // Wednesday -> Monday
    [InlineData(2026, 10, 11, 2026, 10, 5)]  // Sunday -> the Monday six days earlier
    [InlineData(2026, 1, 1, 2025, 12, 29)]   // crosses the year
    public void Weeks_start_on_Monday(int y, int m, int d, int ey, int em, int ed) =>
        ProgressService.MondayOf(new DateOnly(y, m, d)).ShouldBe(new DateOnly(ey, em, ed));
}
