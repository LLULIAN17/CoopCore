using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
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
        numeroCuenta = numeroCuenta?.Trim() ?? string.Empty;

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
        catch (InvalidOperationException)
        {
            return ServiceResult<CuentaSaldoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<IReadOnlyList<MovimientoResponse>>> ConsultarMovimientosAsync(
        string numeroCuenta,
        DateTime? fechaInicio,
        DateTime? fechaFin,
        CancellationToken cancellationToken = default)
    {
        numeroCuenta = numeroCuenta?.Trim() ?? string.Empty;

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
        catch (InvalidOperationException)
        {
            return ServiceResult<IReadOnlyList<MovimientoResponse>>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<CrearCuentaResponse>> CrearAsync(
        CrearCuentaRequest request,
        CancellationToken cancellationToken = default)
    {
        var numeroCuenta = request.NumeroCuenta?.Trim();
        var cedulaSocio = request.CedulaSocio?.Trim();
        var codigoProducto = request.CodigoProducto?.Trim();
        var cedulaEmpleado = request.CedulaEmpleado?.Trim();
        var saldoInicial = request.SaldoInicial ?? 0;

        if (string.IsNullOrWhiteSpace(numeroCuenta) ||
            string.IsNullOrWhiteSpace(cedulaSocio) ||
            string.IsNullOrWhiteSpace(codigoProducto) ||
            string.IsNullOrWhiteSpace(cedulaEmpleado))
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroCuenta, cedulaSocio, codigoProducto y cedulaEmpleado son obligatorios.");
        }

        if (saldoInicial < 0)
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El saldoInicial no puede ser negativo.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_CrearCuenta",
                new[]
                {
                    Text("@NumeroCuenta", 30, numeroCuenta),
                    Text("@CedulaSocio", 20, cedulaSocio),
                    Text("@CodigoProducto", 20, codigoProducto),
                    Text("@CedulaEmpleado", 20, cedulaEmpleado),
                    Money("@SaldoInicial", saldoInicial)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<CrearCuentaResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            var cuenta = MapCrearCuenta(row);

            return ServiceResult<CrearCuentaResponse>.Success(
                cuenta,
                cuenta.Mensaje,
                StatusCodes.Status201Created);
        }
        catch (SqlException ex) when (IsConflict(ex))
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status409Conflict,
                "Ya existe una cuenta con ese numero.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Socio, producto financiero o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo crear la cuenta con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_CrearCuenta.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<CrearCuentaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<DepositoResponse>> RegistrarDepositoAsync(
        RegistrarDepositoRequest request,
        CancellationToken cancellationToken = default)
    {
        var numeroCuenta = request.NumeroCuenta?.Trim();
        var cedulaEmpleado = request.CedulaEmpleado?.Trim();
        var monto = request.Monto.GetValueOrDefault();

        if (string.IsNullOrWhiteSpace(numeroCuenta) ||
            string.IsNullOrWhiteSpace(cedulaEmpleado) ||
            !request.Monto.HasValue)
        {
            return ServiceResult<DepositoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroCuenta, monto y cedulaEmpleado son obligatorios.");
        }

        if (monto <= 0)
        {
            return ServiceResult<DepositoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El monto debe ser mayor que cero.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_RegistrarDeposito",
                new[]
                {
                    Text("@NumeroCuenta", 30, numeroCuenta),
                    Money("@Monto", monto),
                    Text("@CedulaEmpleado", 20, cedulaEmpleado),
                    NullableText("@Observacion", 300, request.Observacion)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<DepositoResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<DepositoResponse>.Success(
                MapDeposito(row),
                "Deposito registrado correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<DepositoResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Cuenta o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<DepositoResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo registrar el deposito con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<DepositoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_RegistrarDeposito.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<DepositoResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<RetiroResponse>> RegistrarRetiroAsync(
        RegistrarRetiroRequest request,
        CancellationToken cancellationToken = default)
    {
        var numeroCuenta = request.NumeroCuenta?.Trim();
        var cedulaEmpleado = request.CedulaEmpleado?.Trim();
        var monto = request.Monto.GetValueOrDefault();

        if (string.IsNullOrWhiteSpace(numeroCuenta) ||
            string.IsNullOrWhiteSpace(cedulaEmpleado) ||
            !request.Monto.HasValue)
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroCuenta, monto y cedulaEmpleado son obligatorios.");
        }

        if (monto <= 0)
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El monto debe ser mayor que cero.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_RegistrarRetiro",
                new[]
                {
                    Text("@NumeroCuenta", 30, numeroCuenta),
                    Money("@Monto", monto),
                    Text("@CedulaEmpleado", 20, cedulaEmpleado),
                    NullableText("@Observacion", 300, request.Observacion)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<RetiroResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<RetiroResponse>.Success(
                MapRetiro(row),
                "Retiro registrado correctamente.");
        }
        catch (SqlException ex) when (IsInsufficientFunds(ex))
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status409Conflict,
                "Saldo insuficiente para realizar el retiro.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Cuenta o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo registrar el retiro con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_RegistrarRetiro.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<RetiroResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<TransferenciaResponse>> RegistrarTransferenciaAsync(
        RegistrarTransferenciaRequest request,
        CancellationToken cancellationToken = default)
    {
        var numeroCuentaOrigen = request.NumeroCuentaOrigen?.Trim();
        var numeroCuentaDestino = request.NumeroCuentaDestino?.Trim();
        var cedulaEmpleado = request.CedulaEmpleado?.Trim();
        var monto = request.Monto.GetValueOrDefault();

        if (string.IsNullOrWhiteSpace(numeroCuentaOrigen) ||
            string.IsNullOrWhiteSpace(numeroCuentaDestino) ||
            string.IsNullOrWhiteSpace(cedulaEmpleado) ||
            !request.Monto.HasValue)
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "numeroCuentaOrigen, numeroCuentaDestino, monto y cedulaEmpleado son obligatorios.");
        }

        if (numeroCuentaOrigen.Equals(numeroCuentaDestino, StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "La cuenta origen y la cuenta destino deben ser diferentes.");
        }

        if (monto <= 0)
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El monto debe ser mayor que cero.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_RegistrarTransferencia",
                new[]
                {
                    Text("@NumeroCuentaOrigen", 30, numeroCuentaOrigen),
                    Text("@NumeroCuentaDestino", 30, numeroCuentaDestino),
                    Money("@Monto", monto),
                    Text("@CedulaEmpleado", 20, cedulaEmpleado),
                    NullableText("@Observacion", 300, request.Observacion)
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<TransferenciaResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            return ServiceResult<TransferenciaResponse>.Success(
                MapTransferencia(row),
                "Transferencia registrada correctamente.");
        }
        catch (SqlException ex) when (IsInsufficientFunds(ex))
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status409Conflict,
                "Saldo insuficiente en la cuenta origen.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Cuenta o empleado no encontrado.");
        }
        catch (SqlException ex) when (IsBadRequest(ex))
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "No se pudo registrar la transferencia con los datos enviados.");
        }
        catch (SqlException)
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_RegistrarTransferencia.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<TransferenciaResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
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

    private static CrearCuentaResponse MapCrearCuenta(IReadOnlyDictionary<string, object?> row)
    {
        return new CrearCuentaResponse(
            row.GetInt32("CuentaID"),
            row.GetString("NumeroCuenta") ?? string.Empty,
            row.GetDecimal("SaldoInicial"),
            row.GetString("Mensaje") ?? "Cuenta creada correctamente.");
    }

    private static DepositoResponse MapDeposito(IReadOnlyDictionary<string, object?> row)
    {
        return new DepositoResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt64("MovimientoID"),
            row.GetString("Referencia") ?? string.Empty,
            row.GetString("NumeroCuenta") ?? string.Empty,
            row.GetDecimal("SaldoAnterior"),
            row.GetDecimal("MontoDepositado"),
            row.GetDecimal("SaldoNuevo"));
    }

    private static RetiroResponse MapRetiro(IReadOnlyDictionary<string, object?> row)
    {
        return new RetiroResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetInt64("MovimientoID"),
            row.GetString("Referencia") ?? string.Empty,
            row.GetString("NumeroCuenta") ?? string.Empty,
            row.GetDecimal("SaldoAnterior"),
            row.GetDecimal("MontoRetirado"),
            row.GetDecimal("SaldoNuevo"));
    }

    private static TransferenciaResponse MapTransferencia(IReadOnlyDictionary<string, object?> row)
    {
        return new TransferenciaResponse(
            row.GetString("Resultado") ?? string.Empty,
            row.GetString("Referencia") ?? string.Empty,
            row.GetInt64("MovimientoSalidaID"),
            row.GetInt64("MovimientoEntradaID"),
            row.GetString("NumeroCuentaOrigen") ?? string.Empty,
            row.GetDecimal("SaldoOrigenAnterior"),
            row.GetDecimal("SaldoOrigenNuevo"),
            row.GetString("NumeroCuentaDestino") ?? string.Empty,
            row.GetDecimal("SaldoDestinoAnterior"),
            row.GetDecimal("SaldoDestinoNuevo"),
            row.GetDecimal("MontoTransferido"));
    }

    private static SqlParameter Text(string name, int size, string value)
    {
        return new SqlParameter(name, SqlDbType.NVarChar, size)
        {
            Value = value
        };
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

    private static SqlParameter Money(string name, decimal value)
    {
        return new SqlParameter(name, SqlDbType.Decimal)
        {
            Precision = 18,
            Scale = 2,
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
        return ex.Message.Contains("Ya existe", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsInsufficientFunds(SqlException ex)
    {
        return ex.Message.Contains("Saldo insuficiente", StringComparison.OrdinalIgnoreCase);
    }

    private static bool IsBadRequest(SqlException ex)
    {
        return ex.Message.Contains("obligatorio", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("debe ser", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("no puede", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("menor", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("solo permite", StringComparison.OrdinalIgnoreCase);
    }
}
