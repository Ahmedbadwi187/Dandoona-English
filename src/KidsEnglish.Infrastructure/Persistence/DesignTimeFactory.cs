using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace KidsEnglish.Infrastructure.Persistence;

/// <summary>Lets `dotnet ef` build the model without booting the API host (no secrets needed).</summary>
internal class DesignTimeFactory : IDesignTimeDbContextFactory<AppDbContext>
{
    public AppDbContext CreateDbContext(string[] args) =>
        new(new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer("Server=localhost;Database=KidsEnglish;Trusted_Connection=True;TrustServerCertificate=True")
            .Options);
}
