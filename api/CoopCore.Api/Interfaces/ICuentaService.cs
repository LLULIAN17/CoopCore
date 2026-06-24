using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface ICuentaService
{
    Task<ServiceResult<CuentaSaldoResponse>> ConsultarSaldoAsync(
        string id,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<IReadOnlyList<MovimientoResponse>>> ConsultarMovimientosAsync(
        string id,
        DateTime? fechaInicio,
        DateTime? fechaFin,
        CancellationToken cancellationToken = default);
}
