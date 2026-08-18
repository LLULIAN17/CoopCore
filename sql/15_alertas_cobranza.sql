/*
  CoopCore - Modulo 9: Alertas y seguimiento de cobranza
  Fecha de ampliacion: 2026-08-15
*/

USE CoopCoreDB;
GO

IF OBJECT_ID(N'coop.GestionCobranza', N'U') IS NULL
BEGIN
    CREATE TABLE coop.GestionCobranza
    (
        GestionCobranzaID BIGINT IDENTITY(1,1) NOT NULL
            CONSTRAINT PK_GestionCobranza PRIMARY KEY,
        PrestamoID INT NOT NULL,
        EmpleadoID INT NOT NULL,
        FechaGestion DATETIME2 NOT NULL
            CONSTRAINT DF_GestionCobranza_Fecha DEFAULT (SYSDATETIME()),
        TipoGestion NVARCHAR(20) NOT NULL,
        Resultado NVARCHAR(30) NOT NULL,
        Comentario NVARCHAR(500) NOT NULL,
        FechaCompromiso DATE NULL,
        MontoCompromiso DECIMAL(18,2) NULL,
        CONSTRAINT CK_GestionCobranza_Tipo CHECK
        (
            TipoGestion IN (N'LLAMADA', N'CORREO', N'SMS', N'VISITA', N'ACUERDO', N'OTRO')
        ),
        CONSTRAINT CK_GestionCobranza_Resultado CHECK
        (
            Resultado IN
            (
                N'CONTACTADO', N'SIN_RESPUESTA', N'COMPROMISO_PAGO',
                N'PAGADO', N'REPROGRAMAR', N'OTRO'
            )
        ),
        CONSTRAINT CK_GestionCobranza_Monto CHECK
        (
            MontoCompromiso IS NULL OR MontoCompromiso > 0
        ),
        CONSTRAINT FK_GestionCobranza_Prestamo FOREIGN KEY (PrestamoID)
            REFERENCES coop.Prestamo(PrestamoID),
        CONSTRAINT FK_GestionCobranza_Empleado FOREIGN KEY (EmpleadoID)
            REFERENCES coop.Empleado(EmpleadoID)
    );
END;
GO

IF NOT EXISTS
(
    SELECT 1 FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'coop.GestionCobranza')
      AND name = N'IX_GestionCobranza_Prestamo_Fecha'
)
BEGIN
    CREATE INDEX IX_GestionCobranza_Prestamo_Fecha
        ON coop.GestionCobranza (PrestamoID, FechaGestion DESC)
        INCLUDE (TipoGestion, Resultado, FechaCompromiso, MontoCompromiso);
END;
GO

