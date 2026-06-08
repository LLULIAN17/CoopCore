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
- `api/`: capa delgada Node.js que ejecuta stored procedures.
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

La API usa Node.js, Express y `mssql`. Se conecta como `coop_api_login`, no
como `sa`, y solo tiene permiso para ejecutar dos SPs:

- `POST /api/auth/login` -> `coop.sp_ValidarLogin`
- `GET /api/cuentas/:numeroCuenta/saldo` -> `coop.sp_ConsultarSaldo`

Tambien ofrece `GET /api/health` como healthcheck, sin acceso a datos.

La configuracion y los ejemplos de uso estan en `api/README.md`.
