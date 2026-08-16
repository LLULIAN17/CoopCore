using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/clientes-morosos")]
[Authorize(Roles = ApiRoles.Credito)]
public sealed class ClientesMorososController : ControllerBase
{
    private readonly IMorosidadService _morosidadService;

    public ClientesMorososController(IMorosidadService morosidadService)
    {
        _morosidadService = morosidadService;
    }

    [HttpGet]
    public async Task<IActionResult> Buscar(
        [FromQuery] BuscarClientesMorososRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _morosidadService.BuscarClientesAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
