/*
  CoopCore - Pruebas de cumplimiento de entrega final
  Archivo: 17_entrega_final_tests.sql
  Autor: Equipo CoopCore
  Fecha: 2026-08-17
  Objetivo: Verificar funciones, uso desde SPs y parametros OUTPUT sin persistir datos.
*/

USE CoopCoreDB;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

PRINT N'Prueba 1 - Existen las dos funciones requeridas';
IF OBJECT_ID(N'coop.fn_CalcularMoraCuota', N'FN') IS NULL
    THROW 52400, 'No existe coop.fn_CalcularMoraCuota.', 1;
IF OBJECT_ID(N'coop.fn_ObtenerCuotasVencidas', N'IF') IS NULL
    THROW 52401, 'No existe coop.fn_ObtenerCuotasVencidas.', 1;
GO

PRINT N'Prueba 2 - Calculo escalar de mora';
DECLARE @Mora DECIMAL(18,2) = coop.fn_CalcularMoraCuota
(
    1000.00,
    200.00,
    '2026-01-01',
    '2026-01-11',
    0.001
);
IF @Mora <> 8.00
    THROW 52402, 'La funcion escalar no devolvio la mora esperada.', 1;
SELECT @Mora AS MoraCalculada, CONVERT(DECIMAL(18,2), 8.00) AS MoraEsperada;
GO

PRINT N'Prueba 3 - Funcion tabular de cuotas vencidas';
DECLARE @PrestamoIDPrueba INT = (SELECT TOP (1) PrestamoID FROM coop.Cuota ORDER BY PrestamoID);
IF @PrestamoIDPrueba IS NULL
    THROW 52403, 'No existen cuotas de seed para probar la funcion tabular.', 1;
IF NOT EXISTS
(
    SELECT 1
    FROM coop.fn_ObtenerCuotasVencidas(@PrestamoIDPrueba, '2100-01-01')
)
    THROW 52404, 'La funcion tabular no devolvio cuotas vencidas del seed.', 1;
SELECT TOP (5) *
FROM coop.fn_ObtenerCuotasVencidas(@PrestamoIDPrueba, '2100-01-01')
ORDER BY NumeroCuota;
GO

PRINT N'Prueba 4 - Las funciones se usan dentro de stored procedures';
IF OBJECT_DEFINITION(OBJECT_ID(N'coop.sp_ConsultarAlertasCobranza'))
   NOT LIKE N'%fn_CalcularMoraCuota%'
    THROW 52405, 'sp_ConsultarAlertasCobranza no usa fn_CalcularMoraCuota.', 1;
IF OBJECT_DEFINITION(OBJECT_ID(N'coop.sp_BuscarClientesMorosos'))
   NOT LIKE N'%fn_ObtenerCuotasVencidas%'
    THROW 52406, 'sp_BuscarClientesMorosos no usa fn_ObtenerCuotasVencidas.', 1;
IF OBJECT_DEFINITION(OBJECT_ID(N'coop.sp_ConsultarDashboardCartera'))
   NOT LIKE N'%fn_ObtenerCuotasVencidas%'
    THROW 52407, 'sp_ConsultarDashboardCartera no usa fn_ObtenerCuotasVencidas.', 1;
GO

PRINT N'Prueba 5 - OUTPUT en deposito (transaccion reversible)';
DECLARE @SaldoSalida DECIMAL(18,2);
DECLARE @MovimientoDeposito BIGINT;
BEGIN TRANSACTION;
EXEC coop.sp_RegistrarDeposito
    @NumeroCuenta = N'CTA-10001',
    @Monto = 1.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba OUTPUT entrega final',
    @NuevoSaldo = @SaldoSalida OUTPUT,
    @NuevoMovimientoID = @MovimientoDeposito OUTPUT;
IF @SaldoSalida IS NULL OR @MovimientoDeposito IS NULL
    THROW 52408, 'sp_RegistrarDeposito no asigno sus parametros OUTPUT.', 1;
SELECT @SaldoSalida AS NuevoSaldoOutput, @MovimientoDeposito AS MovimientoIDOutput;
ROLLBACK TRANSACTION;
GO

PRINT N'Prueba 6 - OUTPUT en transferencia (transaccion reversible)';
DECLARE @MovimientoSalida BIGINT;
DECLARE @MovimientoEntrada BIGINT;
BEGIN TRANSACTION;
EXEC coop.sp_RegistrarTransferencia
    @NumeroCuentaOrigen = N'CTA-10003',
    @NumeroCuentaDestino = N'CTA-10004',
    @Monto = 1.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba OUTPUT entrega final',
    @MovimientoSalidaID = @MovimientoSalida OUTPUT,
    @MovimientoEntradaID = @MovimientoEntrada OUTPUT;
IF @MovimientoSalida IS NULL OR @MovimientoEntrada IS NULL
    THROW 52409, 'sp_RegistrarTransferencia no asigno sus parametros OUTPUT.', 1;
SELECT @MovimientoSalida AS MovimientoSalidaOutput,
       @MovimientoEntrada AS MovimientoEntradaOutput;
ROLLBACK TRANSACTION;
GO

PRINT N'Prueba 7 - OUTPUT en solicitud de prestamo (transaccion reversible)';
DECLARE @PrestamoNuevo INT;
DECLARE @NumeroPrestamoNuevo NVARCHAR(30);
BEGIN TRANSACTION;
EXEC coop.sp_SolicitarPrestamo
    @CedulaSocio = N'SO-1004',
    @CodigoProducto = N'PRE_CONSUMO',
    @MontoSolicitado = 1000.00,
    @PlazoMeses = 6,
    @CedulaEmpleado = N'EM-0102',
    @NuevoPrestamoID = @PrestamoNuevo OUTPUT,
    @NuevoNumeroPrestamo = @NumeroPrestamoNuevo OUTPUT;
IF @PrestamoNuevo IS NULL OR @NumeroPrestamoNuevo IS NULL
    THROW 52410, 'sp_SolicitarPrestamo no asigno sus parametros OUTPUT.', 1;
SELECT @PrestamoNuevo AS PrestamoIDOutput,
       @NumeroPrestamoNuevo AS NumeroPrestamoOutput;
ROLLBACK TRANSACTION;
GO

PRINT N'Pruebas de cumplimiento final completadas correctamente.';
GO
