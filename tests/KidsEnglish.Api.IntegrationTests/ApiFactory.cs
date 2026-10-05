using KidsEnglish.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Testcontainers.MsSql;

namespace KidsEnglish.Api.IntegrationTests;

/// <summary>
/// Runs against a Testcontainers SQL Server by default. Set KIDS_TEST_SQL to a connection string for a
/// throwaway database to run without Docker; that database is dropped and recreated on start.
/// </summary>
public class ApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private static readonly string? ExternalDb = Environment.GetEnvironmentVariable("KIDS_TEST_SQL");
    private readonly MsSqlContainer? _sql = ExternalDb is null
        ? new MsSqlBuilder("mcr.microsoft.com/mssql/server:2022-latest").Build()
        : null;

    private string ConnectionString => ExternalDb ?? _sql!.GetConnectionString();

    public async Task InitializeAsync()
    {
        if (_sql is not null) await _sql.StartAsync();
        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        if (ExternalDb is not null) await db.Database.EnsureDeletedAsync();
        await db.Database.MigrateAsync();
    }

    public new async Task DisposeAsync()
    {
        if (_sql is not null) await _sql.DisposeAsync();
        await base.DisposeAsync();
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.UseSetting("ConnectionStrings:Default", ConnectionString);
        builder.UseSetting("RateLimiting:AuthPermitsPerMinute", "10000");
        builder.UseSetting("Jwt:Key", "integration-tests-only-signing-key-0123456789");
    }
}

[CollectionDefinition("api")]
public class ApiCollection : ICollectionFixture<ApiFactory>;
