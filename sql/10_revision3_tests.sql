/*
  CoopCore - Script 10
  Archivo: 10_revision3_tests.sql
  Fase: Revision 3
  Objetivo: Probar SPs transaccionales implementados en sql/05_transactions.sql.

  Ejecutar despues de:
  00_create_database.sql
  01_schema_tables.sql
  02_seed_data.sql
  03_views.sql
  04_stored_procedures.sql
  05_transactions.sql
  06_security.sql

  Nota:
  Estas pruebas modifican saldos, registran movimientos, crean prestamos de
  prueba, generan cuotas y escriben auditoria. Los prestamos nuevos usan el
  numero generado por coop.sp_SolicitarPrestamo, por lo que el script puede
  repetirse sin chocar con numeros existentes.
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    THROW 51000, 'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.', 1;
END;
GO

USE CoopCoreDB;
GO

SET NOCOUNT ON;
GO

IF SCHEMA_ID(N'coop') IS NULL
BEGIN
    THROW 51002, 'No existe el esquema coop. Ejecute primero sql/01_schema_tables.sql.', 1;
END;
GO

IF
(
    SELECT COUNT(DISTINCT Cedula)
    FROM coop.Empleado
    WHERE Cedula IN (N'EM-0101', N'EM-0102')
      AND Estado = N'ACTIVO'
) < 2
BEGIN
    THROW 51003, 'Faltan empleados activos del seed. Ejecute sql/02_seed_data.sql.', 1;
END;

IF
(
    SELECT COUNT(DISTINCT Cedula)
    FROM coop.Socio
    WHERE Cedula IN (N'SO-1001', N'SO-1004')
      AND Estado = N'ACTIVO'
) < 2
BEGIN
    THROW 51004, 'Faltan socios activos del seed. Ejecute sql/02_seed_data.sql.', 1;
END;

IF NOT EXISTS (SELECT 1 FROM coop.ProductoFinanciero WHERE CodigoProducto = N'PRE_CONSUMO' AND TipoProducto = N'PRESTAMO' AND Estado = N'ACTIVO')
BEGIN
    THROW 51005, 'Falta el producto PRE_CONSUMO activo del seed. Ejecute sql/02_seed_data.sql.', 1;
END;

IF
(
    SELECT COUNT(DISTINCT NumeroCuenta)
    FROM coop.Cuenta
    WHERE NumeroCuenta IN (N'CTA-10001', N'CTA-10002', N'CTA-10003', N'CTA-10004')
      AND EstadoCuenta = N'ACTIVA'
) < 4
BEGIN
    THROW 51006, 'Faltan cuentas activas del seed. Ejecute sql/02_seed_data.sql.', 1;
END;
GO

PRINT N'Revision 3 - Inventario de stored procedures del esquema coop';
SELECT
    name AS StoredProcedure
FROM sys.procedures
WHERE schema_id = SCHEMA_ID(N'coop')
ORDER BY name;
GO

PRINT N'Prueba 1 - Registrar deposito';
EXEC coop.sp_RegistrarDeposito
    @NumeroCuenta = N'CTA-10001',
    @Monto = 25.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba Revision 3 - deposito';
GO

PRINT N'Prueba 2 - Registrar retiro';
EXEC coop.sp_RegistrarRetiro
    @NumeroCuenta = N'CTA-10002',
    @Monto = 10.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba Revision 3 - retiro';
GO

PRINT N'Prueba 3 - Registrar transferencia';
EXEC coop.sp_RegistrarTransferencia
    @NumeroCuentaOrigen = N'CTA-10003',
    @NumeroCuentaDestino = N'CTA-10004',
    @Monto = 15.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba Revision 3 - transferencia';
GO

PRINT N'Prueba 4 - Solicitar, aprobar, amortizar y pagar cuota de un prestamo';
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

EXEC coop.sp_AprobarPrestamo
    @NumeroPrestamo = @NumeroPrestamoPago,
    @CedulaEmpleadoAprueba = N'EM-0102';

EXEC coop.sp_GenerarAmortizacion
    @NumeroPrestamo = @NumeroPrestamoPago;

EXEC coop.sp_PagarCuota
    @NumeroPrestamo = @NumeroPrestamoPago,
    @NumeroCuota = 1,
    @MontoPago = 200.00,
    @NumeroCuentaOrigen = N'CTA-10001',
    @CedulaEmpleado = N'EM-0101';
GO

PRINT N'Prueba 5 - Rechazar prestamo usando una solicitud separada';
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
    @Motivo = N'Prueba Revision 3 - rechazo controlado';
GO

PRINT N'Prueba 6 - Evidencia final de movimientos recientes';
SELECT TOP (20)
    m.MovimientoID,
    m.FechaMovimiento,
    c.NumeroCuenta,
    m.TipoMovimiento,
    m.Monto,
    m.Referencia,
    m.Observacion,
    e.Cedula AS CedulaEmpleado
FROM coop.Movimiento AS m
INNER JOIN coop.Cuenta AS c
    ON c.CuentaID = m.CuentaID
INNER JOIN coop.Empleado AS e
    ON e.EmpleadoID = m.EjecutadoPorEmpleadoID
ORDER BY m.MovimientoID DESC;
GO

PRINT N'Prueba 7 - Evidencia final de auditoria reciente';
SELECT TOP (20)
    a.AuditoriaID,
    a.FechaEvento,
    a.Entidad,
    a.EntidadID,
    a.Accion,
    a.Descripcion,
    e.Cedula AS CedulaEmpleado
FROM coop.Auditoria AS a
LEFT JOIN coop.Empleado AS e
    ON e.EmpleadoID = a.EmpleadoID
ORDER BY a.AuditoriaID DESC;
GO
