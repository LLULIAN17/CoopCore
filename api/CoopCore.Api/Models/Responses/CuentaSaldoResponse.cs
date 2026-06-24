namespace CoopCore.Api.Models.Responses;

public sealed record CuentaSaldoResponse(
    int CuentaId,
    string NumeroCuenta,
    string CedulaSocio,
    string NombreSocio,
    string CodigoProducto,
    string NombreProducto,
    decimal Saldo,
    string EstadoCuenta,
    DateTime FechaApertura,
    DateTime? UltimoMovimiento);
