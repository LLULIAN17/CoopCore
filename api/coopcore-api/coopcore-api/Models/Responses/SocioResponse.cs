namespace CoopCore.Api.Models.Responses;

public sealed record SocioResponse(
    int SocioId,
    string Cedula,
    string Nombre,
    string Apellido,
    string? Correo,
    string? Telefono,
    string? Direccion,
    string? Estado,
    DateTime? FechaRegistro,
    int? CantidadCuentas,
    decimal? SaldoTotalCuentas,
    int? CantidadPrestamos,
    decimal? SaldoTotalPrestamos);
