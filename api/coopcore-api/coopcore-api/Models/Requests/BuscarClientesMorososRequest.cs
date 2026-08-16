using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed class BuscarClientesMorososRequest
{
    [StringLength(160)]
    public string? Termino { get; init; }

    public DateTime? FechaCorte { get; init; }

    [Range(1, 3650)]
    public int DiasMoraMinimos { get; init; } = 1;

    [Range(1, int.MaxValue)]
    public int Pagina { get; init; } = 1;

    [Range(1, 100)]
    public int TamanoPagina { get; init; } = 20;
}
