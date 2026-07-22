using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/socios")]
[Authorize(Roles = ApiRoles.Caja)]
public sealed class SociosController : ControllerBase
{
    private readonly ISocioService _socioService;

    public SociosController(ISocioService socioService)
    {
        _socioService = socioService;
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Obtener(
        string id,
        CancellationToken cancellationToken)
    {
        var result = await _socioService.ObtenerAsync(id, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost]
    public async Task<IActionResult> Registrar(
        [FromBody] RegistrarSocioRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _socioService.RegistrarAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
