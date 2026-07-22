using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record RegistrarSocioRequest(
    [Required]
    [StringLength(20)]
    string? Cedula,
    [Required]
    [StringLength(80)]
    string? Nombre,
    [Required]
    [StringLength(80)]
    string? Apellido,
    [EmailAddress]
    [StringLength(120)]
    string? Correo,
    [StringLength(30)]
    string? Telefono,
    [StringLength(250)]
    string? Direccion,
    [StringLength(20)]
    string? CedulaEmpleadoRegistro);
