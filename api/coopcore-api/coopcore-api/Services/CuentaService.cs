using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class CuentaService : ICuentaService
{
    private readonly ISqlExecutor _sqlExecutor;

    public CuentaService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<CuentaSaldoResponse>> ConsultarSaldoAsync(
        string numeroCuenta,
        CancellationToken cancellationToken = default)
    {
        numeroCuenta = numeroCuenta.Trim();

        if (string.IsNullOrWhiteSpace(numeroCuenta))
        {
            return ServiceResult<CuentaSaldoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El numero de cuenta es obligatorio.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarSaldo",
                new[]
                {
                    new SqlParameter("@NumeroCuenta", SqlDbType.NVarChar, 30)
                    {
                        Value = numeroCuenta
                    }
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            return row is null
                ? ServiceResult<CuentaSaldoResponse>.Failure(
                    StatusCodes.Status404NotFound,
                    "Cuenta no encontrada.")
                : ServiceResult<CuentaSaldoResponse>.Success(
                    MapSaldo(row),
                    "Saldo consultado correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<CuentaSaldoResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Cuenta no encontrada.");
        }
        catch (SqlException)
        {
            return ServiceResult<CuentaSaldoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ConsultarSaldo.");
        }
        catch (InvalidOperationException ex)
        {
            return ServiceResult<CuentaSaldoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                ex.Message);
        }
    }

    public async Task<ServiceResult<IReadOnlyList<MovimientoResponse>>> ConsultarMovimientosAsync(
        string numeroCuenta,
        DateTime? fechaInicio,
        DateTime? fechaFin,
        CancellationToken cancellationToken = default)
    {
        numeroCuenta = numeroCuenta.Trim();

        if (string.IsNullOrWhiteSpace(numeroCuenta))
        {
            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Failure(
                StatusCodes.Status400BadRequest,
                "El numero de cuenta es obligatorio.");
        }

        if (fechaInicio.HasValue && fechaFin.HasValue && fechaInicio > fechaFin)
        {
            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Failure(
                StatusCodes.Status400BadRequest,
                "fechaInicio no puede ser mayor que fechaFin.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarMovimientos",
                new[]
                {
                    new SqlParameter("@NumeroCuenta", SqlDbType.NVarChar, 30)
                    {
                        Value = numeroCuenta
                    },
                    new SqlParameter("@FechaInicio", SqlDbType.DateTime2)
                    {
                        Value = fechaInicio.HasValue ? fechaInicio.Value : DBNull.Value
                    },
                    new SqlParameter("@FechaFin", SqlDbType.DateTime2)
                    {
                        Value = fechaFin.HasValue ? fechaFin.Value : DBNull.Value
                    }
                },
                cancellationToken);

            var movimientos = result.FirstResultSet
                .Select(MapMovimiento)
                .ToArray();

            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Success(
                movimientos,
                "Movimientos consultados correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Failure(
                StatusCodes.Status404NotFound,
                "Cuenta no encontrada.");
        }
        catch (SqlException)
        {
            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ConsultarMovimientos.");
        }
        catch (InvalidOperationException ex)
        {
            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Failure(
                StatusCodes.Status500InternalServerError,
                ex.Message);
        }
    }

    private static CuentaSaldoResponse MapSaldo(IReadOnlyDictionary<string, object?> row)
    {
        return new CuentaSaldoResponse(
            row.GetInt32("CuentaID"),
            row.GetString("NumeroCuenta") ?? string.Empty,
            row.GetString("CedulaSocio") ?? string.Empty,
            row.GetString("NombreSocio") ?? string.Empty,
            row.GetString("CodigoProducto") ?? string.Empty,
            row.GetString("NombreProducto") ?? string.Empty,
            row.GetDecimal("Saldo"),
            row.GetString("EstadoCuenta") ?? string.Empty,
            row.GetDateTime("FechaApertura"),
            row.GetNullableDateTime("UltimoMovimiento"));
    }

    private static MovimientoResponse MapMovimiento(IReadOnlyDictionary<string, object?> row)
    {
        return new MovimientoResponse(
            row.GetInt64("MovimientoID"),
            row.GetDateTime("FechaMovimiento"),
            row.GetString("TipoMovimiento") ?? string.Empty,
            row.GetDecimal("Monto"),
            row.GetString("Referencia"),
            row.GetString("Observacion"),
            row.GetString("CedulaEmpleado"),
            row.GetString("NombreEmpleado"));
    }

    private static bool IsNotFound(SqlException ex)
    {
        return ex.Message.Contains("no existe", StringComparison.OrdinalIgnoreCase);
    }
}
