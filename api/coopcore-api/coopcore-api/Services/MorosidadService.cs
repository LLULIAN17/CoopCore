using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class MorosidadService : IMorosidadService
{
    private readonly ISqlExecutor _sqlExecutor;

    public MorosidadService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<BuscarClientesMorososResponse>> BuscarClientesAsync(
        BuscarClientesMorososRequest request,
        CancellationToken cancellationToken = default)
    {
        var termino = string.IsNullOrWhiteSpace(request.Termino)
            ? null
            : request.Termino.Trim();

        if (termino?.Length > 160)
        {
            return ServiceResult<BuscarClientesMorososResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El termino de busqueda no puede exceder 160 caracteres.");
        }

        if (request.DiasMoraMinimos is < 1 or > 3650)
        {
            return ServiceResult<BuscarClientesMorososResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "diasMoraMinimos debe estar entre 1 y 3650.");
        }

        if (request.Pagina < 1 || request.TamanoPagina is < 1 or > 100)
        {
            return ServiceResult<BuscarClientesMorososResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "pagina debe ser mayor que cero y tamanoPagina debe estar entre 1 y 100.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_BuscarClientesMorosos",
                new[]
                {
                    NullableText("@Termino", 160, termino),
                    NullableDate("@FechaCorte", request.FechaCorte),
                    Number("@DiasMoraMinimos", request.DiasMoraMinimos),
                    Number("@Pagina", request.Pagina),
                    Number("@TamanoPagina", request.TamanoPagina)
                },
                cancellationToken);

            var metadata = result.FirstResultSet.FirstOrDefault();

            if (metadata is null)
            {
                return ServiceResult<BuscarClientesMorososResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio los datos de paginacion.");
            }

            var clientes = result.ResultSets.Count > 1
                ? result.ResultSets[1].Select(MapClienteMoroso).ToArray()
                : Array.Empty<ClienteMorosoResponse>();

            var totalRegistros = metadata.GetInt32("TotalRegistros");
            var totalPaginas = totalRegistros == 0
                ? 0
                : (int)Math.Ceiling(totalRegistros / (double)request.TamanoPagina);

            var response = new BuscarClientesMorososResponse(
                metadata.GetDateTime("FechaCorte"),
                termino,
                request.DiasMoraMinimos,
                request.Pagina,
                request.TamanoPagina,
                totalRegistros,
                totalPaginas,
                metadata.GetDecimal("TotalMontoMora"),
                metadata.GetDecimal("TotalSaldoPrestamosMorosos"),
                clientes);

            return ServiceResult<BuscarClientesMorososResponse>.Success(
                response,
                totalRegistros == 0
                    ? "No se encontraron clientes morosos con los filtros indicados."
                    : "Clientes morosos consultados correctamente.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<BuscarClientesMorososResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo realizar la busqueda con los filtros enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<BuscarClientesMorososResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_BuscarClientesMorosos.");
        }
        catch (Exception ex) when (ex is InvalidOperationException or
                                   KeyNotFoundException or
                                   InvalidCastException or
                                   FormatException or
                                   OverflowException)
        {
            return ServiceResult<BuscarClientesMorososResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    private static ClienteMorosoResponse MapClienteMoroso(
        IReadOnlyDictionary<string, object?> row)
    {
        var prestamos = (row.GetString("PrestamosMorosos") ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

        return new ClienteMorosoResponse(
            row.GetInt32("SocioID"),
            row.GetString("Cedula") ?? string.Empty,
            row.GetString("NombreCompleto") ?? string.Empty,
            row.GetString("Correo"),
            row.GetString("Telefono"),
            row.GetString("EstadoSocio") ?? string.Empty,
            prestamos,
            row.GetInt32("CantidadPrestamosMorosos"),
            row.GetInt32("CantidadCuotasVencidas"),
            row.GetDateTime("FechaPrimeraCuotaVencida"),
            row.GetDateTime("FechaUltimaCuotaVencida"),
            row.GetInt32("DiasMoraMaximos"),
            row.GetString("NivelRiesgo") ?? string.Empty,
            row.GetDecimal("MontoTotalMora"),
            row.GetDecimal("SaldoTotalPrestamosMorosos"));
    }

    private static SqlParameter NullableText(string name, int size, string? value)
    {
        return new SqlParameter(name, SqlDbType.NVarChar, size)
        {
            Value = value is null ? DBNull.Value : value
        };
    }

    private static SqlParameter NullableDate(string name, DateTime? value)
    {
        return new SqlParameter(name, SqlDbType.Date)
        {
            Value = value.HasValue ? value.Value.Date : DBNull.Value
        };
    }

    private static SqlParameter Number(string name, int value)
    {
        return new SqlParameter(name, SqlDbType.Int)
        {
            Value = value
        };
    }

    private static bool IsBadRequest(SqlException ex)
    {
        return ex.Message.Contains("debe estar", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("no puede exceder", StringComparison.OrdinalIgnoreCase);
    }
}
