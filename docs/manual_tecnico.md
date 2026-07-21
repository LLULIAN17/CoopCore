# Manual tecnico - CoopCore

## Arquitectura

CoopCore usa SQL Server como nucleo de datos y logica de negocio. Las tablas,
vistas, restricciones, permisos y stored procedures viven en `CoopCoreDB`,
dentro del esquema `coop`.

La API oficial esta en `api/coopcore-api` y usa .NET 10. Su estructura sigue:

```text
Controllers -> Interfaces -> Services -> Db
```

Los controllers reciben solicitudes HTTP, los services validan datos minimos y
la capa `Db` ejecuta stored procedures con ADO.NET. La API no contiene reglas
financieras criticas ni consultas SQL directas en controllers.

## Estado de Revision 3

La Revision 3 solicita 80% de stored procedures completos y transacciones
explicitas implementadas.

| Metrica | Valor |
|---|---:|
| Stored procedures reales | 18 |
| Minimo requerido para 80% | 15 |
| Stored procedures completos | 18 |
| Cobertura actual | 100% |
| Stored procedures con transacciones explicitas | 8 |

Calculo:

```text
18 * 0.80 = 14.4
Minimo requerido redondeado hacia arriba = 15
Estado actual = 18/18 completos
```

## Inventario de stored procedures

### Procedimientos base

Estan en `sql/04_stored_procedures.sql`:

| SP | Responsabilidad |
|---|---|
| `coop.sp_ValidarLogin` | Autenticar empleados, auditar login y aplicar bloqueo temporal. |
| `coop.sp_ObtenerUsuarioPorCredenciales` | Validar credenciales para consultas internas. |
| `coop.sp_CambiarPassword` | Cambiar password con salt y hash nuevos. |
| `coop.sp_ConsultarSocio` | Consultar socio por cedula o identificador. |
| `coop.sp_ConsultarSaldo` | Consultar saldo y datos principales de una cuenta. |
| `coop.sp_ConsultarMovimientos` | Consultar movimientos por cuenta y rango opcional. |
| `coop.sp_RegistrarSocio` | Registrar socio y auditar la operacion. |
| `coop.sp_CrearCuenta` | Crear cuenta, deposito inicial si aplica y auditoria. |
| `coop.sp_ConsultarPrestamo` | Consultar resumen de prestamo y cuotas. |
| `coop.sp_ConsultarAuditoria` | Consultar eventos de auditoria con filtros. |

### Procedimientos transaccionales

Estan en `sql/05_transactions.sql` y todos usan `SET XACT_ABORT ON`, `BEGIN
TRY`, `BEGIN TRANSACTION`, `COMMIT TRANSACTION`, `BEGIN CATCH`, `ROLLBACK
TRANSACTION` condicionado por `@@TRANCOUNT > 0` y `THROW`.

| SP | Responsabilidad |
|---|---|
| `coop.sp_RegistrarDeposito` | Valida cuenta y empleado, aumenta saldo, registra movimiento `DEPOSITO` y auditoria. |
| `coop.sp_RegistrarRetiro` | Valida cuenta, empleado y saldo suficiente, disminuye saldo, registra `RETIRO` y auditoria. |
| `coop.sp_RegistrarTransferencia` | Valida dos cuentas activas, mueve saldo entre ellas, registra salida y entrada con referencia comun. |
| `coop.sp_PagarCuota` | Debita cuenta origen, actualiza cuota, prestamo, movimiento y auditoria. |
| `coop.sp_SolicitarPrestamo` | Valida socio, producto y empleado; genera numero unico y crea prestamo `SOLICITADO`. |
| `coop.sp_AprobarPrestamo` | Cambia prestamo `SOLICITADO` a `ACTIVO`, asigna aprobador y actualiza fecha de desembolso. |
| `coop.sp_RechazarPrestamo` | Cancela una solicitud con motivo obligatorio; usa estado `CANCELADO` porque el modelo no define `RECHAZADO`. |
| `coop.sp_GenerarAmortizacion` | Genera cuotas para un prestamo `ACTIVO` sin cuotas previas y ajusta la ultima cuota por redondeo. |

## Seguridad

Los roles de base de datos definidos en `sql/06_security.sql` son:

- `rol_admin_coop`
- `rol_cajero_coop`
- `rol_oficial_credito_coop`
- `rol_auditor_coop`
- `rol_api_coop`

Permisos principales:

| Rol | Permisos relevantes |
|---|---|
| `rol_admin_coop` | Ejecuta SPs base y los 8 SPs transaccionales. |
| `rol_cajero_coop` | Ejecuta consultas de cuentas, registro de socio/cuenta, deposito, retiro, transferencia y pago de cuotas. |
| `rol_oficial_credito_coop` | Ejecuta consulta, solicitud, aprobacion, rechazo y amortizacion de prestamos. |
| `rol_auditor_coop` | Consulta vistas y auditoria; tiene denegada escritura directa. |
| `rol_api_coop` | Ejecuta solo los SPs usados por la API .NET actual. |

No se otorgan permisos directos innecesarios sobre tablas para operaciones de
negocio. Las operaciones se canalizan por stored procedures.

## API .NET 10

