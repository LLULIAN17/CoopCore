using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record RechazarPrestamoRequest(
    [Required]
    [StringLength(20)]
    string? CedulaEmpleadoRechaza,
    [Required]
    [StringLength(300)]
    string? Motivo);
