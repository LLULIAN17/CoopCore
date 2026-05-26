/*
  CoopCore - Script 04
  Archivo: 04_stored_procedures.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Definir procedimientos almacenados base.
  Nota: Script idempotente con CREATE OR ALTER PROCEDURE.
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

/* =====================================
   SP 1: Consultar saldo de una cuenta
   ===================================== */
CREATE OR ALTER PROCEDURE coop.sp_ConsultarSaldo
    @NumeroCuenta NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroCuenta = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), N'');

        IF @NumeroCuenta IS NULL
        BEGIN
            THROW 52001, 'El parametro @NumeroCuenta es obligatorio.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM coop.Cuenta WHERE NumeroCuenta = @NumeroCuenta)
        BEGIN
            THROW 52002, 'La cuenta indicada no existe.', 1;
        END;

        SELECT
            c.CuentaID,
            c.NumeroCuenta,
            s.Cedula AS CedulaSocio,
            s.Nombre + N' ' + s.Apellido AS NombreSocio,
            p.CodigoProducto,
            p.NombreProducto,
            c.Saldo,
            c.EstadoCuenta,
            c.FechaApertura,
            um.UltimoMovimiento
        FROM coop.Cuenta AS c
        INNER JOIN coop.Socio AS s
            ON s.SocioID = c.SocioID
        INNER JOIN coop.ProductoFinanciero AS p
            ON p.ProductoFinancieroID = c.ProductoFinancieroID
        OUTER APPLY
        (
            SELECT MAX(m.FechaMovimiento) AS UltimoMovimiento
            FROM coop.Movimiento AS m
            WHERE m.CuentaID = c.CuentaID
        ) AS um
        WHERE c.NumeroCuenta = @NumeroCuenta;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgSaldo NVARCHAR(4000) = N'sp_ConsultarSaldo: ' + ERROR_MESSAGE();
        THROW 52050, @ErrMsgSaldo, 1;
    END CATCH;
END;
GO

/* =========================================
   SP 2: Consultar movimientos de una cuenta
   ========================================= */
CREATE OR ALTER PROCEDURE coop.sp_ConsultarMovimientos
    @NumeroCuenta NVARCHAR(30),
    @FechaInicio DATETIME2 = NULL,
    @FechaFin DATETIME2 = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NumeroCuenta = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), N'');

        IF @NumeroCuenta IS NULL
        BEGIN
            THROW 52003, 'El parametro @NumeroCuenta es obligatorio.', 1;
        END;

        IF @FechaInicio IS NOT NULL
           AND @FechaFin IS NOT NULL
           AND @FechaInicio > @FechaFin
        BEGIN
            THROW 52004, 'El rango de fechas es invalido: @FechaInicio no puede ser mayor que @FechaFin.', 1;
        END;

        IF NOT EXISTS (SELECT 1 FROM coop.Cuenta WHERE NumeroCuenta = @NumeroCuenta)
        BEGIN
            THROW 52005, 'La cuenta indicada no existe.', 1;
        END;

        SELECT
            ma.MovimientoID,
            ma.FechaMovimiento,
            ma.TipoMovimiento,
            ma.Monto,
            ma.Referencia,
            ma.Observacion,
            ma.CedulaEmpleado,
            ma.NombreEmpleado
        FROM coop.vw_MovimientosAuditoria AS ma
        WHERE ma.NumeroCuenta = @NumeroCuenta
          AND (@FechaInicio IS NULL OR ma.FechaMovimiento >= @FechaInicio)
          AND (@FechaFin IS NULL OR ma.FechaMovimiento <= @FechaFin)
        ORDER BY ma.FechaMovimiento DESC, ma.MovimientoID DESC;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgMov NVARCHAR(4000) = N'sp_ConsultarMovimientos: ' + ERROR_MESSAGE();
        THROW 52051, @ErrMsgMov, 1;
    END CATCH;
END;
GO

