using KidsEnglish.Domain;
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

internal class ChildConfig : IEntityTypeConfiguration<Child>
{
    public void Configure(EntityTypeBuilder<Child> b)
    {
        b.Property(x => x.Name).HasMaxLength(30);
        b.Property(x => x.AvatarKey).HasMaxLength(50);
        b.Property(x => x.Track).HasMaxLength(50).HasDefaultValue(Tracks.LittleLearners);
        b.Property(x => x.Skills).HasMaxLength(500); // skill ids joined by commas; null = never asked
        b.HasOne(x => x.Parent).WithMany(p => p.Children).HasForeignKey(x => x.ParentId).OnDelete(DeleteBehavior.Cascade);
        b.HasIndex(x => x.ParentId);
    }
}

internal class ProgressRecordConfig : IEntityTypeConfiguration<ProgressRecord>
{
    public void Configure(EntityTypeBuilder<ProgressRecord> b)
    {
        b.Property(x => x.LessonId).HasMaxLength(100);
        b.Property(x => x.Activity).HasConversion<string>().HasMaxLength(30);
        b.HasIndex(x => new { x.ChildId, x.ClientRecordId }).IsUnique();
        b.HasOne(x => x.Child).WithMany(c => c.Progress).HasForeignKey(x => x.ChildId).OnDelete(DeleteBehavior.Cascade);
    }
}

internal class ChildAchievementConfig : IEntityTypeConfiguration<ChildAchievement>
{
    public void Configure(EntityTypeBuilder<ChildAchievement> b)
    {
        b.Property(x => x.Kind).HasMaxLength(20);
        b.Property(x => x.Key).HasMaxLength(100);
        b.HasIndex(x => new { x.ChildId, x.Kind, x.Key }).IsUnique();
        // deleted with the child (and so with the account), like progress
        b.HasOne(x => x.Child).WithMany(c => c.Achievements).HasForeignKey(x => x.ChildId).OnDelete(DeleteBehavior.Cascade);
    }
}
