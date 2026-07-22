namespace CoopCore.Api.Models.Responses;

public sealed record CrearCuentaResponse(
    int CuentaId,
    string NumeroCuenta,
    decimal SaldoInicial,
    string Mensaje);

public sealed record DepositoResponse(
    string Resultado,
    long MovimientoId,
    string Referencia,
    string NumeroCuenta,
    decimal SaldoAnterior,
    decimal MontoDepositado,
    decimal SaldoNuevo);

public sealed record RetiroResponse(
    string Resultado,
    long MovimientoId,
    string Referencia,
    string NumeroCuenta,
    decimal SaldoAnterior,
    decimal MontoRetirado,
    decimal SaldoNuevo);

public sealed record TransferenciaResponse(
    string Resultado,
    string Referencia,
    long MovimientoSalidaId,
    long MovimientoEntradaId,
    string NumeroCuentaOrigen,
    decimal SaldoOrigenAnterior,
    decimal SaldoOrigenNuevo,
    string NumeroCuentaDestino,
    decimal SaldoDestinoAnterior,
    decimal SaldoDestinoNuevo,
    decimal MontoTransferido);
