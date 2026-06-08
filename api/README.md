# CoopCore API

API minima del proyecto CoopCore (Entregable 2, BTI23 Bases de Datos II).

## Principio de arquitectura

Esta API es una capa delgada. No contiene logica de negocio: recibe peticiones
HTTP, valida su forma, ejecuta stored procedures de SQL Server y devuelve sus
resultados. La logica del dominio permanece en `CoopCoreDB`.

## Seguridad

La API se conecta con `coop_api_login`, nunca con `sa`. Este usuario solo puede
ejecutar `coop.sp_ValidarLogin` y `coop.sp_ConsultarSaldo`; tiene denegado el
acceso directo de lectura y escritura al esquema `coop`.

Las credenciales incluidas son exclusivamente para el laboratorio academico.

## Requisitos

- Node.js 20 o superior.
- SQL Server con `CoopCoreDB` y los scripts `sql/00` a `sql/06` ejecutados.
- Autenticacion mixta habilitada para usar `coop_api_login`.

## Configuracion y arranque

```powershell
cd api
npm install
Copy-Item .env.example .env
npm start
```

La API queda disponible en `http://localhost:3000`.

Para una instancia nombrada puede configurarse `DB_INSTANCE=SQLEXPRESS` y
omitirse `DB_PORT`. Si SQL Server usa un puerto TCP dinamico, configure ese
valor en `DB_PORT`.

## Endpoints

### `GET /api/health`

Healthcheck del proceso.

```powershell
curl.exe http://localhost:3000/api/health
```

### `POST /api/auth/login`

Ejecuta `coop.sp_ValidarLogin`.

```powershell
curl.exe -X POST http://localhost:3000/api/auth/login `
  -H "Content-Type: application/json" `
  -d '{"nombreUsuario":"mlrojas","password":"Lab_Cajero_001"}'
```

Respuestas:

- `200`: login exitoso.
- `400`: faltan parametros.
- `401`: credenciales invalidas.
- `423`: cuenta bloqueada temporalmente.
- `500`: error interno.

### `GET /api/cuentas/:numeroCuenta/saldo`

Ejecuta `coop.sp_ConsultarSaldo`.

```powershell
curl.exe http://localhost:3000/api/cuentas/CTA-10001/saldo
```

Respuestas:

- `200`: cuenta y saldo retornados.
- `404`: cuenta inexistente.
- `500`: error interno.

## Usuarios de laboratorio

| Usuario | Password | Rol |
|---|---|---|
| `mlrojas` | `Lab_Cajero_001` | Cajero |
| `cmena` | `Lab_Oficial_001` | Oficial de credito |
| `asolis` | `Lab_Auditor_001` | Auditor |
| `lporras` | `Lab_Admin_001` | Administrador |

No usar estas credenciales en produccion.
