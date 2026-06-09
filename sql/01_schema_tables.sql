/*
  CoopCore - Script 01
  Archivo: 01_schema_tables.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Crear esquema coop y tablas del dominio.
  Nota: Script idempotente.
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    RAISERROR(
        'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.',
        16,
        1
    );
    RETURN;
END;
GO

USE CoopCoreDB;
GO

-- Opciones requeridas por SQL Server para crear y mantener indices filtrados.
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET NUMERIC_ROUNDABORT OFF;
GO

-- Crear el esquema funcional si aun no existe.
IF SCHEMA_ID(N'coop') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA coop AUTHORIZATION dbo;');
END;
GO

-- Tabla de socios de la cooperativa.
IF OBJECT_ID(N'coop.Socio', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Socio
    (
        SocioID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Socio PRIMARY KEY,
        Cedula NVARCHAR(20) NOT NULL,
        Nombre NVARCHAR(80) NOT NULL,
        Apellido NVARCHAR(80) NOT NULL,
        Correo NVARCHAR(120) NULL,
        Telefono NVARCHAR(30) NULL,
        Direccion NVARCHAR(250) NULL,
        Estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_Socio_Estado DEFAULT (N'ACTIVO'),
        FechaRegistro DATETIME2 NOT NULL
            CONSTRAINT DF_Socio_FechaRegistro DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_Socio_Cedula UNIQUE (Cedula),
        CONSTRAINT CK_Socio_Estado CHECK (Estado IN (N'ACTIVO', N'INACTIVO', N'SUSPENDIDO'))
    );
END;
GO

-- Tabla de roles de aplicacion (no confundir con roles de seguridad SQL Server).
IF OBJECT_ID(N'coop.Rol', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Rol
    (
        RolID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Rol PRIMARY KEY,
        NombreRol NVARCHAR(50) NOT NULL,
        Descripcion NVARCHAR(200) NULL,
        Estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_Rol_Estado DEFAULT (N'ACTIVO'),
        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_Rol_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_Rol_NombreRol UNIQUE (NombreRol),
        CONSTRAINT CK_Rol_Estado CHECK (Estado IN (N'ACTIVO', N'INACTIVO'))
    );
END;
GO

-- Tabla de empleados que operan en la cooperativa.
IF OBJECT_ID(N'coop.Empleado', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Empleado
    (
        EmpleadoID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Empleado PRIMARY KEY,
        Cedula NVARCHAR(20) NOT NULL,
        Nombre NVARCHAR(80) NOT NULL,
        Apellido NVARCHAR(80) NOT NULL,
        Correo NVARCHAR(120) NULL,
        Telefono NVARCHAR(30) NULL,
        RolID INT NULL,
        Estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_Empleado_Estado DEFAULT (N'ACTIVO'),
        FechaIngreso DATETIME2 NOT NULL
            CONSTRAINT DF_Empleado_FechaIngreso DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_Empleado_Cedula UNIQUE (Cedula),
        CONSTRAINT CK_Empleado_Estado CHECK (Estado IN (N'ACTIVO', N'INACTIVO')),
        CONSTRAINT FK_Empleado_Rol FOREIGN KEY (RolID)
            REFERENCES coop.Rol(RolID)
    );
END;
GO

-- Columnas de autenticacion agregadas como migracion idempotente para
-- instalaciones existentes del Entregable 1.
IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'NombreUsuario'
)
BEGIN
    ALTER TABLE coop.Empleado
        ADD NombreUsuario NVARCHAR(50) NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'PasswordHash'
)
BEGIN
    ALTER TABLE coop.Empleado
        ADD PasswordHash VARBINARY(64) NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'PasswordSalt'
)
BEGIN
    ALTER TABLE coop.Empleado
        ADD PasswordSalt VARBINARY(32) NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'UltimoLogin'
)
BEGIN
    ALTER TABLE coop.Empleado
        ADD UltimoLogin DATETIME2 NULL;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'IntentosFallidos'
)
BEGIN
    ALTER TABLE coop.Empleado
        ADD IntentosFallidos INT NOT NULL
            CONSTRAINT DF_Empleado_IntentosFallidos DEFAULT (0);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.columns
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'BloqueadoHasta'
)
BEGIN
    ALTER TABLE coop.Empleado
        ADD BloqueadoHasta DATETIME2 NULL;
END;
GO

-- Un indice unico filtrado permite varios empleados sin credenciales mientras
-- garantiza que todo NombreUsuario asignado sea unico. Una restriccion UNIQUE
-- normal solo permitiria un NULL y fallaria al migrar los empleados existentes.
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Empleado')
      AND name = N'UQ_Empleado_NombreUsuario'
)
BEGIN
    EXEC sys.sp_executesql N'
        CREATE UNIQUE INDEX UQ_Empleado_NombreUsuario
            ON coop.Empleado (NombreUsuario)
            WHERE NombreUsuario IS NOT NULL;
    ';
END;
GO

-- Catalogo de productos financieros.
IF OBJECT_ID(N'coop.ProductoFinanciero', N'U') IS NULL
BEGIN
    CREATE TABLE coop.ProductoFinanciero
    (
        ProductoFinancieroID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_ProductoFinanciero PRIMARY KEY,
        CodigoProducto NVARCHAR(20) NOT NULL,
        NombreProducto NVARCHAR(100) NOT NULL,
        TipoProducto NVARCHAR(30) NOT NULL,
        TasaInteres DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_ProductoFinanciero_TasaInteres DEFAULT (0),
        MontoMinimoApertura DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_ProductoFinanciero_MontoMinimo DEFAULT (0),
        Estado NVARCHAR(20) NOT NULL
            CONSTRAINT DF_ProductoFinanciero_Estado DEFAULT (N'ACTIVO'),
        FechaCreacion DATETIME2 NOT NULL
            CONSTRAINT DF_ProductoFinanciero_FechaCreacion DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_ProductoFinanciero_Codigo UNIQUE (CodigoProducto),
        CONSTRAINT UQ_ProductoFinanciero_Nombre UNIQUE (NombreProducto),
        CONSTRAINT CK_ProductoFinanciero_Tipo CHECK (
            TipoProducto IN (N'AHORRO', N'PRESTAMO', N'CERTIFICADO', N'OTRO')
        ),
        CONSTRAINT CK_ProductoFinanciero_Tasa CHECK (TasaInteres >= 0 AND TasaInteres <= 100),
        CONSTRAINT CK_ProductoFinanciero_MontoMinimo CHECK (MontoMinimoApertura >= 0),
        CONSTRAINT CK_ProductoFinanciero_Estado CHECK (Estado IN (N'ACTIVO', N'INACTIVO'))
    );
END;
GO

-- Cuentas de ahorro o productos vinculados a un socio.
IF OBJECT_ID(N'coop.Cuenta', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Cuenta
    (
        CuentaID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Cuenta PRIMARY KEY,
        NumeroCuenta NVARCHAR(30) NOT NULL,
        SocioID INT NOT NULL,
        ProductoFinancieroID INT NOT NULL,
        CreadaPorEmpleadoID INT NULL,
        Saldo DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_Cuenta_Saldo DEFAULT (0),
        EstadoCuenta NVARCHAR(20) NOT NULL
            CONSTRAINT DF_Cuenta_Estado DEFAULT (N'ACTIVA'),
        FechaApertura DATETIME2 NOT NULL
            CONSTRAINT DF_Cuenta_FechaApertura DEFAULT (SYSDATETIME()),
        CONSTRAINT UQ_Cuenta_NumeroCuenta UNIQUE (NumeroCuenta),
        CONSTRAINT CK_Cuenta_Saldo CHECK (Saldo >= 0),
        CONSTRAINT CK_Cuenta_Estado CHECK (
            EstadoCuenta IN (N'ACTIVA', N'INACTIVA', N'BLOQUEADA', N'CERRADA')
        ),
        CONSTRAINT FK_Cuenta_Socio FOREIGN KEY (SocioID)
            REFERENCES coop.Socio(SocioID),
        CONSTRAINT FK_Cuenta_ProductoFinanciero FOREIGN KEY (ProductoFinancieroID)
            REFERENCES coop.ProductoFinanciero(ProductoFinancieroID),
        CONSTRAINT FK_Cuenta_Empleado FOREIGN KEY (CreadaPorEmpleadoID)
            REFERENCES coop.Empleado(EmpleadoID)
    );
END;
GO

-- Prestamos otorgados a socios.
IF OBJECT_ID(N'coop.Prestamo', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Prestamo
    (
        PrestamoID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Prestamo PRIMARY KEY,
        NumeroPrestamo NVARCHAR(30) NOT NULL,
        SocioID INT NOT NULL,
        ProductoFinancieroID INT NOT NULL,
        AprobadoPorEmpleadoID INT NULL,
        MontoOriginal DECIMAL(18,2) NOT NULL,
        SaldoPendiente DECIMAL(18,2) NOT NULL,
        TasaInteres DECIMAL(18,2) NOT NULL,
        PlazoMeses INT NOT NULL,
        FechaDesembolso DATETIME2 NOT NULL
            CONSTRAINT DF_Prestamo_FechaDesembolso DEFAULT (SYSDATETIME()),
        EstadoPrestamo NVARCHAR(20) NOT NULL
            CONSTRAINT DF_Prestamo_Estado DEFAULT (N'SOLICITADO'),
        CONSTRAINT UQ_Prestamo_NumeroPrestamo UNIQUE (NumeroPrestamo),
        CONSTRAINT CK_Prestamo_MontoOriginal CHECK (MontoOriginal > 0),
        CONSTRAINT CK_Prestamo_SaldoPendiente CHECK (
            SaldoPendiente >= 0 AND SaldoPendiente <= MontoOriginal
        ),
        CONSTRAINT CK_Prestamo_Tasa CHECK (TasaInteres >= 0 AND TasaInteres <= 100),
        CONSTRAINT CK_Prestamo_Plazo CHECK (PlazoMeses > 0),
        CONSTRAINT CK_Prestamo_Estado CHECK (
            EstadoPrestamo IN (N'SOLICITADO', N'ACTIVO', N'PAGADO', N'MORA', N'CANCELADO')
        ),
        CONSTRAINT FK_Prestamo_Socio FOREIGN KEY (SocioID)
            REFERENCES coop.Socio(SocioID),
        CONSTRAINT FK_Prestamo_ProductoFinanciero FOREIGN KEY (ProductoFinancieroID)
            REFERENCES coop.ProductoFinanciero(ProductoFinancieroID),
        CONSTRAINT FK_Prestamo_Empleado FOREIGN KEY (AprobadoPorEmpleadoID)
            REFERENCES coop.Empleado(EmpleadoID)
    );
END;
GO

-- Cuotas de amortizacion por prestamo.
IF OBJECT_ID(N'coop.Cuota', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Cuota
    (
        CuotaID INT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Cuota PRIMARY KEY,
        PrestamoID INT NOT NULL,
        NumeroCuota INT NOT NULL,
        FechaVencimiento DATE NOT NULL,
        MontoCuota DECIMAL(18,2) NOT NULL,
        MontoPagado DECIMAL(18,2) NOT NULL
            CONSTRAINT DF_Cuota_MontoPagado DEFAULT (0),
        FechaPago DATETIME2 NULL,
        EstadoCuota NVARCHAR(20) NOT NULL
            CONSTRAINT DF_Cuota_Estado DEFAULT (N'PENDIENTE'),
        CONSTRAINT UQ_Cuota_Prestamo_Numero UNIQUE (PrestamoID, NumeroCuota),
        CONSTRAINT CK_Cuota_Numero CHECK (NumeroCuota > 0),
        CONSTRAINT CK_Cuota_MontoCuota CHECK (MontoCuota > 0),
        CONSTRAINT CK_Cuota_MontoPagado CHECK (
            MontoPagado >= 0 AND MontoPagado <= MontoCuota
        ),
        CONSTRAINT CK_Cuota_Estado CHECK (
            EstadoCuota IN (N'PENDIENTE', N'PAGADA', N'VENCIDA', N'PARCIAL')
        ),
        CONSTRAINT FK_Cuota_Prestamo FOREIGN KEY (PrestamoID)
            REFERENCES coop.Prestamo(PrestamoID)
    );
END;
GO

-- Bitacora de movimientos monetarios. Debe permanecer inmutable.
IF OBJECT_ID(N'coop.Movimiento', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Movimiento
    (
        MovimientoID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Movimiento PRIMARY KEY,
        CuentaID INT NOT NULL,
        TipoMovimiento NVARCHAR(30) NOT NULL,
        Monto DECIMAL(18,2) NOT NULL,
        Referencia NVARCHAR(50) NULL,
        Observacion NVARCHAR(300) NULL,
        FechaMovimiento DATETIME2 NOT NULL
            CONSTRAINT DF_Movimiento_Fecha DEFAULT (SYSDATETIME()),
        EjecutadoPorEmpleadoID INT NOT NULL,
        CONSTRAINT CK_Movimiento_Tipo CHECK (
            TipoMovimiento IN (
                N'DEPOSITO',
                N'RETIRO',
                N'TRANSFERENCIA_ENTRADA',
                N'TRANSFERENCIA_SALIDA',
                N'AJUSTE'
            )
        ),
        CONSTRAINT CK_Movimiento_Monto CHECK (Monto > 0),
        CONSTRAINT FK_Movimiento_Cuenta FOREIGN KEY (CuentaID)
            REFERENCES coop.Cuenta(CuentaID),
        CONSTRAINT FK_Movimiento_Empleado FOREIGN KEY (EjecutadoPorEmpleadoID)
            REFERENCES coop.Empleado(EmpleadoID)
    );
END;
GO

-- Tabla general de auditoria.
IF OBJECT_ID(N'coop.Auditoria', N'U') IS NULL
BEGIN
    CREATE TABLE coop.Auditoria
    (
        AuditoriaID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_Auditoria PRIMARY KEY,
        Entidad NVARCHAR(100) NOT NULL,
        EntidadID NVARCHAR(100) NULL,
        Accion NVARCHAR(30) NOT NULL,
        Descripcion NVARCHAR(4000) NULL,
        FechaEvento DATETIME2 NOT NULL
            CONSTRAINT DF_Auditoria_FechaEvento DEFAULT (SYSDATETIME()),
        UsuarioSQL NVARCHAR(128) NOT NULL
            CONSTRAINT DF_Auditoria_UsuarioSQL DEFAULT (ORIGINAL_LOGIN()),
        UsuarioBD NVARCHAR(128) NOT NULL
            CONSTRAINT DF_Auditoria_UsuarioBD DEFAULT (USER_NAME()),
        EmpleadoID INT NULL,
        CONSTRAINT CK_Auditoria_Accion CHECK (
            Accion IN (N'INSERT', N'UPDATE', N'DELETE', N'EXECUTE', N'LOGIN', N'OTRO')
        ),
        CONSTRAINT FK_Auditoria_Empleado FOREIGN KEY (EmpleadoID)
            REFERENCES coop.Empleado(EmpleadoID)
    );
END;
GO

-- Refuerzo de inmutabilidad para movimientos contables.
IF OBJECT_ID(N'coop.Movimiento', N'U') IS NOT NULL
BEGIN
    EXEC(N'
    CREATE OR ALTER TRIGGER coop.tr_Movimiento_Inmutable
    ON coop.Movimiento
    INSTEAD OF UPDATE, DELETE
    AS
    BEGIN
        SET NOCOUNT ON;
        THROW 51001, ''coop.Movimiento es inmutable: no se permite UPDATE ni DELETE.'', 1;
    END;
    ');
END;
GO
