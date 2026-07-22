using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/cuentas")]
[Authorize(Roles = ApiRoles.Caja)]
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

    [HttpPost]
    public async Task<IActionResult> Crear(
        [FromBody] CrearCuentaRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.CrearAsync(request, cancellationToken);
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

    [HttpPost("depositos")]
    public async Task<IActionResult> RegistrarDeposito(
        [FromBody] RegistrarDepositoRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.RegistrarDepositoAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("retiros")]
    public async Task<IActionResult> RegistrarRetiro(
        [FromBody] RegistrarRetiroRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.RegistrarRetiroAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost("transferencias")]
    public async Task<IActionResult> RegistrarTransferencia(
        [FromBody] RegistrarTransferenciaRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _cuentaService.RegistrarTransferenciaAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
