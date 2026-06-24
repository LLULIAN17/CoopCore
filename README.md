# CoopCore

Proyecto academico para **BTI23 Bases de Datos II**.

CoopCore modela operaciones de una cooperativa de ahorro y credito usando
**SQL Server** como pieza central del sistema.

## Principio de arquitectura

La base de datos ejecuta la logica de negocio por medio de procedimientos
almacenados. La API mantiene un rol delgado: solicitar operaciones a la BD.

## Estructura del repositorio

- `sql/`: scripts T-SQL por fases.
- `docs/`: documentacion tecnica y evidencias.
- `api/`: capa delgada HTTP; la implementacion vigente esta en
  `api/CoopCore.Api` con .NET 10.
- `frontend/` (opcional): capa cliente opcional.

## Orden sugerido de ejecucion de scripts

1. `sql/00_create_database.sql`
2. `sql/01_schema_tables.sql`
3. `sql/02_seed_data.sql`
4. `sql/03_views.sql`
5. `sql/04_stored_procedures.sql`
6. `sql/05_transactions.sql`
7. `sql/06_security.sql`
8. `sql/07_security_tests.sql`
9. `sql/08_concurrency_tests.sql` (fase posterior del curso)
10. `sql/09_indexes_optimization.sql` (fase posterior del curso)

## Nota sobre credenciales

Las contrasenas usadas en scripts de seguridad son solo de laboratorio.
No usar ni subir credenciales reales.

## Nota sobre capas

La API esta implementada como capa delgada y no reemplaza la logica en base de
datos. El frontend permanece opcional.

## Entregable 2 - Stored Procedures + API minima

### Estado de stored procedures

| Metrica | Valor |
|---|---|
| Total planificado | 17 SPs |
| Minimo requerido (40%) | 7 SPs |
| Implementados completamente (probados y documentados) | **9 SPs (~53%)** |
| En version inicial (contrato creado, logica pendiente) | 8 SPs |
| Cobertura total de creacion | **17/17 (100%)** |

### SPs funcionales (9)

| # | SP | Ubicacion | Categoria |
|---:|---|---|---|
| 1 | `sp_ConsultarSaldo` | `sql/04_stored_procedures.sql` | Consulta |
| 2 | `sp_ConsultarMovimientos` | `sql/04_stored_procedures.sql` | Consulta |
| 3 | `sp_RegistrarSocio` | `sql/04_stored_procedures.sql` | Gestion |
| 4 | `sp_CrearCuenta` | `sql/04_stored_procedures.sql` | Gestion |
| 5 | `sp_ConsultarPrestamo` | `sql/04_stored_procedures.sql` | Consulta |
| 6 | `sp_ValidarLogin` | `sql/04_stored_procedures.sql` | Autenticacion |
| 7 | `sp_ObtenerUsuarioPorCredenciales` | `sql/04_stored_procedures.sql` | Autenticacion |
| 8 | `sp_CambiarPassword` | `sql/04_stored_procedures.sql` | Autenticacion |
| 9 | `sp_ConsultarAuditoria` | `sql/04_stored_procedures.sql` | Consulta |

### SPs en version inicial (8)

Todos se encuentran en `sql/05_transactions.sql`. Tienen nombres, parametros
y validaciones basicas definidos, pero la logica con `BEGIN TRAN`, actualizacion
de saldos y `ROLLBACK` se completara en la Fase de Transacciones.

`sp_RegistrarDeposito`, `sp_RegistrarRetiro`, `sp_RegistrarTransferencia`,
`sp_PagarCuota`, `sp_SolicitarPrestamo`, `sp_AprobarPrestamo`,
`sp_RechazarPrestamo` y `sp_GenerarAmortizacion`.

El estado pendiente se marca internamente con `THROW 52099`; el bloque
`CATCH` de cada SP lo expone como error 52199 con un mensaje explicito.

### API minima

La API vigente para la implementacion inicial del proyecto esta en
`api/CoopCore.Api` y usa **.NET 10 + ASP.NET Core Web API**. Mantiene una
arquitectura por capas:

`Controllers -> Interfaces -> Services -> Db`

La API se conecta como `coop_api_login`, no como `sa`, y ejecuta stored
procedures reales mediante ADO.NET con `Microsoft.Data.SqlClient`.

Endpoints implementados:

- `POST /api/auth/login` -> `coop.sp_ValidarLogin`
- `GET /api/socios/{id}` -> `coop.sp_ConsultarSocio`
- `POST /api/socios` -> `coop.sp_RegistrarSocio`
- `GET /api/cuentas/:numeroCuenta/saldo` -> `coop.sp_ConsultarSaldo`
- `GET /api/cuentas/:numeroCuenta/movimientos` -> `coop.sp_ConsultarMovimientos`
- `GET /api/prestamos/{numeroPrestamo}` -> `coop.sp_ConsultarPrestamo`

Tambien ofrece `GET /api/health` como healthcheck, sin acceso a datos.

La configuracion y los ejemplos de uso estan en `api/CoopCore.Api/README.md`.

## API inicial del proyecto en .NET 10

### Objetivo

Crear una primera API academica para CoopCore usando .NET 10, sin mover la
logica de negocio desde SQL Server hacia C#. La API recibe solicitudes HTTP,
valida datos minimos, llama stored procedures y devuelve respuestas JSON.

### Modulos implementados

| Modulo | Controller | Service | Stored procedures |
|---|---|---|---|
| Auth | `AuthController` | `AuthService` | `coop.sp_ValidarLogin` |
| Socios | `SociosController` | `SocioService` | `coop.sp_ConsultarSocio`, `coop.sp_RegistrarSocio` |
| Cuentas | `CuentasController` | `CuentaService` | `coop.sp_ConsultarSaldo`, `coop.sp_ConsultarMovimientos` |
| Prestamos | `PrestamosController` | `PrestamoService` | `coop.sp_ConsultarPrestamo` |

### Ejecutar la API

```powershell
Copy-Item api\CoopCore.Api\appsettings.example.json api\CoopCore.Api\appsettings.Development.json
dotnet restore api\CoopCore.Api\CoopCore.Api.csproj
dotnet build api\CoopCore.Api\CoopCore.Api.csproj
dotnet run --project api\CoopCore.Api\CoopCore.Api.csproj --urls http://localhost:5000
```

Antes de probar endpoints de datos, ajustar
`ConnectionStrings:CoopCoreDb` en `appsettings.Development.json`.

### Probar endpoints

```powershell
curl.exe http://localhost:5000/api/health

curl.exe -X POST http://localhost:5000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"usuario":"mlrojas","password":"Lab_Cajero_001"}'

curl.exe http://localhost:5000/api/socios/SO-1001
curl.exe http://localhost:5000/api/cuentas/CTA-10001/saldo
curl.exe http://localhost:5000/api/cuentas/CTA-10001/movimientos
curl.exe http://localhost:5000/api/prestamos/PR-20001
```

En ambiente de desarrollo, el documento OpenAPI queda disponible en
`/openapi/v1.json` para probar desde herramientas como Postman, Thunder Client
o un cliente Swagger/OpenAPI.
