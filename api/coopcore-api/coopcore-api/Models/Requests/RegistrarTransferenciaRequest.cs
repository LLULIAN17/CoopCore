using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record RegistrarTransferenciaRequest(
    [Required]
    [StringLength(30)]
    string? NumeroCuentaOrigen,
    [Required]
    [StringLength(30)]
    string? NumeroCuentaDestino,
    [Required]
    [Range(typeof(decimal), "0.01", "9999999999999999.99")]
    decimal? Monto,
    [Required]
    [StringLength(20)]
    string? CedulaEmpleado,
    [StringLength(300)]
    string? Observacion);
