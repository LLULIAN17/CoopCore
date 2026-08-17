using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record RegistrarDepositoRequest(
    [Required]
    [StringLength(30)]
    string? NumeroCuenta,
    [Required]
    [Range(
        typeof(decimal),
        "0.01",
        "9999999999999999.99",
        ParseLimitsInInvariantCulture = true)]
    decimal? Monto,
    [Required]
    [StringLength(20)]
    string? CedulaEmpleado,
    [StringLength(300)]
    string? Observacion);
