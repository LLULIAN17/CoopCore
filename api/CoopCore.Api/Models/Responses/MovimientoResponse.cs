namespace CoopCore.Api.Models.Responses;

public sealed record MovimientoResponse(
    long MovimientoId,
    DateTime FechaMovimiento,
    string TipoMovimiento,
    decimal Monto,
    string? Referencia,
    string? Observacion,
    string? CedulaEmpleado,
    string? NombreEmpleado);
