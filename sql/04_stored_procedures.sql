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

-- Opciones requeridas al modificar coop.Empleado, que tiene un indice
-- unico filtrado sobre NombreUsuario.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

IF SCHEMA_ID(N'coop') IS NULL
BEGIN
    THROW 51002, 'No existe el esquema coop. Ejecute primero sql/01_schema_tables.sql.', 1;
END;
GO

/* ============================================================
   SP 6: Validar credenciales de acceso
   Proposito:
   - Autenticar usuarios del API con SHA2_256 y salt.
   - Registrar intentos en auditoria.
   - Bloquear la cuenta durante 15 minutos despues de 5 fallos.
   Parametros:
   - @NombreUsuario: usuario de aplicacion.
   - @Password: password en texto plano recibido para validacion.
   Resultados:
   - OK: credenciales validas y datos del empleado.
   - FALLO: credenciales invalidas o usuario inactivo/sin credenciales.
   - BLOQUEADO: cuenta dentro del periodo de bloqueo temporal.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_ValidarLogin
    @NombreUsuario NVARCHAR(50),
    @Password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NombreUsuario = NULLIF(LTRIM(RTRIM(@NombreUsuario)), N'');
        SET @Password = NULLIF(@Password, N'');

        IF @NombreUsuario IS NULL OR @Password IS NULL
        BEGIN
            THROW 52070, 'Los parametros @NombreUsuario y @Password son obligatorios.', 1;
        END;

        DECLARE @EmpleadoID INT;
        DECLARE @PasswordHashAlmacenado VARBINARY(64);
        DECLARE @PasswordSaltAlmacenado VARBINARY(32);
        DECLARE @Estado NVARCHAR(20);
        DECLARE @IntentosFallidos INT;
        DECLARE @BloqueadoHasta DATETIME2;
        DECLARE @HashCalculado VARBINARY(64);

        SELECT
            @EmpleadoID = e.EmpleadoID,
            @PasswordHashAlmacenado = e.PasswordHash,
            @PasswordSaltAlmacenado = e.PasswordSalt,
            @Estado = e.Estado,
            @IntentosFallidos = e.IntentosFallidos,
            @BloqueadoHasta = e.BloqueadoHasta
        FROM coop.Empleado AS e
        WHERE e.NombreUsuario = @NombreUsuario;

        -- No revelar al cliente si el usuario no existe.
        IF @EmpleadoID IS NULL
        BEGIN
            INSERT INTO coop.Auditoria (Entidad, Accion, Descripcion)
            VALUES
            (
                N'EMPLEADO',
                N'LOGIN',
                N'Login fallido. Usuario inexistente: ' + @NombreUsuario
            );

            SELECT
                N'FALLO' AS Resultado,
                N'Credenciales invalidas.' AS Mensaje;
            RETURN;
        END;

        IF @Estado <> N'ACTIVO'
        BEGIN
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
                N'EMPLEADO',
                CAST(@EmpleadoID AS NVARCHAR(100)),
                N'LOGIN',
                N'Login fallido. Usuario inactivo.',
                @EmpleadoID
            );

            SELECT
                N'FALLO' AS Resultado,
                N'Credenciales invalidas.' AS Mensaje;
            RETURN;
        END;

        IF @PasswordHashAlmacenado IS NULL OR @PasswordSaltAlmacenado IS NULL
        BEGIN
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
                N'EMPLEADO',
                CAST(@EmpleadoID AS NVARCHAR(100)),
                N'LOGIN',
                N'Login fallido. Usuario sin credenciales configuradas.',
                @EmpleadoID
            );

            SELECT
                N'FALLO' AS Resultado,
                N'Credenciales invalidas.' AS Mensaje;
            RETURN;
        END;

        IF @BloqueadoHasta IS NOT NULL AND @BloqueadoHasta > SYSDATETIME()
        BEGIN
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
                N'EMPLEADO',
                CAST(@EmpleadoID AS NVARCHAR(100)),
                N'LOGIN',
                N'Login fallido. Usuario bloqueado hasta '
                    + CONVERT(NVARCHAR(30), @BloqueadoHasta, 121),
                @EmpleadoID
            );

            SELECT
                N'BLOQUEADO' AS Resultado,
                N'Cuenta bloqueada temporalmente. Intente mas tarde.' AS Mensaje,
                @BloqueadoHasta AS BloqueadoHasta;
            RETURN;
        END;

        SET @HashCalculado = HASHBYTES
        (
            'SHA2_256',
            @PasswordSaltAlmacenado + CONVERT(VARBINARY(MAX), @Password)
        );

        IF @HashCalculado <> @PasswordHashAlmacenado
        BEGIN
            UPDATE coop.Empleado
            SET IntentosFallidos = IntentosFallidos + 1,
                BloqueadoHasta = CASE
                    WHEN IntentosFallidos + 1 >= 5
                    THEN DATEADD(MINUTE, 15, SYSDATETIME())
                    ELSE BloqueadoHasta
                END
            WHERE EmpleadoID = @EmpleadoID;

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
                N'EMPLEADO',
                CAST(@EmpleadoID AS NVARCHAR(100)),
                N'LOGIN',
                N'Login fallido. Password incorrecto. Intentos: '
                    + CAST(@IntentosFallidos + 1 AS NVARCHAR(10)),
                @EmpleadoID
            );

            SELECT
                N'FALLO' AS Resultado,
                N'Credenciales invalidas.' AS Mensaje;
            RETURN;
        END;

        UPDATE coop.Empleado
        SET IntentosFallidos = 0,
            BloqueadoHasta = NULL,
            UltimoLogin = SYSDATETIME()
        WHERE EmpleadoID = @EmpleadoID;

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
            N'EMPLEADO',
            CAST(@EmpleadoID AS NVARCHAR(100)),
            N'LOGIN',
            N'Login exitoso.',
            @EmpleadoID
        );

        SELECT
            N'OK' AS Resultado,
            e.EmpleadoID,
            e.NombreUsuario,
            e.Nombre,
            e.Apellido,
            e.Correo,
            r.NombreRol,
            N'Login exitoso.' AS Mensaje
        FROM coop.Empleado AS e
        LEFT JOIN coop.Rol AS r
            ON r.RolID = e.RolID
        WHERE e.EmpleadoID = @EmpleadoID;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgLogin NVARCHAR(4000) =
            N'sp_ValidarLogin: ' + ERROR_MESSAGE();
        THROW 52060, @ErrMsgLogin, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 7: Obtener usuario por credenciales
   Proposito:
   - Validar credenciales para consultas internas sin auditoria ni bloqueo.
   Parametros:
   - @NombreUsuario: usuario de aplicacion.
   - @Password: password en texto plano recibido para validacion.
   Resultado:
   - Una fila con datos del empleado si las credenciales coinciden.
   - Resultset vacio si las credenciales no coinciden.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_ObtenerUsuarioPorCredenciales
    @NombreUsuario NVARCHAR(50),
    @Password NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NombreUsuario = NULLIF(LTRIM(RTRIM(@NombreUsuario)), N'');
        SET @Password = NULLIF(@Password, N'');

        IF @NombreUsuario IS NULL OR @Password IS NULL
        BEGIN
            THROW 52071, 'Los parametros son obligatorios.', 1;
        END;

        SELECT
            e.EmpleadoID,
            e.NombreUsuario,
            e.Nombre,
            e.Apellido,
            r.NombreRol
        FROM coop.Empleado AS e
        LEFT JOIN coop.Rol AS r
            ON r.RolID = e.RolID
        WHERE e.NombreUsuario = @NombreUsuario
          AND e.Estado = N'ACTIVO'
          AND e.PasswordHash IS NOT NULL
          AND e.PasswordSalt IS NOT NULL
          AND e.PasswordHash = HASHBYTES
          (
              'SHA2_256',
              e.PasswordSalt + CONVERT(VARBINARY(MAX), @Password)
          );
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgCredenciales NVARCHAR(4000) =
            N'sp_ObtenerUsuarioPorCredenciales: ' + ERROR_MESSAGE();
        THROW 52061, @ErrMsgCredenciales, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 8: Cambiar password de un empleado
   Proposito:
   - Validar el password actual y guardar un nuevo hash con salt aleatorio.
   Parametros:
   - @NombreUsuario: usuario de aplicacion.
   - @PasswordActual: password vigente.
   - @PasswordNuevo: nuevo password, minimo 8 caracteres.
   Resultado:
   - OK: password actualizado y evento registrado en auditoria.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_CambiarPassword
    @NombreUsuario NVARCHAR(50),
    @PasswordActual NVARCHAR(100),
    @PasswordNuevo NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @NombreUsuario = NULLIF(LTRIM(RTRIM(@NombreUsuario)), N'');
        SET @PasswordActual = NULLIF(@PasswordActual, N'');
        SET @PasswordNuevo = NULLIF(@PasswordNuevo, N'');

        IF @NombreUsuario IS NULL
           OR @PasswordActual IS NULL
           OR @PasswordNuevo IS NULL
        BEGIN
            THROW 52072, 'Todos los parametros son obligatorios.', 1;
        END;

        IF LEN(@PasswordNuevo) < 8
        BEGIN
            THROW 52073, 'El nuevo password debe tener al menos 8 caracteres.', 1;
        END;

        DECLARE @EmpleadoID INT;
        DECLARE @SaltActual VARBINARY(32);
        DECLARE @HashActual VARBINARY(64);

        SELECT
            @EmpleadoID = e.EmpleadoID,
            @SaltActual = e.PasswordSalt,
            @HashActual = e.PasswordHash
        FROM coop.Empleado AS e
        WHERE e.NombreUsuario = @NombreUsuario
          AND e.Estado = N'ACTIVO';

        IF @EmpleadoID IS NULL
        BEGIN
            THROW 52074, 'Usuario no encontrado o inactivo.', 1;
        END;

        IF @SaltActual IS NULL
           OR @HashActual IS NULL
           OR HASHBYTES
              (
                  'SHA2_256',
                  @SaltActual + CONVERT(VARBINARY(MAX), @PasswordActual)
              ) <> @HashActual
        BEGIN
            THROW 52075, 'Password actual incorrecto.', 1;
        END;

        DECLARE @SaltNuevo VARBINARY(32) = CRYPT_GEN_RANDOM(32);
        DECLARE @HashNuevo VARBINARY(64) = HASHBYTES
        (
            'SHA2_256',
            @SaltNuevo + CONVERT(VARBINARY(MAX), @PasswordNuevo)
        );

        UPDATE coop.Empleado
        SET PasswordSalt = @SaltNuevo,
            PasswordHash = @HashNuevo
        WHERE EmpleadoID = @EmpleadoID;

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
            N'EMPLEADO',
            CAST(@EmpleadoID AS NVARCHAR(100)),
            N'UPDATE',
            N'Cambio de password.',
            @EmpleadoID
        );

        SELECT
            N'OK' AS Resultado,
            N'Password actualizado correctamente.' AS Mensaje;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgPassword NVARCHAR(4000) =
            N'sp_CambiarPassword: ' + ERROR_MESSAGE();
        THROW 52062, @ErrMsgPassword, 1;
    END CATCH;
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
   SP API: Consultar socio por identificador
   Proposito:
   - Exponer una consulta puntual de socio para la API .NET.
   - Acepta cedula o SocioID como identificador de ruta.
   Parametros:
   - @Identificador: cedula del socio o SocioID.
   Resultado:
   - Datos generales y resumen de productos asociados.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_ConsultarSocio
    @Identificador NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @Identificador = NULLIF(LTRIM(RTRIM(@Identificador)), N'');

        IF @Identificador IS NULL
        BEGIN
            THROW 52019, 'El parametro @Identificador es obligatorio.', 1;
        END;

        DECLARE @SocioID INT = TRY_CONVERT(INT, @Identificador);

        IF EXISTS
        (
            SELECT 1
            FROM coop.vw_SociosConsulta
            WHERE Cedula = @Identificador
        )
        BEGIN
            SELECT
                SocioID,
                Cedula,
                Nombre,
                Apellido,
                Correo,
                Telefono,
                Direccion,
                Estado,
                FechaRegistro,
                CantidadCuentas,
                SaldoTotalCuentas,
                CantidadPrestamos,
                SaldoTotalPrestamos
            FROM coop.vw_SociosConsulta
            WHERE Cedula = @Identificador;

            RETURN;
        END;

        IF @SocioID IS NOT NULL
           AND EXISTS
           (
               SELECT 1
               FROM coop.vw_SociosConsulta
               WHERE SocioID = @SocioID
           )
        BEGIN
            SELECT
                SocioID,
                Cedula,
                Nombre,
                Apellido,
                Correo,
                Telefono,
                Direccion,
                Estado,
                FechaRegistro,
                CantidadCuentas,
                SaldoTotalCuentas,
                CantidadPrestamos,
                SaldoTotalPrestamos
            FROM coop.vw_SociosConsulta
            WHERE SocioID = @SocioID;

            RETURN;
        END;

        THROW 52020, 'El socio indicado no existe.', 1;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgSocioConsulta NVARCHAR(4000) =
            N'sp_ConsultarSocio: ' + ERROR_MESSAGE();
        THROW 52055, @ErrMsgSocioConsulta, 1;
    END CATCH;
END;
GO

/* ============================================================
   SP 1: Consultar saldo de una cuenta
   Descripcion: Devuelve saldo, socio, producto y ultimo movimiento.
   Parametros: @NumeroCuenta.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
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

/* ============================================================
   SP 2: Consultar movimientos de una cuenta
   Descripcion: Consulta el historial por cuenta y rango de fechas.
   Parametros: @NumeroCuenta, @FechaInicio y @FechaFin.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
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

/* ============================================================
   SP 3: Registrar socio en la cooperativa
   Descripcion: Crea un socio con validaciones y auditoria.
   Parametros: datos personales y cedula del empleado responsable.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
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

/* ============================================================
   SP 4: Crear cuenta de ahorro para socio
   Descripcion: Abre una cuenta y registra el deposito inicial opcional.
   Parametros: socio, producto, empleado y saldo inicial.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
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

/* ============================================================
   SP 5: Consultar prestamo por numero
   Descripcion: Devuelve resumen y calendario de cuotas del prestamo.
   Parametros: @NumeroPrestamo.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
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

/* ============================================================
   SP 9: Consultar eventos de auditoria
   Proposito:
   - Consultar la bitacora con filtros opcionales por fecha, entidad,
     accion y empleado.
   Parametros:
   - @FechaInicio y @FechaFin: rango inclusivo de fechas.
   - @Entidad: entidad auditada.
   - @Accion: tipo de evento.
   - @CedulaEmpleado: empleado asociado al evento.
   Resultado:
   - Eventos coincidentes ordenados del mas reciente al mas antiguo.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_ConsultarAuditoria
    @FechaInicio DATETIME2 = NULL,
    @FechaFin DATETIME2 = NULL,
    @Entidad NVARCHAR(100) = NULL,
    @Accion NVARCHAR(30) = NULL,
    @CedulaEmpleado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @FechaInicio IS NOT NULL
           AND @FechaFin IS NOT NULL
           AND @FechaInicio > @FechaFin
        BEGIN
            THROW 52080, '@FechaInicio no puede ser mayor que @FechaFin.', 1;
        END;

        SET @Entidad = NULLIF(LTRIM(RTRIM(@Entidad)), N'');
        SET @Accion = NULLIF(LTRIM(RTRIM(@Accion)), N'');
        SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');

        DECLARE @EmpleadoFiltroID INT = NULL;

        IF @CedulaEmpleado IS NOT NULL
        BEGIN
            SELECT @EmpleadoFiltroID = e.EmpleadoID
            FROM coop.Empleado AS e
            WHERE e.Cedula = @CedulaEmpleado;

            IF @EmpleadoFiltroID IS NULL
            BEGIN
                THROW 52081, 'No existe empleado con la cedula indicada.', 1;
            END;
        END;

        SELECT
            a.AuditoriaID,
            a.FechaEvento,
            a.Entidad,
            a.EntidadID,
            a.Accion,
            a.Descripcion,
            a.UsuarioSQL,
            a.UsuarioBD,
            e.Cedula AS CedulaEmpleado,
            CASE
                WHEN e.EmpleadoID IS NOT NULL
                THEN e.Nombre + N' ' + e.Apellido
                ELSE NULL
            END AS NombreEmpleado
        FROM coop.Auditoria AS a
        LEFT JOIN coop.Empleado AS e
            ON e.EmpleadoID = a.EmpleadoID
        WHERE (@FechaInicio IS NULL OR a.FechaEvento >= @FechaInicio)
          AND (@FechaFin IS NULL OR a.FechaEvento <= @FechaFin)
          AND (@Entidad IS NULL OR a.Entidad = @Entidad)
          AND (@Accion IS NULL OR a.Accion = @Accion)
          AND
          (
              @EmpleadoFiltroID IS NULL
              OR a.EmpleadoID = @EmpleadoFiltroID
          )
        ORDER BY a.FechaEvento DESC, a.AuditoriaID DESC;
    END TRY
    BEGIN CATCH
        DECLARE @ErrMsgAuditoria NVARCHAR(4000) =
            N'sp_ConsultarAuditoria: ' + ERROR_MESSAGE();
        THROW 52063, @ErrMsgAuditoria, 1;
    END CATCH;
END;
GO
