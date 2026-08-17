/*
  CoopCore - Modulo 8: Gestion de productos financieros
  Fecha de ampliacion: 2026-08-15
*/

USE CoopCoreDB;
GO

/* ============================================================
   Procedimiento: coop.sp_BuscarProductosFinancieros
   Descripcion: Consulta el catalogo financiero y sus indicadores de uso.
   Parametros: termino, tipo de producto y estado opcionales.
   Resultado: productos con cantidad de cuentas, prestamos y saldo de cartera.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_BuscarProductosFinancieros
    @Termino NVARCHAR(120) = NULL,
    @TipoProducto NVARCHAR(30) = NULL,
    @Estado NVARCHAR(20) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @Termino = NULLIF(LTRIM(RTRIM(@Termino)), N'');
    SET @TipoProducto = NULLIF(UPPER(LTRIM(RTRIM(@TipoProducto))), N'');
    SET @Estado = NULLIF(UPPER(LTRIM(RTRIM(@Estado))), N'');

    IF @TipoProducto IS NOT NULL
       AND @TipoProducto NOT IN (N'AHORRO', N'PRESTAMO', N'CERTIFICADO', N'OTRO')
        THROW 52200, 'TipoProducto invalido.', 1;

    IF @Estado IS NOT NULL AND @Estado NOT IN (N'ACTIVO', N'INACTIVO')
        THROW 52201, 'Estado invalido.', 1;

    SELECT
        pf.ProductoFinancieroID,
        pf.CodigoProducto,
        pf.NombreProducto,
        pf.TipoProducto,
        pf.TasaInteres,
        pf.MontoMinimoApertura,
        pf.Estado,
        pf.FechaCreacion,
        ISNULL(ct.CantidadCuentas, 0) AS CantidadCuentas,
        ISNULL(pr.CantidadPrestamos, 0) AS CantidadPrestamos,
        ISNULL(pr.SaldoCartera, 0) AS SaldoCartera
    FROM coop.ProductoFinanciero AS pf
    LEFT JOIN
    (
        SELECT ProductoFinancieroID, COUNT(*) AS CantidadCuentas
        FROM coop.Cuenta
        GROUP BY ProductoFinancieroID
    ) AS ct
        ON ct.ProductoFinancieroID = pf.ProductoFinancieroID
    LEFT JOIN
    (
        SELECT
            ProductoFinancieroID,
            COUNT(*) AS CantidadPrestamos,
            SUM(CONVERT(DECIMAL(38,2), SaldoPendiente)) AS SaldoCartera
        FROM coop.Prestamo
        GROUP BY ProductoFinancieroID
    ) AS pr
        ON pr.ProductoFinancieroID = pf.ProductoFinancieroID
    WHERE (@TipoProducto IS NULL OR pf.TipoProducto = @TipoProducto)
      AND (@Estado IS NULL OR pf.Estado = @Estado)
      AND
      (
          @Termino IS NULL
          OR pf.CodigoProducto LIKE N'%' + @Termino + N'%'
          OR pf.NombreProducto LIKE N'%' + @Termino + N'%'
      )
    ORDER BY pf.TipoProducto, pf.NombreProducto;
END;
GO

/* ============================================================
   Procedimiento: coop.sp_GuardarProductoFinanciero
   Descripcion: Crea o actualiza un producto financiero con auditoria.
   Parametros: datos del producto y cedula del empleado responsable.
   Resultado: detalle del producto guardado.
   Autor: Equipo CoopCore
   Fecha: 2026-08-17
   ============================================================ */
