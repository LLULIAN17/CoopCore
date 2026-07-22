using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record AprobarPrestamoRequest(
    [Required]
    [StringLength(20)]
    string? CedulaEmpleadoAprueba);
