using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface ICobranzaService
{
    Task<ServiceResult<AlertasCobranzaResponse>> ConsultarAlertasAsync(
        ConsultarAlertasCobranzaRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<GestionCobranzaResponse>> RegistrarGestionAsync(
        RegistrarGestionCobranzaRequest request,
        CancellationToken cancellationToken = default);
}
