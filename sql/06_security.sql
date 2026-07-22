/*
  CoopCore - Script 06
  Archivo: 06_security.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Definir principales y permisos de seguridad.
  Nota: Incluye principales (Prompt 4) y permisos (Prompt 6).
*/

IF DB_ID(N'CoopCoreDB') IS NULL
BEGIN
    THROW 51000, 'No existe CoopCoreDB. Ejecute primero sql/00_create_database.sql.', 1;
END;
GO

USE master;
GO

SET NOCOUNT ON;
GO

/* =========================
   BLOQUE 1: LOGINS (SERVIDOR)
   ========================= */

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'coop_admin_login')
BEGIN
    CREATE LOGIN [coop_admin_login]
    WITH PASSWORD = N'Lab_Coop_Admin_2026!',
         CHECK_POLICY = OFF,
         CHECK_EXPIRATION = OFF;
    PRINT N'Login creado: coop_admin_login';
END
ELSE
BEGIN
    PRINT N'Login ya existe: coop_admin_login';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'coop_cajero_login')
BEGIN
    CREATE LOGIN [coop_cajero_login]
    WITH PASSWORD = N'Lab_Coop_Cajero_2026!',
         CHECK_POLICY = OFF,
         CHECK_EXPIRATION = OFF;
    PRINT N'Login creado: coop_cajero_login';
END
ELSE
BEGIN
    PRINT N'Login ya existe: coop_cajero_login';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'coop_oficial_login')
BEGIN
    CREATE LOGIN [coop_oficial_login]
    WITH PASSWORD = N'Lab_Coop_Oficial_2026!',
         CHECK_POLICY = OFF,
         CHECK_EXPIRATION = OFF;
    PRINT N'Login creado: coop_oficial_login';
END
ELSE
BEGIN
    PRINT N'Login ya existe: coop_oficial_login';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'coop_auditor_login')
BEGIN
    CREATE LOGIN [coop_auditor_login]
    WITH PASSWORD = N'Lab_Coop_Auditor_2026!',
         CHECK_POLICY = OFF,
         CHECK_EXPIRATION = OFF;
    PRINT N'Login creado: coop_auditor_login';
END
ELSE
BEGIN
    PRINT N'Login ya existe: coop_auditor_login';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'coop_api_login')
BEGIN
    CREATE LOGIN [coop_api_login]
    WITH PASSWORD = N'Lab_Coop_API_2026!',
         CHECK_POLICY = OFF,
         CHECK_EXPIRATION = OFF;
    PRINT N'Login creado: coop_api_login';
END
ELSE
BEGIN
    PRINT N'Login ya existe: coop_api_login';
END;
GO

USE CoopCoreDB;
GO

IF SCHEMA_ID(N'coop') IS NULL
BEGIN
    THROW 51002, 'No existe el esquema coop. Ejecute primero sql/01_schema_tables.sql.', 1;
END;
GO

/* =========================
   BLOQUE 2: USUARIOS (BASE DE DATOS)
   ========================= */

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'coop_admin_user')
BEGIN
    CREATE USER [coop_admin_user]
    FOR LOGIN [coop_admin_login]
    WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario creado: coop_admin_user';
END
ELSE
BEGIN
    ALTER USER [coop_admin_user] WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario ya existe (schema ajustado): coop_admin_user';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'coop_cajero_user')
BEGIN
    CREATE USER [coop_cajero_user]
    FOR LOGIN [coop_cajero_login]
    WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario creado: coop_cajero_user';
END
ELSE
BEGIN
    ALTER USER [coop_cajero_user] WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario ya existe (schema ajustado): coop_cajero_user';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'coop_oficial_user')
BEGIN
    CREATE USER [coop_oficial_user]
    FOR LOGIN [coop_oficial_login]
    WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario creado: coop_oficial_user';
END
ELSE
BEGIN
    ALTER USER [coop_oficial_user] WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario ya existe (schema ajustado): coop_oficial_user';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'coop_auditor_user')
