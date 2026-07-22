using CoopCore.Api.Models.Requests;
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

    Task<ServiceResult<CrearCuentaResponse>> CrearAsync(
        CrearCuentaRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<DepositoResponse>> RegistrarDepositoAsync(
        RegistrarDepositoRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<RetiroResponse>> RegistrarRetiroAsync(
        RegistrarRetiroRequest request,
        CancellationToken cancellationToken = default);

    Task<ServiceResult<TransferenciaResponse>> RegistrarTransferenciaAsync(
        RegistrarTransferenciaRequest request,
        CancellationToken cancellationToken = default);
}
