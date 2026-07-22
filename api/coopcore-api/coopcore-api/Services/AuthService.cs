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
    private readonly IJwtTokenService _jwtTokenService;

    public AuthService(
        ISqlExecutor sqlExecutor,
        IJwtTokenService jwtTokenService)
    {
        _sqlExecutor = sqlExecutor;
        _jwtTokenService = jwtTokenService;
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
                var empleadoId = row.GetInt32("EmpleadoID");
                var nombreUsuario = row.GetString("NombreUsuario") ?? usuario;
                var nombre = row.GetString("Nombre");
                var apellido = row.GetString("Apellido");
                var correo = row.GetString("Correo");
                var rol = row.GetString("NombreRol");

                if (string.IsNullOrWhiteSpace(rol))
                {
                    return ServiceResult<LoginResponse>.Failure(
                        StatusCodes.Status500InternalServerError,
                        "El empleado autenticado no tiene rol de aplicacion asignado.");
                }

                var token = _jwtTokenService.GenerateToken(
                    empleadoId,
                    nombreUsuario,
                    nombre,
                    apellido,
                    correo,
                    rol);

                var login = new LoginResponse(
                    empleadoId,
                    nombreUsuario,
                    nombre,
                    apellido,
                    correo,
                    rol,
                    token.Token,
                    token.ExpiraEn,
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
        catch (InvalidOperationException)
        {
            return ServiceResult<LoginResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }

    public async Task<ServiceResult<CambiarPasswordResponse>> CambiarPasswordAsync(
        CambiarPasswordRequest request,
        CancellationToken cancellationToken = default)
    {
        var usuario = request.Usuario?.Trim();

        if (string.IsNullOrWhiteSpace(usuario) ||
            string.IsNullOrWhiteSpace(request.PasswordActual) ||
            string.IsNullOrWhiteSpace(request.PasswordNuevo))
        {
            return ServiceResult<CambiarPasswordResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "usuario, passwordActual y passwordNuevo son obligatorios.");
        }

        if (request.PasswordNuevo.Length < 8)
        {
            return ServiceResult<CambiarPasswordResponse>.Failure(
                StatusCodes.Status400BadRequest,
                "El nuevo password debe tener al menos 8 caracteres.");
        }

        try
        {
            var result = await _sqlExecutor.ExecuteAsync(
                "coop.sp_CambiarPassword",
                new[]
                {
                    new SqlParameter("@NombreUsuario", SqlDbType.NVarChar, 50)
                    {
                        Value = usuario
                    },
                    new SqlParameter("@PasswordActual", SqlDbType.NVarChar, 100)
                    {
                        Value = request.PasswordActual
                    },
                    new SqlParameter("@PasswordNuevo", SqlDbType.NVarChar, 100)
                    {
                        Value = request.PasswordNuevo
                    }
                },
                cancellationToken);

            var row = result.FirstResultSet.FirstOrDefault();

            if (row is null)
            {
                return ServiceResult<CambiarPasswordResponse>.Failure(
                    StatusCodes.Status500InternalServerError,
                    "El stored procedure no devolvio resultado.");
            }

            var response = new CambiarPasswordResponse(
                row.GetString("Resultado") ?? "OK",
                row.GetString("Mensaje") ?? "Password actualizado correctamente.");

            return ServiceResult<CambiarPasswordResponse>.Success(
                response,
                response.Mensaje);
        }
        catch (SqlException ex) when (ex.Message.Contains("incorrecto", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<CambiarPasswordResponse>.Failure(
                StatusCodes.Status401Unauthorized,
                "Password actual incorrecto.");
        }
        catch (SqlException ex) when (ex.Message.Contains("no encontrado", StringComparison.OrdinalIgnoreCase) ||
                                      ex.Message.Contains("inactivo", StringComparison.OrdinalIgnoreCase))
        {
            return ServiceResult<CambiarPasswordResponse>.Failure(
                StatusCodes.Status404NotFound,
                "Usuario no encontrado o inactivo.");
        }
        catch (SqlException)
        {
            return ServiceResult<CambiarPasswordResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "Error al ejecutar coop.sp_CambiarPassword.");
        }
        catch (InvalidOperationException)
        {
            return ServiceResult<CambiarPasswordResponse>.Failure(
                StatusCodes.Status500InternalServerError,
                "La API no pudo procesar la respuesta del stored procedure.");
        }
    }
}