BEGIN
    CREATE USER [coop_auditor_user]
    FOR LOGIN [coop_auditor_login]
    WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario creado: coop_auditor_user';
END
ELSE
BEGIN
    ALTER USER [coop_auditor_user] WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario ya existe (schema ajustado): coop_auditor_user';
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'coop_api_user')
BEGIN
    CREATE USER [coop_api_user]
    FOR LOGIN [coop_api_login]
    WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario creado: coop_api_user';
END
ELSE
BEGIN
    ALTER USER [coop_api_user] WITH DEFAULT_SCHEMA = [coop];
    PRINT N'Usuario ya existe (schema ajustado): coop_api_user';
END;
GO

/* =========================
   BLOQUE 3: ROLES PERSONALIZADOS (BASE DE DATOS)
   ========================= */

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'rol_admin_coop'
      AND type = N'R'
)
BEGIN
    CREATE ROLE [rol_admin_coop] AUTHORIZATION [dbo];
    PRINT N'Rol creado: rol_admin_coop';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: rol_admin_coop';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'rol_cajero_coop'
      AND type = N'R'
)
BEGIN
    CREATE ROLE [rol_cajero_coop] AUTHORIZATION [dbo];
    PRINT N'Rol creado: rol_cajero_coop';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: rol_cajero_coop';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'rol_oficial_credito_coop'
      AND type = N'R'
)
BEGIN
    CREATE ROLE [rol_oficial_credito_coop] AUTHORIZATION [dbo];
    PRINT N'Rol creado: rol_oficial_credito_coop';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: rol_oficial_credito_coop';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'rol_auditor_coop'
      AND type = N'R'
)
BEGIN
    CREATE ROLE [rol_auditor_coop] AUTHORIZATION [dbo];
    PRINT N'Rol creado: rol_auditor_coop';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: rol_auditor_coop';
END;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.database_principals
    WHERE name = N'rol_api_coop'
      AND type = N'R'
)
BEGIN
    CREATE ROLE [rol_api_coop] AUTHORIZATION [dbo];
    PRINT N'Rol creado: rol_api_coop';
END
ELSE
BEGIN
    PRINT N'Rol ya existe: rol_api_coop';
END;
GO

/* =========================
   BLOQUE 4: MEMBRESIAS USUARIO -> ROL
   ========================= */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS drm
    INNER JOIN sys.database_principals AS r
        ON r.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals AS m
        ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'rol_admin_coop'
      AND m.name = N'coop_admin_user'
)
BEGIN
    ALTER ROLE [rol_admin_coop] ADD MEMBER [coop_admin_user];
    PRINT N'Membresia creada: coop_admin_user -> rol_admin_coop';
END
ELSE
BEGIN
    PRINT N'Membresia ya existe: coop_admin_user -> rol_admin_coop';
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS drm
    INNER JOIN sys.database_principals AS r
        ON r.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals AS m
        ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'rol_cajero_coop'
      AND m.name = N'coop_cajero_user'
)
BEGIN
    ALTER ROLE [rol_cajero_coop] ADD MEMBER [coop_cajero_user];
    PRINT N'Membresia creada: coop_cajero_user -> rol_cajero_coop';
END
ELSE
BEGIN
    PRINT N'Membresia ya existe: coop_cajero_user -> rol_cajero_coop';
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS drm
    INNER JOIN sys.database_principals AS r
        ON r.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals AS m
        ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'rol_oficial_credito_coop'
      AND m.name = N'coop_oficial_user'
)
BEGIN
    ALTER ROLE [rol_oficial_credito_coop] ADD MEMBER [coop_oficial_user];
    PRINT N'Membresia creada: coop_oficial_user -> rol_oficial_credito_coop';
END
ELSE
BEGIN
    PRINT N'Membresia ya existe: coop_oficial_user -> rol_oficial_credito_coop';
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS drm
    INNER JOIN sys.database_principals AS r
        ON r.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals AS m
        ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'rol_auditor_coop'
      AND m.name = N'coop_auditor_user'
)
BEGIN
    ALTER ROLE [rol_auditor_coop] ADD MEMBER [coop_auditor_user];
    PRINT N'Membresia creada: coop_auditor_user -> rol_auditor_coop';
