# Smoke test - Sistema completo funcionando

Checklist para demostrar el avance: **Sistema completo funcionando**.

Este documento valida el flujo:

```text
SQL Server -> stored procedures -> permisos -> API .NET -> respuestas HTTP
```

## Alcance

El objetivo es comprobar que la base de datos, la seguridad, las transacciones
y la API oficial actual funcionan de forma coordinada.

La API vigente esta en `api/coopcore-api`. No se debe crear ni restaurar una
segunda API en Node.js, `api/src`, `package.json` ni `api/CoopCore.Api`.

## Brecha identificada

La API actual expone login y consultas principales, pero no expone endpoints
HTTP para los 8 stored procedures transaccionales. Las transacciones se
demuestran actualmente desde SQL Server con `sql/10_revision3_tests.sql`.

Si el profesor solicita que deposito, retiro, transferencia y flujo de
prestamos se ejecuten tambien desde HTTP, el siguiente cambio debe ser agregar
endpoints transaccionales en la misma API .NET actual, sin crear otra API.

Endpoints candidatos para una fase posterior:

| Endpoint propuesto | Stored procedure |
|---|---|
| `POST /api/cuentas/depositos` | `coop.sp_RegistrarDeposito` |
| `POST /api/cuentas/retiros` | `coop.sp_RegistrarRetiro` |
| `POST /api/cuentas/transferencias` | `coop.sp_RegistrarTransferencia` |
| `POST /api/prestamos/solicitudes` | `coop.sp_SolicitarPrestamo` |
| `POST /api/prestamos/{numeroPrestamo}/aprobar` | `coop.sp_AprobarPrestamo` |
| `POST /api/prestamos/{numeroPrestamo}/rechazar` | `coop.sp_RechazarPrestamo` |
| `POST /api/prestamos/{numeroPrestamo}/amortizacion` | `coop.sp_GenerarAmortizacion` |
| `POST /api/prestamos/{numeroPrestamo}/cuotas/{numeroCuota}/pagos` | `coop.sp_PagarCuota` |

No se implementan en este smoke test; solo se deja documentada la propuesta.

## Pre-requisitos

- [ ] SQL Server esta en ejecucion.
- [ ] SSMS esta disponible para ejecutar scripts y capturar evidencia.
- [ ] .NET 10 SDK esta instalado.
- [ ] El repositorio esta limpio o los cambios pendientes son conocidos.
- [ ] La API oficial esta en `api/coopcore-api`.
- [ ] No existe una API paralela en `api/src` ni `api/CoopCore.Api`.

## 1. Preparar base de datos

Ejecutar en SSMS, en este orden:

1. `sql/00_create_database.sql`
2. `sql/01_schema_tables.sql`
3. `sql/02_seed_data.sql`
4. `sql/03_views.sql`
5. `sql/04_stored_procedures.sql`
6. `sql/05_transactions.sql`
7. `sql/06_security.sql`

Evidencia sugerida:

- [ ] Captura de SSMS con ejecucion sin errores.
- [ ] Captura de `CoopCoreDB` creada.
- [ ] Captura del esquema `coop`.

Consulta de verificacion:

```sql
USE CoopCoreDB;

SELECT
    s.name AS Esquema,
    p.name AS StoredProcedure
FROM sys.procedures AS p
INNER JOIN sys.schemas AS s
    ON s.schema_id = p.schema_id
WHERE s.name = N'coop'
ORDER BY p.name;
```

Resultado esperado:

- [ ] Existen 18 stored procedures del esquema `coop`.
- [ ] Existen 10 SPs base en `sql/04_stored_procedures.sql`.
- [ ] Existen 8 SPs transaccionales en `sql/05_transactions.sql`.

## 2. Validar seed minimo

Ejecutar:

```sql
USE CoopCoreDB;

SELECT Cedula, NombreUsuario, Estado
FROM coop.Empleado
WHERE Cedula IN (N'EM-0101', N'EM-0102');

SELECT Cedula, Nombre, Apellido, Estado
FROM coop.Socio
WHERE Cedula IN (N'SO-1001', N'SO-1004');

SELECT NumeroCuenta, EstadoCuenta, Saldo
FROM coop.Cuenta
WHERE NumeroCuenta IN (N'CTA-10001', N'CTA-10002', N'CTA-10003', N'CTA-10004');

SELECT CodigoProducto, TipoProducto, Estado
FROM coop.ProductoFinanciero
WHERE CodigoProducto = N'PRE_CONSUMO';
```

Resultado esperado:

- [ ] Empleados `EM-0101` y `EM-0102` activos.
- [ ] Socios `SO-1001` y `SO-1004` activos.
- [ ] Cuentas `CTA-10001` a `CTA-10004` activas.
- [ ] Producto `PRE_CONSUMO` activo y de tipo `PRESTAMO`.

## 3. Validar seguridad

Ejecutar:

```sql
:r sql/07_security_tests.sql
```

Si SSMS no acepta `:r`, abrir `sql/07_security_tests.sql` y ejecutar todo el
archivo.

Resultado esperado:

