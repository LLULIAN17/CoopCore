namespace CoopCore.Api.Models.Responses;

public sealed record SolicitarPrestamoResponse(
    string Resultado,
    int PrestamoId,
    string NumeroPrestamo,
    string CedulaSocio,
    string CodigoProducto,
    decimal MontoOriginal,
    decimal SaldoPendiente,
    decimal TasaInteres,
    int PlazoMeses,
    string EstadoPrestamo);

public sealed record AprobarPrestamoResponse(
    string Resultado,
    int PrestamoId,
    string NumeroPrestamo,
    decimal MontoOriginal,
    decimal SaldoPendiente,
    decimal TasaInteres,
    int PlazoMeses,
    DateTime FechaDesembolso,
    string EstadoPrestamo,
    string CedulaEmpleadoAprueba);

public sealed record RechazarPrestamoResponse(
    string Resultado,
    int PrestamoId,
    string NumeroPrestamo,
    decimal MontoOriginal,
    decimal SaldoPendiente,
    string EstadoPrestamo,
    string Motivo,
    string CedulaEmpleadoRechaza);

public sealed record GenerarAmortizacionResponse(
    string Resultado,
    string NumeroPrestamo,
    IReadOnlyList<AmortizacionCuotaResponse> Cuotas);

public sealed record AmortizacionCuotaResponse(
    int NumeroCuota,
    DateTime FechaVencimiento,
    decimal MontoCuota,
    decimal MontoPagado,
    string EstadoCuota);

public sealed record PagarCuotaResponse(
    string Resultado,
    long MovimientoId,
    string Referencia,
    string NumeroPrestamo,
    int NumeroCuota,
    decimal MontoCuota,
    decimal MontoPagadoAnterior,
    decimal MontoPago,
    decimal MontoPagadoNuevo,
    string EstadoCuota,
    decimal SaldoPrestamoAnterior,
    decimal SaldoPrestamoNuevo,
    string EstadoPrestamo,
    string NumeroCuentaOrigen,
    decimal SaldoCuentaAnterior,
    decimal SaldoCuentaNuevo);