END
ELSE
BEGIN
    PRINT N'Membresia ya existe: coop_auditor_user -> rol_auditor_coop';
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.database_role_members AS drm
    INNER JOIN sys.database_principals AS r
        ON r.principal_id = drm.role_principal_id
    INNER JOIN sys.database_principals AS m
        ON m.principal_id = drm.member_principal_id
    WHERE r.name = N'rol_api_coop'
      AND m.name = N'coop_api_user'
)
BEGIN
    ALTER ROLE [rol_api_coop] ADD MEMBER [coop_api_user];
    PRINT N'Membresia creada: coop_api_user -> rol_api_coop';
END
ELSE
BEGIN
    PRINT N'Membresia ya existe: coop_api_user -> rol_api_coop';
END;
GO

/* =========================
   BLOQUE 5: PERMISOS POR ROL (PROMPT 6)
   ========================= */

-- Verificacion rapida de roles esperados.
IF DATABASE_PRINCIPAL_ID(N'rol_admin_coop') IS NULL
    THROW 51010, 'No existe el rol rol_admin_coop.', 1;
IF DATABASE_PRINCIPAL_ID(N'rol_cajero_coop') IS NULL
    THROW 51011, 'No existe el rol rol_cajero_coop.', 1;
IF DATABASE_PRINCIPAL_ID(N'rol_oficial_credito_coop') IS NULL
    THROW 51012, 'No existe el rol rol_oficial_credito_coop.', 1;
IF DATABASE_PRINCIPAL_ID(N'rol_auditor_coop') IS NULL
    THROW 51013, 'No existe el rol rol_auditor_coop.', 1;
IF DATABASE_PRINCIPAL_ID(N'rol_api_coop') IS NULL
    THROW 51014, 'No existe el rol rol_api_coop.', 1;
GO

/* -------------------------------------
   ADMINISTRADOR
   - EXECUTE sobre SPs base
   - SELECT sobre vistas y catalogos
   ------------------------------------- */
