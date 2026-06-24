using System.Data;
using CoopCore.Api.Db;
using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;
using Microsoft.Data.SqlClient;

namespace CoopCore.Api.Services;

public sealed class AuthService : IAuthService
{
    private readonly ISqlExecutor _sqlExecutor;

    public AuthService(ISqlExecutor sqlExecutor)
    {
        _sqlExecutor = sqlExecutor;
    }

    public async Task<ServiceResult<LoginResponse>> LoginAsync(
        LoginRequest request,
        CancellationToken cancellationToken = default)
    {
        var usuario = request.Usuario?.Trim();

        if (string.IsNullOrWhiteSpace(usuario) || string.IsNullOrWhiteSpace(request.Password))
        {
            return ServiceResult<LoginResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "usuario y password son obligatorios.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_ValidarLogin",
                new[]
                {
                    new SqlParameter("@NombreUsuario", SqlDbType.NVarChar, 50)
                    {
                        Value = usuario
                    },
                    new SqlParameter("@Password", SqlDbType.NVarChar, 100)
                    {
                        Value = request.Password
                    }
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<LoginResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            var estado = row.GetString("Resultado") ?? "FALLO";
            var mensaje = row.GetString("Mensaje") ?? "Credenciales invalidas.";

            if (estado.Equals("OK", StringComparison.OrdinalIgnoreCase))
            {
                var login = new LoginResponse(
                    row.GetInt32("EmpleadoID"),
                    row.GetString("NombreUsuario"),
                    row.GetString("Nombre"),
                    row.GetString("Apellido"),
                    row.GetString("Correo"),
                    row.GetString("NombreRol"),
                    null);

                return ServiceResult<LoginResponse>.Success(login, mensaje);
            }

            if (estado.Equals("BLOQUEADO", StringComparison.OrdinalIgnoreCase))
            {
                var bloqueo = new LoginResponse(
                    null,
                    usuario,
                    null,
                    null,
                    null,
                    null,
                    row.GetNullableDateTime("BloqueadoHasta"));

                return ServiceResult<LoginResponse>.Failure(
                    StatusCodes.Status423Locked,
                    mensaje,
                    bloqueo);
            }

            return ServiceResult<LoginResponse>.Failure(
                StatusCodes.Status401Unauthorized,
                mensaje);
        }
        catch (SqlException)
        {
            return ServiceResult<LoginResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_ValidarLogin.");
        }
        catch (InvalidOperationException ex)
        {
            return ServiceResult<LoginResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                ex.Message);
        }
    }
}
