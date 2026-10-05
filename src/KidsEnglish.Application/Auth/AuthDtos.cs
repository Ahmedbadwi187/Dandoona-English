using FluentValidation;

namespace KidsEnglish.Application.Auth;

public record RegisterRequest(string Email, string Password, string DisplayName);
public record LoginRequest(string Email, string Password);
public record RefreshRequest(string RefreshToken);
public record LogoutRequest(string RefreshToken);
public record AuthResponse(string AccessToken, DateTime AccessTokenExpiresAt, string RefreshToken, Guid ParentId);

public class RegisterRequestValidator : AbstractValidator<RegisterRequest>
{
    public RegisterRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.Password).NotEmpty().MinimumLength(8).MaximumLength(128);
        RuleFor(x => x.DisplayName).NotEmpty().MaximumLength(100);
    }
}

public class LoginRequestValidator : AbstractValidator<LoginRequest>
{
    public LoginRequestValidator()
    {
        RuleFor(x => x.Email).NotEmpty().MaximumLength(256);
        RuleFor(x => x.Password).NotEmpty().MaximumLength(128);
    }
}

public class RefreshRequestValidator : AbstractValidator<RefreshRequest>
{
    public RefreshRequestValidator() => RuleFor(x => x.RefreshToken).NotEmpty().MaximumLength(512);
}

public class LogoutRequestValidator : AbstractValidator<LogoutRequest>
{
    public LogoutRequestValidator() => RuleFor(x => x.RefreshToken).NotEmpty().MaximumLength(512);
}
