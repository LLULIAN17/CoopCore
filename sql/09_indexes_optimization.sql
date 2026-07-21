/*
  CoopCore - Script 09
  Archivo: 09_indexes_optimization.sql
  Fase: Optimizacion
  Objetivo: Crear indices justificados por la linea base de planes.

  Ejecutar despues de:
  - sql/09_execution_plan_baseline.sql
  - docs/analisis_planes_ejecucion.md

  Los indices se crean de forma idempotente y responden a los casos medidos
  antes de optimizar. No se cambian stored procedures en esta fase.
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

/*
  IX_Movimiento_Cuenta_Fecha
  Justificacion:
  - Casos base: sp_ConsultarSaldo y sp_ConsultarMovimientos.
  - sp_ConsultarSaldo obtiene MAX(FechaMovimiento) por CuentaID.
  - sp_ConsultarMovimientos filtra por cuenta, rango de fechas y ordena por
    FechaMovimiento DESC, MovimientoID DESC.
  - La linea base mostro lecturas sobre coop.Movimiento aun con pocos datos.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Movimiento')
      AND name = N'IX_Movimiento_Cuenta_Fecha'
)
BEGIN
    CREATE INDEX IX_Movimiento_Cuenta_Fecha
        ON coop.Movimiento (CuentaID, FechaMovimiento DESC, MovimientoID DESC)
        INCLUDE
        (
            TipoMovimiento,
            Monto,
            Referencia,
            Observacion,
            EjecutadoPorEmpleadoID
        );

    PRINT N'Indice creado: IX_Movimiento_Cuenta_Fecha';
END
ELSE
BEGIN
    PRINT N'Indice ya existe: IX_Movimiento_Cuenta_Fecha';
END;
GO

/*
  IX_Cuenta_Socio_Saldo
  Justificacion:
  - Caso base: sp_ConsultarSocio.
  - La vista coop.vw_SociosConsulta agrupa cuentas por SocioID para contar
    cuentas y sumar saldos.
  - Este indice apoya el GROUP BY SocioID y evita depender solo de la llave
    primaria cuando la tabla Cuenta crezca.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Cuenta')
      AND name = N'IX_Cuenta_Socio_Saldo'
)
BEGIN
    CREATE INDEX IX_Cuenta_Socio_Saldo
        ON coop.Cuenta (SocioID)
        INCLUDE (Saldo);

    PRINT N'Indice creado: IX_Cuenta_Socio_Saldo';
END
ELSE
BEGIN
    PRINT N'Indice ya existe: IX_Cuenta_Socio_Saldo';
END;
GO

/*
  IX_Prestamo_Socio_Saldo
  Justificacion:
  - Caso base: sp_ConsultarSocio.
  - La vista coop.vw_SociosConsulta agrupa prestamos por SocioID para contar
    prestamos y sumar SaldoPendiente.
  - Este indice apoya el GROUP BY SocioID en consultas de socios.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Prestamo')
      AND name = N'IX_Prestamo_Socio_Saldo'
)
BEGIN
    CREATE INDEX IX_Prestamo_Socio_Saldo
        ON coop.Prestamo (SocioID)
        INCLUDE (SaldoPendiente);

    PRINT N'Indice creado: IX_Prestamo_Socio_Saldo';
END
ELSE
BEGIN
    PRINT N'Indice ya existe: IX_Prestamo_Socio_Saldo';
END;
GO

/*
  IX_Cuota_Prestamo_Numero_Covering
  Justificacion:
  - Casos base: sp_ConsultarPrestamo, sp_GenerarAmortizacion y sp_PagarCuota.
  - sp_ConsultarPrestamo devuelve cuotas por PrestamoID ordenadas por
    NumeroCuota.
  - vw_PrestamosResumen agrupa cuotas por PrestamoID.
  - Ya existe UQ_Cuota_Prestamo_Numero, pero este indice agrega columnas de
    cobertura para la consulta de detalle y los agregados principales.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Cuota')
      AND name = N'IX_Cuota_Prestamo_Numero_Covering'
)
BEGIN
    CREATE INDEX IX_Cuota_Prestamo_Numero_Covering
        ON coop.Cuota (PrestamoID, NumeroCuota)
        INCLUDE
        (
            FechaVencimiento,
            MontoCuota,
            MontoPagado,
            FechaPago,
            EstadoCuota
        );

    PRINT N'Indice creado: IX_Cuota_Prestamo_Numero_Covering';
END
ELSE
BEGIN
    PRINT N'Indice ya existe: IX_Cuota_Prestamo_Numero_Covering';
END;
GO

/*
  IX_Auditoria_Accion_Fecha
  Justificacion:
  - Caso base: sp_ConsultarAuditoria.
  - El caso medido mas claro consulta auditoria por @Accion = LOGIN.
  - El indice ordena por FechaEvento DESC, AuditoriaID DESC para conservar el
    orden cronologico esperado.
  - La tabla Auditoria crece con login, operaciones de cuentas, prestamos y
    transacciones; este indice ayuda a reportes por tipo de evento.
  - Si crecen mucho las consultas por entidad/empleado sin accion, una mejora
    futura seria un indice separado para ese patron.
*/
IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Auditoria')
      AND name = N'IX_Auditoria_Accion_Fecha'
)
BEGIN
    IF EXISTS
    (
        SELECT 1
        FROM sys.indexes
        WHERE object_id = OBJECT_ID(N'coop.Auditoria')
          AND name = N'IX_Auditoria_Fecha_Filtros'
    )
    BEGIN
        DROP INDEX IX_Auditoria_Fecha_Filtros ON coop.Auditoria;
        PRINT N'Indice reemplazado: IX_Auditoria_Fecha_Filtros';
    END;

    CREATE INDEX IX_Auditoria_Accion_Fecha
        ON coop.Auditoria (Accion, FechaEvento DESC, AuditoriaID DESC)
        INCLUDE
        (
            Entidad,
            EmpleadoID,
            EntidadID,
            UsuarioSQL,
            UsuarioBD
        );

    PRINT N'Indice creado: IX_Auditoria_Accion_Fecha';
END
ELSE
BEGIN
    PRINT N'Indice ya existe: IX_Auditoria_Accion_Fecha';
END;
GO

PRINT N'Optimizacion de indices completada. Ejecutar nuevamente sql/09_execution_plan_baseline.sql para comparar antes vs despues.';
GO
