# Plan e inventario del Entregable 2

Proyecto: **CoopCore**

Curso: **BTI23 Bases de Datos II**

Fecha de revision: **8 de junio de 2026**

## 1. Estado actual del repositorio

El Entregable 1 contiene la base de datos `CoopCoreDB`, el esquema `coop`,
8 tablas de dominio, 4 vistas, 5 stored procedures funcionales, 5 roles
personalizados y 7 casos de prueba de seguridad.

Los archivos `sql/05_transactions.sql`, `sql/08_concurrency_tests.sql` y
`sql/09_indexes_optimization.sql` solo contienen su encabezado inicial. En este
entregable se modificara `sql/05_transactions.sql`; los scripts 08 y 09 se
mantendran sin cambios.

Los documentos mencionados en el prompt de reconocimiento
(`diagnostico_inicial.md`, `propuesta_actualizada.md`,
`planificacion_proyecto.md`, `control_acceso.md`,
`prompts_claude_code_codex.md` y `prompts_fase_control_acceso.md`) no existen en
la copia actual del repositorio. El unico documento previo dentro de `docs/` es
`manual_tecnico.md`.

## 2. Stored procedures existentes

Todos estan definidos en `sql/04_stored_procedures.sql` con
`CREATE OR ALTER PROCEDURE`.

| Stored procedure | Parametros | Proposito |
|---|---|---|
| `coop.sp_ConsultarSaldo` | `@NumeroCuenta NVARCHAR(30)` | Consulta los datos generales, el saldo y el ultimo movimiento de una cuenta. |
| `coop.sp_ConsultarMovimientos` | `@NumeroCuenta NVARCHAR(30)`, `@FechaInicio DATETIME2 = NULL`, `@FechaFin DATETIME2 = NULL` | Lista los movimientos de una cuenta, con filtros opcionales por rango de fechas. |
| `coop.sp_RegistrarSocio` | `@Cedula NVARCHAR(20)`, `@Nombre NVARCHAR(80)`, `@Apellido NVARCHAR(80)`, `@Correo NVARCHAR(120) = NULL`, `@Telefono NVARCHAR(30) = NULL`, `@Direccion NVARCHAR(250) = NULL`, `@CedulaEmpleadoRegistro NVARCHAR(20) = NULL` | Registra un socio activo y crea el evento correspondiente en auditoria. |
| `coop.sp_CrearCuenta` | `@NumeroCuenta NVARCHAR(30)`, `@CedulaSocio NVARCHAR(20)`, `@CodigoProducto NVARCHAR(20)`, `@CedulaEmpleado NVARCHAR(20)`, `@SaldoInicial DECIMAL(18,2) = 0` | Crea una cuenta de ahorro, registra el deposito inicial cuando corresponde y audita la operacion. |
| `coop.sp_ConsultarPrestamo` | `@NumeroPrestamo NVARCHAR(30)` | Consulta el resumen de un prestamo y devuelve el detalle de sus cuotas. |

## 3. Universo planificado de stored procedures

Estados usados:

- **EXISTENTE**: implementado antes del Entregable 2.
- **NUEVO FUNCIONAL**: se implementara y probara completamente en este
  entregable.
- **NUEVO VERSION INICIAL**: se creara con su contrato definitivo y
  validaciones basicas, pero su logica transaccional quedara pendiente.

| # | Stored procedure | Estado | Archivo previsto |
|---:|---|---|---|
| 1 | `coop.sp_ConsultarSaldo` | EXISTENTE | `sql/04_stored_procedures.sql` |
| 2 | `coop.sp_ConsultarMovimientos` | EXISTENTE | `sql/04_stored_procedures.sql` |
| 3 | `coop.sp_RegistrarSocio` | EXISTENTE | `sql/04_stored_procedures.sql` |
| 4 | `coop.sp_CrearCuenta` | EXISTENTE | `sql/04_stored_procedures.sql` |
| 5 | `coop.sp_ConsultarPrestamo` | EXISTENTE | `sql/04_stored_procedures.sql` |
| 6 | `coop.sp_ValidarLogin` | NUEVO FUNCIONAL | `sql/04_stored_procedures.sql` |
| 7 | `coop.sp_ObtenerUsuarioPorCredenciales` | NUEVO FUNCIONAL | `sql/04_stored_procedures.sql` |
| 8 | `coop.sp_CambiarPassword` | NUEVO FUNCIONAL | `sql/04_stored_procedures.sql` |
| 9 | `coop.sp_ConsultarAuditoria` | NUEVO FUNCIONAL | `sql/04_stored_procedures.sql` |
| 10 | `coop.sp_RegistrarDeposito` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 11 | `coop.sp_RegistrarRetiro` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 12 | `coop.sp_RegistrarTransferencia` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 13 | `coop.sp_PagarCuota` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 14 | `coop.sp_SolicitarPrestamo` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 15 | `coop.sp_AprobarPrestamo` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 16 | `coop.sp_RechazarPrestamo` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |
| 17 | `coop.sp_GenerarAmortizacion` | NUEVO VERSION INICIAL | `sql/05_transactions.sql` |

