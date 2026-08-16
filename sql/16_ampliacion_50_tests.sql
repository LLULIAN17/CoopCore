/* Pruebas integradas de los modulos 7, 8 y 9. Fecha: 2026-08-15. */

USE CoopCoreDB;
GO

PRINT N'Prueba 1 - Dashboard de cartera';
EXEC coop.sp_ConsultarDashboardCartera @FechaCorte = '2026-02-01';
GO

PRINT N'Prueba 2 - Catalogo de productos';
EXEC coop.sp_BuscarProductosFinancieros @Estado = N'ACTIVO';
GO

PRINT N'Prueba 3 - Crear producto dentro de transaccion reversible';
BEGIN TRANSACTION;
EXEC coop.sp_GuardarProductoFinanciero
    @CodigoProducto = N'PRE_TEST_50',
    @NombreProducto = N'Prestamo Temporal Ampliacion 50',
    @TipoProducto = N'PRESTAMO',
    @TasaInteres = 11.50,
    @MontoMinimoApertura = 0,
    @Estado = N'ACTIVO',
    @CedulaEmpleado = N'EM-0103';
ROLLBACK TRANSACTION;
GO

PRINT N'Prueba 4 - Alertas de cobranza';
EXEC coop.sp_ConsultarAlertasCobranza
    @FechaCorte = '2026-02-01',
    @DiasProximos = 30,
    @SoloVencidas = 0;
GO

PRINT N'Prueba 5 - Registrar gestion dentro de transaccion reversible';
BEGIN TRANSACTION;
EXEC coop.sp_RegistrarGestionCobranza
    @NumeroPrestamo = N'PR-20001',
    @CedulaEmpleado = N'EM-0102',
    @TipoGestion = N'LLAMADA',
    @Resultado = N'COMPROMISO_PAGO',
    @Comentario = N'Prueba reversible de la ampliacion funcional.',
    @FechaCompromiso = '2026-02-05',
    @MontoCompromiso = 300;
ROLLBACK TRANSACTION;
GO
