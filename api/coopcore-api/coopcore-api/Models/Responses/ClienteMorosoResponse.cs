namespace CoopCore.Api.Models.Responses;

public sealed record BuscarClientesMorososResponse(
    DateTime FechaCorte,
    string? Termino,
    int DiasMoraMinimos,
    int Pagina,
    int TamanoPagina,
    int TotalRegistros,
    int TotalPaginas,
    decimal TotalMontoMora,
    decimal TotalSaldoPrestamosMorosos,
    IReadOnlyList<ClienteMorosoResponse> Clientes);

public sealed record ClienteMorosoResponse(
    int SocioId,
    string Cedula,
    string NombreCompleto,
    string? Correo,
    string? Telefono,
    string EstadoSocio,
    IReadOnlyList<string> Prestamos,
    int CantidadPrestamosMorosos,
    int CantidadCuotasVencidas,
    DateTime FechaPrimeraCuotaVencida,
    DateTime FechaUltimaCuotaVencida,
    int DiasMoraMaximos,
    string NivelRiesgo,
    decimal MontoTotalMora,
    decimal SaldoTotalPrestamosMorosos);
