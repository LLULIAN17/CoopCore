using CoopCore.Api.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/cuentas")]
public sealed class CuentasController : ControllerBase
{
    private readonly ICuentaService _cuentaService;

    public CuentasController(ICuentaService cuentaService)
    {
        _cuentaService = cuentaService;
    }

    [HttpGet("{id}/saldo")]
    public async Task<IActionResult> ConsultarSaldo(
        string id,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.ConsultarSaldoAsync(id, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpGet("{id}/movimientos")]
    public async Task<IActionResult> ConsultarMovimientos(
        string id,
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.ConsultarMovimientosAsync(
            id,
            fechaInicio,
            fechaFin,
            cancellationToken);

        return StatusCode(result.StatusCode, result.Response);
    }
}
