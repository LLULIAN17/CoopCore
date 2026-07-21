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

## Ejecutar

```powershell
dotnet restore api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet build api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet run --project api\coopcore-api\coopcore-api\coopcore-api.csproj --urls http://localhost:5000
```

## Endpoints

| Metodo y ruta | Stored procedure |
|---|---|
| `GET /api/health` | No usa base de datos |
| `POST /api/auth/login` | `coop.sp_ValidarLogin` |
| `GET /api/socios/{id}` | `coop.sp_ConsultarSocio` |
| `POST /api/socios` | `coop.sp_RegistrarSocio` |
| `GET /api/cuentas/{numeroCuenta}/saldo` | `coop.sp_ConsultarSaldo` |
| `GET /api/cuentas/{numeroCuenta}/movimientos` | `coop.sp_ConsultarMovimientos` |
| `GET /api/prestamos/{numeroPrestamo}` | `coop.sp_ConsultarPrestamo` |

## Pruebas rapidas

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

Tambien existe `api\coopcore-api\coopcore-api\coopcore-api.http` con ejemplos
para clientes compatibles con archivos `.http`.
