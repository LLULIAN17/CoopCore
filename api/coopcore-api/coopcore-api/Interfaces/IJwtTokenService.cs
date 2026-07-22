using CoopCore.Api.Security;

namespace CoopCore.Api.Interfaces;

public interface IJwtTokenService
{
    JwtTokenResult GenerateToken(
        int empleadoId,
        string nombreUsuario,
        string? nombre,
        string? apellido,
        string? correo,
        string rol);
}
