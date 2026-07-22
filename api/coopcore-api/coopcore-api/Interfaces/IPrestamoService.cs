using CoopCore.Api.Models.Requests;
using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface IPrestamoService
{
    Task<ServiceResult<PrestamoResponse>> ConsultarAsync(
        string numeroPrestamo,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<SolicitarPrestamoResponse>> SolicitarAsync(
        SolicitarPrestamoRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<AprobarPrestamoResponse>> AprobarAsync(
        string numeroPrestamo,
        AprobarPrestamoRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<RechazarPrestamoResponse>> RechazarAsync(
        string numeroPrestamo,
        RechazarPrestamoRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<GenerarAmortizacionResponse>> GenerarAmortizacionAsync(
        GenerarAmortizacionRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<PagarCuotaResponse>> PagarCuotaAsync(
        string numeroPrestamo,
        int numeroCuota,
        PagarCuotaRequest request,
        CancellationToken cancellationToken = default);
}
