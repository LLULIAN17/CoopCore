using System.ComponentModel.DataAnnotations;

namespace CoopCore.Api.Models.Requests;

public sealed record GenerarAmortizacionRequest(
    [Required]
    [StringLength(30)]
    string? NumeroPrestamo);
