using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IPrestamoService
{
    Task<ServiceResult<PrestamoResponse>> ConsultarAsync(
        string numeroPrestamo,
        CancellationToken cancellationToken = default);
}
