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
   Parametros OUTPUT: @NuevoSaldo y @NuevoMovimientoID.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarDeposito
    @NumeroCuenta NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL,
    @NuevoSaldo DECIMAL(18,2) = NULL OUTPUT,
    @NuevoMovimientoID BIGINT = NULL OUTPUT
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
        SET @NuevoMovimientoID = @MovimientoID;
        SET @NuevoSaldo = @SaldoNuevo;

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
            @NuevoMovimientoID AS MovimientoID,
            @Referencia AS Referencia,
            @NumeroCuenta AS NumeroCuenta,
            @SaldoAnterior AS SaldoAnterior,
            @Monto AS MontoDepositado,
            @NuevoSaldo AS SaldoNuevo;
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
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
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
   Parametros OUTPUT: identificadores de los movimientos de salida y entrada.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarTransferencia
    @NumeroCuentaOrigen NVARCHAR(30),
    @NumeroCuentaDestino NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @CedulaEmpleado NVARCHAR(20),
    @Observacion NVARCHAR(300) = NULL,
    @MovimientoSalidaID BIGINT = NULL OUTPUT,
    @MovimientoEntradaID BIGINT = NULL OUTPUT
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
   Proposito:
   - Aplicar un pago a una cuota por pagar o parcial.
   - Debitar la cuenta origen y actualizar saldos de prestamo.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
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
    SET XACT_ABORT ON;

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

        DECLARE @EmpleadoID INT;
        DECLARE @CuentaID INT;
        DECLARE @EstadoCuenta NVARCHAR(20);
        DECLARE @SaldoCuentaAnterior DECIMAL(18,2);
        DECLARE @SaldoCuentaNuevo DECIMAL(18,2);
        DECLARE @PrestamoID INT;
        DECLARE @EstadoPrestamoAnterior NVARCHAR(20);
        DECLARE @EstadoPrestamoNuevo NVARCHAR(20);
        DECLARE @SaldoPrestamoAnterior DECIMAL(18,2);
        DECLARE @SaldoPrestamoNuevo DECIMAL(18,2);
        DECLARE @CuotaID INT;
        DECLARE @MontoCuota DECIMAL(18,2);
        DECLARE @MontoPagadoAnterior DECIMAL(18,2);
        DECLARE @MontoPagadoNuevo DECIMAL(18,2);
        DECLARE @MontoPendienteCuota DECIMAL(18,2);
        DECLARE @EstadoCuotaAnterior NVARCHAR(20);
        DECLARE @EstadoCuotaNuevo NVARCHAR(20);
        DECLARE @FechaPagoAnterior DATETIME2;
        DECLARE @FechaPagoFinal DATETIME2;
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
            THROW 52110, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        SELECT
            @CuentaID = c.CuentaID,
            @EstadoCuenta = c.EstadoCuenta,
            @SaldoCuentaAnterior = c.Saldo
        FROM coop.Cuenta AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.NumeroCuenta = @NumeroCuentaOrigen;

        IF @CuentaID IS NULL
        BEGIN
            THROW 52111, 'La cuenta origen indicada no existe.', 1;
        END;

        IF @EstadoCuenta <> N'ACTIVA'
        BEGIN
            THROW 52112, 'La cuenta origen no esta ACTIVA.', 1;
        END;

        IF @SaldoCuentaAnterior < @MontoPago
        BEGIN
            THROW 52113, 'Saldo insuficiente en la cuenta origen para pagar la cuota.', 1;
        END;

        SELECT
            @PrestamoID = p.PrestamoID,
            @EstadoPrestamoAnterior = p.EstadoPrestamo,
            @SaldoPrestamoAnterior = p.SaldoPendiente
        FROM coop.Prestamo AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.NumeroPrestamo = @NumeroPrestamo;

        IF @PrestamoID IS NULL
        BEGIN
            THROW 52114, 'El prestamo indicado no existe.', 1;
        END;

        IF @EstadoPrestamoAnterior NOT IN (N'ACTIVO', N'MORA')
        BEGIN
            THROW 52115, 'Solo se pueden pagar cuotas de prestamos ACTIVOS o en MORA.', 1;
        END;

        SELECT
            @CuotaID = c.CuotaID,
            @MontoCuota = c.MontoCuota,
            @MontoPagadoAnterior = c.MontoPagado,
            @EstadoCuotaAnterior = c.EstadoCuota,
            @FechaPagoAnterior = c.FechaPago
        FROM coop.Cuota AS c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.PrestamoID = @PrestamoID
          AND c.NumeroCuota = @NumeroCuota;

        IF @CuotaID IS NULL
        BEGIN
            THROW 52116, 'La cuota indicada no existe para el prestamo.', 1;
        END;

        IF @EstadoCuotaAnterior = N'PAGADA'
           OR @MontoPagadoAnterior >= @MontoCuota
        BEGIN
            THROW 52117, 'La cuota ya esta pagada completamente.', 1;
        END;

        SET @MontoPendienteCuota = @MontoCuota - @MontoPagadoAnterior;

        IF @MontoPago > @MontoPendienteCuota
        BEGIN
            THROW 52118, 'El pago no puede superar el monto por pagar de la cuota.', 1;
        END;

        IF @MontoPago > @SaldoPrestamoAnterior
        BEGIN
            THROW 52119, 'El pago no puede superar el saldo restante del prestamo.', 1;
        END;

        SET @SaldoCuentaNuevo = @SaldoCuentaAnterior - @MontoPago;
        SET @SaldoPrestamoNuevo = @SaldoPrestamoAnterior - @MontoPago;
        SET @MontoPagadoNuevo = @MontoPagadoAnterior + @MontoPago;
        SET @EstadoCuotaNuevo =
            CASE
                WHEN @MontoPagadoNuevo = @MontoCuota THEN N'PAGADA'
                ELSE N'PARCIAL'
            END;
        SET @FechaPagoFinal =
            CASE
                WHEN @EstadoCuotaNuevo = N'PAGADA' THEN SYSDATETIME()
                ELSE @FechaPagoAnterior
            END;
        SET @EstadoPrestamoNuevo =
            CASE
                WHEN @SaldoPrestamoNuevo = 0 THEN N'PAGADO'
                ELSE @EstadoPrestamoAnterior
            END;
        SET @Referencia =
            N'CUO-' + CONVERT(NVARCHAR(8), SYSDATETIME(), 112)
            + REPLACE(CONVERT(NVARCHAR(8), CONVERT(TIME(0), SYSDATETIME())), N':', N'')
            + N'-' + RIGHT(CONVERT(NVARCHAR(36), NEWID()), 6);

        UPDATE coop.Cuenta
        SET Saldo = @SaldoCuentaNuevo
        WHERE CuentaID = @CuentaID;

        UPDATE coop.Cuota
        SET MontoPagado = @MontoPagadoNuevo,
            EstadoCuota = @EstadoCuotaNuevo,
            FechaPago = @FechaPagoFinal
        WHERE CuotaID = @CuotaID;

        UPDATE coop.Prestamo
        SET SaldoPendiente = @SaldoPrestamoNuevo,
            EstadoPrestamo = @EstadoPrestamoNuevo
        WHERE PrestamoID = @PrestamoID;

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
            @MontoPago,
            @Referencia,
            N'Pago de cuota ' + CAST(@NumeroCuota AS NVARCHAR(20))
                + N' del prestamo ' + @NumeroPrestamo,
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
            N'CUOTA',
            CAST(@CuotaID AS NVARCHAR(100)),
            N'UPDATE',
            N'Pago de cuota registrado. Prestamo: ' + @NumeroPrestamo
                + N'. Cuota: ' + CAST(@NumeroCuota AS NVARCHAR(20))
                + N'. Monto: ' + CONVERT(NVARCHAR(40), @MontoPago)
                + N'. Referencia: ' + @Referencia,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'CUOTA_PAGADA' AS Resultado,
            @MovimientoID AS MovimientoID,
            @Referencia AS Referencia,
            @NumeroPrestamo AS NumeroPrestamo,
            @NumeroCuota AS NumeroCuota,
            @MontoCuota AS MontoCuota,
            @MontoPagadoAnterior AS MontoPagadoAnterior,
            @MontoPago AS MontoPago,
            @MontoPagadoNuevo AS MontoPagadoNuevo,
            @EstadoCuotaNuevo AS EstadoCuota,
            @SaldoPrestamoAnterior AS SaldoPrestamoAnterior,
            @SaldoPrestamoNuevo AS SaldoPrestamoNuevo,
            @EstadoPrestamoNuevo AS EstadoPrestamo,
            @NumeroCuentaOrigen AS NumeroCuentaOrigen,
            @SaldoCuentaAnterior AS SaldoCuentaAnterior,
            @SaldoCuentaNuevo AS SaldoCuentaNuevo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgPagoCuota NVARCHAR(4000) =
            N'sp_PagarCuota: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgPagoCuota, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 14: Solicitar prestamo
   Proposito:
   - Crear una solicitud de prestamo para un socio activo.
   - Generar un numero de prestamo unico dentro de la transaccion.
   Parametros OUTPUT: @NuevoPrestamoID y @NuevoNumeroPrestamo.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_SolicitarPrestamo
    @CedulaSocio NVARCHAR(20),
    @CodigoProducto NVARCHAR(20),
    @MontoSolicitado DECIMAL(18,2),
    @PlazoMeses INT,
    @CedulaEmpleado NVARCHAR(20),
    @NuevoPrestamoID INT = NULL OUTPUT,
    @NuevoNumeroPrestamo NVARCHAR(30) = NULL OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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

        DECLARE @SocioID INT;
        DECLARE @ProductoFinancieroID INT;
        DECLARE @EmpleadoID INT;
        DECLARE @TipoProducto NVARCHAR(30);
        DECLARE @TasaInteres DECIMAL(18,2);
        DECLARE @NumeroPrestamo NVARCHAR(30);
        DECLARE @PrestamoID INT;

        BEGIN TRANSACTION;

        SELECT
            @SocioID = s.SocioID
        FROM coop.Socio AS s
        WHERE s.Cedula = @CedulaSocio
          AND s.Estado = N'ACTIVO';

        IF @SocioID IS NULL
        BEGIN
            THROW 52130, 'No existe un socio activo con la cedula indicada.', 1;
        END;

        SELECT
            @ProductoFinancieroID = p.ProductoFinancieroID,
            @TipoProducto = p.TipoProducto,
            @TasaInteres = p.TasaInteres
        FROM coop.ProductoFinanciero AS p
        WHERE p.CodigoProducto = @CodigoProducto
          AND p.Estado = N'ACTIVO';

        IF @ProductoFinancieroID IS NULL
        BEGIN
            THROW 52131, 'El producto financiero indicado no existe o esta inactivo.', 1;
        END;

        IF @TipoProducto <> N'PRESTAMO'
        BEGIN
            THROW 52132, 'El producto financiero debe ser de tipo PRESTAMO.', 1;
        END;

        SELECT
            @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleado
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52133, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        WHILE @NumeroPrestamo IS NULL
              OR EXISTS
              (
                  SELECT 1
                  FROM coop.Prestamo
                  WHERE NumeroPrestamo = @NumeroPrestamo
              )
        BEGIN
            SET @NumeroPrestamo =
                N'PR-' + CONVERT(NVARCHAR(8), SYSDATETIME(), 112)
                + REPLACE(CONVERT(NVARCHAR(8), CONVERT(TIME(0), SYSDATETIME())), N':', N'')
                + N'-' + RIGHT(CONVERT(NVARCHAR(36), NEWID()), 6);
        END;

        INSERT INTO coop.Prestamo
        (
            NumeroPrestamo,
            SocioID,
            ProductoFinancieroID,
            MontoOriginal,
            SaldoPendiente,
            TasaInteres,
            PlazoMeses,
            EstadoPrestamo
        )
        VALUES
        (
            @NumeroPrestamo,
            @SocioID,
            @ProductoFinancieroID,
            @MontoSolicitado,
            @MontoSolicitado,
            @TasaInteres,
            @PlazoMeses,
            N'SOLICITADO'
        );

        SET @PrestamoID = CONVERT(INT, SCOPE_IDENTITY());
        SET @NuevoPrestamoID = @PrestamoID;
        SET @NuevoNumeroPrestamo = @NumeroPrestamo;

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
            N'PRESTAMO',
            CAST(@PrestamoID AS NVARCHAR(100)),
            N'INSERT',
            N'Solicitud de prestamo registrada. Numero: ' + @NumeroPrestamo
                + N'. Socio: ' + @CedulaSocio
                + N'. Monto: ' + CONVERT(NVARCHAR(40), @MontoSolicitado)
                + N'. Plazo meses: ' + CAST(@PlazoMeses AS NVARCHAR(20)),
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'PRESTAMO_SOLICITADO' AS Resultado,
            @NuevoPrestamoID AS PrestamoID,
            @NuevoNumeroPrestamo AS NumeroPrestamo,
            @CedulaSocio AS CedulaSocio,
            @CodigoProducto AS CodigoProducto,
            @MontoSolicitado AS MontoOriginal,
            @MontoSolicitado AS SaldoPendiente,
            @TasaInteres AS TasaInteres,
            @PlazoMeses AS PlazoMeses,
            N'SOLICITADO' AS EstadoPrestamo;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgSolicitud NVARCHAR(4000) =
            N'sp_SolicitarPrestamo: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgSolicitud, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 15: Aprobar prestamo
   Proposito:
   - Cambiar una solicitud de prestamo a ACTIVO.
   - Registrar empleado aprobador, fecha de desembolso y auditoria.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_AprobarPrestamo
    @NumeroPrestamo NVARCHAR(30),
    @CedulaEmpleadoAprueba NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');
        SET @CedulaEmpleadoAprueba =
            NULLIF(LTRIM(RTRIM(@CedulaEmpleadoAprueba)), N'');

        IF @NumeroPrestamo IS NULL OR @CedulaEmpleadoAprueba IS NULL
        BEGIN
            THROW 52096, 'Numero de prestamo y cedula del aprobador son obligatorios.', 1;
        END;

        DECLARE @EmpleadoID INT;
        DECLARE @PrestamoID INT;
        DECLARE @EstadoPrestamo NVARCHAR(20);
        DECLARE @FechaDesembolso DATETIME2;

        BEGIN TRANSACTION;

        SELECT
            @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleadoAprueba
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52140, 'No existe un empleado aprobador activo con la cedula indicada.', 1;
        END;

        SELECT
            @PrestamoID = p.PrestamoID,
            @EstadoPrestamo = p.EstadoPrestamo
        FROM coop.Prestamo AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.NumeroPrestamo = @NumeroPrestamo;

        IF @PrestamoID IS NULL
        BEGIN
            THROW 52141, 'El prestamo indicado no existe.', 1;
        END;

        IF @EstadoPrestamo <> N'SOLICITADO'
        BEGIN
            THROW 52142, 'Solo se pueden aprobar prestamos en estado SOLICITADO.', 1;
        END;

        SET @FechaDesembolso = SYSDATETIME();

        UPDATE coop.Prestamo
        SET EstadoPrestamo = N'ACTIVO',
            AprobadoPorEmpleadoID = @EmpleadoID,
            FechaDesembolso = @FechaDesembolso
        WHERE PrestamoID = @PrestamoID;

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
            N'PRESTAMO',
            CAST(@PrestamoID AS NVARCHAR(100)),
            N'UPDATE',
            N'Prestamo aprobado. Numero: ' + @NumeroPrestamo
                + N'. Estado anterior: ' + @EstadoPrestamo
                + N'. Estado nuevo: ACTIVO.',
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'PRESTAMO_APROBADO' AS Resultado,
            p.PrestamoID,
            p.NumeroPrestamo,
            p.MontoOriginal,
            p.SaldoPendiente,
            p.TasaInteres,
            p.PlazoMeses,
            p.FechaDesembolso,
            p.EstadoPrestamo,
            e.Cedula AS CedulaEmpleadoAprueba
        FROM coop.Prestamo AS p
        INNER JOIN coop.Empleado AS e
            ON e.EmpleadoID = p.AprobadoPorEmpleadoID
        WHERE p.PrestamoID = @PrestamoID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgAprobacion NVARCHAR(4000) =
            N'sp_AprobarPrestamo: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgAprobacion, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 16: Rechazar prestamo
   Proposito:
   - Cancelar una solicitud de prestamo con motivo obligatorio.
   - Usar CANCELADO porque el modelo actual no define estado RECHAZADO.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RechazarPrestamo
    @NumeroPrestamo NVARCHAR(30),
    @CedulaEmpleadoRechaza NVARCHAR(20),
    @Motivo NVARCHAR(300)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

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

        DECLARE @EmpleadoID INT;
        DECLARE @PrestamoID INT;
        DECLARE @EstadoPrestamo NVARCHAR(20);

        BEGIN TRANSACTION;

        SELECT
            @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleadoRechaza
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52150, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        SELECT
            @PrestamoID = p.PrestamoID,
            @EstadoPrestamo = p.EstadoPrestamo
        FROM coop.Prestamo AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.NumeroPrestamo = @NumeroPrestamo;

        IF @PrestamoID IS NULL
        BEGIN
            THROW 52151, 'El prestamo indicado no existe.', 1;
        END;

        IF @EstadoPrestamo <> N'SOLICITADO'
        BEGIN
            THROW 52152, 'Solo se pueden rechazar prestamos en estado SOLICITADO.', 1;
        END;

        UPDATE coop.Prestamo
        SET EstadoPrestamo = N'CANCELADO'
        WHERE PrestamoID = @PrestamoID;

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
            N'PRESTAMO',
            CAST(@PrestamoID AS NVARCHAR(100)),
            N'UPDATE',
            N'Prestamo rechazado usando estado CANCELADO. Numero: '
                + @NumeroPrestamo + N'. Motivo: ' + @Motivo,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'PRESTAMO_RECHAZADO' AS Resultado,
            p.PrestamoID,
            p.NumeroPrestamo,
            p.MontoOriginal,
            p.SaldoPendiente,
            p.EstadoPrestamo,
            @Motivo AS Motivo,
            @CedulaEmpleadoRechaza AS CedulaEmpleadoRechaza
        FROM coop.Prestamo AS p
        WHERE p.PrestamoID = @PrestamoID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgRechazo NVARCHAR(4000) =
            N'sp_RechazarPrestamo: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgRechazo, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 17: Generar amortizacion
   Proposito:
   - Generar cuotas para un prestamo ACTIVO sin cuotas previas.
   - Ajustar la ultima cuota para cuadrar con el saldo restante.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_GenerarAmortizacion
    @NumeroPrestamo NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');

        IF @NumeroPrestamo IS NULL
        BEGIN
            THROW 52098, 'El numero de prestamo es obligatorio.', 1;
        END;

        DECLARE @PrestamoID INT;
        DECLARE @EstadoPrestamo NVARCHAR(20);
        DECLARE @SaldoPendiente DECIMAL(18,2);
        DECLARE @PlazoMeses INT;
        DECLARE @FechaDesembolso DATETIME2;
        DECLARE @EmpleadoAuditoriaID INT;
        DECLARE @NumeroActual INT = 1;
        DECLARE @MontoCuotaBase DECIMAL(18,2);
        DECLARE @MontoCuotaActual DECIMAL(18,2);
        DECLARE @TotalAsignado DECIMAL(18,2) = 0;

        BEGIN TRANSACTION;

        SELECT
            @PrestamoID = p.PrestamoID,
            @EstadoPrestamo = p.EstadoPrestamo,
            @SaldoPendiente = p.SaldoPendiente,
            @PlazoMeses = p.PlazoMeses,
            @FechaDesembolso = p.FechaDesembolso,
            @EmpleadoAuditoriaID = p.AprobadoPorEmpleadoID
        FROM coop.Prestamo AS p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.NumeroPrestamo = @NumeroPrestamo;

        IF @PrestamoID IS NULL
        BEGIN
            THROW 52160, 'El prestamo indicado no existe.', 1;
        END;

        IF @EstadoPrestamo <> N'ACTIVO'
        BEGIN
            THROW 52161, 'Solo se puede generar amortizacion para prestamos ACTIVOS.', 1;
        END;

        IF @SaldoPendiente <= 0
        BEGIN
            THROW 52162, 'El prestamo no tiene saldo restante para amortizar.', 1;
        END;

        IF @PlazoMeses <= 0
        BEGIN
            THROW 52163, 'El plazo del prestamo debe ser mayor que cero.', 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM coop.Cuota WITH (UPDLOCK, HOLDLOCK)
            WHERE PrestamoID = @PrestamoID
        )
        BEGIN
            THROW 52164, 'El prestamo ya tiene cuotas generadas.', 1;
        END;

        SET @MontoCuotaBase = ROUND(@SaldoPendiente / @PlazoMeses, 2);

        WHILE @NumeroActual <= @PlazoMeses
        BEGIN
            IF @NumeroActual < @PlazoMeses
            BEGIN
                SET @MontoCuotaActual = @MontoCuotaBase;
            END
            ELSE
            BEGIN
                SET @MontoCuotaActual = @SaldoPendiente - @TotalAsignado;
            END;

            IF @MontoCuotaActual <= 0
            BEGIN
                THROW 52165, 'La amortizacion genero una cuota no valida.', 1;
            END;

            INSERT INTO coop.Cuota
            (
                PrestamoID,
                NumeroCuota,
                FechaVencimiento,
                MontoCuota,
                MontoPagado,
                EstadoCuota
            )
            VALUES
            (
                @PrestamoID,
                @NumeroActual,
                DATEADD(MONTH, @NumeroActual, CAST(@FechaDesembolso AS DATE)),
                @MontoCuotaActual,
                0,
                N'PENDIENTE'
            );

            SET @TotalAsignado = @TotalAsignado + @MontoCuotaActual;
            SET @NumeroActual = @NumeroActual + 1;
        END;

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
            N'CUOTA',
            CAST(@PrestamoID AS NVARCHAR(100)),
            N'INSERT',
            N'Amortizacion generada. Prestamo: ' + @NumeroPrestamo
                + N'. Cuotas: ' + CAST(@PlazoMeses AS NVARCHAR(20))
                + N'. Total programado: ' + CONVERT(NVARCHAR(40), @TotalAsignado),
            @EmpleadoAuditoriaID
        );

        COMMIT TRANSACTION;

        SELECT
            N'AMORTIZACION_GENERADA' AS Resultado,
            @NumeroPrestamo AS NumeroPrestamo,
            c.NumeroCuota,
            c.FechaVencimiento,
            c.MontoCuota,
            c.MontoPagado,
            c.EstadoCuota
        FROM coop.Cuota AS c
        WHERE c.PrestamoID = @PrestamoID
        ORDER BY c.NumeroCuota;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
        BEGIN
            ROLLBACK TRANSACTION;
        END;

        DECLARE @ErrMsgAmortizacion NVARCHAR(4000) =
            N'sp_GenerarAmortizacion: ' + ERROR_MESSAGE();
        THROW 52199, @ErrMsgAmortizacion, 1;
    END CATCH;
END;
GO
