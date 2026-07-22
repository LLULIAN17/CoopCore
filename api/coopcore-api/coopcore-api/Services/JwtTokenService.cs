using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Options;
using CoopCore.Api.Security;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace CoopCore.Api.Services;

public sealed class JwtTokenService : IJwtTokenService
{
    private readonly JwtSettings _settings;

    public JwtTokenService(IOptions<JwtSettings> settings)
    {
        _settings = settings.Value;
    }

    public JwtTokenResult GenerateToken(
        int empleadoId,
        string nombreUsuario,
        string? nombre,
        string? apellido,
        string? correo,
        string rol)
    {
        var now = DateTimeOffset.UtcNow;
        var expirationMinutes = _settings.ExpirationMinutes > 0
            ? _settings.ExpirationMinutes
            : 60;
        var expiresAt = now.AddMinutes(expirationMinutes);

        var claims = new List<Claim>
        {
            new(JwtRegisteredClaimNames.Sub, empleadoId.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N")),
            new(ClaimTypes.NameIdentifier, empleadoId.ToString()),
            new(ClaimTypes.Name, nombreUsuario),
            new(ClaimTypes.Role, rol),
            new("rol", rol)
        };

        AddOptionalClaim(claims, ClaimTypes.GivenName, nombre);
        AddOptionalClaim(claims, ClaimTypes.Surname, apellido);
        AddOptionalClaim(claims, ClaimTypes.Email, correo);

        var credentials = new SigningCredentials(
            new SymmetricSecurityKey(_settings.GetSigningKeyBytes()),
            SecurityAlgorithms.HmacSha256);

        var token = new JwtSecurityToken(
            issuer: _settings.Issuer,
            audience: _settings.Audience,
            claims: claims,
            notBefore: now.UtcDateTime,
            expires: expiresAt.UtcDateTime,
            signingCredentials: credentials);

        return new JwtTokenResult(
            new JwtSecurityTokenHandler().WriteToken(token),
            expiresAt);
    }

    private static void AddOptionalClaim(
        ICollection<Claim> claims,
        string type,
        string? value)
    {
        if (!string.IsNullOrWhiteSpace(value))
        {
            claims.Add(new Claim(type, value));
        }
    }
}
