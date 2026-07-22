namespace CoopCore.Api.Models.Responses;

public sealed record AuditoriaResponse(
    long AuditoriaId,
    DateTime FechaEvento,
    string Entidad,
    string? EntidadId,
    string Accion,
    string? Descripcion,
    string UsuarioSql,
    string UsuarioBd,
    string? CedulaEmpleado,
    string? NombreEmpleado);
