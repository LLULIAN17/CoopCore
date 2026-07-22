using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
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
        string numeroPrestamo,
        CancellationToken cancellationToken = default)
    {
        numeroPrestamo = numeroPrestamo?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(numeroPrestamo))
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
                        Value = numeroPrestamo
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
        catch (InvalidOperationException)
        {
            return ServiceResult<PrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<SolicitarPrestamoResponse>> SolicitarAsync(
        SolicitarPrestamoRequest request,
        CancellationToken cancellationToken = default)
    {
        var cedulaSocio = request.CedulaSocio?.Trim();
        var codigoProducto = request.CodigoProducto?.Trim();
        var cedulaEmpleado = request.CedulaEmpleado?.Trim();
        var montoSolicitado = request.MontoSolicitado.GetValueOrDefault();
        var plazoMeses = request.PlazoMeses.GetValueOrDefault();

        if (string.IsNullOrWhiteSpace(cedulaSocio) ||
            string.IsNullOrWhiteSpace(codigoProducto) ||
            string.IsNullOrWhiteSpace(cedulaEmpleado) ||
            !request.MontoSolicitado.HasValue ||
            !request.PlazoMeses.HasValue)
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "cedulaSocio, codigoProducto, montoSolicitado, plazoMeses y cedulaEmpleado son obligatorios.");
        }

        if (montoSolicitado <= 0)
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El montoSolicitado debe ser mayor que cero.");
        }

        if (plazoMeses <= 0)
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El plazoMeses debe ser mayor que cero.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_SolicitarPrestamo",
                new[]
                {
                    Text("@CedulaSocio", 20, cedulaSocio),
                    Text("@CodigoProducto", 20, codigoProducto),
                    Money("@MontoSolicitado", montoSolicitado),
                    Number("@PlazoMeses", plazoMeses),
                    Text("@CedulaEmpleado", 20, cedulaEmpleado)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<SolicitarPrestamoResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<SolicitarPrestamoResponse>.Success(
                MapSolicitarPrestamo(row),
                "Prestamo solicitado correctamente.",
                StatusCodes.Status201Created);
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Socio, producto financiero o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo solicitar el prestamo con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_SolicitarPrestamo.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<SolicitarPrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<AprobarPrestamoResponse>> AprobarAsync(
        string numeroPrestamo,
        AprobarPrestamoRequest request,
        CancellationToken cancellationToken = default)
    {
        numeroPrestamo = numeroPrestamo?.Trim() ?? string.Empty;
        var cedulaEmpleadoAprueba = request.CedulaEmpleadoAprueba?.Trim();

        if (string.IsNullOrWhiteSpace(numeroPrestamo) ||
            string.IsNullOrWhiteSpace(cedulaEmpleadoAprueba))
        {
            return ServiceResult<AprobarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroPrestamo y cedulaEmpleadoAprueba son obligatorios.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_AprobarPrestamo",
                new[]
                {
                    Text("@NumeroPrestamo", 30, numeroPrestamo),
                    Text("@CedulaEmpleadoAprueba", 20, cedulaEmpleadoAprueba)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<AprobarPrestamoResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<AprobarPrestamoResponse>.Success(
                MapAprobarPrestamo(row),
                "Prestamo aprobado correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<AprobarPrestamoResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Prestamo o empleado aprobador no encontrado.");
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            return ServiceResult<AprobarPrestamoResponse>.Failure(
                StatusCodes.Status409Conflict,
                "El prestamo no se puede aprobar en su estado actual.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<AprobarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo aprobar el prestamo con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<AprobarPrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_AprobarPrestamo.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<AprobarPrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<RechazarPrestamoResponse>> RechazarAsync(
        string numeroPrestamo,
        RechazarPrestamoRequest request,
        CancellationToken cancellationToken = default)
    {
        numeroPrestamo = numeroPrestamo?.Trim() ?? string.Empty;
        var cedulaEmpleadoRechaza = request.CedulaEmpleadoRechaza?.Trim();
        var motivo = request.Motivo?.Trim();

        if (string.IsNullOrWhiteSpace(numeroPrestamo) ||
            string.IsNullOrWhiteSpace(cedulaEmpleadoRechaza) ||
            string.IsNullOrWhiteSpace(motivo))
        {
            return ServiceResult<RechazarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroPrestamo, cedulaEmpleadoRechaza y motivo son obligatorios.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_RechazarPrestamo",
                new[]
                {
                    Text("@NumeroPrestamo", 30, numeroPrestamo),
                    Text("@CedulaEmpleadoRechaza", 20, cedulaEmpleadoRechaza),
                    Text("@Motivo", 300, motivo)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<RechazarPrestamoResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<RechazarPrestamoResponse>.Success(
                MapRechazarPrestamo(row),
                "Prestamo rechazado correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<RechazarPrestamoResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Prestamo o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            return ServiceResult<RechazarPrestamoResponse>.Failure(
                StatusCodes.Status409Conflict,
                "El prestamo no se puede rechazar en su estado actual.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<RechazarPrestamoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo rechazar el prestamo con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<RechazarPrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_RechazarPrestamo.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<RechazarPrestamoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<GenerarAmortizacionResponse>> GenerarAmortizacionAsync(
        GenerarAmortizacionRequest request,
        CancellationToken cancellationToken = default)
    {
        var numeroPrestamo = request.NumeroPrestamo?.Trim();

        if (string.IsNullOrWhiteSpace(numeroPrestamo))
        {
            return ServiceResult<GenerarAmortizacionResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El numeroPrestamo es obligatorio.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_GenerarAmortizacion",
                new[]
                {
                    Text("@NumeroPrestamo", 30, numeroPrestamo)
                },
                cancellationToken);

            var rows = result.FirstResultSet;
            var first = rows.FirstOrDefault();

            if (first is null)
            {
                return ServiceResult<GenerarAmortizacionResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            var cuotas = rows.Select(MapAmortizacionCuota).ToArray();
            var response = new GenerarAmortizacionResponse(
                first.GetString("Resultado") ?? "AMORTIZACION_GENERADA",
                first.GetString("NumeroPrestamo") ?? numeroPrestamo,
                cuotas);

            return ServiceResult<GenerarAmortizacionResponse>.Success(
                response,
                "Amortizacion generada correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<GenerarAmortizacionResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Prestamo no encontrado.");
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            return ServiceResult<GenerarAmortizacionResponse>.Failure(
                StatusCodes.Status409Conflict,
                "No se puede generar amortizacion para el prestamo en su estado actual.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<GenerarAmortizacionResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo generar la amortizacion con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<GenerarAmortizacionResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_GenerarAmortizacion.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<GenerarAmortizacionResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<PagarCuotaResponse>> PagarCuotaAsync(
        string numeroPrestamo,
        int numeroCuota,
        PagarCuotaRequest request,
        CancellationToken cancellationToken = default)
    {
        numeroPrestamo = numeroPrestamo?.Trim() ?? string.Empty;
        var numeroCuentaOrigen = request.NumeroCuentaOrigen?.Trim();
        var cedulaEmpleado = request.CedulaEmpleado?.Trim();
        var montoPago = request.MontoPago.GetValueOrDefault();

        if (string.IsNullOrWhiteSpace(numeroPrestamo) ||
            string.IsNullOrWhiteSpace(numeroCuentaOrigen) ||
            string.IsNullOrWhiteSpace(cedulaEmpleado) ||
            !request.MontoPago.HasValue)
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroPrestamo, numeroCuentaOrigen, montoPago y cedulaEmpleado son obligatorios.");
        }

        if (numeroCuota <= 0)
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El numeroCuota debe ser mayor que cero.");
        }

        if (montoPago <= 0)
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El montoPago debe ser mayor que cero.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_PagarCuota",
                new[]
                {
                    Text("@NumeroPrestamo", 30, numeroPrestamo),
                    Number("@NumeroCuota", numeroCuota),
                    Money("@MontoPago", montoPago),
                    Text("@NumeroCuentaOrigen", 30, numeroCuentaOrigen),
                    Text("@CedulaEmpleado", 20, cedulaEmpleado)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<PagarCuotaResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<PagarCuotaResponse>.Success(
                MapPagarCuota(row),
                "Cuota pagada correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Prestamo, cuota, cuenta o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status409Conflict,
                "No se pudo pagar la cuota por el estado actual del prestamo, la cuota o la cuenta.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo pagar la cuota con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_PagarCuota.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<PagarCuotaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
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
            row.GetNullableDateTime("FechaDesembolso"),
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

    private static SolicitarPrestamoResponse MapSolicitarPrestamo(
        IReadOnlyDictionary<string, object?> row)
    {
        return new SolicitarPrestamoResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt32("PrestamoID"),
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetString("CedulaSocio") ?? string.Empty,
            row.GetString("CodigoProducto") ?? string.Empty,
            row.GetDecimal("MontoOriginal"),
            row.GetDecimal("SaldoPendiente"),
            row.GetDecimal("TasaInteres"),
            row.GetInt32("PlazoMeses"),
            row.GetString("EstadoPrestamo") ?? string.Empty);
    }

    private static AprobarPrestamoResponse MapAprobarPrestamo(
        IReadOnlyDictionary<string, object?> row)
    {
        return new AprobarPrestamoResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt32("PrestamoID"),
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetDecimal("MontoOriginal"),
            row.GetDecimal("SaldoPendiente"),
            row.GetDecimal("TasaInteres"),
            row.GetInt32("PlazoMeses"),
            row.GetDateTime("FechaDesembolso"),
            row.GetString("EstadoPrestamo") ?? string.Empty,
            row.GetString("CedulaEmpleadoAprueba") ?? string.Empty);
    }

    private static RechazarPrestamoResponse MapRechazarPrestamo(
        IReadOnlyDictionary<string, object?> row)
    {
        return new RechazarPrestamoResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt32("PrestamoID"),
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetDecimal("MontoOriginal"),
            row.GetDecimal("SaldoPendiente"),
            row.GetString("EstadoPrestamo") ?? string.Empty,
            row.GetString("Motivo") ?? string.Empty,
            row.GetString("CedulaEmpleadoRechaza") ?? string.Empty);
    }

    private static AmortizacionCuotaResponse MapAmortizacionCuota(
        IReadOnlyDictionary<string, object?> row)
    {
        return new AmortizacionCuotaResponse(
            row.GetInt32("NumeroCuota"),
            row.GetDateTime("FechaVencimiento"),
            row.GetDecimal("MontoCuota"),
            row.GetDecimal("MontoPagado"),
            row.GetString("EstadoCuota") ?? string.Empty);
    }

    private static PagarCuotaResponse MapPagarCuota(
        IReadOnlyDictionary<string, object?> row)
    {
        return new PagarCuotaResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt64("MovimientoID"),
            row.GetString("Referencia") ?? string.Empty,
            row.GetString("NumeroPrestamo") ?? string.Empty,
            row.GetInt32("NumeroCuota"),
            row.GetDecimal("MontoCuota"),
            row.GetDecimal("MontoPagadoAnterior"),
            row.GetDecimal("MontoPago"),
            row.GetDecimal("MontoPagadoNuevo"),
            row.GetString("EstadoCuota") ?? string.Empty,
            row.GetDecimal("SaldoPrestamoAnterior"),
            row.GetDecimal("SaldoPrestamoNuevo"),
            row.GetString("EstadoPrestamo") ?? string.Empty,
            row.GetString("NumeroCuentaOrigen") ?? string.Empty,
            row.GetDecimal("SaldoCuentaAnterior"),
            row.GetDecimal("SaldoCuentaNuevo"));
    }

    private static SqlParameter Text(string name, int size, string value)
    {
        return new SqlParameter(name, SqlDbType.NVarChar, size)
        {
            Value = value
        };
    }

    private static SqlParameter Money(string name, decimal value)
    {
        return new SqlParameter(name, SqlDbType.Decimal)
        {
            Precision = 18,
            Scale = 2,
            Value = value
        };
    }

    private static SqlParameter Number(string name, int value)
    {
        return new SqlParameter(name, SqlDbType.Int)
        {
            Value = value
        };
    }

    private static bool IsNotFound(SqlException ex)
    {
        return ex.Message.Contains("no existe", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("inactivo", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsConflict(SqlException ex)
    {
        return ex.Message.Contains("Solo se pueden", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("ya tiene cuotas", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("ya esta pagada", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("Saldo insuficiente", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("monto pendiente", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("saldo pendiente", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("estado actual", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsBadRequest(SqlException ex)
    {
        return ex.Message.Contains("obligatorio", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("debe ser mayor", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("debe ser de tipo", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("no puede", StringComparison.OrdinalIgnoreCase);
    }
}
