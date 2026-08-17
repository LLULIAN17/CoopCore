/*
  CoopCore - Ampliacion de morosidad
  Archivo: 11_busqueda_clientes_morosos.sql
  Objetivo: Crear el buscador paginado de clientes con cuotas vencidas.
  Nota: Script idempotente.
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

IF OBJECT_ID(N'coop.Socio', N'U') IS NULL
   OR OBJECT_ID(N'coop.Prestamo', N'U') IS NULL
   OR OBJECT_ID(N'coop.Cuota', N'U') IS NULL
BEGIN
    THROW 51003, 'Faltan tablas base. Ejecute primero sql/01_schema_tables.sql.', 1;
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.Cuota')
      AND name = N'IX_Cuota_FechaVencimiento_Prestamo'
)
BEGIN
    CREATE INDEX IX_Cuota_FechaVencimiento_Prestamo
        ON coop.Cuota (FechaVencimiento, PrestamoID)
        INCLUDE (MontoCuota, MontoPagado, EstadoCuota);
END;
GO

/* ============================================================
   Procedimiento: coop.sp_BuscarClientesMorosos
   Descripcion: Busca y pagina socios con cuotas vencidas a una fecha de corte.
   Parametros: termino, fecha de corte, dias minimos, pagina y tamano de pagina.
   Resultado: resumen y detalle paginado de clientes morosos.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_BuscarClientesMorosos
    @Termino NVARCHAR(160) = NULL,
    @FechaCorte DATE = NULL,
    @DiasMoraMinimos INT = 1,
    @Pagina INT = 1,
    @TamanoPagina INT = 20
AS
BEGIN
    SET NOCOUNT ON;

    SET @Termino = NULLIF(LTRIM(RTRIM(@Termino)), N'');
    SET @FechaCorte = ISNULL(@FechaCorte, CONVERT(DATE, SYSDATETIME()));

    IF LEN(@Termino) > 160
        THROW 52100, 'El termino de busqueda no puede exceder 160 caracteres.', 1;

    IF @DiasMoraMinimos NOT BETWEEN 1 AND 3650
        THROW 52101, 'DiasMoraMinimos debe estar entre 1 y 3650.', 1;

    IF @Pagina < 1
        THROW 52102, 'Pagina debe ser mayor que cero.', 1;

    IF @TamanoPagina NOT BETWEEN 1 AND 100
        THROW 52103, 'TamanoPagina debe estar entre 1 y 100.', 1;

    DECLARE @Patron NVARCHAR(324);
    DECLARE @FechaVencimientoMaxima DATE = DATEADD(DAY, -@DiasMoraMinimos, @FechaCorte);
    DECLARE @FilasOmitidas INT = (@Pagina - 1) * @TamanoPagina;

    IF @Termino IS NOT NULL
    BEGIN
        SET @Patron = N'%' +
            REPLACE(
                REPLACE(
                    REPLACE(@Termino, N'\', N'\\'),
                    N'%',
                    N'\%'
                ),
                N'_',
                N'\_'
            ) + N'%';
    END;

    CREATE TABLE #PrestamosMorosos
    (
        PrestamoID INT NOT NULL PRIMARY KEY,
        NumeroPrestamo NVARCHAR(30) NOT NULL,
        SocioID INT NOT NULL,
        CantidadCuotasVencidas INT NOT NULL,
        FechaPrimeraCuotaVencida DATE NOT NULL,
        FechaUltimaCuotaVencida DATE NOT NULL,
        DiasMoraMaximos INT NOT NULL,
        MontoTotalMora DECIMAL(38,2) NOT NULL,
        SaldoPendiente DECIMAL(18,2) NOT NULL
    );

    INSERT INTO #PrestamosMorosos
    (
        PrestamoID,
        NumeroPrestamo,
        SocioID,
        CantidadCuotasVencidas,
        FechaPrimeraCuotaVencida,
        FechaUltimaCuotaVencida,
        DiasMoraMaximos,
        MontoTotalMora,
        SaldoPendiente
    )
    SELECT
        p.PrestamoID,
        p.NumeroPrestamo,
        p.SocioID,
        COUNT(*) AS CantidadCuotasVencidas,
        MIN(c.FechaVencimiento) AS FechaPrimeraCuotaVencida,
        MAX(c.FechaVencimiento) AS FechaUltimaCuotaVencida,
        MAX(c.DiasMora) AS DiasMoraMaximos,
        SUM(CONVERT(DECIMAL(38,2), c.MontoPendiente)) AS MontoTotalMora,
        p.SaldoPendiente
    FROM coop.Prestamo AS p
    INNER JOIN coop.Socio AS s
        ON s.SocioID = p.SocioID
    CROSS APPLY coop.fn_ObtenerCuotasVencidas(p.PrestamoID, @FechaCorte) AS c
    WHERE p.EstadoPrestamo IN (N'ACTIVO', N'MORA')
      AND p.SaldoPendiente > 0
      AND c.FechaVencimiento <= @FechaVencimientoMaxima
      AND
      (
          @Patron IS NULL
          OR s.Cedula LIKE @Patron ESCAPE N'\'
          OR s.Nombre LIKE @Patron ESCAPE N'\'
          OR s.Apellido LIKE @Patron ESCAPE N'\'
          OR (s.Nombre + N' ' + s.Apellido) LIKE @Patron ESCAPE N'\'
          OR s.Correo LIKE @Patron ESCAPE N'\'
          OR s.Telefono LIKE @Patron ESCAPE N'\'
          OR p.NumeroPrestamo LIKE @Patron ESCAPE N'\'
      )
    GROUP BY
        p.PrestamoID,
        p.NumeroPrestamo,
        p.SocioID,
        p.SaldoPendiente;

    CREATE TABLE #ClientesMorosos
    (
        SocioID INT NOT NULL PRIMARY KEY,
        Cedula NVARCHAR(20) NOT NULL,
        NombreCompleto NVARCHAR(161) NOT NULL,
        Correo NVARCHAR(120) NULL,
        Telefono NVARCHAR(30) NULL,
        EstadoSocio NVARCHAR(20) NOT NULL,
        PrestamosMorosos NVARCHAR(MAX) NOT NULL,
        CantidadPrestamosMorosos INT NOT NULL,
        CantidadCuotasVencidas INT NOT NULL,
        FechaPrimeraCuotaVencida DATE NOT NULL,
        FechaUltimaCuotaVencida DATE NOT NULL,
        DiasMoraMaximos INT NOT NULL,
        NivelRiesgo NVARCHAR(10) NOT NULL,
        MontoTotalMora DECIMAL(38,2) NOT NULL,
        SaldoTotalPrestamosMorosos DECIMAL(38,2) NOT NULL
    );

    INSERT INTO #ClientesMorosos
    SELECT
        s.SocioID,
        s.Cedula,
        s.Nombre + N' ' + s.Apellido AS NombreCompleto,
        s.Correo,
        s.Telefono,
        s.Estado AS EstadoSocio,
        STRING_AGG(CONVERT(NVARCHAR(MAX), pm.NumeroPrestamo), N',')
            WITHIN GROUP (ORDER BY pm.NumeroPrestamo) AS PrestamosMorosos,
        COUNT(*) AS CantidadPrestamosMorosos,
        SUM(pm.CantidadCuotasVencidas) AS CantidadCuotasVencidas,
        MIN(pm.FechaPrimeraCuotaVencida) AS FechaPrimeraCuotaVencida,
        MAX(pm.FechaUltimaCuotaVencida) AS FechaUltimaCuotaVencida,
        MAX(pm.DiasMoraMaximos) AS DiasMoraMaximos,
        CASE
            WHEN MAX(pm.DiasMoraMaximos) >= 90 THEN N'CRITICO'
            WHEN MAX(pm.DiasMoraMaximos) >= 60 THEN N'ALTO'
            WHEN MAX(pm.DiasMoraMaximos) >= 30 THEN N'MEDIO'
            ELSE N'BAJO'
        END AS NivelRiesgo,
        SUM(pm.MontoTotalMora) AS MontoTotalMora,
        SUM(CONVERT(DECIMAL(38,2), pm.SaldoPendiente)) AS SaldoTotalPrestamosMorosos
    FROM #PrestamosMorosos AS pm
    INNER JOIN coop.Socio AS s
        ON s.SocioID = pm.SocioID
    GROUP BY
        s.SocioID,
        s.Cedula,
        s.Nombre,
        s.Apellido,
        s.Correo,
        s.Telefono,
        s.Estado;

    DECLARE @TotalRegistros INT;
    DECLARE @TotalMontoMora DECIMAL(38,2);
    DECLARE @TotalSaldoPrestamosMorosos DECIMAL(38,2);

    SELECT
        @TotalRegistros = COUNT(*),
        @TotalMontoMora = ISNULL(SUM(MontoTotalMora), 0),
        @TotalSaldoPrestamosMorosos = ISNULL(SUM(SaldoTotalPrestamosMorosos), 0)
    FROM #ClientesMorosos;

    SELECT
        @FechaCorte AS FechaCorte,
        @TotalRegistros AS TotalRegistros,
        @TotalMontoMora AS TotalMontoMora,
        @TotalSaldoPrestamosMorosos AS TotalSaldoPrestamosMorosos;

    SELECT
        SocioID,
        Cedula,
        NombreCompleto,
        Correo,
        Telefono,
        EstadoSocio,
        PrestamosMorosos,
        CantidadPrestamosMorosos,
        CantidadCuotasVencidas,
        FechaPrimeraCuotaVencida,
        FechaUltimaCuotaVencida,
        DiasMoraMaximos,
        NivelRiesgo,
        MontoTotalMora,
        SaldoTotalPrestamosMorosos
    FROM #ClientesMorosos
    ORDER BY
        DiasMoraMaximos DESC,
        MontoTotalMora DESC,
        Cedula
    OFFSET @FilasOmitidas ROWS
    FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_admin_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarClientesMorosos TO rol_admin_coop;

IF DATABASE_PRINCIPAL_ID(N'rol_oficial_credito_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarClientesMorosos TO rol_oficial_credito_coop;

IF DATABASE_PRINCIPAL_ID(N'rol_api_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarClientesMorosos TO rol_api_coop;
GO
