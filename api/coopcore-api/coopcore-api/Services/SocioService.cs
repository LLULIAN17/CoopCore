using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class SocioService : ISocioService
{
    private readonly ISqlExecutor _sqlExecutor;

    public SocioService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<SocioResponse>> ObtenerAsync(
        string id,
        CancellationToken cancellationToken = default)
    {
        id = id?.Trim() ?? string.Empty;

        if (string.IsNullOrWhiteSpace(id))
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El identificador del socio es obligatorio.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ConsultarSocio",
                new[]
                {
                    new SqlParameter("@Identificador", SqlDbType.NVarChar, 30)
                    {
                        Value = id
                    }
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            return row is null
                ? ServiceResult<SocioResponse>.Failure(
                    StatusCodes.Status404NotFound,
                    "Socio no encontrado.")
                : ServiceResult<SocioResponse>.Success(
                    MapSocio(row),
                    "Socio consultado correctamente.");
        }
        catch (SqlException ex) when (IsNotFound(ex))
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Socio no encontrado.");
        }
        catch (SqlException)
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ConsultarSocio.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<SocioResponse>> RegistrarAsync(
        RegistrarSocioRequest request,
        CancellationToken cancellationToken = default)
    {
        var cedula = request.Cedula?.Trim();
        var nombre = request.Nombre?.Trim();
        var apellido = request.Apellido?.Trim();

        if (string.IsNullOrWhiteSpace(cedula) ||
            string.IsNullOrWhiteSpace(nombre) ||
            string.IsNullOrWhiteSpace(apellido))
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "cedula, nombre y apellido son obligatorios.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_RegistrarSocio",
                new[]
                {
                    Text("@Cedula", 20, cedula),
                    Text("@Nombre", 80, nombre),
                    Text("@Apellido", 80, apellido),
                    NullableText("@Correo", 120, request.Correo),
                    NullableText("@Telefono", 30, request.Telefono),
                    NullableText("@Direccion", 250, request.Direccion),
                    NullableText("@CedulaEmpleadoRegistro", 20, request.CedulaEmpleadoRegistro)
                },
                cancellationToken);

            var row = result.FirstResultSet.First();
            var socio = new SocioResponse(
                row.GetInt32("SocioID"),
                row.GetString("Cedula") ?? cedula,
                row.GetString("Nombre") ?? nombre,
                row.GetString("Apellido") ?? apellido,
                request.Correo?.Trim(),
                request.Telefono?.Trim(),
                request.Direccion?.Trim(),
                "ACTIVO",
                null,
                null,
                null,
                null,
                null);

            return ServiceResult<SocioResponse>.Success(
                socio,
                row.GetString("Mensaje") ?? "Socio registrado correctamente.",
                StatusCodes.Status201Created);
        }
        catch (SqlException ex) when (ex.Message.Contains("Ya existe", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status409Conflict,
                "Ya existe un socio con la cedula indicada.");
        }
        catch (SqlException)
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_RegistrarSocio.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<SocioResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    private static SocioResponse MapSocio(IReadOnlyDictionary<string, object?> row)
    {
        return new SocioResponse(
            row.GetInt32("SocioID"),
            row.GetString("Cedula") ?? string.Empty,
            row.GetString("Nombre") ?? string.Empty,
            row.GetString("Apellido") ?? string.Empty,
            row.GetString("Correo"),
            row.GetString("Telefono"),
            row.GetString("Direccion"),
            row.GetString("Estado"),
            row.GetNullableDateTime("FechaRegistro"),
            row.GetNullableInt32("CantidadCuentas"),
            row.TryGetValue("SaldoTotalCuentas", out var saldoCuentas) && saldoCuentas is not null
                ? Convert.ToDecimal(saldoCuentas)
                : null,
            row.GetNullableInt32("CantidadPrestamos"),
            row.TryGetValue("SaldoTotalPrestamos", out var saldoPrestamos) && saldoPrestamos is not null
                ? Convert.ToDecimal(saldoPrestamos)
                : null);
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

    private static bool IsNotFound(SqlException ex)
    {
        return ex.Message.Contains("no existe", StringComparison.OrdinalIgnoreCase) ||
               ex.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase);
    }
}
