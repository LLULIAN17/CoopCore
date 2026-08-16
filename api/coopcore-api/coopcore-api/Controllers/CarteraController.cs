using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/cartera")]
[Authorize(Roles = ApiRoles.Credito)]
public sealed class CarteraController : ControllerBase
{
    private readonly ICarteraService _carteraService;

    public CarteraController(ICarteraService carteraService)
    {
        _carteraService = carteraService;
    }

    [HttpGet("dashboard")]
    public async Task<IActionResult> Dashboard(
        [FromQuery] ConsultarDashboardCarteraRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _carteraService.ConsultarDashboardAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
