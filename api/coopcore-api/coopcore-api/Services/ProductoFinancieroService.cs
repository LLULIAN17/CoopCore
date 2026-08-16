using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class ProductoFinancieroService : IProductoFinancieroService
{
    private static readonly string[] ProductTypes =
        ["AHORRO", "PRESTAMO", "CERTIFICADO", "OTRO"];
    private static readonly string[] ProductStatuses = ["ACTIVO", "INACTIVO"];

    private readonly ISqlExecutor _sqlExecutor;

    public ProductoFinancieroService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<IReadOnlyList<ProductoFinancieroResponse>>> BuscarAsync(
        BuscarProductosFinancierosRequest request,
        CancellationToken cancellationToken = default)
    {
        var type = Normalize(request.TipoProducto);
        var status = Normalize(request.Estado);

        if (type is not null && !ProductTypes.Contains(type))
        {
            return ServiceResult<IReadOnlyList<ProductoFinancieroResponse>>.Failure(
                StatusCodes.Status400BadRequest,
                "tipoProducto no es valido.");
        }
        if (status is not null && !ProductStatuses.Contains(status))
        {
            return ServiceResult<IReadOnlyList<ProductoFinancieroResponse>>.Failure(
                StatusCodes.Status400BadRequest,
                "estado no es valido.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_BuscarProductosFinancieros",
                new[]
                {
                    NullableText("@Termino", 120, request.Termino),
                    NullableText("@TipoProducto", 30, type),
                    NullableText("@Estado", 20, status)
                },
                cancellationToken);

            return ServiceResult<IReadOnlyList<ProductoFinancieroResponse>>.Success(
                result.FirstResultSet.Select(MapProduct).ToArray(),
                "Productos financieros consultados correctamente.");
        }
        catch (SqlException)
        {
            return ServiceResult<IReadOnlyList<ProductoFinancieroResponse>>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al consultar los productos financieros.");
        }
    }

    public Task<ServiceResult<GuardarProductoFinancieroResponse>> CrearAsync(
        GuardarProductoFinancieroRequest request,
        CancellationToken cancellationToken = default)
    {
        return SaveAsync(null, request, true, cancellationToken);
    }

    public Task<ServiceResult<GuardarProductoFinancieroResponse>> ActualizarAsync(
        int productoFinancieroId,
        GuardarProductoFinancieroRequest request,
        CancellationToken cancellationToken = default)
    {
        if (productoFinancieroId <= 0)
        {
            return Task.FromResult(
                ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                    StatusCodes.Status400BadRequest,
                    "El identificador del producto debe ser mayor que cero."));
        }

        return SaveAsync(productoFinancieroId, request, false, cancellationToken);
    }

    private async Task<ServiceResult<GuardarProductoFinancieroResponse>> SaveAsync(
        int? productId,
        GuardarProductoFinancieroRequest request,
        bool isCreate,
        CancellationToken cancellationToken)
    {
        var code = Normalize(request.CodigoProducto);
        var name = request.NombreProducto?.Trim();
        var type = Normalize(request.TipoProducto);
        var status = Normalize(request.Estado);
        var employee = request.CedulaEmpleado?.Trim();

        if (code is null || name is null || type is null || status is null || employee is null ||
            !request.TasaInteres.HasValue || !request.MontoMinimoApertura.HasValue)
        {
            return ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "Todos los datos del producto son obligatorios.");
        }
        if (!ProductTypes.Contains(type) || !ProductStatuses.Contains(status) ||
            request.TasaInteres is < 0 or > 100 || request.MontoMinimoApertura < 0)
        {
            return ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "Tipo, estado, tasa o monto minimo invalido.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_GuardarProductoFinanciero",
                new[]
                {
                    NullableNumber("@ProductoFinancieroID", productId),
                    Text("@CodigoProducto", 20, code),
                    Text("@NombreProducto", 100, name),
                    Text("@TipoProducto", 30, type),
                    Money("@TasaInteres", request.TasaInteres.Value),
                    Money("@MontoMinimoApertura", request.MontoMinimoApertura.Value),
                    Text("@Estado", 20, status),
                    Text("@CedulaEmpleado", 20, employee)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();
            if (row is null)
            {
                return ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El producto no devolvio resultado.");
            }

            return ServiceResult<GuardarProductoFinancieroResponse>.Success(
                MapSavedProduct(row),
                isCreate ? "Producto creado correctamente." : "Producto actualizado correctamente.",
                isCreate ? StatusCodes.Status201Created : StatusCodes.Status200OK);
        }
        catch (SqlException ex) when (ex.Message.Contains("Ya existe", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                StatusCodes.Status409Conflict,
                "Ya existe un producto con el codigo o nombre indicado.");
        }
        catch (SqlException ex) when (ex.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Producto o empleado no encontrado.");
        }
        catch (SqlException)
        {
            return ServiceResult<GuardarProductoFinancieroResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al guardar el producto financiero.");
        }
    }

    private static ProductoFinancieroResponse MapProduct(
        IReadOnlyDictionary<string, object?> row)
    {
        return new ProductoFinancieroResponse(
            row.GetInt32("ProductoFinancieroID"),
            row.GetString("CodigoProducto") ?? string.Empty,
            row.GetString("NombreProducto") ?? string.Empty,
            row.GetString("TipoProducto") ?? string.Empty,
            row.GetDecimal("TasaInteres"),
            row.GetDecimal("MontoMinimoApertura"),
            row.GetString("Estado") ?? string.Empty,
            row.GetDateTime("FechaCreacion"),
            row.GetInt32("CantidadCuentas"),
            row.GetInt32("CantidadPrestamos"),
            row.GetDecimal("SaldoCartera"));
    }

    private static GuardarProductoFinancieroResponse MapSavedProduct(
        IReadOnlyDictionary<string, object?> row)
    {
        return new GuardarProductoFinancieroResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt32("ProductoFinancieroID"),
            row.GetString("CodigoProducto") ?? string.Empty,
            row.GetString("NombreProducto") ?? string.Empty,
            row.GetString("TipoProducto") ?? string.Empty,
            row.GetDecimal("TasaInteres"),
            row.GetDecimal("MontoMinimoApertura"),
            row.GetString("Estado") ?? string.Empty,
            row.GetDateTime("FechaCreacion"));
    }

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToUpperInvariant();

    private static SqlParameter Text(string name, int size, string value) =>
        new(name, SqlDbType.NVarChar, size) { Value = value };

    private static SqlParameter NullableText(string name, int size, string? value) =>
        new(name, SqlDbType.NVarChar, size)
        {
            Value = string.IsNullOrWhiteSpace(value) ? DBNull.Value : value.Trim()
        };

    private static SqlParameter NullableNumber(string name, int? value) =>
        new(name, SqlDbType.Int) { Value = value.HasValue ? value.Value : DBNull.Value };

    private static SqlParameter Money(string name, decimal value) =>
        new(name, SqlDbType.Decimal) { Precision = 18, Scale = 2, Value = value };
}
