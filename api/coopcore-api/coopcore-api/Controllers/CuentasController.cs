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

    [HttpGet("{numeroCuenta}/saldo")]
    public async Task<IActionResult> ConsultarSaldo(
        string numeroCuenta,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.ConsultarSaldoAsync(numeroCuenta, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpGet("{numeroCuenta}/movimientos")]
    public async Task<IActionResult> ConsultarMovimientos(
        string numeroCuenta,
        [FromQuery] DateTime? fechaInicio,
        [FromQuery] DateTime? fechaFin,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.ConsultarMovimientosAsync(
            numeroCuenta,
            fechaInicio,
            fechaFin,
            cancellationToken);

        return StatusCode(result.StatusCode, result.Response);
    }
}
