using KidsEnglish.Application.Abstractions;
using KidsEnglish.Infrastructure.Persistence;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
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

    /// <summary>Every e-mail the API tried to send (the real sender is replaced so tests can read the codes).</summary>
    public TestEmailSender Emails { get; } = new();

    private string ConnectionString => ExternalDb ?? _sql!.GetConnectionString();

    /// <summary>The statistics key the API is configured with (from appsettings.Testing.json).</summary>
    public string StatsKey => Services.GetRequiredService<IConfiguration>()["Stats:Key"]!;

    /// <summary>A throwaway packs folder the API serves at /packs (tests write pack files into it).</summary>
    public string PacksRoot { get; } = Directory.CreateTempSubdirectory("packs").FullName;

    /// <summary>A throwaway cards folder the API serves at /cards.</summary>
    public string CardsRoot { get; } = Directory.CreateTempSubdirectory("cards").FullName;

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
        Directory.Delete(PacksRoot, recursive: true);
        Directory.Delete(CardsRoot, recursive: true);
    }

    /// <summary>
    /// The settings come from appsettings.Testing.json (copied next to the tests): rate limit, Jwt (including Jwt:Key), stats key.
    /// Only what is different on every run is set here: the throwaway database of the container and the two temporary folders.
    /// </summary>
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureAppConfiguration((_, config) =>
        {
            config.AddJsonFile(Path.Combine(AppContext.BaseDirectory, "appsettings.Testing.json"), optional: false, reloadOnChange: false);
            config.AddInMemoryCollection(new Dictionary<string, string?>
            {
                ["ConnectionStrings:Default"] = ConnectionString,
                ["ContentPacks:Root"] = PacksRoot,
                ["ContentCards:Root"] = CardsRoot,
            });
        });
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<IEmailSender>();
            services.AddSingleton<IEmailSender>(Emails);
        });
    }
}

public class TestEmailSender : IEmailSender
{
    private readonly List<EmailMessage> _sent = [];
    public IReadOnlyList<EmailMessage> Sent { get { lock (_sent) return [.._sent]; } }
    public Task SendAsync(EmailMessage message, CancellationToken ct)
    {
        lock (_sent) _sent.Add(message);
        return Task.CompletedTask;
    }
    /// <summary>The code in the last message sent to this address (the line after the one ending with "code:").</summary>
    public string LastCodeFor(string to) =>
        Sent.Last(m => m.To == to).Body.Split('\n').SkipWhile(l => !l.TrimEnd().EndsWith("code:")).Skip(1).First().Trim();
}

[CollectionDefinition("api")]
public class ApiCollection : ICollectionFixture<ApiFactory>;