/* =====================================
   SP 3: Registrar socio en la cooperativa
   ===================================== */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarSocio
    @Cedula NVARCHAR(20),
    @Nombre NVARCHAR(80),
    @Apellido NVARCHAR(80),
    @Correo NVARCHAR(120) = NULL,
    @Telefono NVARCHAR(30) = NULL,
    @Direccion NVARCHAR(250) = NULL,
    @CedulaEmpleadoRegistro NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @SocioID INT;
        DECLARE @EmpleadoRegistroID INT = NULL;

        SET @Cedula = NULLIF(LTRIM(RTRIM(@Cedula)), N'');
        SET @Nombre = NULLIF(LTRIM(RTRIM(@Nombre)), N'');
        SET @Apellido = NULLIF(LTRIM(RTRIM(@Apellido)), N'');
        SET @Correo = NULLIF(LTRIM(RTRIM(@Correo)), N'');
        SET @Telefono = NULLIF(LTRIM(RTRIM(@Telefono)), N'');
        SET @Direccion = NULLIF(LTRIM(RTRIM(@Direccion)), N'');
        SET @CedulaEmpleadoRegistro = NULLIF(LTRIM(RTRIM(@CedulaEmpleadoRegistro)), N'');

        IF @Cedula IS NULL OR @Nombre IS NULL OR @Apellido IS NULL
        BEGIN
            THROW 52006, 'Los parametros @Cedula, @Nombre y @Apellido son obligatorios.', 1;
        END;

        IF EXISTS (SELECT 1 FROM coop.Socio WHERE Cedula = @Cedula)
        BEGIN
            THROW 52007, 'Ya existe un socio con la cedula indicada.', 1;
        END;

        IF @CedulaEmpleadoRegistro IS NOT NULL
        BEGIN
            SELECT @EmpleadoRegistroID = e.EmpleadoID
            FROM coop.Empleado AS e
            WHERE e.Cedula = @CedulaEmpleadoRegistro;

            IF @EmpleadoRegistroID IS NULL
            BEGIN
                THROW 52008, 'La cedula del empleado de registro no existe.', 1;
            END;
        END;

        INSERT INTO coop.Socio
        (
            Cedula,
            Nombre,
            Apellido,
            Correo,
            Telefono,
            Direccion,
            Estado
        )
        VALUES
        (
            @Cedula,
            @Nombre,
            @Apellido,
            @Correo,
            @Telefono,
            @Direccion,
            N'ACTIVO'
        );

        SET @SocioID = SCOPE_IDENTITY();

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
            N'SOCIO',
            CAST(@SocioID AS NVARCHAR(100)),
            N'INSERT',
            N'Registro de socio desde sp_RegistrarSocio. Cedula: ' + @Cedula,
            @EmpleadoRegistroID
        );

        SELECT
            @SocioID AS SocioID,
            @Cedula AS Cedula,
            @Nombre AS Nombre,
            @Apellido AS Apellido,
            N'Socio registrado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgSocio NVARCHAR(4000) = N'sp_RegistrarSocio: ' + ERROR_MESSAGE();
        THROW 52052, @ErrMsgSocio, 1;
    END CATCH;
END;
GO

/* =====================================
   SP 4: Crear cuenta de ahorro para socio
   ===================================== */
