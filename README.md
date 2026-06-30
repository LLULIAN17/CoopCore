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
11. `sql/10_revision3_tests.sql` (pruebas de transacciones Revision 3)

## Nota sobre credenciales

Las contrasenas usadas en scripts de seguridad son solo de laboratorio.
No usar ni subir credenciales reales.

## Nota sobre capas

La API esta implementada como capa delgada y no reemplaza la logica en base de
datos. El frontend permanece opcional.

## Revision 3 - Stored Procedures y transacciones

### Estado de stored procedures

| Metrica | Valor |
|---|---|
| Total real detectado | 18 SPs |
| Minimo requerido (80%) | 15 SPs |
| Implementados completamente | **18 SPs (100%)** |
| Con transacciones explicitas | **8 SPs** |
| Marcadores de implementacion incompleta en `sql/05_transactions.sql` | **0** |

Calculo del 80%:

```text
18 * 0.80 = 14.4
Minimo requerido redondeado hacia arriba = 15 SPs completos
Resultado actual = 18/18 SPs completos
```

### SPs funcionales (18)

En `sql/04_stored_procedures.sql`:

| # | SP | Categoria |
|---:|---|---|
| 1 | `coop.sp_ValidarLogin` | Autenticacion |
| 2 | `coop.sp_ObtenerUsuarioPorCredenciales` | Autenticacion |
| 3 | `coop.sp_CambiarPassword` | Autenticacion |
| 4 | `coop.sp_ConsultarSocio` | Consulta |
| 5 | `coop.sp_ConsultarSaldo` | Consulta |
| 6 | `coop.sp_ConsultarMovimientos` | Consulta |
| 7 | `coop.sp_RegistrarSocio` | Gestion |
| 8 | `coop.sp_CrearCuenta` | Gestion |
| 9 | `coop.sp_ConsultarPrestamo` | Consulta |
| 10 | `coop.sp_ConsultarAuditoria` | Consulta |

En `sql/05_transactions.sql`:

| # | SP | Categoria |
|---:|---|---|
| 11 | `coop.sp_RegistrarDeposito` | Cuentas, transaccional |
| 12 | `coop.sp_RegistrarRetiro` | Cuentas, transaccional |
| 13 | `coop.sp_RegistrarTransferencia` | Cuentas, transaccional |
| 14 | `coop.sp_PagarCuota` | Prestamos, transaccional |
| 15 | `coop.sp_SolicitarPrestamo` | Prestamos, transaccional |
| 16 | `coop.sp_AprobarPrestamo` | Prestamos, transaccional |
| 17 | `coop.sp_RechazarPrestamo` | Prestamos, transaccional |
| 18 | `coop.sp_GenerarAmortizacion` | Prestamos, transaccional |

Los 8 SPs transaccionales usan `BEGIN TRY`, `SET XACT_ABORT ON`,
`BEGIN TRANSACTION`, `COMMIT TRANSACTION`, `BEGIN CATCH`, `ROLLBACK
TRANSACTION` cuando `@@TRANCOUNT > 0` y `THROW` para errores controlados.
Tambien registran auditoria y, cuando aplica, movimientos en `coop.Movimiento`.

### Pruebas de Revision 3

`sql/10_revision3_tests.sql` incluye pruebas para:

- Deposito.
- Retiro.
- Transferencia.
- Solicitud de prestamo.
- Aprobacion de prestamo.
- Generacion de amortizacion.
- Pago de cuota.
- Rechazo de prestamo usando una solicitud separada.

Ejemplo de ejecucion manual:

```sql
EXEC coop.sp_RegistrarDeposito
    @NumeroCuenta = N'CTA-10001',
    @Monto = 25.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba manual Revision 3';
```

Los permisos de `sql/06_security.sql` ya conceden ejecucion de los SPs
transaccionales a los roles internos correspondientes.

## Entregable 3 - API inicial en .NET 10

La API vigente para el tercer entregable esta en `api/CoopCore.Api` y usa
**.NET 10 + ASP.NET Core Web API**. Mantiene una arquitectura por capas:

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
