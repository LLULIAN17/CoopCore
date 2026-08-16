/*
  CoopCore - Modulo 7: Dashboard de cartera
  Fecha de ampliacion: 2026-08-15
  Objetivo: Resumir cartera, morosidad, riesgo y proximos vencimientos.
*/

IF DB_ID(N'CoopCoreDB') IS NULL
    THROW 51000, 'No existe CoopCoreDB.', 1;
GO

USE CoopCoreDB;
GO

IF OBJECT_ID(N'coop.Prestamo', N'U') IS NULL
   OR OBJECT_ID(N'coop.Cuota', N'U') IS NULL
BEGIN
    THROW 51003, 'Faltan las tablas de prestamos y cuotas.', 1;
END;
GO

CREATE OR ALTER PROCEDURE coop.sp_ConsultarDashboardCartera
    @FechaCorte DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET @FechaCorte = ISNULL(@FechaCorte, CONVERT(DATE, SYSDATETIME()));

    CREATE TABLE #MoraPorPrestamo
    (
        PrestamoID INT NOT NULL PRIMARY KEY,
        SocioID INT NOT NULL,
        CuotasVencidas INT NOT NULL,
        MontoVencido DECIMAL(38,2) NOT NULL,
        DiasMoraMaximos INT NOT NULL
    );

    INSERT INTO #MoraPorPrestamo
    SELECT
        p.PrestamoID,
        p.SocioID,
        COUNT(*) AS CuotasVencidas,
        SUM(CONVERT(DECIMAL(38,2), c.MontoCuota - c.MontoPagado)) AS MontoVencido,
        MAX(DATEDIFF(DAY, c.FechaVencimiento, @FechaCorte)) AS DiasMoraMaximos
    FROM coop.Prestamo AS p
    INNER JOIN coop.Cuota AS c
        ON c.PrestamoID = p.PrestamoID
    WHERE p.EstadoPrestamo IN (N'ACTIVO', N'MORA')
      AND p.SaldoPendiente > 0
      AND c.FechaVencimiento < @FechaCorte
      AND c.MontoPagado < c.MontoCuota
      AND c.EstadoCuota <> N'PAGADA'
    GROUP BY p.PrestamoID, p.SocioID;

    DECLARE @SaldoCarteraTotal DECIMAL(38,2);
    DECLARE @MontoVencido DECIMAL(38,2);

    SELECT @SaldoCarteraTotal = ISNULL(SUM(CONVERT(DECIMAL(38,2), SaldoPendiente)), 0)
    FROM coop.Prestamo
    WHERE EstadoPrestamo IN (N'ACTIVO', N'MORA');

    SELECT @MontoVencido = ISNULL(SUM(MontoVencido), 0)
    FROM #MoraPorPrestamo;

    SELECT
        @FechaCorte AS FechaCorte,
        (SELECT COUNT(*) FROM coop.Socio WHERE Estado = N'ACTIVO') AS TotalSociosActivos,
        (SELECT COUNT(*) FROM coop.Prestamo WHERE EstadoPrestamo IN (N'ACTIVO', N'MORA')) AS TotalPrestamosVigentes,
        @SaldoCarteraTotal AS SaldoCarteraTotal,
        (SELECT COUNT(*) FROM #MoraPorPrestamo) AS PrestamosConMora,
        (SELECT COUNT(DISTINCT SocioID) FROM #MoraPorPrestamo) AS ClientesMorosos,
        @MontoVencido AS MontoVencido,
        (SELECT ISNULL(SUM(CuotasVencidas), 0) FROM #MoraPorPrestamo) AS CuotasVencidas,
        CAST
        (
            CASE
                WHEN @SaldoCarteraTotal = 0 THEN 0
                ELSE (@MontoVencido * 100.0) / @SaldoCarteraTotal
            END
            AS DECIMAL(9,2)
        ) AS IndiceMorosidadPct;

    ;WITH RiesgoCliente AS
    (
        SELECT
            SocioID,
            MAX(DiasMoraMaximos) AS DiasMoraMaximos,
            SUM(MontoVencido) AS MontoVencido
        FROM #MoraPorPrestamo
        GROUP BY SocioID
    ), Clasificado AS
    (
        SELECT
            CASE
                WHEN DiasMoraMaximos >= 90 THEN N'CRITICO'
                WHEN DiasMoraMaximos >= 60 THEN N'ALTO'
                WHEN DiasMoraMaximos >= 30 THEN N'MEDIO'
                ELSE N'BAJO'
            END AS NivelRiesgo,
            MontoVencido
        FROM RiesgoCliente
    )
    SELECT
        NivelRiesgo,
        COUNT(*) AS CantidadClientes,
        SUM(MontoVencido) AS MontoVencido
    FROM Clasificado
    GROUP BY NivelRiesgo
    ORDER BY CASE NivelRiesgo
        WHEN N'CRITICO' THEN 1
        WHEN N'ALTO' THEN 2
        WHEN N'MEDIO' THEN 3
        ELSE 4
    END;

    SELECT TOP (10)
        s.SocioID,
        s.Cedula,
        s.Nombre + N' ' + s.Apellido AS NombreCliente,
        p.NumeroPrestamo,
        c.NumeroCuota,
        c.FechaVencimiento,
        c.MontoCuota - c.MontoPagado AS MontoPendiente,
        DATEDIFF(DAY, @FechaCorte, c.FechaVencimiento) AS DiasParaVencer
    FROM coop.Cuota AS c
    INNER JOIN coop.Prestamo AS p
        ON p.PrestamoID = c.PrestamoID
    INNER JOIN coop.Socio AS s
        ON s.SocioID = p.SocioID
    WHERE p.EstadoPrestamo IN (N'ACTIVO', N'MORA')
      AND c.MontoPagado < c.MontoCuota
      AND c.EstadoCuota <> N'PAGADA'
      AND c.FechaVencimiento >= @FechaCorte
      AND c.FechaVencimiento <= DATEADD(DAY, 30, @FechaCorte)
    ORDER BY c.FechaVencimiento, c.MontoCuota - c.MontoPagado DESC;
END;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_admin_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarDashboardCartera TO rol_admin_coop;
IF DATABASE_PRINCIPAL_ID(N'rol_oficial_credito_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarDashboardCartera TO rol_oficial_credito_coop;
IF DATABASE_PRINCIPAL_ID(N'rol_api_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarDashboardCartera TO rol_api_coop;
GO
