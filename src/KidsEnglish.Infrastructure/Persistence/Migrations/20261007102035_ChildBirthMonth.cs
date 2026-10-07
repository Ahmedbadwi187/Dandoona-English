using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KidsEnglish.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ChildBirthMonth : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "BirthMonth",
                table: "Children",
                type: "int",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BirthMonth",
                table: "Children");
        }
    }
}