La API vigente esta en `api/coopcore-api`. Esta es la unica API oficial del
repositorio; la API Node.js/Express del segundo avance queda solo como
antecedente historico en la documentacion de esa entrega.

Endpoints implementados:

| Metodo y ruta | Stored procedure |
|---|---|
| `POST /api/auth/login` | `coop.sp_ValidarLogin` |
| `GET /api/socios/{id}` | `coop.sp_ConsultarSocio` |
| `POST /api/socios` | `coop.sp_RegistrarSocio` |
| `GET /api/cuentas/{numeroCuenta}/saldo` | `coop.sp_ConsultarSaldo` |
| `GET /api/cuentas/{numeroCuenta}/movimientos` | `coop.sp_ConsultarMovimientos` |
| `GET /api/prestamos/{numeroPrestamo}` | `coop.sp_ConsultarPrestamo` |

La Revision 3 no agrego endpoints transaccionales. Por minimo privilegio,
`rol_api_coop` conserva permisos solo sobre los SPs que consumen esos endpoints.

### Ejecucion local

```powershell
Copy-Item api\coopcore-api\coopcore-api\appsettings.example.json api\coopcore-api\coopcore-api\appsettings.Development.json
dotnet restore api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet build api\coopcore-api\coopcore-api\coopcore-api.csproj
dotnet run --project api\coopcore-api\coopcore-api\coopcore-api.csproj --urls http://localhost:5000
```

Antes de usar endpoints de datos se debe configurar
`ConnectionStrings:CoopCoreDb` en `appsettings.Development.json` con el login
SQL `coop_api_login`.

## Orden de ejecucion de scripts

1. `sql/00_create_database.sql`
2. `sql/01_schema_tables.sql`
3. `sql/02_seed_data.sql`
4. `sql/03_views.sql`
5. `sql/04_stored_procedures.sql`
6. `sql/05_transactions.sql`
7. `sql/06_security.sql`
8. `sql/07_security_tests.sql`
9. `sql/08_concurrency_tests.sql`
10. `sql/09_execution_plan_baseline.sql`
11. `sql/09_indexes_optimization.sql`
12. `sql/10_revision3_tests.sql`

Para demostrar la Revision 3, ejecutar especialmente los scripts `00` a `06`
y luego `10_revision3_tests.sql`.

Para el avance de optimizacion, ejecutar primero
`sql/09_execution_plan_baseline.sql` con el plan real activado en SSMS y
documentar los resultados en `docs/analisis_planes_ejecucion.md`. Los indices o
ajustes deben aplicarse despues de esa evidencia base.

Las optimizaciones implementadas estan en `sql/09_indexes_optimization.sql` y
su justificacion se resume en `docs/optimizacion_indices.md`.

## Pruebas SQL de Revision 3

`sql/10_revision3_tests.sql` prueba:

1. Deposito.
2. Retiro.
3. Transferencia.
4. Solicitud de prestamo.
5. Aprobacion de prestamo.
6. Generacion de amortizacion.
7. Pago de cuota.
8. Rechazo de prestamo con una solicitud separada.

El script usa datos del seed (`EM-0101`, `EM-0102`, `SO-1001`, `SO-1004`,
`CTA-10001` a `CTA-10004` y `PRE_CONSUMO`). Tambien valida que esos datos
minimos existan antes de ejecutar operaciones.

Ejemplo manual:

```sql
EXEC coop.sp_RegistrarTransferencia
    @NumeroCuentaOrigen = N'CTA-10003',
    @NumeroCuentaDestino = N'CTA-10004',
    @Monto = 15.00,
    @CedulaEmpleado = N'EM-0101',
    @Observacion = N'Prueba manual Revision 3';
```

## Evidencia de cumplimiento

- `sql/05_transactions.sql` no contiene `THROW 52099`.
- `sql/05_transactions.sql` no contiene comentarios de `VERSION INICIAL`.
- Los 8 SPs transaccionales contienen `BEGIN TRANSACTION`, `COMMIT
  TRANSACTION` y `ROLLBACK TRANSACTION`.
- `sql/06_security.sql` concede `GRANT EXECUTE` de los SPs transaccionales a
  los roles internos correspondientes.
- `sql/10_revision3_tests.sql` incluye ejecuciones `EXEC` para todos los SPs
  transaccionales requeridos.
- `docs/informe_revision_3.md` resume el estado de entrega y la evidencia.

## Credenciales academicas

Usuarios de aplicacion del seed:

| Usuario | Password | Rol de aplicacion |
|---|---|---|
| `mlrojas` | `Lab_Cajero_001` | `CAJERO_APP` |
| `cmena` | `Lab_Oficial_001` | `OFICIAL_CREDITO_APP` |
| `asolis` | `Lab_Auditor_001` | `AUDITOR_APP` |
| `lporras` | `Lab_Admin_001` | `ADMIN_APP` |

Logins SQL de laboratorio:

| Login | Uso |
|---|---|
| `coop_admin_login` | Administracion interna. |
| `coop_cajero_login` | Operaciones de caja. |
| `coop_oficial_login` | Gestion de credito. |
| `coop_auditor_login` | Auditoria. |
| `coop_api_login` | API .NET. |

Estas credenciales son exclusivamente academicas y no deben reutilizarse en
ambientes reales.
