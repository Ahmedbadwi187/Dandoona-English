using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using KidsEnglish.Application.Abstractions;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace KidsEnglish.Infrastructure.Identity;

public class JwtOptions
{
    public const string Section = "Jwt";
    public string Issuer { get; set; } = "KidsEnglish";
    public string Audience { get; set; } = "KidsEnglish.Mobile";
    /// <summary>Signing key (>= 32 chars). Supply via user-secrets / Key Vault, never commit.</summary>
    public string Key { get; set; } = "";
    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 30;
}

internal class TokenService(IOptions<JwtOptions> options, IClock clock) : ITokenService
{
    private readonly JwtOptions _o = options.Value;

    public TimeSpan RefreshTokenLifetime => TimeSpan.FromDays(_o.RefreshTokenDays);

    public AccessToken CreateAccessToken(Guid parentId, string email)
    {
        var expires = clock.UtcNow.AddMinutes(_o.AccessTokenMinutes);
        var creds = new SigningCredentials(new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_o.Key)), SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            _o.Issuer, _o.Audience,
            [new Claim(JwtRegisteredClaimNames.Sub, parentId.ToString()), new Claim(JwtRegisteredClaimNames.Email, email)],
            notBefore: clock.UtcNow, expires: expires, signingCredentials: creds);
        return new AccessToken(new JwtSecurityTokenHandler().WriteToken(token), expires);
    }

    public (string Raw, string Hash) CreateRefreshToken()
    {
        var raw = Convert.ToBase64String(RandomNumberGenerator.GetBytes(48));
        return (raw, Hash(raw));
    }

    public string Hash(string rawToken) =>
        Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(rawToken))).ToLowerInvariant();
}
