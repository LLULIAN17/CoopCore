using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/cobranza")]
[Authorize(Roles = ApiRoles.Credito)]
public sealed class CobranzaController : ControllerBase
{
    private readonly ICobranzaService _cobranzaService;

    public CobranzaController(ICobranzaService cobranzaService)
    {
        _cobranzaService = cobranzaService;
    }

    [HttpGet("alertas")]
    public async Task<IActionResult> Alertas(
        [FromQuery] ConsultarAlertasCobranzaRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _cobranzaService.ConsultarAlertasAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("gestiones")]
    public async Task<IActionResult> RegistrarGestion(
        [FromBody] RegistrarGestionCobranzaRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _cobranzaService.RegistrarGestionAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