/* ============================================================
   Procedimiento: coop.sp_ConsultarAlertasCobranza
   Descripcion: Prioriza cuotas vencidas o proximas para gestion de cobro.
   Parametros: fecha de corte, horizonte de dias y filtro de vencidas.
   Resultado: alertas con contacto, prioridad, mora y ultima gestion.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_ConsultarAlertasCobranza
    @FechaCorte DATE = NULL,
    @DiasProximos INT = 7,
    @SoloVencidas BIT = 0
AS
BEGIN
    SET NOCOUNT ON;
    SET @FechaCorte = ISNULL(@FechaCorte, CONVERT(DATE, SYSDATETIME()));

    IF @DiasProximos NOT BETWEEN 0 AND 90
        THROW 52300, 'DiasProximos debe estar entre 0 y 90.', 1;

    SELECT
        c.CuotaID,
        s.SocioID,
        s.Cedula,
        s.Nombre + N' ' + s.Apellido AS NombreCliente,
        s.Telefono,
        s.Correo,
        p.NumeroPrestamo,
        c.NumeroCuota,
        c.FechaVencimiento,
        c.MontoCuota - c.MontoPagado AS MontoPendiente,
        CASE
            WHEN c.FechaVencimiento < @FechaCorte THEN N'VENCIDA'
            WHEN c.FechaVencimiento = @FechaCorte THEN N'VENCE_HOY'
            ELSE N'PROXIMA'
        END AS TipoAlerta,
        CASE
            WHEN DATEDIFF(DAY, c.FechaVencimiento, @FechaCorte) >= 90 THEN N'CRITICA'
            WHEN DATEDIFF(DAY, c.FechaVencimiento, @FechaCorte) >= 30 THEN N'ALTA'
            WHEN c.FechaVencimiento <= DATEADD(DAY, 3, @FechaCorte) THEN N'MEDIA'
            ELSE N'BAJA'
        END AS Prioridad,
        CASE
            WHEN c.FechaVencimiento < @FechaCorte
            THEN DATEDIFF(DAY, c.FechaVencimiento, @FechaCorte)
            ELSE 0
        END AS DiasMora,
        CASE
            WHEN c.FechaVencimiento >= @FechaCorte
            THEN DATEDIFF(DAY, @FechaCorte, c.FechaVencimiento)
            ELSE 0
        END AS DiasParaVencer,
        coop.fn_CalcularMoraCuota
        (
            c.MontoCuota,
            c.MontoPagado,
            c.FechaVencimiento,
            @FechaCorte,
            coop.fn_ObtenerTasaMoraDiaria()
        ) AS MoraEstimada,
        ug.FechaGestion AS UltimaGestionFecha,
        ug.TipoGestion AS UltimaGestionTipo,
        ug.Resultado AS UltimaGestionResultado,
        ug.FechaCompromiso,
        ug.MontoCompromiso
    FROM coop.Cuota AS c
    INNER JOIN coop.Prestamo AS p
        ON p.PrestamoID = c.PrestamoID
    INNER JOIN coop.Socio AS s
        ON s.SocioID = p.SocioID
    OUTER APPLY
    (
        SELECT TOP (1)
            gc.FechaGestion,
            gc.TipoGestion,
            gc.Resultado,
            gc.FechaCompromiso,
            gc.MontoCompromiso
        FROM coop.GestionCobranza AS gc
        WHERE gc.PrestamoID = p.PrestamoID
        ORDER BY gc.FechaGestion DESC, gc.GestionCobranzaID DESC
    ) AS ug
    WHERE p.EstadoPrestamo IN (N'ACTIVO', N'MORA')
      AND p.SaldoPendiente > 0
      AND c.EstadoCuota <> N'PAGADA'
      AND c.MontoPagado < c.MontoCuota
      AND c.FechaVencimiento <= DATEADD(DAY, @DiasProximos, @FechaCorte)
      AND (@SoloVencidas = 0 OR c.FechaVencimiento < @FechaCorte)
    ORDER BY
        CASE
            WHEN c.FechaVencimiento < @FechaCorte THEN 0
            WHEN c.FechaVencimiento = @FechaCorte THEN 1
            ELSE 2
        END,
        c.FechaVencimiento,
        c.MontoCuota - c.MontoPagado DESC;
END;
GO

/* ============================================================
   Procedimiento: coop.sp_RegistrarGestionCobranza
   Descripcion: Registra una gestion de cobro y su evento de auditoria.
   Parametros: prestamo, empleado, tipo, resultado, comentario y compromiso.
   Resultado: detalle de la gestion creada.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_RegistrarGestionCobranza
    @NumeroPrestamo NVARCHAR(30),
    @CedulaEmpleado NVARCHAR(20),
    @TipoGestion NVARCHAR(20),
    @Resultado NVARCHAR(30),
    @Comentario NVARCHAR(500),
    @FechaCompromiso DATE = NULL,
    @MontoCompromiso DECIMAL(18,2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @NumeroPrestamo = NULLIF(LTRIM(RTRIM(@NumeroPrestamo)), N'');
    SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');
    SET @TipoGestion = NULLIF(UPPER(LTRIM(RTRIM(@TipoGestion))), N'');
    SET @Resultado = NULLIF(UPPER(LTRIM(RTRIM(@Resultado))), N'');
    SET @Comentario = NULLIF(LTRIM(RTRIM(@Comentario)), N'');

    IF @NumeroPrestamo IS NULL OR @CedulaEmpleado IS NULL OR @Comentario IS NULL
        THROW 52310, 'Prestamo, empleado y comentario son obligatorios.', 1;
    IF @TipoGestion NOT IN (N'LLAMADA', N'CORREO', N'SMS', N'VISITA', N'ACUERDO', N'OTRO')
        THROW 52311, 'TipoGestion invalido.', 1;
    IF @Resultado NOT IN
    (
        N'CONTACTADO', N'SIN_RESPUESTA', N'COMPROMISO_PAGO',
        N'PAGADO', N'REPROGRAMAR', N'OTRO'
    )
        THROW 52312, 'Resultado invalido.', 1;
    IF @Resultado = N'COMPROMISO_PAGO'
       AND (@FechaCompromiso IS NULL OR @MontoCompromiso IS NULL OR @MontoCompromiso <= 0)
        THROW 52313, 'El compromiso de pago requiere fecha y monto.', 1;

    DECLARE @PrestamoID INT;
    DECLARE @EmpleadoID INT;

    SELECT @PrestamoID = PrestamoID
    FROM coop.Prestamo
    WHERE NumeroPrestamo = @NumeroPrestamo
      AND EstadoPrestamo IN (N'ACTIVO', N'MORA');

    SELECT @EmpleadoID = EmpleadoID
    FROM coop.Empleado
    WHERE Cedula = @CedulaEmpleado AND Estado = N'ACTIVO';

    IF @PrestamoID IS NULL THROW 52314, 'Prestamo no encontrado o no vigente.', 1;
    IF @EmpleadoID IS NULL THROW 52315, 'Empleado no encontrado o inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO coop.GestionCobranza
        (
            PrestamoID,
            EmpleadoID,
            TipoGestion,
            Resultado,
            Comentario,
            FechaCompromiso,
            MontoCompromiso
        )
        VALUES
        (
            @PrestamoID,
            @EmpleadoID,
            @TipoGestion,
            @Resultado,
            @Comentario,
            @FechaCompromiso,
            @MontoCompromiso
        );

        DECLARE @GestionCobranzaID BIGINT = SCOPE_IDENTITY();

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
            N'GESTION_COBRANZA',
            CAST(@GestionCobranzaID AS NVARCHAR(100)),
            N'INSERT',
            N'Gestion ' + @TipoGestion + N' para prestamo ' + @NumeroPrestamo
                + N'. Resultado: ' + @Resultado,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'REGISTRADA' AS ResultadoOperacion,
            gc.GestionCobranzaID,
            p.NumeroPrestamo,
            gc.FechaGestion,
            gc.TipoGestion,
            gc.Resultado,
            gc.Comentario,
            gc.FechaCompromiso,
            gc.MontoCompromiso,
            e.Cedula AS CedulaEmpleado,
            e.Nombre + N' ' + e.Apellido AS NombreEmpleado
        FROM coop.GestionCobranza AS gc
        INNER JOIN coop.Prestamo AS p
            ON p.PrestamoID = gc.PrestamoID
        INNER JOIN coop.Empleado AS e
            ON e.EmpleadoID = gc.EmpleadoID
        WHERE gc.GestionCobranzaID = @GestionCobranzaID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_admin_coop') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarAlertasCobranza TO rol_admin_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarGestionCobranza TO rol_admin_coop;
END;
IF DATABASE_PRINCIPAL_ID(N'rol_oficial_credito_coop') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarAlertasCobranza TO rol_oficial_credito_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarGestionCobranza TO rol_oficial_credito_coop;
END;
IF DATABASE_PRINCIPAL_ID(N'rol_api_coop') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarAlertasCobranza TO rol_api_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarGestionCobranza TO rol_api_coop;
END;
GO
