using KidsEnglish.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;

namespace KidsEnglish.Infrastructure.Persistence;

internal class ParentConfig : IEntityTypeConfiguration<Parent>
{
    public void Configure(EntityTypeBuilder<Parent> b)
    {
        b.Property(x => x.DisplayName).HasMaxLength(100);
        b.Property(x => x.PreferredLanguage).HasConversion<string>().HasMaxLength(10);
        // Shared primary key with the Identity user (1:1).
        b.HasOne<ApplicationUser>().WithOne().HasForeignKey<Parent>(x => x.Id).OnDelete(DeleteBehavior.Cascade);
    }
}

internal class RefreshTokenConfig : IEntityTypeConfiguration<RefreshToken>
{
    public void Configure(EntityTypeBuilder<RefreshToken> b)
    {
        b.Property(x => x.TokenHash).HasMaxLength(64);
        b.HasIndex(x => x.TokenHash).IsUnique();
        b.HasOne<Parent>().WithMany(p => p.RefreshTokens).HasForeignKey(x => x.ParentId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal class TrackConfig : IEntityTypeConfiguration<Track>
{
    public void Configure(EntityTypeBuilder<Track> b)
    {
        b.Property(x => x.Code).HasMaxLength(50);
        b.HasIndex(x => x.Code).IsUnique();
        b.Property(x => x.Name).HasMaxLength(100);
        b.Property(x => x.CefrFrom).HasMaxLength(10);
        b.Property(x => x.CefrTo).HasMaxLength(10);
        b.HasData(
            new Track { Id = 1, Code = "little-learners", Name = "Little Learners", MinAge = 3, MaxAge = 5, CefrFrom = "Pre-A1", CefrTo = "Pre-A1" },
            new Track { Id = 2, Code = "explorers", Name = "Explorers", MinAge = 6, MaxAge = 8, CefrFrom = "Pre-A1", CefrTo = "A1" },
            new Track { Id = 3, Code = "champions", Name = "Champions", MinAge = 9, MaxAge = 12, CefrFrom = "A1", CefrTo = "A2" });
    }
}

internal class ChildConfig : IEntityTypeConfiguration<Child>
{
    public void Configure(EntityTypeBuilder<Child> b)
    {
        b.Property(x => x.Name).HasMaxLength(30);
        b.Property(x => x.AvatarKey).HasMaxLength(50);
        b.HasOne(x => x.Parent).WithMany(p => p.Children).HasForeignKey(x => x.ParentId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.Track).WithMany().HasForeignKey(x => x.TrackId).OnDelete(DeleteBehavior.Restrict);
        b.HasIndex(x => x.ParentId);
    }
}

internal class LessonConfig : IEntityTypeConfiguration<Lesson>
{
    public void Configure(EntityTypeBuilder<Lesson> b)
    {
        b.Property(x => x.Code).HasMaxLength(100);
        b.Property(x => x.Title).HasMaxLength(200);
        b.Property(x => x.CurriculumHash).HasMaxLength(64);
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        b.HasIndex(x => new { x.TrackId, x.Code }).IsUnique();
        b.HasOne(x => x.Track).WithMany(t => t.Lessons).HasForeignKey(x => x.TrackId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal class ActivityConfig : IEntityTypeConfiguration<Activity>
{
    public void Configure(EntityTypeBuilder<Activity> b)
    {
        b.Property(x => x.Type).HasConversion<string>().HasMaxLength(30);
        b.Property(x => x.ConfigJson).HasColumnType("nvarchar(max)");
        b.HasOne(x => x.Lesson).WithMany(l => l.Activities).HasForeignKey(x => x.LessonId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal class AssetConfig : IEntityTypeConfiguration<Asset>
{
    public void Configure(EntityTypeBuilder<Asset> b)
    {
        b.Property(x => x.Kind).HasConversion<string>().HasMaxLength(10);
        b.Property(x => x.Status).HasConversion<string>().HasMaxLength(20);
        b.Property(x => x.Source).HasConversion<string>().HasMaxLength(20);
        b.Property(x => x.Role).HasMaxLength(50);
        b.Property(x => x.ContentHash).HasMaxLength(64);
        b.Property(x => x.BlobPath).HasMaxLength(500);
        b.HasIndex(x => x.ContentHash);
        b.HasOne(x => x.Lesson).WithMany(l => l.Assets).HasForeignKey(x => x.LessonId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Activity>().WithMany().HasForeignKey(x => x.ActivityId).OnDelete(DeleteBehavior.NoAction);
    }
}

internal class ContentPackConfig : IEntityTypeConfiguration<ContentPack>
{
    public void Configure(EntityTypeBuilder<ContentPack> b)
    {
        b.Property(x => x.ManifestBlobPath).HasMaxLength(500);
        b.Property(x => x.PublishedBy).HasMaxLength(256);
        b.HasIndex(x => new { x.TrackId, x.Version }).IsUnique();
        b.HasOne(x => x.Track).WithMany().HasForeignKey(x => x.TrackId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal class ContentPackLessonConfig : IEntityTypeConfiguration<ContentPackLesson>
{
    public void Configure(EntityTypeBuilder<ContentPackLesson> b)
    {
        b.HasKey(x => new { x.ContentPackId, x.LessonId });
        b.Property(x => x.CurriculumHash).HasMaxLength(64);
        b.HasOne<ContentPack>().WithMany(p => p.Lessons).HasForeignKey(x => x.ContentPackId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne<Lesson>().WithMany().HasForeignKey(x => x.LessonId).OnDelete(DeleteBehavior.Restrict);
    }
}

internal class ProgressRecordConfig : IEntityTypeConfiguration<ProgressRecord>
{
    public void Configure(EntityTypeBuilder<ProgressRecord> b)
    {
        b.HasIndex(x => new { x.ChildId, x.ClientRecordId }).IsUnique();
        b.HasOne(x => x.Child).WithMany(c => c.Progress).HasForeignKey(x => x.ChildId).OnDelete(DeleteBehavior.Cascade);
        b.HasOne(x => x.Activity).WithMany().HasForeignKey(x => x.ActivityId).OnDelete(DeleteBehavior.Restrict);
    }
}
