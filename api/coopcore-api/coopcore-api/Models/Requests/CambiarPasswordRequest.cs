using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record CambiarPasswordRequest(
    [Required]
    [StringLength(50)]
    string? Usuario,
    [Required]
    [StringLength(100)]
    string? PasswordActual,
    [Required]
    [MinLength(8)]
    [StringLength(100)]
    string? PasswordNuevo);
