using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KidsEnglish.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ChildSkillsGoalAndProfileTime : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<int>(
                name: "GoalMinutes",
                table: "Children",
                type: "int",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "ProfileUpdatedAt",
                table: "Children",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "Skills",
                table: "Children",
                type: "nvarchar(500)",
                maxLength: 500,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GoalMinutes",
                table: "Children");

            migrationBuilder.DropColumn(
                name: "ProfileUpdatedAt",
                table: "Children");

            migrationBuilder.DropColumn(
                name: "Skills",
                table: "Children");
        }
    }
}
