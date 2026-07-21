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

    [HttpGet("{numeroPrestamo}")]
    public async Task<IActionResult> Consultar(
        string numeroPrestamo,
        CancellationToken cancellationToken)
    {
        var result = await _prestamoService.ConsultarAsync(numeroPrestamo, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