CREATE OR ALTER PROCEDURE coop.sp_GuardarProductoFinanciero
    @ProductoFinancieroID INT = NULL,
    @CodigoProducto NVARCHAR(20),
    @NombreProducto NVARCHAR(100),
    @TipoProducto NVARCHAR(30),
    @TasaInteres DECIMAL(18,2),
    @MontoMinimoApertura DECIMAL(18,2),
    @Estado NVARCHAR(20),
    @CedulaEmpleado NVARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @CodigoProducto = NULLIF(UPPER(LTRIM(RTRIM(@CodigoProducto))), N'');
    SET @NombreProducto = NULLIF(LTRIM(RTRIM(@NombreProducto)), N'');
    SET @TipoProducto = NULLIF(UPPER(LTRIM(RTRIM(@TipoProducto))), N'');
    SET @Estado = NULLIF(UPPER(LTRIM(RTRIM(@Estado))), N'');
    SET @CedulaEmpleado = NULLIF(LTRIM(RTRIM(@CedulaEmpleado)), N'');

    IF @CodigoProducto IS NULL OR @NombreProducto IS NULL OR @CedulaEmpleado IS NULL
        THROW 52210, 'Codigo, nombre y cedula del empleado son obligatorios.', 1;
    IF @TipoProducto NOT IN (N'AHORRO', N'PRESTAMO', N'CERTIFICADO', N'OTRO')
        THROW 52211, 'TipoProducto invalido.', 1;
    IF @Estado NOT IN (N'ACTIVO', N'INACTIVO')
        THROW 52212, 'Estado invalido.', 1;
    IF @TasaInteres NOT BETWEEN 0 AND 100 OR @MontoMinimoApertura < 0
        THROW 52213, 'Tasa o monto minimo fuera de rango.', 1;

    DECLARE @EmpleadoID INT;
    DECLARE @Accion NVARCHAR(30);
    SELECT @EmpleadoID = EmpleadoID
    FROM coop.Empleado
    WHERE Cedula = @CedulaEmpleado AND Estado = N'ACTIVO';

    IF @EmpleadoID IS NULL
        THROW 52214, 'Empleado no encontrado o inactivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @ProductoFinancieroID IS NULL
        BEGIN
            IF EXISTS
            (
                SELECT 1 FROM coop.ProductoFinanciero
                WHERE CodigoProducto = @CodigoProducto OR NombreProducto = @NombreProducto
            )
                THROW 52215, 'Ya existe un producto con el codigo o nombre indicado.', 1;

            INSERT INTO coop.ProductoFinanciero
            (
                CodigoProducto,
                NombreProducto,
                TipoProducto,
                TasaInteres,
                MontoMinimoApertura,
                Estado
            )
            VALUES
            (
                @CodigoProducto,
                @NombreProducto,
                @TipoProducto,
                @TasaInteres,
                @MontoMinimoApertura,
                @Estado
            );

            SET @ProductoFinancieroID = SCOPE_IDENTITY();
            SET @Accion = N'INSERT';
        END
        ELSE
        BEGIN
            IF NOT EXISTS
            (
                SELECT 1 FROM coop.ProductoFinanciero
                WHERE ProductoFinancieroID = @ProductoFinancieroID
            )
                THROW 52216, 'Producto financiero no encontrado.', 1;

            IF EXISTS
            (
                SELECT 1 FROM coop.ProductoFinanciero
                WHERE ProductoFinancieroID <> @ProductoFinancieroID
                  AND (CodigoProducto = @CodigoProducto OR NombreProducto = @NombreProducto)
            )
                THROW 52215, 'Ya existe otro producto con el codigo o nombre indicado.', 1;

            UPDATE coop.ProductoFinanciero
            SET CodigoProducto = @CodigoProducto,
                NombreProducto = @NombreProducto,
                TipoProducto = @TipoProducto,
                TasaInteres = @TasaInteres,
                MontoMinimoApertura = @MontoMinimoApertura,
                Estado = @Estado
            WHERE ProductoFinancieroID = @ProductoFinancieroID;

            SET @Accion = N'UPDATE';
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
            N'PRODUCTO_FINANCIERO',
            CAST(@ProductoFinancieroID AS NVARCHAR(100)),
            @Accion,
            N'Producto guardado desde sp_GuardarProductoFinanciero: ' + @CodigoProducto,
            @EmpleadoID
        );

        COMMIT TRANSACTION;

        SELECT
            N'GUARDADO' AS Resultado,
            ProductoFinancieroID,
            CodigoProducto,
            NombreProducto,
            TipoProducto,
            TasaInteres,
            MontoMinimoApertura,
            Estado,
            FechaCreacion
        FROM coop.ProductoFinanciero
        WHERE ProductoFinancieroID = @ProductoFinancieroID;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

IF DATABASE_PRINCIPAL_ID(N'rol_admin_coop') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarProductosFinancieros TO rol_admin_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_GuardarProductoFinanciero TO rol_admin_coop;
END;
IF DATABASE_PRINCIPAL_ID(N'rol_cajero_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarProductosFinancieros TO rol_cajero_coop;
IF DATABASE_PRINCIPAL_ID(N'rol_oficial_credito_coop') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarProductosFinancieros TO rol_oficial_credito_coop;
IF DATABASE_PRINCIPAL_ID(N'rol_api_coop') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_BuscarProductosFinancieros TO rol_api_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_GuardarProductoFinanciero TO rol_api_coop;
END;
GO
