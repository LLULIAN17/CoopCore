using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed class BuscarProductosFinancierosRequest
{
    [StringLength(120)]
    public string? Termino { get; init; }

    [StringLength(30)]
    public string? TipoProducto { get; init; }

    [StringLength(20)]
    public string? Estado { get; init; }
}

public sealed record GuardarProductoFinancieroRequest(
    [Required, StringLength(20)] string? CodigoProducto,
    [Required, StringLength(100)] string? NombreProducto,
    [Required, StringLength(30)] string? TipoProducto,
    [Range(
        typeof(decimal),
        "0",
        "100",
        ParseLimitsInInvariantCulture = true)]
    decimal? TasaInteres,
    [Range(
        typeof(decimal),
        "0",
        "9999999999999999.99",
        ParseLimitsInInvariantCulture = true)]
    decimal? MontoMinimoApertura,
    [Required, StringLength(20)] string? Estado,
    [Required, StringLength(20)] string? CedulaEmpleado);
