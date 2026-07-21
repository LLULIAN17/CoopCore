# Informe Revision 3 - CoopCore

## Requerimiento evaluado

La instruccion de la Revision 3 indica:

```text
El 80% de los stored procedures completos, transacciones explicitas implementadas.
```

## Resultado

CoopCore queda con **18/18 stored procedures completos** y con los **8
procedimientos transaccionales** implementados mediante transacciones
explicitas.

| Metrica | Resultado |
|---|---:|
| Total real de stored procedures | 18 |
| Minimo requerido para 80% | 15 |
| Stored procedures completos | 18 |
| Cumplimiento | 100% |
| Stored procedures con transacciones explicitas | 8 |

Calculo:

```text
18 * 0.80 = 14.4
Minimo requerido = 15
Resultado actual = 18
```

## Stored procedures completos

### `sql/04_stored_procedures.sql`

1. `coop.sp_ValidarLogin`
2. `coop.sp_ObtenerUsuarioPorCredenciales`
3. `coop.sp_CambiarPassword`
4. `coop.sp_ConsultarSocio`
5. `coop.sp_ConsultarSaldo`
6. `coop.sp_ConsultarMovimientos`
7. `coop.sp_RegistrarSocio`
8. `coop.sp_CrearCuenta`
9. `coop.sp_ConsultarPrestamo`
10. `coop.sp_ConsultarAuditoria`

### `sql/05_transactions.sql`

1. `coop.sp_RegistrarDeposito`
2. `coop.sp_RegistrarRetiro`
3. `coop.sp_RegistrarTransferencia`
4. `coop.sp_PagarCuota`
5. `coop.sp_SolicitarPrestamo`
6. `coop.sp_AprobarPrestamo`
7. `coop.sp_RechazarPrestamo`
8. `coop.sp_GenerarAmortizacion`

## Transacciones explicitas implementadas

Los 8 procedimientos de `sql/05_transactions.sql` incluyen:

- `SET XACT_ABORT ON`
- `BEGIN TRY`
- `BEGIN TRANSACTION`
- `COMMIT TRANSACTION`
- `BEGIN CATCH`
- `ROLLBACK TRANSACTION` cuando `@@TRANCOUNT > 0`
- `THROW` con mensajes claros
- Validaciones de parametros y registros relacionados
- Auditoria en `coop.Auditoria`
- Movimientos en `coop.Movimiento` cuando aplica
- `SELECT` final con datos utiles de confirmacion

## Reglas de negocio cubiertas

| SP | Reglas implementadas |
|---|---|
| `sp_RegistrarDeposito` | Valida cuenta activa, empleado activo y monto positivo; incrementa saldo; registra `DEPOSITO`. |
| `sp_RegistrarRetiro` | Valida cuenta activa, empleado activo, monto positivo y saldo suficiente; registra `RETIRO`. |
| `sp_RegistrarTransferencia` | Valida cuentas distintas y activas, empleado activo, saldo suficiente y registra salida/entrada con referencia comun. |
| `sp_PagarCuota` | Valida prestamo activo o en mora, cuota no pagada, cuenta activa, saldo suficiente y pago dentro del monto por pagar. |
| `sp_SolicitarPrestamo` | Valida socio activo, producto activo de tipo `PRESTAMO`, empleado activo, monto y plazo; genera numero unico. |
| `sp_AprobarPrestamo` | Valida solicitud existente en estado `SOLICITADO`; pasa a `ACTIVO` y asigna aprobador. |
| `sp_RechazarPrestamo` | Valida solicitud en estado `SOLICITADO`; registra motivo y usa estado `CANCELADO` porque el modelo no define `RECHAZADO`. |
| `sp_GenerarAmortizacion` | Valida prestamo `ACTIVO`, sin cuotas previas; genera cuotas y ajusta la ultima por redondeo. |

## Seguridad actualizada

`sql/06_security.sql` concede permisos por objeto:

