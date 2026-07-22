# Pruebas HTTP y Postman de la API CoopCore

## Objetivo

Validar que la API oficial `.NET 10` funciona con autenticacion JWT, roles de
aplicacion, validaciones HTTP y conexion a stored procedures reales.

Archivo principal de pruebas:

```text
api/coopcore-api/coopcore-api/coopcore-api.http
```

## Preparacion

1. Ejecutar los scripts SQL del proyecto hasta tener datos semilla,
   procedimientos almacenados, seguridad e indices.
2. Copiar `appsettings.example.json` a `appsettings.Development.json`.
3. Ajustar `ConnectionStrings:CoopCoreDb` con el login `coop_api_login`.
4. Revisar `JwtSettings:SigningKey` y usar una clave de al menos 32 bytes.
5. Ejecutar la API:

```powershell
dotnet run --project api\coopcore-api\coopcore-api\coopcore-api.csproj --urls http://localhost:5000
```

## Ejecucion con archivo .http

El archivo `.http` esta dividido en cuatro bloques:

| Bloque | Proposito |
|---|---|
| Healthcheck | Verificar que la API esta activa. |
| Logins | Obtener JWT para cajero, oficial, auditor y admin. |
| Consultas seguras | Probar endpoints `GET` con token valido. |
| Pruebas negativas | Confirmar respuestas `400`, `401` y `403`. |
| Operaciones con escritura | Crear socio/cuenta, movimientos, prestamo, amortizacion y pago. |

Antes de repetir las operaciones con escritura, cambiar:

```http
@runId = 20260721A
```

Ese valor evita choques por cedulas o numeros de cuenta ya creados.

## Ejecucion con Swagger

Con la API levantada:

```text
http://localhost:5000/swagger
```

Flujo recomendado:

1. Ejecutar `POST /api/auth/login`.
2. Copiar `datos.token`.
3. Presionar `Authorize`.
4. Pegar `Bearer {token}`.
5. Ejecutar endpoints protegidos.

## Ejecucion con Postman

Postman puede importar el contrato OpenAPI desde:

```text
http://localhost:5000/swagger/v1/swagger.json
```

Despues de importar:

1. Crear una variable `baseUrl` con `http://localhost:5000`.
2. Ejecutar `POST /api/auth/login`.
3. Guardar `datos.token` como variable `token`.
4. En Authorization, usar tipo `Bearer Token` con `{{token}}`.

## Codigos esperados

| Caso | Codigo esperado |
|---|---:|
| `GET /api/health` | 200 |
| Login valido | 200 |
| Consulta protegida con token y rol correcto | 200 |
| Crear socio/cuenta o solicitar prestamo | 201 |
| Body invalido o monto negativo | 400 |
| Endpoint protegido sin token | 401 |
| Token valido pero rol incorrecto | 403 |
| Recurso inexistente | 404 |
| Regla de negocio conflictiva, como saldo insuficiente | 409 |

## Credenciales usadas

| Usuario | Password | Rol |
|---|---|---|
| `mlrojas` | `Lab_Cajero_001` | `CAJERO_APP` |
| `cmena` | `Lab_Oficial_001` | `OFICIAL_CREDITO_APP` |
| `asolis` | `Lab_Auditor_001` | `AUDITOR_APP` |
| `lporras` | `Lab_Admin_001` | `ADMIN_APP` |

## Evidencia esperada

Al ejecutar la suite completa se debe observar:

- `datos.token` presente en cada login exitoso.
- Consultas de socio, cuenta, movimientos, prestamo y auditoria con `ok=true`.
- Respuesta `401` al consultar una ruta protegida sin token.
- Respuesta `403` al consultar auditoria con token de cajero.
- Respuesta `400` al enviar deposito con monto negativo.
- Operaciones de escritura con `ok=true` cuando se usa un `runId` nuevo.
