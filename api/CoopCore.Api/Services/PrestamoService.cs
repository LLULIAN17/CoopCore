using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class PrestamoService : IPrestamoService
{
    private readonly ISqlExecutor _sqlExecutor;

    public PrestamoService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<PrestamoResponse>> ConsultarAsync(
        string id,
        CancellationToken cancellationToken = default)
    {
        id = id.Trim();

        if (string.IsNullOrWhiteSpace(id))
        {
            return ServiceResult<PrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El numero de prestamo es obligatorio.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarPrestamo",
                new[]
                {
                    new SqlParameter("@NumeroPrestamo", SqlDbType.NVarChar, 30)
                    {
                        Value = id
                    }
                },
                cancellationToken);

            var resumen = result.FirstResultSet.FirstOrDefault();

            if (resumen is null)
            {
                return ServiceResult<PrestamoResponse>.Failure(
                    StatusCodes.Status404NotFound,
                    "Prestamo no encontrado.");
            }

            var cuotas = result.ResultSets.Count > 1
                ? result.ResultSets[1].Select(MapCuota).ToArray()
                : Array.Empty<CuotaResponse>();

            return ServiceResult<PrestamoResponse>.Success(
                MapPrestamo(resumen, cuotas),
                "Prestamo consultado correctamente.");
        }
        catch (SqlException ex) when (ex.Message.Contains("no existe", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<PrestamoResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Prestamo no encontrado.");
        }
        catch (SqlException)
        {
            return ServiceResult<PrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ConsultarPrestamo.");
        }
        catch (InvalidOperationException ex)
        {
            return ServiceResult<PrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                ex.Message);
        }
    }

    private static PrestamoResponse MapPrestamo(
        IReadOnlyDictionary<string, object?> row,
        IReadOnlyList<CuotaResponse> cuotas)
    {
        return new PrestamoResponse(
            row.GetInt32("PrestamoID"),
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetString("CedulaSocio") ?? string.Empty,
            row.GetString("NombreSocio") ?? string.Empty,
            row.GetString("CodigoProducto") ?? string.Empty,
            row.GetString("NombreProducto") ?? string.Empty,
            row.GetDecimal("MontoOriginal"),
            row.GetDecimal("SaldoPendiente"),
            row.GetDecimal("TasaInteres"),
            row.GetInt32("PlazoMeses"),
            row.GetDateTime("FechaDesembolso"),
            row.GetString("EstadoPrestamo") ?? string.Empty,
            row.GetInt32("CantidadCuotas"),
            row.GetDecimal("TotalProgramado"),
            row.GetDecimal("TotalPagado"),
            row.GetInt32("CuotasPendientes"),
            cuotas);
    }

    private static CuotaResponse MapCuota(IReadOnlyDictionary<string, object?> row)
    {
        return new CuotaResponse(
            row.GetInt32("CuotaID"),
            row.GetInt32("NumeroCuota"),
            row.GetDateTime("FechaVencimiento"),
            row.GetDecimal("MontoCuota"),
            row.GetDecimal("MontoPagado"),
            row.GetNullableDateTime("FechaPago"),
            row.GetString("EstadoCuota") ?? string.Empty);
    }
}
