/*
  CoopCore - Script 03
  Archivo: 03_views.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Crear vistas de consulta para minimo privilegio.
  Nota: Script idempotente con CREATE OR ALTER VIEW.
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

-- Resumen de cuentas para consulta operativa.
CREATE OR ALTER VIEW coop.vw_CuentasResumen
AS
SELECT
    c.CuentaID,
    c.NumeroCuenta,
    s.SocioID,
    s.Cedula AS CedulaSocio,
    s.Nombre + N' ' + s.Apellido AS NombreSocio,
    p.CodigoProducto,
    p.NombreProducto,
    c.Saldo,
    c.EstadoCuenta,
    c.FechaApertura
FROM coop.Cuenta AS c
INNER JOIN coop.Socio AS s
    ON s.SocioID = c.SocioID
INNER JOIN coop.ProductoFinanciero AS p
    ON p.ProductoFinancieroID = c.ProductoFinancieroID;
GO

-- Vista de movimientos con trazabilidad para auditoria.
CREATE OR ALTER VIEW coop.vw_MovimientosAuditoria
AS
SELECT
    m.MovimientoID,
    m.FechaMovimiento,
    m.TipoMovimiento,
    m.Monto,
    m.Referencia,
    m.Observacion,
    c.NumeroCuenta,
    s.Cedula AS CedulaSocio,
    s.Nombre + N' ' + s.Apellido AS NombreSocio,
    e.Cedula AS CedulaEmpleado,
    e.Nombre + N' ' + e.Apellido AS NombreEmpleado
FROM coop.Movimiento AS m
INNER JOIN coop.Cuenta AS c
    ON c.CuentaID = m.CuentaID
INNER JOIN coop.Socio AS s
    ON s.SocioID = c.SocioID
INNER JOIN coop.Empleado AS e
    ON e.EmpleadoID = m.EjecutadoPorEmpleadoID;
GO

-- Resumen de prestamos con agregados de cuotas.
CREATE OR ALTER VIEW coop.vw_PrestamosResumen
AS
SELECT
    pr.PrestamoID,
    pr.NumeroPrestamo,
    s.Cedula AS CedulaSocio,
    s.Nombre + N' ' + s.Apellido AS NombreSocio,
    p.CodigoProducto,
    p.NombreProducto,
    pr.MontoOriginal,
    pr.SaldoPendiente,
    pr.TasaInteres,
    pr.PlazoMeses,
    pr.FechaDesembolso,
    pr.EstadoPrestamo,
    ISNULL(cu.CantidadCuotas, 0) AS CantidadCuotas,
    ISNULL(cu.TotalProgramado, 0) AS TotalProgramado,
    ISNULL(cu.TotalPagado, 0) AS TotalPagado,
    ISNULL(cu.CuotasPendientes, 0) AS CuotasPendientes
FROM coop.Prestamo AS pr
INNER JOIN coop.Socio AS s
    ON s.SocioID = pr.SocioID
INNER JOIN coop.ProductoFinanciero AS p
    ON p.ProductoFinancieroID = pr.ProductoFinancieroID
LEFT JOIN
(
    SELECT
        PrestamoID,
        COUNT(*) AS CantidadCuotas,
        SUM(MontoCuota) AS TotalProgramado,
        SUM(MontoPagado) AS TotalPagado,
        SUM(CASE WHEN EstadoCuota IN (N'PENDIENTE', N'VENCIDA', N'PARCIAL') THEN 1 ELSE 0 END) AS CuotasPendientes
    FROM coop.Cuota
    GROUP BY PrestamoID
) AS cu
    ON cu.PrestamoID = pr.PrestamoID;
GO

-- Vista de consulta general de socios con productos asociados.
CREATE OR ALTER VIEW coop.vw_SociosConsulta
AS
SELECT
    s.SocioID,
    s.Cedula,
    s.Nombre,
    s.Apellido,
    s.Correo,
    s.Telefono,
    s.Direccion,
    s.Estado,
    s.FechaRegistro,
    ISNULL(ct.CantidadCuentas, 0) AS CantidadCuentas,
    ISNULL(ct.SaldoTotal, 0) AS SaldoTotalCuentas,
    ISNULL(pr.CantidadPrestamos, 0) AS CantidadPrestamos,
    ISNULL(pr.SaldoPrestamos, 0) AS SaldoTotalPrestamos
FROM coop.Socio AS s
LEFT JOIN
(
    SELECT
        SocioID,
        COUNT(*) AS CantidadCuentas,
        SUM(Saldo) AS SaldoTotal
    FROM coop.Cuenta
    GROUP BY SocioID
) AS ct
    ON ct.SocioID = s.SocioID
LEFT JOIN
(
    SELECT
        SocioID,
        COUNT(*) AS CantidadPrestamos,
        SUM(SaldoPendiente) AS SaldoPrestamos
    FROM coop.Prestamo
    GROUP BY SocioID
) AS pr
    ON pr.SocioID = s.SocioID;
GO