IF OBJECT_ID(N'coop.sp_ConsultarSaldo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarSaldo TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_ConsultarSocio', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarSocio TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_ConsultarMovimientos', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarMovimientos TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_RegistrarSocio', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarSocio TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_CrearCuenta', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_CrearCuenta TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_ConsultarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarPrestamo TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_RegistrarDeposito', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarDeposito TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_RegistrarRetiro', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarRetiro TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_RegistrarTransferencia', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarTransferencia TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_PagarCuota', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_PagarCuota TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_SolicitarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_SolicitarPrestamo TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_AprobarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_AprobarPrestamo TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_RechazarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RechazarPrestamo TO rol_admin_coop;
IF OBJECT_ID(N'coop.sp_GenerarAmortizacion', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_GenerarAmortizacion TO rol_admin_coop;

IF OBJECT_ID(N'coop.vw_CuentasResumen', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_CuentasResumen TO rol_admin_coop;
IF OBJECT_ID(N'coop.vw_MovimientosAuditoria', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_MovimientosAuditoria TO rol_admin_coop;
IF OBJECT_ID(N'coop.vw_PrestamosResumen', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_PrestamosResumen TO rol_admin_coop;
IF OBJECT_ID(N'coop.vw_SociosConsulta', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_SociosConsulta TO rol_admin_coop;

IF OBJECT_ID(N'coop.Rol', N'U') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.Rol TO rol_admin_coop;
IF OBJECT_ID(N'coop.ProductoFinanciero', N'U') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.ProductoFinanciero TO rol_admin_coop;
GO

/* -------------------------------------
   CAJERO
   - EXECUTE sobre SPs de caja
   - SELECT sobre vistas operativas de caja
   - DENY DELETE sobre esquema
   ------------------------------------- */
IF OBJECT_ID(N'coop.sp_ConsultarSaldo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarSaldo TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_ConsultarSocio', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarSocio TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_ConsultarMovimientos', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarMovimientos TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_RegistrarSocio', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarSocio TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_CrearCuenta', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_CrearCuenta TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_RegistrarDeposito', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarDeposito TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_RegistrarRetiro', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarRetiro TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_RegistrarTransferencia', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarTransferencia TO rol_cajero_coop;
IF OBJECT_ID(N'coop.sp_PagarCuota', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_PagarCuota TO rol_cajero_coop;

IF OBJECT_ID(N'coop.vw_CuentasResumen', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_CuentasResumen TO rol_cajero_coop;
IF OBJECT_ID(N'coop.vw_MovimientosAuditoria', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_MovimientosAuditoria TO rol_cajero_coop;

DENY DELETE ON SCHEMA::coop TO rol_cajero_coop;
GO

/* -------------------------------------
   OFICIAL DE CREDITO
   - EXECUTE sobre SPs de prestamos
   - SELECT sobre resumen de prestamos
   ------------------------------------- */
IF OBJECT_ID(N'coop.sp_ConsultarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarPrestamo TO rol_oficial_credito_coop;
IF OBJECT_ID(N'coop.sp_SolicitarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_SolicitarPrestamo TO rol_oficial_credito_coop;
IF OBJECT_ID(N'coop.sp_AprobarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_AprobarPrestamo TO rol_oficial_credito_coop;
IF OBJECT_ID(N'coop.sp_RechazarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RechazarPrestamo TO rol_oficial_credito_coop;
IF OBJECT_ID(N'coop.sp_GenerarAmortizacion', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_GenerarAmortizacion TO rol_oficial_credito_coop;

IF OBJECT_ID(N'coop.vw_PrestamosResumen', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_PrestamosResumen TO rol_oficial_credito_coop;
GO

/* -------------------------------------
   AUDITOR
   - SELECT sobre vistas/reportes
   - DENY de escritura sobre esquema
   ------------------------------------- */
IF OBJECT_ID(N'coop.vw_CuentasResumen', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_CuentasResumen TO rol_auditor_coop;
IF OBJECT_ID(N'coop.vw_MovimientosAuditoria', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_MovimientosAuditoria TO rol_auditor_coop;
IF OBJECT_ID(N'coop.vw_PrestamosResumen', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_PrestamosResumen TO rol_auditor_coop;
IF OBJECT_ID(N'coop.vw_SociosConsulta', N'V') IS NOT NULL
    GRANT SELECT ON OBJECT::coop.vw_SociosConsulta TO rol_auditor_coop;

DENY INSERT ON SCHEMA::coop TO rol_auditor_coop;
DENY UPDATE ON SCHEMA::coop TO rol_auditor_coop;
DENY DELETE ON SCHEMA::coop TO rol_auditor_coop;
GO

/* -------------------------------------
   API
   - EXECUTE solo sobre SPs autorizados
   - DENY de acceso directo a datos
   ------------------------------------- */
-- El permiso a nivel de esquema de la version anterior se retira para que
-- nuevos SPs no queden expuestos automaticamente al API.
REVOKE EXECUTE ON SCHEMA::coop FROM rol_api_coop;

IF OBJECT_ID(N'coop.sp_ConsultarSaldo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarSaldo TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_ValidarLogin', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ValidarLogin TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_CambiarPassword', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_CambiarPassword TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_ConsultarSocio', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarSocio TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_RegistrarSocio', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarSocio TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_CrearCuenta', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_CrearCuenta TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_ConsultarMovimientos', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarMovimientos TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_ConsultarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarPrestamo TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_RegistrarDeposito', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarDeposito TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_RegistrarRetiro', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarRetiro TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_RegistrarTransferencia', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RegistrarTransferencia TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_PagarCuota', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_PagarCuota TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_SolicitarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_SolicitarPrestamo TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_AprobarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_AprobarPrestamo TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_RechazarPrestamo', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_RechazarPrestamo TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_GenerarAmortizacion', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_GenerarAmortizacion TO rol_api_coop;
IF OBJECT_ID(N'coop.sp_ConsultarAuditoria', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarAuditoria TO rol_api_coop;

-- Por minimo privilegio, rol_api_coop conserva solo los SPs usados por
-- los endpoints de la API .NET y no recibe EXECUTE sobre todo el esquema.

DENY SELECT ON SCHEMA::coop TO rol_api_coop;
DENY INSERT ON SCHEMA::coop TO rol_api_coop;
DENY UPDATE ON SCHEMA::coop TO rol_api_coop;
DENY DELETE ON SCHEMA::coop TO rol_api_coop;
GO

/* -------------------------------------
   PROTECCION DE TABLAS BASE
   - Los roles de consulta trabajan por vistas
   - Las operaciones se canalizan por SPs
   ------------------------------------- */
-- Los DENY SELECT sobre tablas base se eliminaron porque rompian el
-- ownership chaining de las vistas. Como rol_cajero_coop,
-- rol_oficial_credito_coop y rol_auditor_coop NO tienen GRANT SELECT
-- sobre las tablas (solo sobre las vistas), por defecto ya no pueden
-- leerlas. No hace falta DENY explicito.
--
-- Los REVOKE siguientes tambien limpian los DENY que hayan quedado aplicados
-- al ejecutar una version anterior de este script.
IF OBJECT_ID(N'coop.Socio', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Socio FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Socio FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Socio FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Empleado', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Empleado FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Empleado FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Empleado FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Rol', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Rol FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Rol FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Rol FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.ProductoFinanciero', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.ProductoFinanciero FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.ProductoFinanciero FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.ProductoFinanciero FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Cuenta', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Cuenta FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Cuenta FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Cuenta FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Movimiento', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Movimiento FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Movimiento FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Movimiento FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Prestamo', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Prestamo FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Prestamo FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Prestamo FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Cuota', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Cuota FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Cuota FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Cuota FROM rol_auditor_coop;
END;

IF OBJECT_ID(N'coop.Auditoria', N'U') IS NOT NULL
BEGIN
    REVOKE SELECT ON OBJECT::coop.Auditoria FROM rol_cajero_coop;
    REVOKE SELECT ON OBJECT::coop.Auditoria FROM rol_oficial_credito_coop;
    REVOKE SELECT ON OBJECT::coop.Auditoria FROM rol_auditor_coop;
END;
GO

/* -------------------------------------
   AUTENTICACION
   - API: solo login
   - Roles internos: operaciones autorizadas
   ------------------------------------- */
IF OBJECT_ID(N'coop.sp_ValidarLogin', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ValidarLogin TO rol_admin_coop;

IF OBJECT_ID(N'coop.sp_ObtenerUsuarioPorCredenciales', N'P') IS NOT NULL
    GRANT EXECUTE ON OBJECT::coop.sp_ObtenerUsuarioPorCredenciales TO rol_admin_coop;

IF OBJECT_ID(N'coop.sp_CambiarPassword', N'P') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_CambiarPassword TO rol_admin_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_CambiarPassword TO rol_cajero_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_CambiarPassword TO rol_oficial_credito_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_CambiarPassword TO rol_auditor_coop;
END;
GO

/* -------------------------------------
   CONSULTA DE AUDITORIA
   - SP funcional para administrador y auditor
   ------------------------------------- */
IF OBJECT_ID(N'coop.sp_ConsultarAuditoria', N'P') IS NOT NULL
BEGIN
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarAuditoria TO rol_admin_coop;
    GRANT EXECUTE ON OBJECT::coop.sp_ConsultarAuditoria TO rol_auditor_coop;
END;
GO

-- Los 8 SPs de sql/05_transactions.sql ya tienen transacciones explicitas.
-- Sus permisos se asignan arriba por rol: caja para cajeros, prestamos para
-- oficiales de credito y cobertura completa para administradores.
