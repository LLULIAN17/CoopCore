using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record CrearCuentaRequest(
    [Required]
    [StringLength(30)]
    string? NumeroCuenta,
    [Required]
    [StringLength(20)]
    string? CedulaSocio,
    [Required]
    [StringLength(20)]
    string? CodigoProducto,
    [Required]
    [StringLength(20)]
    string? CedulaEmpleado,
    [Range(
        typeof(decimal),
        "0",
        "9999999999999999.99",
        ParseLimitsInInvariantCulture = true)]
    decimal? SaldoInicial);
