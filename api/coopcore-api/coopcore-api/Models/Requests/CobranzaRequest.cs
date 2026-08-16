using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed class ConsultarAlertasCobranzaRequest
{
    public DateTime? FechaCorte { get; init; }

    [Range(0, 90)]
    public int DiasProximos { get; init; } = 7;

    public bool SoloVencidas { get; init; }
}

public sealed record RegistrarGestionCobranzaRequest(
    [Required, StringLength(30)] string? NumeroPrestamo,
    [Required, StringLength(20)] string? CedulaEmpleado,
    [Required, StringLength(20)] string? TipoGestion,
    [Required, StringLength(30)] string? Resultado,
    [Required, StringLength(500, MinimumLength = 5)] string? Comentario,
    DateTime? FechaCompromiso,
    [Range(typeof(decimal), "0.01", "9999999999999999.99")] decimal? MontoCompromiso);
