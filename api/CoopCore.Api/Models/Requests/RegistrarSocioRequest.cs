namespace CoopCore.Api.Models.Requests;

public sealed record RegistrarSocioRequest(
    string? Cedula,
    string? Nombre,
    string? Apellido,
    string? Correo,
    string? Telefono,
    string? Direccion,
    string? CedulaEmpleadoRegistro);
