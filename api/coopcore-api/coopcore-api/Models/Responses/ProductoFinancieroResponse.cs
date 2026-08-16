namespace CoopCore.Api.Models.Responses;

public sealed record ProductoFinancieroResponse(
    int ProductoFinancieroId,
    string CodigoProducto,
    string NombreProducto,
    string TipoProducto,
    decimal TasaInteres,
    decimal MontoMinimoApertura,
    string Estado,
    DateTime FechaCreacion,
    int CantidadCuentas,
    int CantidadPrestamos,
    decimal SaldoCartera);

public sealed record GuardarProductoFinancieroResponse(
    string Resultado,
    int ProductoFinancieroId,
    string CodigoProducto,
    string NombreProducto,
    string TipoProducto,
    decimal TasaInteres,
    decimal MontoMinimoApertura,
    string Estado,
    DateTime FechaCreacion);
