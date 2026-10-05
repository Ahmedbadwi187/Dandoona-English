using KidsEnglish.Application.Abstractions;
using KidsEnglish.Application.Curriculum;
using KidsEnglish.Infrastructure.Curriculum;
using KidsEnglish.Infrastructure.Identity;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;

namespace KidsEnglish.Infrastructure;

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
            })
            .AddRoles<IdentityRole<Guid>>()
            .AddEntityFrameworkStores<AppDbContext>();

        services.AddOptions<JwtOptions>()
            .Bind(config.GetSection(JwtOptions.Section))
            .Validate(o => o.Key.Length >= 32, "Jwt:Key must be at least 32 characters.")
            .ValidateOnStart();

        services.AddSingleton<IClock, SystemClock>();
        services.AddScoped<IIdentityService, IdentityService>();
        services.AddScoped<ITokenService, TokenService>();
        services.AddSingleton<ICurriculumReader, YamlCurriculumReader>();
        return services;
    }
}
