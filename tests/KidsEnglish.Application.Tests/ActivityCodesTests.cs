using KidsEnglish.Application.Progress;
using KidsEnglish.Domain.Enums;
using Shouldly;
using Xunit;

namespace KidsEnglish.Application.Tests;

public class ActivityCodesTests
{
    [Fact]
    public void Every_activity_the_app_sends_has_a_code_and_the_codes_round_trip()
    {
        foreach (var code in new[] { "trace", "trace-small", "listen-and-tap", "record-and-listen", "match-picture", "color-the-object" })
        {
            ActivityCodes.TryParse(code, out var type).ShouldBeTrue(code);
            ActivityCodes.ToCode(type).ShouldBe(code);
        }
        foreach (var type in Enum.GetValues<ActivityType>()) ActivityCodes.ToCode(type).ShouldNotBeNullOrEmpty($"{type} has a code");
    }

    [Fact]
    public void The_small_letter_tracing_is_its_own_activity_and_unknown_codes_are_still_refused()
    {
        ActivityCodes.TryParse("trace-small", out var type).ShouldBeTrue();
        type.ShouldBe(ActivityType.TraceSmall);
        ActivityCodes.TryParse("trace-tiny", out _).ShouldBeFalse();
    }
}
