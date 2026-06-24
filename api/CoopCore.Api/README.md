# CoopCore.Api

API inicial de CoopCore en **.NET 10** con ASP.NET Core Web API.

## Objetivo

Exponer una capa HTTP delgada para el proyecto academico CoopCore. La API no
contiene logica financiera importante: valida la forma de las solicitudes,
ejecuta stored procedures en SQL Server y devuelve respuestas JSON.

## Arquitectura

```text
Controllers -> Interfaces -> Services -> Db
```

- `Controllers/`: reciben requests HTTP y devuelven responses.
- `Interfaces/`: contratos de servicios y ejecucion SQL.
- `Services/`: validacion minima y coordinacion de llamadas a SQL Server.
- `Db/`: conexion y ejecucion de stored procedures con ADO.NET.
- `Models/Requests`: modelos de entrada.
- `Models/Responses`: modelos de salida JSON.

## Configuracion

Copie el archivo de ejemplo y ajuste la cadena de conexion local:

```powershell
Copy-Item api\CoopCore.Api\appsettings.example.json api\CoopCore.Api\appsettings.Development.json
```

La cadena recomendada usa el login academico `coop_api_login`:

```json
{
  "ConnectionStrings": {
    "CoopCoreDb": "Server=localhost;Database=CoopCoreDB;User Id=coop_api_login;Password=Lab_Coop_API_2026!;TrustServerCertificate=True;Encrypt=False;"
  }
}
```

No suba `appsettings.Development.json` ni otros archivos locales con secretos.

## Compilar y ejecutar

```powershell
dotnet restore api\CoopCore.Api\CoopCore.Api.csproj
dotnet build api\CoopCore.Api\CoopCore.Api.csproj
dotnet run --project api\CoopCore.Api\CoopCore.Api.csproj --urls http://localhost:5000
```

Healthcheck:

```powershell
curl.exe http://localhost:5000/api/health
```

En desarrollo, el documento OpenAPI queda disponible en:

```text
http://localhost:5000/openapi/v1.json
```

## Endpoints y stored procedures

| Metodo | Ruta | Stored procedure |
|---|---|---|
| `POST` | `/api/auth/login` | `coop.sp_ValidarLogin` |
| `GET` | `/api/socios/{id}` | `coop.sp_ConsultarSocio` |
| `POST` | `/api/socios` | `coop.sp_RegistrarSocio` |
| `GET` | `/api/cuentas/{id}/saldo` | `coop.sp_ConsultarSaldo` |
| `GET` | `/api/cuentas/{id}/movimientos` | `coop.sp_ConsultarMovimientos` |
| `GET` | `/api/prestamos/{id}` | `coop.sp_ConsultarPrestamo` |

## Pruebas con curl

Login:

```powershell
curl.exe -X POST http://localhost:5000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"usuario":"mlrojas","password":"Lab_Cajero_001"}'
```

Consultar socio:

```powershell
curl.exe http://localhost:5000/api/socios/SO-1001
```

Registrar socio:

```powershell
curl.exe -X POST http://localhost:5000/api/socios `
  -H "Content-Type: application/json" `
  -d '{"cedula":"SO-2001","nombre":"Laura","apellido":"Vargas","correo":"laura.vargas@correo.lab","telefono":"8888-2001","direccion":"San Jose","cedulaEmpleadoRegistro":"EM-0101"}'
```

Consultar saldo:

```powershell
curl.exe http://localhost:5000/api/cuentas/CTA-10001/saldo
```

Consultar movimientos:

```powershell
curl.exe "http://localhost:5000/api/cuentas/CTA-10001/movimientos?fechaInicio=2026-01-01&fechaFin=2026-12-31"
```

Consultar prestamo:

```powershell
curl.exe http://localhost:5000/api/prestamos/PR-20001
```

## Respuestas de error

Todos los errores controlados se devuelven en JSON con esta forma:

```json
{
  "ok": false,
  "mensaje": "Descripcion del error.",
  "datos": null
}
```

La API no expone passwords, hashes, salts ni stack traces en las respuestas.
