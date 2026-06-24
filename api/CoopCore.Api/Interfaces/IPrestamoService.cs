using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IPrestamoService
{
    Task<ServiceResult<PrestamoResponse>> ConsultarAsync(
        string id,
        CancellationToken cancellationToken = default);
}
