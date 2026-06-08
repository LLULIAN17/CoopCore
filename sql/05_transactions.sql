/*
  CoopCore - Script 05
  Archivo: 05_transactions.sql
  Fase: Transacciones (Tema 2 del curso)
  Objetivo: SPs transaccionales para operaciones de dinero y prestamos.

  ESTADO ACTUAL (Entregable 2):
  Los 8 SPs de este archivo estan en VERSION INICIAL. Sus parametros y nombres
  son los definitivos. La logica transaccional completa (BEGIN TRAN, validaciones
  de negocio, actualizacion de saldos, registro en Movimiento, manejo de
  ROLLBACK) se implementara en la Fase de Transacciones del curso.

  Cada SP valida sus parametros basicos y lanza un THROW 52099 indicando que
  la implementacion esta pendiente. Esto garantiza que los SPs existen con su
  contrato definido, pero no se reportaran como funcionales hasta el Tema 2.

  Los GRANT EXECUTE sobre estos SPs NO se conceden todavia (ver
  06_security.sql). Se concederan cuando los SPs esten completamente
  implementados.
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    THROW 51000, 'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.', 1;
END;
GO

USE CoopCoreDB;
GO

IF SCHEMA_ID(N'coop') IS NULL
BEGIN
    THROW 51002, 'No existe el esquema coop. Ejecute primero sql/01_schema_tables.sql.', 1;
END;
GO

/* ============================================================
   SP 10: Registrar deposito
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarDeposito
    @NumeroCuenta NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroCuenta = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');
        SET @Observacion = NULLIF(LTRIM(RTRIM(@Observacion)), N'');

        IF @NumeroCuenta IS NULL OR @Monto IS NULL OR @CedulaEmpleado IS NULL
        BEGIN
            THROW 52090, 'Numero de cuenta, monto y cedula de empleado son obligatorios.', 1;
        END;

        IF @Monto <= 0
        BEGIN
            THROW 52091, 'El monto del deposito debe ser mayor que cero.', 1;
        END;

        THROW 52099, 'sp_RegistrarDeposito: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgDeposito NVARCHAR(4000) =
            N'sp_RegistrarDeposito: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgDeposito, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 11: Registrar retiro
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarRetiro
    @NumeroCuenta NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroCuenta = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');
        SET @Observacion = NULLIF(LTRIM(RTRIM(@Observacion)), N'');

        IF @NumeroCuenta IS NULL OR @Monto IS NULL OR @CedulaEmpleado IS NULL
        BEGIN
            THROW 52092, 'Numero de cuenta, monto y cedula de empleado son obligatorios.', 1;
        END;

        IF @Monto <= 0
        BEGIN
            THROW 52093, 'El monto del retiro debe ser mayor que cero.', 1;
        END;

        THROW 52099, 'sp_RegistrarRetiro: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgRetiro NVARCHAR(4000) =
            N'sp_RegistrarRetiro: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgRetiro, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 12: Registrar transferencia
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarTransferencia
    @NumeroCuentaOrigen NVARCHAR(30),
    @NumeroCuentaDestino NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroCuentaOrigen =
            NULLIF(LTRIM(RTRIM(@NumeroCuentaOrigen)), N'');
        SET @NumeroCuentaDestino =
            NULLIF(LTRIM(RTRIM(@NumeroCuentaDestino)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');
        SET @Observacion = NULLIF(LTRIM(RTRIM(@Observacion)), N'');

        IF @NumeroCuentaOrigen IS NULL
           OR @NumeroCuentaDestino IS NULL
           OR @Monto IS NULL
           OR @CedulaEmpleado IS NULL
        BEGIN
            THROW 52094, 'Cuentas, monto y cedula de empleado son obligatorios.', 1;
        END;

        IF @Monto <= 0
        BEGIN
            THROW 52095, 'El monto de la transferencia debe ser mayor que cero.', 1;
        END;

        IF @NumeroCuentaOrigen = @NumeroCuentaDestino
        BEGIN
            THROW 52096, 'La cuenta origen y la cuenta destino deben ser diferentes.', 1;
        END;

        THROW 52099, 'sp_RegistrarTransferencia: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgTransferencia NVARCHAR(4000) =
            N'sp_RegistrarTransferencia: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgTransferencia, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 13: Pagar cuota
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_PagarCuota
    @NumeroPrestamo NVARCHAR(30),
    @NumeroCuota INT,
    @MontoPago DECIMAL(18,2),
    @NumeroCuentaOrigen NVARCHAR(30),
    @CedulaEmpleado NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');
        SET @NumeroCuentaOrigen =
            NULLIF(LTRIM(RTRIM(@NumeroCuentaOrigen)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');

        IF @NumeroPrestamo IS NULL
           OR @NumeroCuota IS NULL
           OR @MontoPago IS NULL
           OR @NumeroCuentaOrigen IS NULL
           OR @CedulaEmpleado IS NULL
        BEGIN
            THROW 52090, 'Todos los parametros de pago de cuota son obligatorios.', 1;
        END;

        IF @NumeroCuota <= 0
        BEGIN
            THROW 52091, 'El numero de cuota debe ser mayor que cero.', 1;
        END;

        IF @MontoPago <= 0
        BEGIN
            THROW 52092, 'El monto del pago debe ser mayor que cero.', 1;
        END;

        THROW 52099, 'sp_PagarCuota: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgPagoCuota NVARCHAR(4000) =
            N'sp_PagarCuota: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgPagoCuota, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 14: Solicitar prestamo
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_SolicitarPrestamo
    @CedulaSocio NVARCHAR(20),
    @CodigoProducto NVARCHAR(20),
    @MontoSolicitado DECIMAL(18,2),
    @PlazoMeses INT,
    @CedulaEmpleado NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @CedulaSocio = NULLIF(LTRIM(RTRIM(@CedulaSocio)), N'');
        SET @CodigoProducto = NULLIF(LTRIM(RTRIM(@CodigoProducto)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');

        IF @CedulaSocio IS NULL
           OR @CodigoProducto IS NULL
           OR @MontoSolicitado IS NULL
           OR @PlazoMeses IS NULL
           OR @CedulaEmpleado IS NULL
        BEGIN
            THROW 52093, 'Todos los parametros de solicitud son obligatorios.', 1;
        END;

        IF @MontoSolicitado <= 0
        BEGIN
            THROW 52094, 'El monto solicitado debe ser mayor que cero.', 1;
        END;

        IF @PlazoMeses <= 0
        BEGIN
            THROW 52095, 'El plazo debe ser mayor que cero.', 1;
        END;

        THROW 52099, 'sp_SolicitarPrestamo: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgSolicitud NVARCHAR(4000) =
            N'sp_SolicitarPrestamo: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgSolicitud, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 15: Aprobar prestamo
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_AprobarPrestamo
    @NumeroPrestamo NVARCHAR(30),
    @CedulaEmpleadoAprueba NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');
        SET @CedulaEmpleadoAprueba =
            NULLIF(LTRIM(RTRIM(@CedulaEmpleadoAprueba)), N'');

        IF @NumeroPrestamo IS NULL OR @CedulaEmpleadoAprueba IS NULL
        BEGIN
            THROW 52096, 'Numero de prestamo y cedula del aprobador son obligatorios.', 1;
        END;

        THROW 52099, 'sp_AprobarPrestamo: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgAprobacion NVARCHAR(4000) =
            N'sp_AprobarPrestamo: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgAprobacion, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 16: Rechazar prestamo
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RechazarPrestamo
    @NumeroPrestamo NVARCHAR(30),
    @CedulaEmpleadoRechaza NVARCHAR(20),
    @Motivo NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');
        SET @CedulaEmpleadoRechaza =
            NULLIF(LTRIM(RTRIM(@CedulaEmpleadoRechaza)), N'');
        SET @Motivo = NULLIF(LTRIM(RTRIM(@Motivo)), N'');

        IF @NumeroPrestamo IS NULL
           OR @CedulaEmpleadoRechaza IS NULL
           OR @Motivo IS NULL
        BEGIN
            THROW 52097, 'Numero de prestamo, cedula y motivo son obligatorios.', 1;
        END;

        THROW 52099, 'sp_RechazarPrestamo: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgRechazo NVARCHAR(4000) =
            N'sp_RechazarPrestamo: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgRechazo, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 17: Generar amortizacion
   ESTADO: VERSION INICIAL
   Logica transaccional completa pendiente para la Fase de Transacciones
   (Tema 2). Esta version solo valida parametros.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_GenerarAmortizacion
    @NumeroPrestamo NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');

        IF @NumeroPrestamo IS NULL
        BEGIN
            THROW 52098, 'El numero de prestamo es obligatorio.', 1;
        END;

        THROW 52099, 'sp_GenerarAmortizacion: pendiente de implementacion completa en Fase de Transacciones (Tema 2).', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgAmortizacion NVARCHAR(4000) =
            N'sp_GenerarAmortizacion: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgAmortizacion, 1;
    END CATCH;
END;
GO
