using CoopCore.Api.Interfaces;
using CoopCore.Api.Models.Requests;
using CoopCore.Api.Security;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CoopCore.Api.Controllers;

[ApiController]
[Route("api/productos-financieros")]
[Authorize(Roles = ApiRoles.Operacion)]
public sealed class ProductosFinancierosController : ControllerBase
{
    private readonly IProductoFinancieroService _productoService;

    public ProductosFinancierosController(IProductoFinancieroService productoService)
    {
        _productoService = productoService;
    }

    [HttpGet]
    public async Task<IActionResult> Buscar(
        [FromQuery] BuscarProductosFinancierosRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _productoService.BuscarAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPost]
    [Authorize(Roles = ApiRoles.Admin)]
    public async Task<IActionResult> Crear(
        [FromBody] GuardarProductoFinancieroRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _productoService.CrearAsync(request, cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }

    [HttpPut("{productoFinancieroId:int}")]
    [Authorize(Roles = ApiRoles.Admin)]
    public async Task<IActionResult> Actualizar(
        int productoFinancieroId,
        [FromBody] GuardarProductoFinancieroRequest request,
        CancellationToken cancellationToken)
    {
        var result = await _productoService.ActualizarAsync(
            productoFinancieroId,
            request,
            cancellationToken);
        return StatusCode(result.StatusCode, result.Response);
    }
}
