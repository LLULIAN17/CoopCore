using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface ICarteraService
{
    Task<ServiceResult<DashboardCarteraResponse>> ConsultarDashboardAsync(
        ConsultarDashboardCarteraRequest request,
        CancellationToken cancellationToken = default);
}
