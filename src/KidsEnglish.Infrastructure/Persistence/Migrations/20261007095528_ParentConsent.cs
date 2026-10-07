using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace KidsEnglish.Infrastructure.Persistence.Migrations
{
    /// <inheritdoc />
    public partial class ParentConsent : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "GuardianConfirmedAt",
                table: "Parents",
                type: "datetime2",
                nullable: true);

            migrationBuilder.AddColumn<DateTime>(
                name: "TermsAcceptedAt",
                table: "Parents",
                type: "datetime2",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "GuardianConfirmedAt",
                table: "Parents");

            migrationBuilder.DropColumn(
                name: "TermsAcceptedAt",
                table: "Parents");
        }
    }
}
