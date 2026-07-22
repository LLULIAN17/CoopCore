using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/prestamos")]
public sealed class PrestamosController : ControllerBase
{
    private readonly IPrestamoService _prestamoService;

    public PrestamosController(IPrestamoService prestamoService)
    {
        _prestamoService = prestamoService;
    }

    [HttpGet("{numeroPrestamo}")]
    [Authorize(Roles = ApiRoles.Credito)]
    public async Task<IActionResult> Consultar(
        string numeroPrestamo,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.ConsultarAsync(numeroPrestamo, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost]
    [Authorize(Roles = ApiRoles.Credito)]
    public async Task<IActionResult> Solicitar(
        [FromBody] SolicitarPrestamoRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.SolicitarAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("{numeroPrestamo}/aprobar")]
    [Authorize(Roles = ApiRoles.Credito)]
    public async Task<IActionResult> Aprobar(
        string numeroPrestamo,
        [FromBody] AprobarPrestamoRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.AprobarAsync(
            numeroPrestamo,
            request,
            cancellationToken);

        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("{numeroPrestamo}/rechazar")]
    [Authorize(Roles = ApiRoles.Credito)]
    public async Task<IActionResult> Rechazar(
        string numeroPrestamo,
        [FromBody] RechazarPrestamoRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.RechazarAsync(
            numeroPrestamo,
            request,
            cancellationToken);

        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("{numeroPrestamo}/amortizacion")]
    [Authorize(Roles = ApiRoles.Credito)]
    public async Task<IActionResult> GenerarAmortizacion(
        string numeroPrestamo,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.GenerarAmortizacionAsync(
            new GenerarAmortizacionRequest(numeroPrestamo),
            cancellationToken);

        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("{numeroPrestamo}/cuotas/{numeroCuota:int}/pagos")]
    [Authorize(Roles = ApiRoles.Caja)]
    public async Task<IActionResult> PagarCuota(
        string numeroPrestamo,
        int numeroCuota,
        [FromBody] PagarCuotaRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.PagarCuotaAsync(
            numeroPrestamo,
            numeroCuota,
            request,
            cancellationToken);

        return StatusCode(result.StatusCode, result.Response);
    }
}
