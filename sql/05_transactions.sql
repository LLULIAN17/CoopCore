/*
  CoopCore - Script 05
  Archivo: 05_transactions.sql
  Fase: Transacciones (Tema 2 del curso)
  Objetivo: SPs transaccionales para operaciones de dinero y prestamos.

  ESTADO REVISION 3:
  Los SPs de cuentas y prestamos se implementan con transacciones explicitas,
  validaciones de negocio, registro de movimientos, auditoria y manejo de
  ROLLBACK para cumplir la Revision 3.
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
   Proposito:
   - Aumentar el saldo de una cuenta activa.
   - Registrar movimiento y auditoria dentro de una transaccion explicita.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarDeposito
    @NumeroCuenta NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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

        DECLARE @CuentaID INT;
        DECLARE @EmpleadoID INT;
        DECLARE @EstadoCuenta NVARCHAR(20);
        DECLARE @SaldoAnterior DECIMAL(18,2);
        DECLARE @SaldoNuevo DECIMAL(18,2);
        DECLARE @Referencia NVARCHAR(50);
        DECLARE @MovimientoID BIGINT;

        BEGIN TRANSACTION;

        SELECT
            @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleado
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52092, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        SELECT
            @CuentaID = c.CuentaID,
            @EstadoCuenta = c.EstadoCuenta,
            @SaldoAnterior = c.Saldo
        FROM coop.Cuenta AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.NumeroCuenta = @NumeroCuenta;

        IF @CuentaID IS NULL
        BEGIN
            THROW 52093, 'La cuenta indicada no existe.', 1;
        END;

        IF @EstadoCuenta <> N'ACTIVA'
        BEGIN
            THROW 52094, 'La cuenta indicada no esta ACTIVA.', 1;
        END;

        SET @SaldoNuevo = @SaldoAnterior + @Monto;
        SET @Referencia =
            N'DEP-' + CONVERT(NVARCHAR(8), SYSDATETIME(), 112)
            + REPLACE(CONVERT(NVARCHAR(8), CONVERT(TIME(0), SYSDATETIME())), N':', N'')
            + N'-' + RIGHT(CONVERT(NVARCHAR(36), NEWID()), 6);

        UPDATE coop.Cuenta
        SET Saldo = @SaldoNuevo
        WHERE CuentaID = @CuentaID;

        INSERT INTO coop.Movimiento
        (
            CuentaID,
            TipoMovimiento,
            Monto,
            Referencia,
            Observacion,
            EjecutadoPorEmpleadoID
        )
        VALUES
        (
            @CuentaID,
            N'DEPOSITO',
            @Monto,
            @Referencia,
            ISNULL(@Observacion, N'Deposito registrado por transaccion.'),
            @EmpleadoID
        );

        SET @MovimientoID = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT INTO coop.Auditoria
        (
            Entidad,
            EntidadID,
            Accion,
            Descripcion,
            EmpleadoID
        )
        VALUES
        (
            N'CUENTA',
            CAST(@CuentaID AS NVARCHAR(100)),
            N'UPDATE',
            N'Deposito registrado. Cuenta: ' + @NumeroCuenta
                + N'. Monto: ' + CONVERT(NVARCHAR(40), @Monto)
                + N'. Saldo anterior: ' + CONVERT(NVARCHAR(40), @SaldoAnterior)
                + N'. Saldo nuevo: ' + CONVERT(NVARCHAR(40), @SaldoNuevo)
                + N'. Referencia: ' + @Referencia,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'DEPOSITO_REGISTRADO' AS Resultado,
            @MovimientoID AS MovimientoID,
            @Referencia AS Referencia,
            @NumeroCuenta AS NumeroCuenta,
            @SaldoAnterior AS SaldoAnterior,
            @Monto AS MontoDepositado,
            @SaldoNuevo AS SaldoNuevo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgDeposito NVARCHAR(4000) =
            N'sp_RegistrarDeposito: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgDeposito, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 11: Registrar retiro
   Proposito:
   - Disminuir el saldo de una cuenta activa con saldo suficiente.
   - Registrar movimiento y auditoria dentro de una transaccion explicita.
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarRetiro
    @NumeroCuenta NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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

        DECLARE @CuentaID INT;
        DECLARE @EmpleadoID INT;
        DECLARE @EstadoCuenta NVARCHAR(20);
        DECLARE @SaldoAnterior DECIMAL(18,2);
        DECLARE @SaldoNuevo DECIMAL(18,2);
        DECLARE @Referencia NVARCHAR(50);
        DECLARE @MovimientoID BIGINT;

        BEGIN TRANSACTION;

        SELECT
            @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleado
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52094, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        SELECT
            @CuentaID = c.CuentaID,
            @EstadoCuenta = c.EstadoCuenta,
            @SaldoAnterior = c.Saldo
        FROM coop.Cuenta AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.NumeroCuenta = @NumeroCuenta;

        IF @CuentaID IS NULL
        BEGIN
            THROW 52095, 'La cuenta indicada no existe.', 1;
        END;

        IF @EstadoCuenta <> N'ACTIVA'
        BEGIN
            THROW 52096, 'La cuenta indicada no esta ACTIVA.', 1;
        END;

        IF @SaldoAnterior < @Monto
        BEGIN
            THROW 52097, 'Saldo insuficiente para realizar el retiro.', 1;
        END;

        SET @SaldoNuevo = @SaldoAnterior - @Monto;
        SET @Referencia =
            N'RET-' + CONVERT(NVARCHAR(8), SYSDATETIME(), 112)
            + REPLACE(CONVERT(NVARCHAR(8), CONVERT(TIME(0), SYSDATETIME())), N':', N'')
            + N'-' + RIGHT(CONVERT(NVARCHAR(36), NEWID()), 6);

        UPDATE coop.Cuenta
        SET Saldo = @SaldoNuevo
        WHERE CuentaID = @CuentaID;

        INSERT INTO coop.Movimiento
        (
            CuentaID,
            TipoMovimiento,
            Monto,
            Referencia,
            Observacion,
            EjecutadoPorEmpleadoID
        )
        VALUES
        (
            @CuentaID,
            N'RETIRO',
            @Monto,
            @Referencia,
            ISNULL(@Observacion, N'Retiro registrado por transaccion.'),
            @EmpleadoID
        );

        SET @MovimientoID = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT INTO coop.Auditoria
        (
            Entidad,
            EntidadID,
            Accion,
            Descripcion,
            EmpleadoID
        )
        VALUES
        (
            N'CUENTA',
            CAST(@CuentaID AS NVARCHAR(100)),
            N'UPDATE',
            N'Retiro registrado. Cuenta: ' + @NumeroCuenta
                + N'. Monto: ' + CONVERT(NVARCHAR(40), @Monto)
                + N'. Saldo anterior: ' + CONVERT(NVARCHAR(40), @SaldoAnterior)
                + N'. Saldo nuevo: ' + CONVERT(NVARCHAR(40), @SaldoNuevo)
                + N'. Referencia: ' + @Referencia,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'RETIRO_REGISTRADO' AS Resultado,
            @MovimientoID AS MovimientoID,
            @Referencia AS Referencia,
            @NumeroCuenta AS NumeroCuenta,
            @SaldoAnterior AS SaldoAnterior,
            @Monto AS MontoRetirado,
            @SaldoNuevo AS SaldoNuevo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgRetiro NVARCHAR(4000) =
            N'sp_RegistrarRetiro: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgRetiro, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 12: Registrar transferencia
   Proposito:
   - Mover fondos entre dos cuentas activas con bloqueos consistentes.
   - Registrar dos movimientos y auditoria en una sola transaccion.
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
    SET XACT_ABORT ON;

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

        DECLARE @EmpleadoID INT;
        DECLARE @CuentaOrigenID INT;
        DECLARE @CuentaDestinoID INT;
        DECLARE @EstadoOrigen NVARCHAR(20);
        DECLARE @EstadoDestino NVARCHAR(20);
        DECLARE @SaldoOrigenAnterior DECIMAL(18,2);
        DECLARE @SaldoDestinoAnterior DECIMAL(18,2);
        DECLARE @SaldoOrigenNuevo DECIMAL(18,2);
        DECLARE @SaldoDestinoNuevo DECIMAL(18,2);
        DECLARE @Referencia NVARCHAR(50);
        DECLARE @MovimientoSalidaID BIGINT;
        DECLARE @MovimientoEntradaID BIGINT;

        DECLARE @CuentasTransferencia TABLE
        (
            NumeroCuenta NVARCHAR(30) NOT NULL PRIMARY KEY,
            CuentaID INT NOT NULL,
            EstadoCuenta NVARCHAR(20) NOT NULL,
            Saldo DECIMAL(18,2) NOT NULL
        );

        BEGIN TRANSACTION;

        SELECT
            @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleado
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52097, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        INSERT INTO @CuentasTransferencia
        (
            NumeroCuenta,
            CuentaID,
            EstadoCuenta,
            Saldo
        )
        SELECT TOP (2)
            c.NumeroCuenta,
            c.CuentaID,
            c.EstadoCuenta,
            c.Saldo
        FROM coop.Cuenta AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.NumeroCuenta IN (@NumeroCuentaOrigen, @NumeroCuentaDestino)
        ORDER BY c.CuentaID;

        SELECT
            @CuentaOrigenID = ct.CuentaID,
            @EstadoOrigen = ct.EstadoCuenta,
            @SaldoOrigenAnterior = ct.Saldo
        FROM @CuentasTransferencia AS ct
        WHERE ct.NumeroCuenta = @NumeroCuentaOrigen;

        SELECT
            @CuentaDestinoID = ct.CuentaID,
            @EstadoDestino = ct.EstadoCuenta,
            @SaldoDestinoAnterior = ct.Saldo
        FROM @CuentasTransferencia AS ct
        WHERE ct.NumeroCuenta = @NumeroCuentaDestino;

        IF @CuentaOrigenID IS NULL
        BEGIN
            THROW 52098, 'La cuenta origen indicada no existe.', 1;
        END;

        IF @CuentaDestinoID IS NULL
        BEGIN
            THROW 52103, 'La cuenta destino indicada no existe.', 1;
        END;

        IF @EstadoOrigen <> N'ACTIVA'
        BEGIN
            THROW 52100, 'La cuenta origen no esta ACTIVA.', 1;
        END;

        IF @EstadoDestino <> N'ACTIVA'
        BEGIN
            THROW 52101, 'La cuenta destino no esta ACTIVA.', 1;
        END;

        IF @SaldoOrigenAnterior < @Monto
        BEGIN
            THROW 52102, 'Saldo insuficiente en la cuenta origen.', 1;
        END;

        SET @SaldoOrigenNuevo = @SaldoOrigenAnterior - @Monto;
        SET @SaldoDestinoNuevo = @SaldoDestinoAnterior + @Monto;
        SET @Referencia =
            N'TRF-' + CONVERT(NVARCHAR(8), SYSDATETIME(), 112)
            + REPLACE(CONVERT(NVARCHAR(8), CONVERT(TIME(0), SYSDATETIME())), N':', N'')
            + N'-' + RIGHT(CONVERT(NVARCHAR(36), NEWID()), 6);

        UPDATE coop.Cuenta
        SET Saldo = @SaldoOrigenNuevo
        WHERE CuentaID = @CuentaOrigenID;

        UPDATE coop.Cuenta
        SET Saldo = @SaldoDestinoNuevo
        WHERE CuentaID = @CuentaDestinoID;

        INSERT INTO coop.Movimiento
        (
            CuentaID,
            TipoMovimiento,
            Monto,
            Referencia,
            Observacion,
            EjecutadoPorEmpleadoID
        )
        VALUES
        (
            @CuentaOrigenID,
            N'TRANSFERENCIA_SALIDA',
            @Monto,
            @Referencia,
            ISNULL(@Observacion, N'Transferencia enviada a ' + @NumeroCuentaDestino),
            @EmpleadoID
        );

        SET @MovimientoSalidaID = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT INTO coop.Movimiento
        (
            CuentaID,
            TipoMovimiento,
            Monto,
            Referencia,
            Observacion,
            EjecutadoPorEmpleadoID
        )
        VALUES
        (
            @CuentaDestinoID,
            N'TRANSFERENCIA_ENTRADA',
            @Monto,
            @Referencia,
            ISNULL(@Observacion, N'Transferencia recibida desde ' + @NumeroCuentaOrigen),
            @EmpleadoID
        );

        SET @MovimientoEntradaID = CONVERT(BIGINT, SCOPE_IDENTITY());

        INSERT INTO coop.Auditoria
        (
            Entidad,
            EntidadID,
            Accion,
            Descripcion,
            EmpleadoID
        )
        VALUES
        (
            N'CUENTA',
            CAST(@CuentaOrigenID AS NVARCHAR(100)) + N'->' + CAST(@CuentaDestinoID AS NVARCHAR(100)),
            N'UPDATE',
            N'Transferencia registrada. Origen: ' + @NumeroCuentaOrigen
                + N'. Destino: ' + @NumeroCuentaDestino
                + N'. Monto: ' + CONVERT(NVARCHAR(40), @Monto)
                + N'. Referencia: ' + @Referencia,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'TRANSFERENCIA_REGISTRADA' AS Resultado,
            @Referencia AS Referencia,
            @MovimientoSalidaID AS MovimientoSalidaID,
            @MovimientoEntradaID AS MovimientoEntradaID,
            @NumeroCuentaOrigen AS NumeroCuentaOrigen,
            @SaldoOrigenAnterior AS SaldoOrigenAnterior,
            @SaldoOrigenNuevo AS SaldoOrigenNuevo,
            @NumeroCuentaDestino AS NumeroCuentaDestino,
            @SaldoDestinoAnterior AS SaldoDestinoAnterior,
            @SaldoDestinoNuevo AS SaldoDestinoNuevo,
            @Monto AS MontoTransferido;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

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
