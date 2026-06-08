/*
  CoopCore - Script 02
  Archivo: 02_seed_data.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Insertar datos de prueba coherentes.
  Nota: Script idempotente (MERGE/UPSERT).
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    THROW 51000, 'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.', 1;
END;
GO

USE CoopCoreDB;
GO

-- Opciones requeridas para modificar tablas que tienen indices filtrados.
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

SET NOCOUNT ON;
GO

-- Roles de aplicacion.
;WITH src AS
(
    SELECT *
    FROM (VALUES
        (N'ADMIN_APP', N'Rol de aplicacion para administracion interna', N'ACTIVO'),
        (N'CAJERO_APP', N'Rol de aplicacion para operaciones de caja', N'ACTIVO'),
        (N'OFICIAL_CREDITO_APP', N'Rol de aplicacion para gestion de creditos', N'ACTIVO'),
        (N'AUDITOR_APP', N'Rol de aplicacion para consulta y auditoria', N'ACTIVO')
    ) AS v (NombreRol, Descripcion, Estado)
)
MERGE coop.Rol AS tgt
USING src
    ON tgt.NombreRol = src.NombreRol
WHEN MATCHED THEN
    UPDATE SET
        tgt.Descripcion = src.Descripcion,
        tgt.Estado = src.Estado
WHEN NOT MATCHED BY TARGET THEN
    INSERT (NombreRol, Descripcion, Estado)
    VALUES (src.NombreRol, src.Descripcion, src.Estado);
GO

-- ============================================================
-- ATENCION: PASSWORDS DE LABORATORIO
-- Los hashes de abajo son LITERALES (no generados al vuelo) para que el
-- seed sea reproducible. Las contrasenas en texto plano estan documentadas
-- en docs/manual_tecnico.md y SOLO sirven en ambiente academico.
-- NO USAR EN PRODUCCION.
-- ============================================================
-- Empleados de prueba.
;WITH src AS
(
    SELECT
        v.Cedula,
        v.Nombre,
        v.Apellido,
        v.Correo,
        v.Telefono,
        r.RolID,
        v.Estado,
        v.FechaIngreso,
        v.NombreUsuario,
        v.PasswordHash,
        v.PasswordSalt
    FROM (VALUES
        (
            N'EM-0101', N'Maria', N'Rojas', N'maria.rojas@coopcore.lab',
            N'7000-0101', N'CAJERO_APP', N'ACTIVO',
            CAST('2024-01-10T08:00:00' AS DATETIME2), N'mlrojas',
            0x190DCDC8D4AE97097176545B77DDD33F789241FAB35BD9BE52883C505CE57925,
            0x1A2B3C4D5E6F708192A3B4C5D6E7F80910111213141516171819202122232425
        ),
        (
            N'EM-0102', N'Carlos', N'Mena', N'carlos.mena@coopcore.lab',
            N'7000-0102', N'OFICIAL_CREDITO_APP', N'ACTIVO',
            CAST('2024-01-11T08:00:00' AS DATETIME2), N'cmena',
            0xAADACD201C304D85B67003AC83977CE8D650D9BF08DF60810C3043DDCBCA3F9D,
            0x2B3C4D5E6F708192A3B4C5D6E7F8091011121314151617181920212223242526
        ),
        (
            N'EM-0103', N'Andrea', N'Solis', N'andrea.solis@coopcore.lab',
            N'7000-0103', N'AUDITOR_APP', N'ACTIVO',
            CAST('2024-01-12T08:00:00' AS DATETIME2), N'asolis',
            0x90A78C43790F25C35B8DF14C67C7B3F7AE51D3273C6260198B3EA52B4A52EAD7,
            0x3C4D5E6F708192A3B4C5D6E7F809101112131415161718192021222324252627
        ),
        (
            N'EM-0104', N'Luis', N'Porras', N'luis.porras@coopcore.lab',
            N'7000-0104', N'ADMIN_APP', N'ACTIVO',
            CAST('2024-01-13T08:00:00' AS DATETIME2), N'lporras',
            0x9B954E0E7781B97D13D9E86D0ED79CE06D0B7F83939285E3B68D981C58B25524,
            0x4D5E6F708192A3B4C5D6E7F80910111213141516171819202122232425262728
        )
    ) AS v
    (
        Cedula,
        Nombre,
        Apellido,
        Correo,
        Telefono,
        NombreRol,
        Estado,
        FechaIngreso,
        NombreUsuario,
        PasswordHash,
        PasswordSalt
    )
    INNER JOIN coop.Rol AS r
        ON r.NombreRol = v.NombreRol
)
MERGE coop.Empleado AS tgt
USING src
    ON tgt.Cedula = src.Cedula
WHEN MATCHED THEN
    UPDATE SET
        tgt.Nombre = src.Nombre,
        tgt.Apellido = src.Apellido,
        tgt.Correo = src.Correo,
        tgt.Telefono = src.Telefono,
        tgt.RolID = src.RolID,
        tgt.Estado = src.Estado,
        tgt.FechaIngreso = src.FechaIngreso,
        tgt.NombreUsuario = src.NombreUsuario,
        tgt.PasswordHash = src.PasswordHash,
        tgt.PasswordSalt = src.PasswordSalt
WHEN NOT MATCHED BY TARGET THEN
    INSERT
    (
        Cedula,
        Nombre,
        Apellido,
        Correo,
        Telefono,
        RolID,
        Estado,
        FechaIngreso,
        NombreUsuario,
        PasswordHash,
        PasswordSalt
    )
    VALUES
    (
        src.Cedula,
        src.Nombre,
        src.Apellido,
        src.Correo,
        src.Telefono,
        src.RolID,
        src.Estado,
        src.FechaIngreso,
        src.NombreUsuario,
        src.PasswordHash,
        src.PasswordSalt
    );
GO

-- Socios de prueba.
;WITH src AS
(
    SELECT *
    FROM (VALUES
        (N'SO-1001', N'Ana',   N'Martinez', N'ana.martinez@correo.lab',   N'8888-1001', N'San Jose',   N'ACTIVO',   CAST('2024-02-01T09:00:00' AS DATETIME2)),
        (N'SO-1002', N'Diego', N'Alvarado', N'diego.alvarado@correo.lab', N'8888-1002', N'Alajuela',   N'ACTIVO',   CAST('2024-02-02T09:00:00' AS DATETIME2)),
        (N'SO-1003', N'Paula', N'Chaves',   N'paula.chaves@correo.lab',   N'8888-1003', N'Heredia',    N'ACTIVO',   CAST('2024-02-03T09:00:00' AS DATETIME2)),
        (N'SO-1004', N'Jorge', N'Urena',    N'jorge.urena@correo.lab',    N'8888-1004', N'Cartago',    N'ACTIVO',   CAST('2024-02-04T09:00:00' AS DATETIME2))
    ) AS v (Cedula, Nombre, Apellido, Correo, Telefono, Direccion, Estado, FechaRegistro)
)
MERGE coop.Socio AS tgt
USING src
    ON tgt.Cedula = src.Cedula
WHEN MATCHED THEN
    UPDATE SET
        tgt.Nombre = src.Nombre,
        tgt.Apellido = src.Apellido,
        tgt.Correo = src.Correo,
        tgt.Telefono = src.Telefono,
        tgt.Direccion = src.Direccion,
        tgt.Estado = src.Estado,
        tgt.FechaRegistro = src.FechaRegistro
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Cedula, Nombre, Apellido, Correo, Telefono, Direccion, Estado, FechaRegistro)
    VALUES (src.Cedula, src.Nombre, src.Apellido, src.Correo, src.Telefono, src.Direccion, src.Estado, src.FechaRegistro);
GO

-- Productos financieros de prueba.
;WITH src AS
(
    SELECT *
    FROM (VALUES
        (N'AHO_BASICO',  N'Cuenta Ahorro Basico',    N'AHORRO',   CAST(1.50  AS DECIMAL(18,2)), CAST(100.00 AS DECIMAL(18,2)), N'ACTIVO', CAST('2024-01-01T08:00:00' AS DATETIME2)),
        (N'AHO_JUVENIL', N'Cuenta Ahorro Juvenil',   N'AHORRO',   CAST(2.25  AS DECIMAL(18,2)), CAST(50.00  AS DECIMAL(18,2)), N'ACTIVO', CAST('2024-01-01T08:00:00' AS DATETIME2)),
        (N'PRE_CONSUMO', N'Prestamo Personal Consumo', N'PRESTAMO', CAST(14.75 AS DECIMAL(18,2)), CAST(0.00   AS DECIMAL(18,2)), N'ACTIVO', CAST('2024-01-01T08:00:00' AS DATETIME2))
    ) AS v (CodigoProducto, NombreProducto, TipoProducto, TasaInteres, MontoMinimoApertura, Estado, FechaCreacion)
)
MERGE coop.ProductoFinanciero AS tgt
USING src
    ON tgt.CodigoProducto = src.CodigoProducto
WHEN MATCHED THEN
    UPDATE SET
        tgt.NombreProducto = src.NombreProducto,
        tgt.TipoProducto = src.TipoProducto,
        tgt.TasaInteres = src.TasaInteres,
        tgt.MontoMinimoApertura = src.MontoMinimoApertura,
        tgt.Estado = src.Estado,
        tgt.FechaCreacion = src.FechaCreacion
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CodigoProducto, NombreProducto, TipoProducto, TasaInteres, MontoMinimoApertura, Estado, FechaCreacion)
    VALUES (src.CodigoProducto, src.NombreProducto, src.TipoProducto, src.TasaInteres, src.MontoMinimoApertura, src.Estado, src.FechaCreacion);
GO

-- Cuentas de ahorro por socio.
;WITH src AS
(
    SELECT
        v.NumeroCuenta,
        s.SocioID,
        p.ProductoFinancieroID,
        e.EmpleadoID AS CreadaPorEmpleadoID,
        v.Saldo,
        v.EstadoCuenta,
        v.FechaApertura
    FROM (VALUES
        (N'CTA-10001', N'SO-1001', N'AHO_BASICO',  N'EM-0101', CAST(1500.00 AS DECIMAL(18,2)), N'ACTIVA', CAST('2026-01-15T09:30:00' AS DATETIME2)),
        (N'CTA-10002', N'SO-1002', N'AHO_BASICO',  N'EM-0101', CAST(840.00  AS DECIMAL(18,2)), N'ACTIVA', CAST('2026-01-16T09:30:00' AS DATETIME2)),
        (N'CTA-10003', N'SO-1003', N'AHO_JUVENIL', N'EM-0101', CAST(3250.00 AS DECIMAL(18,2)), N'ACTIVA', CAST('2026-01-17T09:30:00' AS DATETIME2)),
        (N'CTA-10004', N'SO-1004', N'AHO_BASICO',  N'EM-0101', CAST(460.00  AS DECIMAL(18,2)), N'ACTIVA', CAST('2026-01-18T09:30:00' AS DATETIME2))
    ) AS v (NumeroCuenta, CedulaSocio, CodigoProducto, CedulaEmpleado, Saldo, EstadoCuenta, FechaApertura)
    INNER JOIN coop.Socio AS s
        ON s.Cedula = v.CedulaSocio
    INNER JOIN coop.ProductoFinanciero AS p
        ON p.CodigoProducto = v.CodigoProducto
    INNER JOIN coop.Empleado AS e
        ON e.Cedula = v.CedulaEmpleado
)
MERGE coop.Cuenta AS tgt
USING src
    ON tgt.NumeroCuenta = src.NumeroCuenta
WHEN MATCHED THEN
    UPDATE SET
        tgt.SocioID = src.SocioID,
        tgt.ProductoFinancieroID = src.ProductoFinancieroID,
        tgt.CreadaPorEmpleadoID = src.CreadaPorEmpleadoID,
        tgt.Saldo = src.Saldo,
        tgt.EstadoCuenta = src.EstadoCuenta,
        tgt.FechaApertura = src.FechaApertura
WHEN NOT MATCHED BY TARGET THEN
    INSERT (NumeroCuenta, SocioID, ProductoFinancieroID, CreadaPorEmpleadoID, Saldo, EstadoCuenta, FechaApertura)
    VALUES (src.NumeroCuenta, src.SocioID, src.ProductoFinancieroID, src.CreadaPorEmpleadoID, src.Saldo, src.EstadoCuenta, src.FechaApertura);
GO

-- Prestamos de prueba.
;WITH src AS
(
    SELECT
        v.NumeroPrestamo,
        s.SocioID,
        p.ProductoFinancieroID,
        e.EmpleadoID AS AprobadoPorEmpleadoID,
        v.MontoOriginal,
        v.SaldoPendiente,
        v.TasaInteres,
        v.PlazoMeses,
        v.FechaDesembolso,
        v.EstadoPrestamo
    FROM (VALUES
        (N'PR-20001', N'SO-1002', N'PRE_CONSUMO', N'EM-0102', CAST(5000.00 AS DECIMAL(18,2)), CAST(3200.00 AS DECIMAL(18,2)), CAST(14.75 AS DECIMAL(18,2)), 24, CAST('2025-09-15T10:00:00' AS DATETIME2), N'ACTIVO'),
        (N'PR-20002', N'SO-1003', N'PRE_CONSUMO', N'EM-0102', CAST(1200.00 AS DECIMAL(18,2)), CAST(0.00    AS DECIMAL(18,2)), CAST(12.50 AS DECIMAL(18,2)),  4, CAST('2024-06-20T10:00:00' AS DATETIME2), N'PAGADO')
    ) AS v (NumeroPrestamo, CedulaSocio, CodigoProducto, CedulaEmpleado, MontoOriginal, SaldoPendiente, TasaInteres, PlazoMeses, FechaDesembolso, EstadoPrestamo)
    INNER JOIN coop.Socio AS s
        ON s.Cedula = v.CedulaSocio
    INNER JOIN coop.ProductoFinanciero AS p
        ON p.CodigoProducto = v.CodigoProducto
    INNER JOIN coop.Empleado AS e
        ON e.Cedula = v.CedulaEmpleado
)
MERGE coop.Prestamo AS tgt
USING src
    ON tgt.NumeroPrestamo = src.NumeroPrestamo
WHEN MATCHED THEN
    UPDATE SET
        tgt.SocioID = src.SocioID,
        tgt.ProductoFinancieroID = src.ProductoFinancieroID,
        tgt.AprobadoPorEmpleadoID = src.AprobadoPorEmpleadoID,
        tgt.MontoOriginal = src.MontoOriginal,
        tgt.SaldoPendiente = src.SaldoPendiente,
        tgt.TasaInteres = src.TasaInteres,
        tgt.PlazoMeses = src.PlazoMeses,
        tgt.FechaDesembolso = src.FechaDesembolso,
        tgt.EstadoPrestamo = src.EstadoPrestamo
WHEN NOT MATCHED BY TARGET THEN
    INSERT (NumeroPrestamo, SocioID, ProductoFinancieroID, AprobadoPorEmpleadoID, MontoOriginal, SaldoPendiente, TasaInteres, PlazoMeses, FechaDesembolso, EstadoPrestamo)
    VALUES (src.NumeroPrestamo, src.SocioID, src.ProductoFinancieroID, src.AprobadoPorEmpleadoID, src.MontoOriginal, src.SaldoPendiente, src.TasaInteres, src.PlazoMeses, src.FechaDesembolso, src.EstadoPrestamo);
GO

-- Cuotas de los prestamos.
;WITH src AS
(
    SELECT
        p.PrestamoID,
        v.NumeroCuota,
        v.FechaVencimiento,
        v.MontoCuota,
        v.MontoPagado,
        v.FechaPago,
        v.EstadoCuota
    FROM (VALUES
        (N'PR-20001', 1, CAST('2025-10-15' AS DATE), CAST(250.00 AS DECIMAL(18,2)), CAST(250.00 AS DECIMAL(18,2)), CAST('2025-10-14T12:00:00' AS DATETIME2), N'PAGADA'),
        (N'PR-20001', 2, CAST('2025-11-15' AS DATE), CAST(250.00 AS DECIMAL(18,2)), CAST(250.00 AS DECIMAL(18,2)), CAST('2025-11-15T14:00:00' AS DATETIME2), N'PAGADA'),
        (N'PR-20001', 3, CAST('2025-12-15' AS DATE), CAST(250.00 AS DECIMAL(18,2)), CAST(200.00 AS DECIMAL(18,2)), CAST('2025-12-18T10:30:00' AS DATETIME2), N'PARCIAL'),
        (N'PR-20001', 4, CAST('2026-01-15' AS DATE), CAST(250.00 AS DECIMAL(18,2)), CAST(0.00   AS DECIMAL(18,2)), NULL,                                    N'PENDIENTE'),
        (N'PR-20002', 1, CAST('2024-07-20' AS DATE), CAST(300.00 AS DECIMAL(18,2)), CAST(300.00 AS DECIMAL(18,2)), CAST('2024-07-19T11:00:00' AS DATETIME2), N'PAGADA'),
        (N'PR-20002', 2, CAST('2024-08-20' AS DATE), CAST(300.00 AS DECIMAL(18,2)), CAST(300.00 AS DECIMAL(18,2)), CAST('2024-08-20T11:00:00' AS DATETIME2), N'PAGADA'),
        (N'PR-20002', 3, CAST('2024-09-20' AS DATE), CAST(300.00 AS DECIMAL(18,2)), CAST(300.00 AS DECIMAL(18,2)), CAST('2024-09-20T11:00:00' AS DATETIME2), N'PAGADA'),
        (N'PR-20002', 4, CAST('2024-10-20' AS DATE), CAST(300.00 AS DECIMAL(18,2)), CAST(300.00 AS DECIMAL(18,2)), CAST('2024-10-20T11:00:00' AS DATETIME2), N'PAGADA')
    ) AS v (NumeroPrestamo, NumeroCuota, FechaVencimiento, MontoCuota, MontoPagado, FechaPago, EstadoCuota)
    INNER JOIN coop.Prestamo AS p
        ON p.NumeroPrestamo = v.NumeroPrestamo
)
MERGE coop.Cuota AS tgt
USING src
    ON tgt.PrestamoID = src.PrestamoID
   AND tgt.NumeroCuota = src.NumeroCuota
WHEN MATCHED THEN
    UPDATE SET
        tgt.FechaVencimiento = src.FechaVencimiento,
        tgt.MontoCuota = src.MontoCuota,
        tgt.MontoPagado = src.MontoPagado,
        tgt.FechaPago = src.FechaPago,
        tgt.EstadoCuota = src.EstadoCuota
WHEN NOT MATCHED BY TARGET THEN
    INSERT (PrestamoID, NumeroCuota, FechaVencimiento, MontoCuota, MontoPagado, FechaPago, EstadoCuota)
    VALUES (src.PrestamoID, src.NumeroCuota, src.FechaVencimiento, src.MontoCuota, src.MontoPagado, src.FechaPago, src.EstadoCuota);
GO

-- Movimientos de caja sobre cuentas.
;WITH src AS
(
    SELECT
        c.CuentaID,
        v.TipoMovimiento,
        v.Monto,
        v.Referencia,
        v.Observacion,
        v.FechaMovimiento,
        e.EmpleadoID AS EjecutadoPorEmpleadoID
    FROM (VALUES
        (N'CTA-10001', N'DEPOSITO',  CAST(2000.00 AS DECIMAL(18,2)), N'M-CTA10001-001', N'Deposito inicial de prueba',             CAST('2026-01-15T10:00:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10001', N'RETIRO',    CAST(500.00  AS DECIMAL(18,2)), N'M-CTA10001-002', N'Retiro de ventanilla de prueba',         CAST('2026-02-05T11:00:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10002', N'DEPOSITO',  CAST(1000.00 AS DECIMAL(18,2)), N'M-CTA10002-001', N'Deposito por caja',                       CAST('2026-01-16T10:00:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10002', N'RETIRO',    CAST(160.00  AS DECIMAL(18,2)), N'M-CTA10002-002', N'Retiro de efectivo',                      CAST('2026-02-10T11:30:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10003', N'DEPOSITO',  CAST(3500.00 AS DECIMAL(18,2)), N'M-CTA10003-001', N'Deposito por transferencia recibida',     CAST('2026-01-17T10:00:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10003', N'RETIRO',    CAST(250.00  AS DECIMAL(18,2)), N'M-CTA10003-002', N'Retiro parcial para gastos',              CAST('2026-02-12T09:15:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10004', N'DEPOSITO',  CAST(600.00  AS DECIMAL(18,2)), N'M-CTA10004-001', N'Deposito en ventanilla',                  CAST('2026-01-18T10:00:00' AS DATETIME2), N'EM-0101'),
        (N'CTA-10004', N'RETIRO',    CAST(140.00  AS DECIMAL(18,2)), N'M-CTA10004-002', N'Retiro para consumo personal',            CAST('2026-02-14T09:50:00' AS DATETIME2), N'EM-0101')
    ) AS v (NumeroCuenta, TipoMovimiento, Monto, Referencia, Observacion, FechaMovimiento, CedulaEmpleado)
    INNER JOIN coop.Cuenta AS c
        ON c.NumeroCuenta = v.NumeroCuenta
    INNER JOIN coop.Empleado AS e
        ON e.Cedula = v.CedulaEmpleado
)
MERGE coop.Movimiento AS tgt
USING src
    ON tgt.Referencia = src.Referencia
WHEN NOT MATCHED BY TARGET THEN
    INSERT (CuentaID, TipoMovimiento, Monto, Referencia, Observacion, FechaMovimiento, EjecutadoPorEmpleadoID)
    VALUES (src.CuentaID, src.TipoMovimiento, src.Monto, src.Referencia, src.Observacion, src.FechaMovimiento, src.EjecutadoPorEmpleadoID);
GO

-- Eventos de auditoria de referencia.
;WITH src AS
(
    SELECT
        v.Entidad,
        v.EntidadID,
        v.Accion,
        v.Descripcion,
        v.FechaEvento,
        e.EmpleadoID
    FROM (VALUES
        (N'SOCIO',    N'SO-1001',   N'INSERT', N'Seed inicial de socio SO-1001',       CAST('2024-02-01T09:05:00' AS DATETIME2), N'EM-0104'),
        (N'CUENTA',   N'CTA-10001', N'INSERT', N'Apertura de cuenta de prueba CTA-10001', CAST('2026-01-15T09:35:00' AS DATETIME2), N'EM-0101'),
        (N'PRESTAMO', N'PR-20001',  N'INSERT', N'Registro inicial de prestamo PR-20001', CAST('2025-09-15T10:05:00' AS DATETIME2), N'EM-0102')
    ) AS v (Entidad, EntidadID, Accion, Descripcion, FechaEvento, CedulaEmpleado)
    INNER JOIN coop.Empleado AS e
        ON e.Cedula = v.CedulaEmpleado
)
MERGE coop.Auditoria AS tgt
USING src
    ON tgt.Entidad = src.Entidad
   AND ISNULL(tgt.EntidadID, N'') = ISNULL(src.EntidadID, N'')
   AND tgt.Accion = src.Accion
WHEN MATCHED THEN
    UPDATE SET
        tgt.Descripcion = src.Descripcion,
        tgt.FechaEvento = src.FechaEvento,
        tgt.EmpleadoID = src.EmpleadoID
WHEN NOT MATCHED BY TARGET THEN
    INSERT (Entidad, EntidadID, Accion, Descripcion, FechaEvento, EmpleadoID)
    VALUES (src.Entidad, src.EntidadID, src.Accion, src.Descripcion, src.FechaEvento, src.EmpleadoID);
GO
