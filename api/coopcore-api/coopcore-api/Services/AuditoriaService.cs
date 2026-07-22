using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class AuditoriaService : IAuditoriaService
{
    private readonly ISqlExecutor _sqlExecutor;

    public AuditoriaService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<IReadOnlyList<AuditoriaResponse>>> ConsultarAsync(
        ConsultarAuditoriaRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.FechaInicio.HasValue &&
            request.FechaFin.HasValue &&
            request.FechaInicio > request.FechaFin)
        {
            return ServiceResult<IReadOnlyList<AuditoriaResponse>>.Failure(
                StatusCodes.Status400BadRequest,
                "fechaInicio no puede ser mayor que fechaFin.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarAuditoria",
                new[]
                {
                    NullableDate("@FechaInicio", request.FechaInicio),
                    NullableDate("@FechaFin", request.FechaFin),
                    NullableText("@Entidad", 100, request.Entidad),
                    NullableText("@Accion", 30, request.Accion),
                    NullableText("@CedulaEmpleado", 20, request.CedulaEmpleado)
                },
                cancellationToken);

            var eventos = result.FirstResultSet
                .Select(MapAuditoria)
                .ToArray();

            return ServiceResult<IReadOnlyList<AuditoriaResponse>>.Success(
                eventos,
                "Auditoria consultada correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<IReadOnlyList<AuditoriaResponse>>.Failure(
                StatusCodes.Status404NotFound,
                "Empleado no encontrado.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<IReadOnlyList<AuditoriaResponse>>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo consultar la auditoria con los filtros enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<IReadOnlyList<AuditoriaResponse>>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ConsultarAuditoria.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<IReadOnlyList<AuditoriaResponse>>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    private static AuditoriaResponse MapAuditoria(IReadOnlyDictionary<string, object?> row)
    {
        return new AuditoriaResponse(
            row.GetInt64("AuditoriaID"),
            row.GetDateTime("FechaEvento"),
            row.GetString("Entidad") ?? string.Empty,
            row.GetString("EntidadID"),
            row.GetString("Accion") ?? string.Empty,
            row.GetString("Descripcion"),
            row.GetString("UsuarioSQL") ?? string.Empty,
            row.GetString("UsuarioBD") ?? string.Empty,
            row.GetString("CedulaEmpleado"),
            row.GetString("NombreEmpleado"));
    }

    private static SqlParameter NullableText(string name, int size, string? value)
    {
        return new SqlParameter(name, SqlDbType.NVarChar, size)
        {
            Value = string.IsNullOrWhiteSpace(value)
                ? DBNull.Value
                : value.Trim()
        };
    }

    private static SqlParameter NullableDate(string name, DateTime? value)
    {
        return new SqlParameter(name, SqlDbType.DateTime2)
        {
            Value = value.HasValue ? value.Value : DBNull.Value
        };
    }

    private static bool IsNotFound(SqlException ex)
    {
        return ex.Message.Contains("no existe", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsBadRequest(SqlException ex)
    {
        return ex.Message.Contains("no puede", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("invalido", StringComparison.OrdinalIgnoreCase);
    }
}
