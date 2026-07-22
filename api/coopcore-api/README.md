# CoopCore API

API oficial de CoopCore para el proyecto de Bases de Datos II.

## Estado

Esta es la unica API vigente del repositorio. Usa **.NET 10 + ASP.NET Core** y
ejecuta stored procedures reales de `CoopCoreDB` mediante
`Microsoft.Data.SqlClient`.

La API Node.js/Express creada durante el segundo avance queda solo como
antecedente historico. No se debe restaurar `api/src`, `package.json` ni una
segunda API paralela.

## Arquitectura

```text
Controllers -> Interfaces -> Services -> Db -> Stored procedures SQL Server
```

Los controllers reciben solicitudes HTTP. Los services validan datos minimos.
La capa `Db` abre la conexion y ejecuta stored procedures. La logica de negocio
permanece en SQL Server.

## Configuracion

Crear una configuracion local a partir de la plantilla:

```powershell
Copy-Item api\coopcore-api\coopcore-api\appsettings.example.json api\coopcore-api\coopcore-api\appsettings.Development.json
```

Ajustar `ConnectionStrings:CoopCoreDb` en
`api\coopcore-api\coopcore-api\appsettings.Development.json`.

La conexion debe usar el login academico restringido `coop_api_login`, no `sa`.
El archivo `appsettings.Development.json` no debe subirse a Git.

La seccion `JwtSettings` define emisor, audiencia, clave de firma y minutos de
vigencia del token. Para un ambiente real se debe reemplazar `SigningKey` por
una clave privada de al menos 32 bytes.

## Ejecutar

```powershell
dotnet restore api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet build api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet run --project api\coopcore-api\coopcore-api\coopcore-api.csproj --urls http://localhost:5000
```

## Swagger / OpenAPI

Con la API en ejecucion, la documentacion interactiva queda disponible en:

```text
http://localhost:5000/swagger
```

El contrato OpenAPI en JSON queda disponible en:

```text
http://localhost:5000/swagger/v1/swagger.json
```

Swagger incluye autenticacion Bearer. Primero ejecute `POST /api/auth/login`,
copie `datos.token`, presione **Authorize** y pegue:

```text
Bearer {token}
```

## Autenticacion y roles

`POST /api/auth/login` es publico. Si las credenciales son validas devuelve
los datos del empleado, su rol de aplicacion y un token JWT.

| Rol | Acceso principal |
|---|---|
| `ADMIN_APP` | Todos los modulos protegidos |
| `CAJERO_APP` | Socios, cuentas, depositos, retiros, transferencias y pago de cuotas |
| `OFICIAL_CREDITO_APP` | Consulta y gestion de prestamos |
| `AUDITOR_APP` | Consulta de auditoria |

Todos los roles autenticados pueden ejecutar `POST /api/auth/cambiar-password`.

## Endpoints

| Metodo y ruta | Stored procedure | Roles |
|---|---|---|
| `GET /api/health` | No usa base de datos | Publico |
| `POST /api/auth/login` | `coop.sp_ValidarLogin` | Publico |
| `POST /api/auth/cambiar-password` | `coop.sp_CambiarPassword` | Todos |
| `GET /api/socios/{id}` | `coop.sp_ConsultarSocio` | `ADMIN_APP`, `CAJERO_APP` |
| `POST /api/socios` | `coop.sp_RegistrarSocio` | `ADMIN_APP`, `CAJERO_APP` |
| `POST /api/cuentas` | `coop.sp_CrearCuenta` | `ADMIN_APP`, `CAJERO_APP` |
| `GET /api/cuentas/{numeroCuenta}/saldo` | `coop.sp_ConsultarSaldo` | `ADMIN_APP`, `CAJERO_APP` |
| `GET /api/cuentas/{numeroCuenta}/movimientos` | `coop.sp_ConsultarMovimientos` | `ADMIN_APP`, `CAJERO_APP` |
| `POST /api/cuentas/depositos` | `coop.sp_RegistrarDeposito` | `ADMIN_APP`, `CAJERO_APP` |
| `POST /api/cuentas/retiros` | `coop.sp_RegistrarRetiro` | `ADMIN_APP`, `CAJERO_APP` |
| `POST /api/cuentas/transferencias` | `coop.sp_RegistrarTransferencia` | `ADMIN_APP`, `CAJERO_APP` |
| `GET /api/prestamos/{numeroPrestamo}` | `coop.sp_ConsultarPrestamo` | `ADMIN_APP`, `OFICIAL_CREDITO_APP` |
| `POST /api/prestamos` | `coop.sp_SolicitarPrestamo` | `ADMIN_APP`, `OFICIAL_CREDITO_APP` |
| `POST /api/prestamos/{numeroPrestamo}/aprobar` | `coop.sp_AprobarPrestamo` | `ADMIN_APP`, `OFICIAL_CREDITO_APP` |
| `POST /api/prestamos/{numeroPrestamo}/rechazar` | `coop.sp_RechazarPrestamo` | `ADMIN_APP`, `OFICIAL_CREDITO_APP` |
| `POST /api/prestamos/{numeroPrestamo}/amortizacion` | `coop.sp_GenerarAmortizacion` | `ADMIN_APP`, `OFICIAL_CREDITO_APP` |
| `POST /api/prestamos/{numeroPrestamo}/cuotas/{numeroCuota}/pagos` | `coop.sp_PagarCuota` | `ADMIN_APP`, `CAJERO_APP` |
| `GET /api/auditoria` | `coop.sp_ConsultarAuditoria` | `ADMIN_APP`, `AUDITOR_APP` |

## Pruebas rapidas

```powershell
curl.exe http://localhost:5000/api/health

curl.exe -X POST http://localhost:5000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"usuario":"mlrojas","password":"Lab_Cajero_001"}'

curl.exe http://localhost:5000/api/cuentas/CTA-10001/saldo `
  -H "Authorization: Bearer <TOKEN>"
```

Tambien existe `api\coopcore-api\coopcore-api\coopcore-api.http` con una suite
de pruebas para clientes compatibles con archivos `.http`. La guia de ejecucion
esta en `docs\evidencias\api_http_tests.md`.
