using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record ConsultarAuditoriaRequest(
    DateTime? FechaInicio,
    DateTime? FechaFin,
    [StringLength(100)]
    string? Entidad,
    [StringLength(30)]
    string? Accion,
    [StringLength(20)]
    string? CedulaEmpleado);
