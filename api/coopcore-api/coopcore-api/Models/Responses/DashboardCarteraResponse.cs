namespace CoopCore.Api.Models.Responses;

public sealed record DashboardCarteraResponse(
    DateTime FechaCorte,
    int TotalSociosActivos,
    int TotalPrestamosVigentes,
    decimal SaldoCarteraTotal,
    int PrestamosConMora,
    int ClientesMorosos,
    decimal MontoVencido,
    int CuotasVencidas,
    decimal IndiceMorosidadPct,
    IReadOnlyList<RiesgoCarteraResponse> DistribucionRiesgo,
    IReadOnlyList<ProximoVencimientoResponse> ProximosVencimientos);

public sealed record RiesgoCarteraResponse(
    string NivelRiesgo,
    int CantidadClientes,
    decimal MontoVencido);

public sealed record ProximoVencimientoResponse(
    int SocioId,
    string Cedula,
    string NombreCliente,
    string NumeroPrestamo,
    int NumeroCuota,
    DateTime FechaVencimiento,
    decimal MontoPendiente,
    int DiasParaVencer);
