using FluentValidation;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using KidsEnglish.Application.Curriculum;
using Microsoft.Extensions.DependencyInjection;

namespace KidsEnglish.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssemblyContaining<RegisterRequestValidator>();
        services.AddScoped<AuthService>();
        services.AddScoped<ChildService>();
        services.AddScoped<CurriculumSyncService>();
        return services;
    }
}
