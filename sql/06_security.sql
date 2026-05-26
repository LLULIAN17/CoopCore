/*
  CoopCore - Script 06
  Archivo: 06_security.sql
  Fase: Control de acceso (Tema 1)
  Objetivo: Definir principales y permisos de seguridad.
  Nota: En este prompt se crean principales y membresias.
  Nota: Los permisos GRANT/DENY se agregan en el Prompt 6.
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
