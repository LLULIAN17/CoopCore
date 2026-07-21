using CoopCore.Api.Models.Responses;

namespace CoopCore.Api.Interfaces;

public interface ICuentaService
{
    Task<ServiceResult<CuentaSaldoResponse>> ConsultarSaldoAsync(
        string numeroCuenta,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<IReadOnlyList<MovimientoResponse>>> ConsultarMovimientosAsync(
        string numeroCuenta,
        DateTime? fechaInicio,
        DateTime? fechaFin,
        CancellationToken cancellationToken = default);
}
