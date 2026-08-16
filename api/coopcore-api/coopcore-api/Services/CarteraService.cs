using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class CarteraService : ICarteraService
{
    private readonly ISqlExecutor _sqlExecutor;

    public CarteraService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<DashboardCarteraResponse>> ConsultarDashboardAsync(
        ConsultarDashboardCarteraRequest request,
        CancellationToken cancellationToken = default)
    {
        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarDashboardCartera",
                new[] { NullableDate("@FechaCorte", request.FechaCorte) },
                cancellationToken);

            var summary = result.FirstResultSet.FirstOrDefault();
            if (summary is null)
            {
                return ServiceResult<DashboardCarteraResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El dashboard no devolvio su resumen.");
            }

            var risks = result.ResultSets.Count > 1
                ? result.ResultSets[1].Select(MapRisk).ToArray()
                : Array.Empty<RiesgoCarteraResponse>();
            var dueDates = result.ResultSets.Count > 2
                ? result.ResultSets[2].Select(MapDueDate).ToArray()
                : Array.Empty<ProximoVencimientoResponse>();

            var response = new DashboardCarteraResponse(
                summary.GetDateTime("FechaCorte"),
                summary.GetInt32("TotalSociosActivos"),
                summary.GetInt32("TotalPrestamosVigentes"),
                summary.GetDecimal("SaldoCarteraTotal"),
                summary.GetInt32("PrestamosConMora"),
                summary.GetInt32("ClientesMorosos"),
                summary.GetDecimal("MontoVencido"),
                summary.GetInt32("CuotasVencidas"),
                summary.GetDecimal("IndiceMorosidadPct"),
                risks,
                dueDates);

            return ServiceResult<DashboardCarteraResponse>.Success(
                response,
                "Dashboard de cartera consultado correctamente.");
        }
        catch (SqlException)
        {
            return ServiceResult<DashboardCarteraResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ConsultarDashboardCartera.");
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return ServiceResult<DashboardCarteraResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del dashboard.");
        }
    }

    private static RiesgoCarteraResponse MapRisk(IReadOnlyDictionary<string, object?> row)
    {
        return new RiesgoCarteraResponse(
            row.GetString("NivelRiesgo") ?? string.Empty,
            row.GetInt32("CantidadClientes"),
            row.GetDecimal("MontoVencido"));
    }

    private static ProximoVencimientoResponse MapDueDate(
        IReadOnlyDictionary<string, object?> row)
    {
        return new ProximoVencimientoResponse(
            row.GetInt32("SocioID"),
            row.GetString("Cedula") ?? string.Empty,
            row.GetString("NombreCliente") ?? string.Empty,
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetInt32("NumeroCuota"),
            row.GetDateTime("FechaVencimiento"),
            row.GetDecimal("MontoPendiente"),
            row.GetInt32("DiasParaVencer"));
    }

    private static SqlParameter NullableDate(string name, DateTime? value)
    {
        return new SqlParameter(name, SqlDbType.Date)
        {
            Value = value.HasValue ? value.Value.Date : DBNull.Value
        };
    }
}
