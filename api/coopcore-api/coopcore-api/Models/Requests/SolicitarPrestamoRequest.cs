using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record SolicitarPrestamoRequest(
    [Required]
    [StringLength(20)]
    string? CedulaSocio,
    [Required]
    [StringLength(20)]
    string? CodigoProducto,
    [Required]
    [Range(typeof(decimal), "0.01", "9999999999999999.99")]
    decimal? MontoSolicitado,
    [Required]
    [Range(1, int.MaxValue)]
    int? PlazoMeses,
    [Required]
    [StringLength(20)]
    string? CedulaEmpleado);
