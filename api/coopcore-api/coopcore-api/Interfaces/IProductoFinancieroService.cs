using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IProductoFinancieroService
{
    Task<ServiceResult<IReadOnlyList<ProductoFinancieroResponse>>> BuscarAsync(
        BuscarProductosFinancierosRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<GuardarProductoFinancieroResponse>> CrearAsync(
        GuardarProductoFinancieroRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<GuardarProductoFinancieroResponse>> ActualizarAsync(
        int productoFinancieroId,
        GuardarProductoFinancieroRequest request,
        CancellationToken cancellationToken = default);
}
