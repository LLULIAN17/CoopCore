using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IMorosidadService
{
    Task<ServiceResult<BuscarClientesMorososResponse>> BuscarClientesAsync(
        BuscarClientesMorososRequest request,
        CancellationToken cancellationToken = default);
}
