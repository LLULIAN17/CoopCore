using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class CobranzaService : ICobranzaService
{
    private static readonly string[] ManagementTypes =
        ["LLAMADA", "CORREO", "SMS", "VISITA", "ACUERDO", "OTRO"];
    private static readonly string[] ManagementResults =
        ["CONTACTADO", "SIN_RESPUESTA", "COMPROMISO_PAGO", "PAGADO", "REPROGRAMAR", "OTRO"];

    private readonly ISqlExecutor _sqlExecutor;

    public CobranzaService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<AlertasCobranzaResponse>> ConsultarAlertasAsync(
        ConsultarAlertasCobranzaRequest request,
        CancellationToken cancellationToken = default)
    {
        if (request.DiasProximos is < 0 or > 90)
        {
            return ServiceResult<AlertasCobranzaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "diasProximos debe estar entre 0 y 90.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarAlertasCobranza",
                new[]
                {
                    NullableDate("@FechaCorte", request.FechaCorte),
                    Number("@DiasProximos", request.DiasProximos),
                    Flag("@SoloVencidas", request.SoloVencidas)
                },
                cancellationToken);

            var alerts = result.FirstResultSet.Select(MapAlert).ToArray();
            var response = new AlertasCobranzaResponse(
                request.FechaCorte?.Date ?? DateTime.Today,
                request.DiasProximos,
                alerts.Length,
                alerts.Count(item => item.TipoAlerta == "VENCIDA"),
                alerts.Count(item => item.TipoAlerta != "VENCIDA"),
                alerts.Sum(item => item.MontoPendiente),
                alerts);

            return ServiceResult<AlertasCobranzaResponse>.Success(
                response,
                "Alertas de cobranza consultadas correctamente.");
        }
        catch (SqlException)
        {
            return ServiceResult<AlertasCobranzaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al consultar las alertas de cobranza.");
        }
    }

    public async Task<ServiceResult<GestionCobranzaResponse>> RegistrarGestionAsync(
        RegistrarGestionCobranzaRequest request,
        CancellationToken cancellationToken = default)
    {
        var loan = request.NumeroPrestamo?.Trim();
        var employee = request.CedulaEmpleado?.Trim();
        var type = Normalize(request.TipoGestion);
        var resultName = Normalize(request.Resultado);
        var comment = request.Comentario?.Trim();

        if (loan is null || employee is null || type is null || resultName is null || comment is null)
        {
            return ServiceResult<GestionCobranzaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "Los datos principales de la gestion son obligatorios.");
        }
        if (!ManagementTypes.Contains(type) || !ManagementResults.Contains(resultName))
        {
            return ServiceResult<GestionCobranzaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "Tipo o resultado de gestion invalido.");
        }
        if (resultName == "COMPROMISO_PAGO" &&
            (!request.FechaCompromiso.HasValue || !request.MontoCompromiso.HasValue ||
             request.MontoCompromiso <= 0))
        {
            return ServiceResult<GestionCobranzaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "Un compromiso de pago requiere fecha y monto.");
        }

        try
        {
            var execution = await _sqlExecutor.ExecuteAsync(
                "coop.sp_RegistrarGestionCobranza",
                new[]
                {
                    Text("@NumeroPrestamo", 30, loan),
                    Text("@CedulaEmpleado", 20, employee),
                    Text("@TipoGestion", 20, type),
                    Text("@Resultado", 30, resultName),
                    Text("@Comentario", 500, comment),
                    NullableDate("@FechaCompromiso", request.FechaCompromiso),
                    NullableMoney("@MontoCompromiso", request.MontoCompromiso)
                },
                cancellationToken);

            var row = execution.FirstResultSet.FirstOrDefault();
            if (row is null)
            {
                return ServiceResult<GestionCobranzaResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "La gestion no devolvio resultado.");
            }

            return ServiceResult<GestionCobranzaResponse>.Success(
                MapManagement(row),
                "Gestion de cobranza registrada correctamente.",
                StatusCodes.Status201Created);
        }
        catch (SqlException ex) when (ex.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<GestionCobranzaResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Prestamo o empleado no encontrado.");
        }
        catch (SqlException)
        {
            return ServiceResult<GestionCobranzaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al registrar la gestion de cobranza.");
        }
    }

    private static AlertaCobranzaResponse MapAlert(IReadOnlyDictionary<string, object?> row)
    {
        return new AlertaCobranzaResponse(
            row.GetInt32("CuotaID"),
            row.GetInt32("SocioID"),
            row.GetString("Cedula") ?? string.Empty,
            row.GetString("NombreCliente") ?? string.Empty,
            row.GetString("Telefono"),
            row.GetString("Correo"),
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetInt32("NumeroCuota"),
            row.GetDateTime("FechaVencimiento"),
            row.GetDecimal("MontoPendiente"),
            row.GetString("TipoAlerta") ?? string.Empty,
            row.GetString("Prioridad") ?? string.Empty,
            row.GetInt32("DiasMora"),
            row.GetInt32("DiasParaVencer"),
            row.GetNullableDateTime("UltimaGestionFecha"),
            row.GetString("UltimaGestionTipo"),
            row.GetString("UltimaGestionResultado"),
            row.GetNullableDateTime("FechaCompromiso"),
            NullableDecimal(row, "MontoCompromiso"));
    }

    private static GestionCobranzaResponse MapManagement(
        IReadOnlyDictionary<string, object?> row)
    {
        return new GestionCobranzaResponse(
            row.GetString("ResultadoOperacion") ?? string.Empty,
            row.GetInt64("GestionCobranzaID"),
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetDateTime("FechaGestion"),
            row.GetString("TipoGestion") ?? string.Empty,
            row.GetString("Resultado") ?? string.Empty,
            row.GetString("Comentario") ?? string.Empty,
            row.GetNullableDateTime("FechaCompromiso"),
            NullableDecimal(row, "MontoCompromiso"),
            row.GetString("CedulaEmpleado") ?? string.Empty,
            row.GetString("NombreEmpleado") ?? string.Empty);
    }

    private static decimal? NullableDecimal(IReadOnlyDictionary<string, object?> row, string name) =>
        row.TryGetValue(name, out var value) && value is not null ? Convert.ToDecimal(value) : null;

    private static string? Normalize(string? value) =>
        string.IsNullOrWhiteSpace(value) ? null : value.Trim().ToUpperInvariant();

    private static SqlParameter Text(string name, int size, string value) =>
        new(name, SqlDbType.NVarChar, size) { Value = value };

    private static SqlParameter Number(string name, int value) =>
        new(name, SqlDbType.Int) { Value = value };

    private static SqlParameter Flag(string name, bool value) =>
        new(name, SqlDbType.Bit) { Value = value };

    private static SqlParameter NullableDate(string name, DateTime? value) =>
        new(name, SqlDbType.Date) { Value = value.HasValue ? value.Value.Date : DBNull.Value };

    private static SqlParameter NullableMoney(string name, decimal? value) =>
        new(name, SqlDbType.Decimal)
        {
            Precision = 18,
            Scale = 2,
            Value = value.HasValue ? value.Value : DBNull.Value
        };
}
