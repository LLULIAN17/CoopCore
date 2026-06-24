using CoopCore.Api.Interfaces;
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

    [HttpGet("{id}")]
    public async Task<IActionResult> Consultar(
        string id,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.ConsultarAsync(id, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
