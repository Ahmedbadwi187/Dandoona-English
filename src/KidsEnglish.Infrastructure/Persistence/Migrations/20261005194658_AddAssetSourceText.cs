using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KidsEnglish.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class AddAssetSourceText : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Assets_LessonId",
                table: "Assets");

            migrationBuilder.AddColumn<string>(
                name: "SourceText",
                table: "Assets",
                type: "nvarchar(max)",
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateIndex(
                name: "IX_Assets_LessonId_Role",
                table: "Assets",
                columns: new[] { "LessonId", "Role" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Assets_LessonId_Role",
                table: "Assets");

            migrationBuilder.DropColumn(
                name: "SourceText",
                table: "Assets");

            migrationBuilder.CreateIndex(
                name: "IX_Assets_LessonId",
                table: "Assets",
                column: "LessonId");
        }
    }
}
