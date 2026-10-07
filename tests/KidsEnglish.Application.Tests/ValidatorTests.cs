using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Domain.Entities;
using KidsEnglish.Domain;
using NSubstitute;
using Shouldly;

namespace KidsEnglish.Application.Tests;

public class ValidatorTests
{
    private static IClock Clock2026()
    {
        var clock = Substitute.For<IClock>();
        clock.UtcNow.Returns(new DateTime(2026, 6, 1, 0, 0, 0, DateTimeKind.Utc));
        return clock;
    }

    [Theory]
    [InlineData("a@b.com", "password1", "Sara", true)]
    [InlineData("not-an-email", "password1", "Sara", false)]
    [InlineData("a@b.com", "short", "Sara", false)]
    [InlineData("a@b.com", "password1", "", true)] // the first name is optional
    public void Register_validation(string email, string password, string name, bool valid) =>
        new RegisterRequestValidator().Validate(new RegisterRequest(email, password, name, true, true)).IsValid.ShouldBe(valid);

    [Theory]
    [InlineData(true, false)]
    [InlineData(false, true)]
    [InlineData(false, false)]
    public void Register_needs_both_confirmations(bool guardian, bool terms) =>
        new RegisterRequestValidator().Validate(new RegisterRequest("a@b.com", "password1", "Sara", guardian, terms)).IsValid.ShouldBeFalse();

    [Theory]
    [InlineData(2022, true)]   // age 4
    [InlineData(2014, true)]   // age 12
    [InlineData(2026, false)]  // newborn
    [InlineData(2000, false)]  // adult
    public void Child_birth_year_range(int birthYear, bool valid)
    {
        var v = new CreateChildRequestValidator(Clock2026());
        v.Validate(new CreateChildRequest("Omar", "fox", birthYear, "little-learners")).IsValid.ShouldBe(valid);
    }

    [Fact]
    public void Child_name_is_required_and_capped()
    {
        var v = new CreateChildRequestValidator(Clock2026());
        v.Validate(new CreateChildRequest("", "fox", 2022, "little-learners")).IsValid.ShouldBeFalse();
        v.Validate(new CreateChildRequest(new string('x', 31), "fox", 2022, "little-learners")).IsValid.ShouldBeFalse();
    }
}

public class DomainTests
{
    [Fact]
    public void Track_codes_are_validated()
    {
        Tracks.IsValid("little-learners").ShouldBeTrue();
        Tracks.IsValid("explorers").ShouldBeTrue();
        Tracks.IsValid("nope").ShouldBeFalse();
        Tracks.IsValid(null).ShouldBeFalse();
    }

    [Fact]
    public void Refresh_token_active_state()
    {
        var now = DateTime.UtcNow;
        new RefreshToken { ExpiresAt = now.AddDays(1) }.IsActive(now).ShouldBeTrue();
        new RefreshToken { ExpiresAt = now.AddDays(-1) }.IsActive(now).ShouldBeFalse();
        new RefreshToken { ExpiresAt = now.AddDays(1), RevokedAt = now }.IsActive(now).ShouldBeFalse();
    }
}
