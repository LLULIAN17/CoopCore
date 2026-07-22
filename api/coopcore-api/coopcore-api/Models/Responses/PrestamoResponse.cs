namespace CoopCore.Api.Models.Responses;

public sealed record PrestamoResponse(
    int PrestamoId,
    string NumeroPrestamo,
    string CedulaSocio,
    string NombreSocio,
    string CodigoProducto,
    string NombreProducto,
    decimal MontoOriginal,
    decimal SaldoPendiente,
    decimal TasaInteres,
    int PlazoMeses,
    DateTime? FechaDesembolso,
    string EstadoPrestamo,
    int CantidadCuotas,
    decimal TotalProgramado,
    decimal TotalPagado,
    int CuotasPendientes,
    IReadOnlyList<CuotaResponse> Cuotas);

public sealed record CuotaResponse(
    int CuotaId,
    int NumeroCuota,
    DateTime FechaVencimiento,
    decimal MontoCuota,
    decimal MontoPagado,
    DateTime? FechaPago,
    string EstadoCuota);