- `rol_admin_coop`: los 8 SPs transaccionales.
- `rol_cajero_coop`: deposito, retiro, transferencia y pago de cuota.
- `rol_oficial_credito_coop`: solicitud, aprobacion, rechazo y amortizacion de prestamos.
- `rol_api_coop`: conserva solo los SPs que consume la API .NET actual.

No se agregaron permisos directos innecesarios sobre tablas para operaciones de
negocio.

## Pruebas SQL

Se agrego `sql/10_revision3_tests.sql`.

El archivo prueba:

1. Registrar deposito.
2. Registrar retiro.
3. Registrar transferencia.
4. Solicitar prestamo.
5. Aprobar prestamo.
6. Generar amortizacion.
7. Pagar cuota.
8. Rechazar prestamo usando una solicitud separada.

Tambien muestra evidencia final de movimientos y auditoria recientes.

## Orden recomendado de ejecucion

1. `sql/00_create_database.sql`
2. `sql/01_schema_tables.sql`
3. `sql/02_seed_data.sql`
4. `sql/03_views.sql`
5. `sql/04_stored_procedures.sql`
6. `sql/05_transactions.sql`
7. `sql/06_security.sql`
8. `sql/10_revision3_tests.sql`

Los scripts `07_security_tests.sql`, `08_concurrency_tests.sql` y
`09_indexes_optimization.sql` pueden ejecutarse como validaciones adicionales
segun el tema de la clase.

## Ejemplos de prueba manual

Deposito:

```sql
EXEC coop.sp_RegistrarDeposito
    @NumeroCuenta = N'CTA-10001',
    @Monto = 25.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba manual Revision 3';
```

Transferencia:

```sql
EXEC coop.sp_RegistrarTransferencia
    @NumeroCuentaOrigen = N'CTA-10003',
    @NumeroCuentaDestino = N'CTA-10004',
    @Monto = 15.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba manual Revision 3';
```

Solicitud de prestamo:

```sql
EXEC coop.sp_SolicitarPrestamo
    @CedulaSocio = N'SO-1001',
    @CodigoProducto = N'PRE_CONSUMO',
    @MontoSolicitado = 600.00,
    @PlazoMeses = 3,
    @CedulaEmpleado = N'EM-0102';
```

## API .NET 10

La prioridad de esta revision fue SQL y transacciones. En el estado actual del
repositorio, la API oficial queda consolidada en `api/coopcore-api` como unica
API .NET 10 y mantiene la arquitectura:

```text
Controllers -> Interfaces -> Services -> Db
```

Endpoints actuales que ejecutan stored procedures:

| Endpoint | Stored procedure |
|---|---|
| `POST /api/auth/login` | `coop.sp_ValidarLogin` |
| `GET /api/socios/{id}` | `coop.sp_ConsultarSocio` |
| `POST /api/socios` | `coop.sp_RegistrarSocio` |
| `GET /api/cuentas/{numeroCuenta}/saldo` | `coop.sp_ConsultarSaldo` |
| `GET /api/cuentas/{numeroCuenta}/movimientos` | `coop.sp_ConsultarMovimientos` |
| `GET /api/prestamos/{numeroPrestamo}` | `coop.sp_ConsultarPrestamo` |

La implementacion vigente ya no mantiene una API Node.js/Express paralela. Esa
version pertenece al historial del segundo avance y no debe presentarse como la
API actual.

## Archivos modificados para Revision 3

- `.gitignore`
- `docs/revision3_diagnostico.md`
- `sql/05_transactions.sql`
- `sql/06_security.sql`
- `sql/10_revision3_tests.sql`
- `README.md`
- `docs/manual_tecnico.md`
- `docs/informe_revision_3.md`

## Evidencia de cierre

- `sql/05_transactions.sql` ya no contiene `THROW 52099`.
- `sql/05_transactions.sql` ya no contiene `VERSION INICIAL`.
- Los 8 SPs transaccionales tienen `BEGIN TRANSACTION`, `COMMIT TRANSACTION` y
  `ROLLBACK TRANSACTION`.
- El calculo del 80% se cumple: se requieren 15 y hay 18 completos.
