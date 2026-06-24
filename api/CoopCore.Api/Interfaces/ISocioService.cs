using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface ISocioService
{
    Task<ServiceResult<SocioResponse>> ObtenerAsync(
        string id,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<SocioResponse>> RegistrarAsync(
        RegistrarSocioRequest request,
        CancellationToken cancellationToken = default);
}