- [ ] Los casos autorizados muestran `[OK]`.
- [ ] Los accesos prohibidos muestran `[DENEGADO ESPERADO]`.
- [ ] No aparece ningun `[ERROR]`.
- [ ] El caso de ownership chaining confirma que `sp_ValidarLogin` puede
      auditar y actualizar login sin dar acceso directo a tablas al usuario API.

## 4. Validar transacciones

Ejecutar:

```sql
:r sql/10_revision3_tests.sql
```

Si SSMS no acepta `:r`, abrir `sql/10_revision3_tests.sql` y ejecutar todo el
archivo.

Resultado esperado:

- [ ] Deposito registrado.
- [ ] Retiro registrado.
- [ ] Transferencia registrada.
- [ ] Solicitud de prestamo creada.
- [ ] Prestamo aprobado.
- [ ] Amortizacion generada.
- [ ] Cuota pagada.
- [ ] Solicitud separada rechazada.
- [ ] Movimientos recientes visibles.
- [ ] Auditoria reciente visible.

## 5. Configurar API local

Crear archivo local de configuracion:

```powershell
Copy-Item api\coopcore-api\coopcore-api\appsettings.example.json api\coopcore-api\coopcore-api\appsettings.Development.json
```

Editar `api\coopcore-api\coopcore-api\appsettings.Development.json` y ajustar
`ConnectionStrings:CoopCoreDb`.

La cadena debe usar `coop_api_login`, no `sa`.

Validar que el archivo local no se versiona:

```powershell
git status --short
```

Resultado esperado:

- [ ] `appsettings.Development.json` no aparece como archivo nuevo para commit.
- [ ] No hay passwords personales en archivos versionados.

## 6. Compilar API

Ejecutar:

```powershell
dotnet restore api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet build api\coopcore-api\coopcore-api\coopcore-api.csproj
```

Resultado esperado:

- [ ] Restore correcto.
- [ ] Build correcto.
- [ ] 0 errores.

## 7. Ejecutar API

Ejecutar:

```powershell
dotnet run --project api\coopcore-api\coopcore-api\coopcore-api.csproj --urls http://localhost:5000
```

Mantener la terminal abierta para las pruebas HTTP.

Resultado esperado:

- [ ] La API escucha en `http://localhost:5000`.
- [ ] No aparece error de configuracion al probar endpoints de datos.

## 8. Probar endpoints HTTP

En otra terminal:

```powershell
curl.exe -i http://localhost:5000/api/health
```

Resultado esperado:

- [ ] HTTP `200`.
- [ ] JSON con `ok: true`.

Login:

```powershell
curl.exe -i -X POST http://localhost:5000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"usuario":"mlrojas","password":"Lab_Cajero_001"}'
```

Resultado esperado:

- [ ] HTTP `200`.
- [ ] JSON con `ok: true`.
- [ ] Datos del empleado autenticado.

Socio:

```powershell
curl.exe -i http://localhost:5000/api/socios/SO-1001
```

Resultado esperado:

- [ ] HTTP `200`.
- [ ] Datos del socio.

Saldo:

```powershell
curl.exe -i http://localhost:5000/api/cuentas/CTA-10001/saldo
```

Resultado esperado:

- [ ] HTTP `200`.
- [ ] Datos de la cuenta y saldo.

Movimientos:

```powershell
curl.exe -i http://localhost:5000/api/cuentas/CTA-10001/movimientos
```

Resultado esperado:

- [ ] HTTP `200`.
- [ ] Lista de movimientos.

Prestamo:

```powershell
curl.exe -i http://localhost:5000/api/prestamos/PR-20001
```

Resultado esperado:

- [ ] HTTP `200`.
- [ ] Resumen del prestamo.
- [ ] Lista de cuotas si existen.

## 9. Validar auditoria del API

Luego del login por API, ejecutar en SSMS:

```sql
USE CoopCoreDB;

SELECT TOP (10)
    AuditoriaID,
    FechaEvento,
    Entidad,
    Accion,
    Descripcion,
    UsuarioBD
FROM coop.Auditoria
WHERE Accion = N'LOGIN'
ORDER BY AuditoriaID DESC;
```

Resultado esperado:

- [ ] Hay eventos `LOGIN` recientes.
- [ ] La operacion aparece asociada al usuario de base de datos del API.

## 10. Evidencias sugeridas

Guardar capturas con nombres consistentes:

```text
sistema_01_git_status_inicial.png
sistema_02_scripts_sql_ok.png
sistema_03_sps_18.png
sistema_04_seed_minimo.png
sistema_05_security_tests.png
sistema_06_revision3_transactions.png
sistema_07_api_build.png
sistema_08_api_run.png
sistema_09_healthcheck.png
sistema_10_login_api.png
sistema_11_socio_api.png
sistema_12_saldo_api.png
sistema_13_movimientos_api.png
sistema_14_prestamo_api.png
sistema_15_auditoria_api.png
```

## 11. Estado no ejecutado desde Codex

Desde Codex se puede verificar que la API compila con `dotnet build`. Las
pruebas que dependen de SQL Server, SSMS, datos locales y cadena de conexion
deben ejecutarse manualmente en el equipo del proyecto.

No se debe avanzar a optimizacion de indices hasta documentar primero el
analisis base de planes de ejecucion solicitado por el profesor.
