namespace CoopCore.Api.Models.Responses;

public sealed record LoginResponse(
    int? EmpleadoId,
    string? NombreUsuario,
    string? Nombre,
    string? Apellido,
    string? Correo,
    string? Rol,
    DateTime? BloqueadoHasta);
