using KidsEnglish.Application.Abstractions;
using KidsEnglish.Infrastructure.Identity;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace KidsEnglish.Infrastructure;

/// <summary>Development e-mail: writes the whole message to the log instead of sending it.</summary>
internal class DevEmailSender(Microsoft.Extensions.Logging.ILogger<DevEmailSender> log) : IEmailSender
{
    public Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        log.LogInformation("EMAIL (not sent, development) to {To} | {Subject}\n{Body}", message.To, message.Subject, message.Body);
        return Task.CompletedTask;
    }
}

internal class SystemClock : IClock { public DateTime UtcNow => DateTime.UtcNow; }

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(this IServiceCollection services, IConfiguration config)
    {
        services.AddDbContext<AppDbContext>(o =>
            o.UseSqlServer(config.GetConnectionString("Default"), sql => sql.EnableRetryOnFailure()));
        services.AddScoped<IAppDbContext>(sp => sp.GetRequiredService<AppDbContext>());

        services.AddIdentityCore<ApplicationUser>(o =>
            {
                o.User.RequireUniqueEmail = true;
                o.Password.RequiredLength = 8;
                o.Lockout.MaxFailedAccessAttempts = 5;
                o.Lockout.DefaultLockoutTimeSpan = TimeSpan.FromMinutes(15);
                o.Lockout.AllowedForNewUsers = true;
                // the password reset code is the short number the e-mail provider makes (6 digits, easy to type on a phone)
                o.Tokens.PasswordResetTokenProvider = TokenOptions.DefaultEmailProvider;
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddEntityFrameworkStores<AppDbContext>()
            .AddDefaultTokenProviders(); // codes for e-mail verification and password reset

        services.AddOptions<JwtOptions>()
            .Bind(config.GetSection(JwtOptions.Section))
            .Validate(o => o.Key.Length >= 32, "Jwt:Key must be at least 32 characters.")
            .ValidateOnStart();

        services.AddSingleton<IClock, SystemClock>();
        services.AddScoped<IIdentityService, IdentityService>();
        services.AddScoped<ITokenService, TokenService>();
        // E-mail: with Email:Host in appsettings the messages are sent by that SMTP server; without it they are written to the log.
        services.AddOptions<EmailOptions>().Bind(config.GetSection(EmailOptions.Section));
        if (!string.IsNullOrWhiteSpace(config[$"{EmailOptions.Section}:Host"]))
            services.AddSingleton<IEmailSender, SmtpEmailSender>();
        else
            services.AddSingleton<IEmailSender, DevEmailSender>();
        return services;
    }
}
