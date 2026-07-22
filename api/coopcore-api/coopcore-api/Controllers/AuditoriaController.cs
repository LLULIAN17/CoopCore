using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/auditoria")]
[Authorize(Roles = ApiRoles.Auditoria)]
public sealed class AuditoriaController : ControllerBase
{
    private readonly IAuditoriaService _auditoriaService;

    public AuditoriaController(IAuditoriaService auditoriaService)
    {
        _auditoriaService = auditoriaService;
    }

    [HttpGet]
    public async Task<IActionResult> Consultar(
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin,
        [FromQuery] string? entidad,
        [FromQuery] string? accion,
        [FromQuery] string? cedulaEmpleado,
        CancellationToken cancellationToken)
    {
        var request = new ConsultarAuditoriaRequest(
            fechaInicio,
            fechaFin,
            entidad,
            accion,
            cedulaEmpleado);

        var result = await _auditoriaService.ConsultarAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
