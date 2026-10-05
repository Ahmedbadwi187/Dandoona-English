using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Domain.Entities;
using KidsEnglish.Domain.Enums;
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
    [InlineData("a@b.com", "password1", "", false)]
    public void Register_validation(string email, string password, string name, bool valid) =>
        new RegisterRequestValidator().Validate(new RegisterRequest(email, password, name)).IsValid.ShouldBe(valid);

    [Theory]
    [InlineData(2022, true)]   // age 4
    [InlineData(2014, true)]   // age 12
    [InlineData(2026, false)]  // newborn
    [InlineData(2000, false)]  // adult
    public void Child_birth_year_range(int birthYear, bool valid)
    {
        var v = new CreateChildRequestValidator(Clock2026());
        v.Validate(new CreateChildRequest("Omar", "fox", birthYear, 1)).IsValid.ShouldBe(valid);
    }

    [Fact]
    public void Child_name_is_required_and_capped()
    {
        var v = new CreateChildRequestValidator(Clock2026());
        v.Validate(new CreateChildRequest("", "fox", 2022, 1)).IsValid.ShouldBeFalse();
        v.Validate(new CreateChildRequest(new string('x', 31), "fox", 2022, 1)).IsValid.ShouldBeFalse();
    }
}

public class DomainTests
{
    [Fact]
    public void Asset_only_moves_forward_one_step_or_back_to_draft()
    {
        var asset = new Asset { Status = AssetStatus.Generated };
        asset.CanTransitionTo(AssetStatus.Approved).ShouldBeTrue();
        asset.CanTransitionTo(AssetStatus.Draft).ShouldBeTrue();
        asset.CanTransitionTo(AssetStatus.Published).ShouldBeFalse(); // cannot skip review
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
