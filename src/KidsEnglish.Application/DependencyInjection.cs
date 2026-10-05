using FluentValidation;
using KidsEnglish.Application.Auth;
using KidsEnglish.Application.Children;
using Microsoft.Extensions.DependencyInjection;

namespace KidsEnglish.Application;

public static class DependencyInjection
{
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        services.AddValidatorsFromAssemblyContaining<RegisterRequestValidator>();
        services.AddScoped<AuthService>();
        services.AddScoped<ChildService>();
        return services;
    }
}