## 4. Calculo de cobertura

| Metrica | Calculo | Resultado |
|---|---:|---:|
| Total planificado | Universo definido | 17 SPs |
| Minimo requerido | `17 x 0.40 = 6.8`, redondeado hacia arriba | 7 SPs |
| Meta funcional del Entregable 2 | `9 / 17 x 100` | 9 SPs (aprox. 53%) |
| Cobertura de creacion esperada | `17 / 17 x 100` | 17 SPs (100%) |

La meta funcional supera el minimo requerido por 2 stored procedures. Los
otros 8 SPs quedaran creados en version inicial y no se reportaran como
funcionales.

## 5. Orden de fases

1. **Prompt 2 - Schema, seed y permisos.** Extender `coop.Empleado` con
   columnas de autenticacion, agregar credenciales reproducibles al seed y
   corregir los `DENY SELECT` que interfieren con las vistas.
2. **Prompt 3 - Autenticacion.** Crear los 3 SPs de autenticacion, asignar sus
   permisos y ampliar las pruebas de seguridad para validar el ownership
   chaining.
3. **Prompt 4 - Cobertura de SPs.** Crear `sp_ConsultarAuditoria` como noveno
   SP funcional y los 8 SPs transaccionales en version inicial.
4. **Prompt 5 - API minima.** Crear la capa Node.js, Express y `mssql` con
   endpoints de login y consulta de saldo que ejecuten SPs reales.
5. **Prompt 6 - Documentacion.** Actualizar el README y el manual tecnico con
   el estado completo del Entregable 2.
6. **Prompt 7 - Smoke test.** Crear el checklist integral y la estructura para
   capturar evidencias de SQL Server, API y Git.

## 6. Riesgos identificados

### 6.1 Conflicto entre `GRANT` de vistas y `DENY SELECT` de tablas base

`sql/06_security.sql` concede acceso a vistas para cajero, oficial de credito y
auditor, pero tambien aplica `DENY SELECT` explicito sobre las tablas usadas por
esas vistas. El `DENY` puede prevalecer durante la resolucion de permisos y
romper las consultas mediante vistas, a pesar del `GRANT SELECT` sobre ellas.

Mitigacion: eliminar solamente esos `DENY SELECT` por objeto. Los roles seguiran
sin acceso directo porque no recibiran `GRANT SELECT` sobre las tablas. Se deben
mantener las restricciones de escritura y las pruebas de acceso directo.

### 6.2 Ownership chaining de `coop.sp_ValidarLogin`

`sp_ValidarLogin` necesitara actualizar `coop.Empleado` e insertar en
`coop.Auditoria`, mientras que `rol_api_coop` tiene denegadas esas operaciones
directas sobre el esquema. Debe comprobarse expresamente que el SP puede
realizarlas mediante ownership chaining al ejecutarse como `coop_api_user`.

Mitigacion: agregar casos de prueba para login exitoso y fallido, y verificar
los cambios en ambas tablas. Si la cadena de propiedad no funciona, definir el
procedimiento con `WITH EXECUTE AS OWNER` antes de aprobar el cambio.

### 6.3 Reproducibilidad del seed de passwords

Generar salts con `CRYPT_GEN_RANDOM` durante cada ejecucion cambiaria las
credenciales y podria dejar los hashes sin correspondencia con las passwords
documentadas.

Mitigacion: usar salts y hashes hexadecimales literales, previamente calculados,
y mantener exactamente el algoritmo
`HASHBYTES('SHA2_256', PasswordSalt + CONVERT(VARBINARY(MAX), @Password))`
con entrada `NVARCHAR`.

### 6.4 Permiso `EXECUTE` demasiado amplio para el API

El estado actual concede `GRANT EXECUTE ON SCHEMA::coop TO rol_api_coop`. Esto
permite ejecutar cualquier SP presente o futuro del esquema y contradice el
objetivo de autorizar solo operaciones especificas, incluyendo la prueba que
espera denegar `sp_CambiarPassword`.

Mitigacion: durante la fase de autenticacion, reemplazar el permiso a nivel de
esquema por `GRANT EXECUTE` a nivel de objeto para los SPs autorizados al API,
como `sp_ValidarLogin` y `sp_ConsultarSaldo`, y verificar la denegacion de los
demas procedimientos.

## 7. Criterio de cierre del Entregable 2

El entregable se considerara listo cuando:

- Los 17 SPs existan y los 9 marcados como funcionales hayan sido probados.
- Los 8 SPs transaccionales indiquen claramente su estado inicial y no tengan
  permisos de ejecucion concedidos hasta completar su implementacion.
- Los 11 casos de seguridad produzcan resultados esperados.
- El API use `coop_api_login` y ejecute unicamente SPs autorizados.
- La documentacion distinga sin ambiguedad los SPs funcionales de los que
  tienen logica pendiente.
- El smoke test integral y sus evidencias esten completos antes de la defensa.
