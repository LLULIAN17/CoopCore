using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record PagarCuotaRequest(
    [Required]
    [Range(
        typeof(decimal),
        "0.01",
        "9999999999999999.99",
        ParseLimitsInInvariantCulture = true)]
    decimal? MontoPago,
    [Required]
    [StringLength(30)]
    string? NumeroCuentaOrigen,
    [Required]
    [StringLength(20)]
    string? CedulaEmpleado);
