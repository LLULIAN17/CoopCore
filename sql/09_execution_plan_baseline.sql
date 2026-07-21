/*
  CoopCore - Script 09A
  Archivo: 09_execution_plan_baseline.sql
  Fase: Analisis de planes antes de optimizar
  Objetivo:
  - Capturar linea base de planes de ejecucion, STATISTICS IO y STATISTICS TIME.
  - Ejecutar casos representativos antes de crear indices u optimizar consultas.

  IMPORTANTE:
  - Activar "Include Actual Execution Plan" en SSMS antes de ejecutar.
  - No crear indices en este script.
  - No modificar stored procedures en este script.
  - La seccion transaccional se ejecuta dentro de una transaccion externa y
    termina con ROLLBACK para no dejar datos permanentes.
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    THROW 51000, 'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.', 1;
END;
GO

USE CoopCoreDB;
GO

SET NOCOUNT ON;
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

PRINT N'============================================================';
PRINT N'LINEA BASE DE PLANES - ANTES DE OPTIMIZAR';
PRINT N'Fecha de ejecucion:';
SELECT SYSDATETIME() AS FechaEjecucion;
PRINT N'============================================================';
GO

PRINT N'Inventario de indices existentes antes de optimizar';
SELECT
    s.name AS Esquema,
    t.name AS Tabla,
    i.name AS Indice,
    i.type_desc AS TipoIndice,
    i.is_unique AS EsUnico,
    i.has_filter AS TieneFiltro,
    i.filter_definition AS Filtro
FROM sys.indexes AS i
INNER JOIN sys.tables AS t
    ON t.object_id = i.object_id
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
WHERE s.name = N'coop'
  AND i.index_id > 0
ORDER BY t.name, i.index_id;
GO

PRINT N'Conteo de filas por tabla antes de medir';
SELECT
    s.name AS Esquema,
    t.name AS Tabla,
    SUM(p.rows) AS FilasAproximadas
FROM sys.tables AS t
INNER JOIN sys.schemas AS s
    ON s.schema_id = t.schema_id
INNER JOIN sys.partitions AS p
    ON p.object_id = t.object_id
   AND p.index_id IN (0, 1)
WHERE s.name = N'coop'
GROUP BY s.name, t.name
ORDER BY t.name;
GO

PRINT N'Caso 1 - sp_ValidarLogin';
EXEC coop.sp_ValidarLogin
    @NombreUsuario = N'mlrojas',
    @Password = N'Lab_Cajero_001';
GO

PRINT N'Caso 2 - sp_ConsultarSocio por cedula';
EXEC coop.sp_ConsultarSocio
    @Identificador = N'SO-1001';
GO

PRINT N'Caso 2B - sp_ConsultarSocio por SocioID';
EXEC coop.sp_ConsultarSocio
    @Identificador = N'1';
GO

PRINT N'Caso 3 - sp_ConsultarSaldo';
EXEC coop.sp_ConsultarSaldo
    @NumeroCuenta = N'CTA-10001';
GO

PRINT N'Caso 4 - sp_ConsultarMovimientos sin rango';
EXEC coop.sp_ConsultarMovimientos
    @NumeroCuenta = N'CTA-10001';
GO

PRINT N'Caso 4B - sp_ConsultarMovimientos con rango';
EXEC coop.sp_ConsultarMovimientos
    @NumeroCuenta = N'CTA-10001',
    @FechaInicio = '2026-01-01',
    @FechaFin = '2026-12-31';
GO

PRINT N'Caso 5 - sp_ConsultarPrestamo';
EXEC coop.sp_ConsultarPrestamo
    @NumeroPrestamo = N'PR-20001';
GO

PRINT N'Caso 6 - sp_ConsultarAuditoria por accion LOGIN';
EXEC coop.sp_ConsultarAuditoria
    @Accion = N'LOGIN';
GO

PRINT N'Caso 6B - sp_ConsultarAuditoria por rango, entidad y empleado';
EXEC coop.sp_ConsultarAuditoria
    @FechaInicio = '2026-01-01',
    @FechaFin = '2026-12-31',
    @Entidad = N'CUENTA',
    @CedulaEmpleado = N'EM-0101';
GO

PRINT N'============================================================';
PRINT N'Casos transaccionales dentro de ROLLBACK externo';
PRINT N'============================================================';
GO

BEGIN TRY
    BEGIN TRANSACTION BaselinePlanesTransaccional;

    PRINT N'Caso 7 - sp_RegistrarDeposito';
    EXEC coop.sp_RegistrarDeposito
        @NumeroCuenta = N'CTA-10001',
        @Monto = 25.00,
        @CedulaEmpleado = N'EM-0101',
        @Observacion = N'Baseline plan - deposito';

    PRINT N'Caso 8 - sp_RegistrarRetiro';
    EXEC coop.sp_RegistrarRetiro
        @NumeroCuenta = N'CTA-10002',
        @Monto = 10.00,
        @CedulaEmpleado = N'EM-0101',
        @Observacion = N'Baseline plan - retiro';

    PRINT N'Caso 9 - sp_RegistrarTransferencia';
    EXEC coop.sp_RegistrarTransferencia
        @NumeroCuentaOrigen = N'CTA-10003',
        @NumeroCuentaDestino = N'CTA-10004',
        @Monto = 15.00,
        @CedulaEmpleado = N'EM-0101',
        @Observacion = N'Baseline plan - transferencia';

    PRINT N'Caso 10 - sp_SolicitarPrestamo';
    DECLARE @SolicitudPago TABLE
    (
        Resultado NVARCHAR(50),
        PrestamoID INT,
        NumeroPrestamo NVARCHAR(30),
        CedulaSocio NVARCHAR(20),
        CodigoProducto NVARCHAR(20),
        MontoOriginal DECIMAL(18,2),
        SaldoPendiente DECIMAL(18,2),
        TasaInteres DECIMAL(18,2),
        PlazoMeses INT,
        EstadoPrestamo NVARCHAR(20)
    );

    DECLARE @NumeroPrestamoPago NVARCHAR(30);

    INSERT INTO @SolicitudPago
    EXEC coop.sp_SolicitarPrestamo
        @CedulaSocio = N'SO-1001',
        @CodigoProducto = N'PRE_CONSUMO',
        @MontoSolicitado = 600.00,
        @PlazoMeses = 3,
        @CedulaEmpleado = N'EM-0102';

    SELECT @NumeroPrestamoPago = NumeroPrestamo
    FROM @SolicitudPago;

    SELECT *
    FROM @SolicitudPago;

    PRINT N'Caso 11 - sp_AprobarPrestamo';
    EXEC coop.sp_AprobarPrestamo
        @NumeroPrestamo = @NumeroPrestamoPago,
        @CedulaEmpleadoAprueba = N'EM-0102';

    PRINT N'Caso 12 - sp_GenerarAmortizacion';
    EXEC coop.sp_GenerarAmortizacion
        @NumeroPrestamo = @NumeroPrestamoPago;

    PRINT N'Caso 13 - sp_PagarCuota';
    EXEC coop.sp_PagarCuota
        @NumeroPrestamo = @NumeroPrestamoPago,
        @NumeroCuota = 1,
        @MontoPago = 200.00,
        @NumeroCuentaOrigen = N'CTA-10001',
        @CedulaEmpleado = N'EM-0101';

    PRINT N'Caso 14 - sp_RechazarPrestamo';
    DECLARE @SolicitudRechazo TABLE
    (
        Resultado NVARCHAR(50),
        PrestamoID INT,
        NumeroPrestamo NVARCHAR(30),
        CedulaSocio NVARCHAR(20),
        CodigoProducto NVARCHAR(20),
        MontoOriginal DECIMAL(18,2),
        SaldoPendiente DECIMAL(18,2),
        TasaInteres DECIMAL(18,2),
        PlazoMeses INT,
        EstadoPrestamo NVARCHAR(20)
    );

    DECLARE @NumeroPrestamoRechazo NVARCHAR(30);

    INSERT INTO @SolicitudRechazo
    EXEC coop.sp_SolicitarPrestamo
        @CedulaSocio = N'SO-1004',
        @CodigoProducto = N'PRE_CONSUMO',
        @MontoSolicitado = 300.00,
        @PlazoMeses = 2,
        @CedulaEmpleado = N'EM-0102';

    SELECT @NumeroPrestamoRechazo = NumeroPrestamo
    FROM @SolicitudRechazo;

    SELECT *
    FROM @SolicitudRechazo;

    EXEC coop.sp_RechazarPrestamo
        @NumeroPrestamo = @NumeroPrestamoRechazo,
        @CedulaEmpleadoRechaza = N'EM-0102',
        @Motivo = N'Baseline plan - rechazo controlado';

    ROLLBACK TRANSACTION BaselinePlanesTransaccional;
    PRINT N'ROLLBACK aplicado. Los cambios transaccionales de la linea base no quedaron permanentes.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
    BEGIN
        ROLLBACK TRANSACTION;
    END;

    DECLARE @ErrMsgBaseline NVARCHAR(4000) =
        N'Error en linea base de planes: ' + ERROR_MESSAGE();
    THROW 53000, @ErrMsgBaseline, 1;
END CATCH;
GO

SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;
GO

PRINT N'============================================================';
PRINT N'FIN LINEA BASE DE PLANES - NO SE CREARON INDICES';
PRINT N'Guardar capturas de plan real y Messages antes de optimizar.';
PRINT N'============================================================';
GO
