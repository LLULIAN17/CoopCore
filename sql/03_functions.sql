/*
  CoopCore - Funciones de dominio
  Archivo: 03_functions.sql
  Autor: Equipo CoopCore
  Fecha: 2026-08-17
  Objetivo: Centralizar calculos de morosidad reutilizados por los stored procedures.
  Nota: Ejecutar despues de 01_schema_tables.sql y antes de los procedimientos.
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
   Funcion: coop.fn_ObtenerTasaMoraDiaria
   Descripcion: Define la tasa de mora diaria institucional en un solo lugar.
   Parametros: ninguno.
   Retorno: tasa diaria aplicada a las cuotas vencidas.
   Nota: WITH SCHEMABINDING permite que el motor la inserte en linea (inlining).
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER FUNCTION coop.fn_ObtenerTasaMoraDiaria()
RETURNS DECIMAL(9,6)
WITH SCHEMABINDING
AS
BEGIN
    RETURN CONVERT(DECIMAL(9,6), 0.001);
END;
GO

/* ============================================================
   Funcion: coop.fn_CalcularMoraCuota
   Descripcion: Calcula la mora simple estimada de una cuota vencida.
   Parametros: monto, monto pagado, vencimiento, fecha de corte y tasa diaria.
   Retorno: mora estimada redondeada a dos decimales; cero si no hay atraso.
   Nota: WITH SCHEMABINDING permite que el motor la inserte en linea (inlining)
         y evita la evaluacion fila por fila dentro de los CROSS APPLY.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER FUNCTION coop.fn_CalcularMoraCuota
(
    @MontoCuota DECIMAL(18,2),
    @MontoPagado DECIMAL(18,2),
    @FechaVencimiento DATE,
    @FechaCorte DATE,
    @TasaMoraDiaria DECIMAL(9,6)
)
RETURNS DECIMAL(18,2)
WITH SCHEMABINDING
AS
BEGIN
    DECLARE @MontoPendiente DECIMAL(18,2) =
        CASE
            WHEN @MontoCuota IS NULL OR @MontoPagado IS NULL THEN 0
            WHEN @MontoCuota <= @MontoPagado THEN 0
            ELSE @MontoCuota - @MontoPagado
        END;
    DECLARE @DiasMora INT =
        CASE
            WHEN @FechaVencimiento IS NULL OR @FechaCorte IS NULL THEN 0
            WHEN @FechaVencimiento >= @FechaCorte THEN 0
            ELSE DATEDIFF(DAY, @FechaVencimiento, @FechaCorte)
        END;
    DECLARE @TasaAplicada DECIMAL(9,6) =
        CASE
            WHEN @TasaMoraDiaria IS NULL OR @TasaMoraDiaria < 0 THEN 0
            ELSE @TasaMoraDiaria
        END;

    RETURN CONVERT
    (
        DECIMAL(18,2),
        ROUND(@MontoPendiente * @DiasMora * @TasaAplicada, 2)
    );
END;
GO

/* ============================================================
   Funcion: coop.fn_ObtenerCuotasVencidas
   Descripcion: Devuelve las cuotas vencidas y pendientes de un prestamo.
   Parametros: identificador del prestamo y fecha de corte.
   Retorno: tabla con monto pendiente, dias de mora y mora estimada.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER FUNCTION coop.fn_ObtenerCuotasVencidas
(
    @PrestamoID INT,
    @FechaCorte DATE
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        c.CuotaID,
        c.PrestamoID,
        c.NumeroCuota,
        c.FechaVencimiento,
        c.MontoCuota,
        c.MontoPagado,
        CONVERT(DECIMAL(18,2), c.MontoCuota - c.MontoPagado) AS MontoPendiente,
        DATEDIFF(DAY, c.FechaVencimiento, @FechaCorte) AS DiasMora,
        coop.fn_CalcularMoraCuota
        (
            c.MontoCuota,
            c.MontoPagado,
            c.FechaVencimiento,
            @FechaCorte,
            coop.fn_ObtenerTasaMoraDiaria()
        ) AS MoraEstimada
    FROM coop.Cuota AS c
    WHERE c.PrestamoID = @PrestamoID
      AND c.FechaVencimiento < @FechaCorte
      AND c.EstadoCuota <> N'PAGADA'
      AND c.MontoPagado < c.MontoCuota
);
GO

PRINT N'Funciones de dominio creadas o actualizadas correctamente.';
GO
