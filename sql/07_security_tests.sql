/*
  CoopCore - Script 07
  Archivo: 07_security_tests.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Validar permisos con EXECUTE AS USER y REVERT.
  Nota: Cada caso usa EXECUTE AS USER ... REVERT.
  Nota: Los fallos esperados se capturan con TRY...CATCH.
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    THROW 51000, 'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.', 1;
END;
GO

USE CoopCoreDB;
GO

SET NOCOUNT ON;
GO

-- Verificacion basica de usuarios requeridos para las pruebas.
IF DATABASE_PRINCIPAL_ID(N'coop_cajero_user') IS NULL
    THROW 51020, 'No existe coop_cajero_user. Ejecute sql/06_security.sql.', 1;
IF DATABASE_PRINCIPAL_ID(N'coop_auditor_user') IS NULL
    THROW 51021, 'No existe coop_auditor_user. Ejecute sql/06_security.sql.', 1;
IF DATABASE_PRINCIPAL_ID(N'coop_oficial_user') IS NULL
    THROW 51022, 'No existe coop_oficial_user. Ejecute sql/06_security.sql.', 1;
IF DATABASE_PRINCIPAL_ID(N'coop_api_user') IS NULL
    THROW 51023, 'No existe coop_api_user. Ejecute sql/06_security.sql.', 1;
GO

PRINT N'============================================================';
PRINT N'INICIO DE PRUEBAS DE SEGURIDAD (PROMPT 7)';
PRINT N'============================================================';
GO

/* ============================================================
   CASO 1: CAJERO puede ejecutar un SP de caja (esperado OK)
   ============================================================ */
PRINT N'CASO 1 - Cajero ejecuta SP de caja (sp_ConsultarSaldo)';
BEGIN TRY
    EXECUTE AS USER = N'coop_cajero_user';

    EXEC coop.sp_ConsultarSaldo
        @NumeroCuenta = N'CTA-10001';

    PRINT N'[OK] Cajero pudo ejecutar sp_ConsultarSaldo.';
    REVERT;
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[ERROR] CASO 1 fallo: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ============================================================
   CASO 2: CAJERO NO puede borrar (esperado DENEGADO)
   ============================================================ */
PRINT N'CASO 2 - Cajero intenta DELETE directo en schema coop (debe fallar)';
BEGIN TRY
    EXECUTE AS USER = N'coop_cajero_user';

    DELETE FROM coop.Socio
    WHERE SocioID = -1;

    REVERT;
    PRINT N'[ERROR] CASO 2 no genero denegacion y debia fallar.';
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[DENEGADO ESPERADO] CASO 2: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ============================================================
   CASO 3: AUDITOR puede consultar vistas (esperado OK)
   ============================================================ */
PRINT N'CASO 3 - Auditor consulta vistas de reporte';
BEGIN TRY
    EXECUTE AS USER = N'coop_auditor_user';

    SELECT TOP (1) *
    FROM coop.vw_CuentasResumen;

    SELECT TOP (1) *
    FROM coop.vw_MovimientosAuditoria;

    SELECT TOP (1) *
    FROM coop.vw_PrestamosResumen;

    SELECT TOP (1) *
    FROM coop.vw_SociosConsulta;

    PRINT N'[OK] Auditor pudo consultar las vistas.';
    REVERT;
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[ERROR] CASO 3 fallo: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ============================================================
   CASO 4: AUDITOR NO puede modificar datos (esperado DENEGADO)
   ============================================================ */
PRINT N'CASO 4 - Auditor intenta UPDATE directo (debe fallar)';
BEGIN TRY
    EXECUTE AS USER = N'coop_auditor_user';

    UPDATE coop.Socio
    SET Telefono = Telefono
    WHERE SocioID = -1;

    REVERT;
    PRINT N'[ERROR] CASO 4 no genero denegacion y debia fallar.';
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[DENEGADO ESPERADO] CASO 4: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ============================================================
   CASO 5: OFICIAL puede ejecutar SP de prestamos (esperado OK)
   ============================================================ */
PRINT N'CASO 5 - Oficial de credito ejecuta sp_ConsultarPrestamo';
BEGIN TRY
    EXECUTE AS USER = N'coop_oficial_user';

    EXEC coop.sp_ConsultarPrestamo
        @NumeroPrestamo = N'PR-20001';

    PRINT N'[OK] Oficial de credito pudo ejecutar sp_ConsultarPrestamo.';
    REVERT;
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[ERROR] CASO 5 fallo: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ============================================================
   CASO 6: API puede ejecutar SP (esperado OK)
   ============================================================ */
PRINT N'CASO 6 - API ejecuta SP permitido';
BEGIN TRY
    EXECUTE AS USER = N'coop_api_user';

    EXEC coop.sp_ConsultarSaldo
        @NumeroCuenta = N'CTA-10001';

    PRINT N'[OK] API pudo ejecutar sp_ConsultarSaldo.';
    REVERT;
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[ERROR] CASO 6 fallo: ' + ERROR_MESSAGE();
END CATCH;
GO

/* ============================================================
   CASO 7: API NO accede a tablas directas (esperado DENEGADO)
   ============================================================ */
PRINT N'CASO 7 - API intenta SELECT directo en tabla base (debe fallar)';
BEGIN TRY
    EXECUTE AS USER = N'coop_api_user';

    SELECT TOP (1) *
    FROM coop.Cuenta;

    REVERT;
    PRINT N'[ERROR] CASO 7 no genero denegacion y debia fallar.';
END TRY
BEGIN CATCH
    BEGIN TRY
        REVERT;
    END TRY
    BEGIN CATCH
    END CATCH;

    PRINT N'[DENEGADO ESPERADO] CASO 7: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT N'============================================================';
PRINT N'FIN DE PRUEBAS DE SEGURIDAD (PROMPT 7)';
PRINT N'Revise la pestaña Messages en SSMS para evidencia.';
PRINT N'============================================================';
GO