CREATE OR ALTER PROCEDURE coop.sp_CrearCuenta
    @NumeroCuenta NVARCHAR(30),
    @CedulaSocio NVARCHAR(20),
    @CodigoProducto NVARCHAR(20),
    @CedulaEmpleado NVARCHAR(20),
    @SaldoInicial DECIMAL(18,2) = 0
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @SocioID INT;
        DECLARE @ProductoFinancieroID INT;
        DECLARE @EmpleadoID INT;
        DECLARE @CuentaID INT;
        DECLARE @TipoProducto NVARCHAR(30);
        DECLARE @MontoMinimoApertura DECIMAL(18,2);

        SET @NumeroCuenta = NULLIF(LTRIM(RTRIM(@NumeroCuenta)), N'');
        SET @CedulaSocio = NULLIF(LTRIM(RTRIM(@CedulaSocio)), N'');
        SET @CodigoProducto = NULLIF(LTRIM(RTRIM(@CodigoProducto)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');

        IF @NumeroCuenta IS NULL OR @CedulaSocio IS NULL OR @CodigoProducto IS NULL OR @CedulaEmpleado IS NULL
        BEGIN
            THROW 52009, 'Los parametros @NumeroCuenta, @CedulaSocio, @CodigoProducto y @CedulaEmpleado son obligatorios.', 1;
        END;

        IF @SaldoInicial < 0
        BEGIN
            THROW 52010, 'El @SaldoInicial no puede ser negativo.', 1;
        END;

        IF EXISTS (SELECT 1 FROM coop.Cuenta WHERE NumeroCuenta = @NumeroCuenta)
        BEGIN
            THROW 52011, 'Ya existe una cuenta con ese numero.', 1;
        END;

        SELECT @SocioID = s.SocioID
        FROM coop.Socio AS s
        WHERE s.Cedula = @CedulaSocio;

        IF @SocioID IS NULL
        BEGIN
            THROW 52012, 'No existe un socio con la cedula indicada.', 1;
        END;

        SELECT
            @ProductoFinancieroID = p.ProductoFinancieroID,
            @TipoProducto = p.TipoProducto,
            @MontoMinimoApertura = p.MontoMinimoApertura
        FROM coop.ProductoFinanciero AS p
        WHERE p.CodigoProducto = @CodigoProducto
          AND p.Estado = N'ACTIVO';

        IF @ProductoFinancieroID IS NULL
        BEGIN
            THROW 52013, 'El producto financiero indicado no existe o esta inactivo.', 1;
        END;

        IF @TipoProducto <> N'AHORRO'
        BEGIN
            THROW 52014, 'sp_CrearCuenta solo permite productos de tipo AHORRO.', 1;
        END;

        IF @SaldoInicial < @MontoMinimoApertura
        BEGIN
            THROW 52015, 'El saldo inicial es menor al monto minimo de apertura del producto.', 1;
        END;

        SELECT @EmpleadoID = e.EmpleadoID
        FROM coop.Empleado AS e
        WHERE e.Cedula = @CedulaEmpleado
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52016, 'No existe un empleado activo con la cedula indicada.', 1;
        END;

        INSERT INTO coop.Cuenta
        (
            NumeroCuenta,
            SocioID,
            ProductoFinancieroID,
            CreadaPorEmpleadoID,
            Saldo,
            EstadoCuenta
        )
        VALUES
        (
            @NumeroCuenta,
            @SocioID,
            @ProductoFinancieroID,
            @EmpleadoID,
            @SaldoInicial,
            N'ACTIVA'
        );

        SET @CuentaID = SCOPE_IDENTITY();

        IF @SaldoInicial > 0
        BEGIN
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
                @SaldoInicial,
                N'APERTURA-' + @NumeroCuenta,
                N'Deposito inicial por apertura de cuenta.',
                @EmpleadoID
            );
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
            N'CUENTA',
            CAST(@CuentaID AS NVARCHAR(100)),
            N'INSERT',
            N'Creacion de cuenta desde sp_CrearCuenta. Numero: ' + @NumeroCuenta,
            @EmpleadoID
        );

        SELECT
            @CuentaID AS CuentaID,
            @NumeroCuenta AS NumeroCuenta,
            @SaldoInicial AS SaldoInicial,
            N'Cuenta creada correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgCuenta NVARCHAR(4000) = N'sp_CrearCuenta: ' + ERROR_MESSAGE();
        THROW 52053, @ErrMsgCuenta, 1;
    END CATCH;
END;
GO

/* =====================================
   SP 5: Consultar prestamo por numero
   ===================================== */
CREATE OR ALTER PROCEDURE coop.sp_ConsultarPrestamo
    @NumeroPrestamo NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @PrestamoID INT;

        SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');

        IF @NumeroPrestamo IS NULL
        BEGIN
            THROW 52017, 'El parametro @NumeroPrestamo es obligatorio.', 1;
        END;

        SELECT @PrestamoID = p.PrestamoID
        FROM coop.Prestamo AS p
        WHERE p.NumeroPrestamo = @NumeroPrestamo;

        IF @PrestamoID IS NULL
        BEGIN
            THROW 52018, 'El prestamo indicado no existe.', 1;
        END;

        SELECT
            pr.PrestamoID,
            pr.NumeroPrestamo,
            pr.CedulaSocio,
            pr.NombreSocio,
            pr.CodigoProducto,
            pr.NombreProducto,
            pr.MontoOriginal,
            pr.SaldoPendiente,
            pr.TasaInteres,
            pr.PlazoMeses,
            pr.FechaDesembolso,
            pr.EstadoPrestamo,
            pr.CantidadCuotas,
            pr.TotalProgramado,
            pr.TotalPagado,
            pr.CuotasPendientes
        FROM coop.vw_PrestamosResumen AS pr
        WHERE pr.NumeroPrestamo = @NumeroPrestamo;

        SELECT
            c.CuotaID,
            c.NumeroCuota,
            c.FechaVencimiento,
            c.MontoCuota,
            c.MontoPagado,
            c.FechaPago,
            c.EstadoCuota
        FROM coop.Cuota AS c
        WHERE c.PrestamoID = @PrestamoID
        ORDER BY c.NumeroCuota;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgPrestamo NVARCHAR(4000) = N'sp_ConsultarPrestamo: ' + ERROR_MESSAGE();
        THROW 52054, @ErrMsgPrestamo, 1;
    END CATCH;
END;
GO
