# CoopCore API - Entregable 3

La implementacion vigente de la API inicial del tercer entregable esta en
`api/CoopCore.Api` y usa **.NET 10 + ASP.NET Core Web API**.

La carpeta `api/src` corresponde al prototipo Node.js creado en una fase
anterior y no forma parte de esta implementacion solicitada por el profesor.

## Proyecto actual

- Ruta: `api/CoopCore.Api/`
- Framework: `.NET 10`
- Acceso a datos: ADO.NET con `Microsoft.Data.SqlClient`
- Arquitectura: `Controllers -> Interfaces -> Services -> Db`
- Documentacion de uso: `api/CoopCore.Api/README.md`

## Comandos rapidos

```powershell
dotnet restore api\CoopCore.Api\CoopCore.Api.csproj
dotnet build api\CoopCore.Api\CoopCore.Api.csproj
dotnet run --project api\CoopCore.Api\CoopCore.Api.csproj --urls http://localhost:5000
```

Antes de probar endpoints contra SQL Server, copie
`api/CoopCore.Api/appsettings.example.json` como
`api/CoopCore.Api/appsettings.Development.json` y ajuste la cadena de conexion
local. Ese archivo esta ignorado por Git.
