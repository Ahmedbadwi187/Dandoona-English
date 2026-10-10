using System.Net;
using System.Net.Http.Json;
using KidsEnglish.Application.Auth;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Shouldly;

namespace KidsEnglish.Api.IntegrationTests;

[Collection("api")]
public class ParentAccountTests(ApiFactory factory)
{
    private static string NewEmail() => $"{Guid.NewGuid():N}@test.com";

    private Task<HttpResponseMessage> Register(string email, string name = "Sara", bool guardian = true, bool terms = true) =>
        factory.CreateClient().PostAsJsonAsync("/api/auth/register", new RegisterRequest(email, "Passw0rd!x", name, guardian, terms));

    [Theory]
    [InlineData(false, true)]
    [InlineData(true, false)]
    [InlineData(false, false)]
    public async Task Registration_needs_both_confirmations(bool guardian, bool terms)
    {
        var res = await Register(NewEmail(), guardian: guardian, terms: terms);
        res.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
    }

    [Fact]
    public async Task The_first_name_is_optional_and_both_confirmations_are_recorded_with_a_time()
    {
        var email = NewEmail();
        var res = await Register(email, name: "");
        res.StatusCode.ShouldBe(HttpStatusCode.OK);
        var auth = (await res.Content.ReadFromJsonAsync<AuthResponse>())!;

        using var scope = factory.Services.CreateScope();
        var parent = await scope.ServiceProvider.GetRequiredService<AppDbContext>().Parents.SingleAsync(p => p.Id == auth.ParentId);
        parent.DisplayName.ShouldBe("Parent");
        parent.GuardianConfirmedAt.ShouldNotBeNull();
        parent.TermsAcceptedAt.ShouldNotBeNull();
    }

    [Fact]
    public async Task Registering_sends_a_verification_code_that_confirms_the_email()
    {
        var email = NewEmail();
        (await Register(email)).StatusCode.ShouldBe(HttpStatusCode.OK);
        var code = factory.Emails.LastCodeFor(email);

        var wrong = await factory.CreateClient().PostAsJsonAsync("/api/auth/verify-email", new VerifyEmailRequest(email, "not-the-code"));
        wrong.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        var ok = await factory.CreateClient().PostAsJsonAsync("/api/auth/verify-email", new VerifyEmailRequest(email, code));
        ok.StatusCode.ShouldBe(HttpStatusCode.NoContent);
    }

    [Fact]
    public async Task Forgot_password_says_the_same_thing_for_unknown_emails_and_sends_nothing_to_them()
    {
        var unknown = NewEmail();
        var res = await factory.CreateClient().PostAsJsonAsync("/api/auth/forgot-password", new ForgotPasswordRequest(unknown));
        res.StatusCode.ShouldBe(HttpStatusCode.NoContent);
        factory.Emails.Sent.ShouldNotContain(m => m.To == unknown);
    }

    [Fact]
    public async Task A_reset_code_sets_a_new_password_signs_other_devices_out_and_works_once()
    {
        var email = NewEmail();
        var first = (await (await Register(email)).Content.ReadFromJsonAsync<AuthResponse>())!;
        var c = factory.CreateClient();

        (await c.PostAsJsonAsync("/api/auth/forgot-password", new ForgotPasswordRequest(email))).StatusCode.ShouldBe(HttpStatusCode.NoContent);
        var code = factory.Emails.LastCodeFor(email);
        code.Length.ShouldBe(6); // a short number the parent can type on a phone
        code.ShouldAllBe(ch => char.IsDigit(ch));

        var bad = await c.PostAsJsonAsync("/api/auth/reset-password", new ResetPasswordRequest(email, "nope", "NewPassw0rd!y"));
        bad.StatusCode.ShouldBe(HttpStatusCode.BadRequest);
        var reset = await c.PostAsJsonAsync("/api/auth/reset-password", new ResetPasswordRequest(email, code, "NewPassw0rd!y"));
        reset.StatusCode.ShouldBe(HttpStatusCode.NoContent);

        (await c.PostAsJsonAsync("/api/auth/login", new LoginRequest(email, "Passw0rd!x"))).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);
        (await c.PostAsJsonAsync("/api/auth/login", new LoginRequest(email, "NewPassw0rd!y"))).StatusCode.ShouldBe(HttpStatusCode.OK);
        (await c.PostAsJsonAsync("/api/auth/refresh", new RefreshRequest(first.RefreshToken))).StatusCode.ShouldBe(HttpStatusCode.Unauthorized);

        var again = await c.PostAsJsonAsync("/api/auth/reset-password", new ResetPasswordRequest(email, code, "Another1Passw0rd!"));
        again.StatusCode.ShouldBe(HttpStatusCode.BadRequest); // the code was used
    }
}
