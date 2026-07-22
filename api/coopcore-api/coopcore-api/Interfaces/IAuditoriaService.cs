using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IAuditoriaService
{
    Task<ServiceResult<IReadOnlyList<AuditoriaResponse>>> ConsultarAsync(
        ConsultarAuditoriaRequest request,
        CancellationToken cancellationToken = default);
}
