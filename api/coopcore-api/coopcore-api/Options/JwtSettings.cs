using System.Text;

namespace CoopCore.Api.Options;

public sealed class JwtSettings
{
    public const string SectionName = "JwtSettings";

    public string Issuer { get; init; } = "CoopCore.Api";

    public string Audience { get; init; } = "CoopCore.Clients";

    public string SigningKey { get; init; } =
        "CoopCore-Local-Development-Signing-Key-Change-2026";

    public int ExpirationMinutes { get; init; } = 60;

    public byte[] GetSigningKeyBytes()
    {
        var keyBytes = Encoding.UTF8.GetBytes(SigningKey);

        if (keyBytes.Length < 32)
        {
            throw new InvalidOperationException(
                "JwtSettings:SigningKey debe tener al menos 32 bytes.");
        }

        return keyBytes;
    }
}
