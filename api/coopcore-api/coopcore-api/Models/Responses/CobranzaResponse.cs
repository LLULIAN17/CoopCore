namespace CoopCore.Api.Models.Responses;

public sealed record AlertasCobranzaResponse(
    DateTime FechaCorte,
    int DiasProximos,
    int TotalAlertas,
    int TotalVencidas,
    int TotalProximas,
    decimal MontoTotalPendiente,
    IReadOnlyList<AlertaCobranzaResponse> Alertas);

public sealed record AlertaCobranzaResponse(
    int CuotaId,
    int SocioId,
    string Cedula,
    string NombreCliente,
    string? Telefono,
    string? Correo,
    string NumeroPrestamo,
    int NumeroCuota,
    DateTime FechaVencimiento,
    decimal MontoPendiente,
    string TipoAlerta,
    string Prioridad,
    int DiasMora,
    int DiasParaVencer,
    DateTime? UltimaGestionFecha,
    string? UltimaGestionTipo,
    string? UltimaGestionResultado,
    DateTime? FechaCompromiso,
    decimal? MontoCompromiso);

public sealed record GestionCobranzaResponse(
    string ResultadoOperacion,
    long GestionCobranzaId,
    string NumeroPrestamo,
    DateTime FechaGestion,
    string TipoGestion,
    string Resultado,
    string Comentario,
    DateTime? FechaCompromiso,
    decimal? MontoCompromiso,
    string CedulaEmpleado,
    string NombreEmpleado);
