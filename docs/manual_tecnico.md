# Manual tecnico - CoopCore

## Arquitectura

CoopCore usa SQL Server como nucleo de datos y logica de negocio. Las tablas,
vistas, restricciones, permisos y stored procedures viven en `CoopCoreDB`,
dentro del esquema `coop`.

La API en `api/` es una capa delgada: valida la forma de las peticiones HTTP,
ejecuta stored procedures autorizados y transforma sus resultados a JSON. No
contiene consultas SQL directas ni reglas de negocio.

## Estado actual del proyecto (Entregable 2)

### Resumen ejecutivo

- El 100% de los SPs planificados esta creado: **17/17**.
- **9/17 SPs (~53%)** estan completamente implementados y probados.
- El minimo academico del 40% equivale a 7 SPs, por lo que la meta se supera
  por 2 SPs funcionales.
- Los otros 8 SPs tienen su contrato definitivo y validaciones basicas, pero
  su implementacion transaccional permanece pendiente.
- La API ejecuta 2 SPs reales con un login de minimo privilegio.
- La autenticacion incluye SHA2_256 con salt, auditoria y bloqueo temporal.
- `sql/07_security_tests.sql` contiene 11 casos de seguridad.

### Inventario funcional

Los 9 SPs funcionales estan en `sql/04_stored_procedures.sql`:

| SP | Responsabilidad |
|---|---|
| `coop.sp_ConsultarSaldo` | Consultar cuenta, socio, producto, saldo y ultimo movimiento. |
| `coop.sp_ConsultarMovimientos` | Consultar movimientos con rango opcional de fechas. |
| `coop.sp_RegistrarSocio` | Registrar un socio y auditar la operacion. |
| `coop.sp_CrearCuenta` | Crear una cuenta, deposito inicial y evento de auditoria. |
| `coop.sp_ConsultarPrestamo` | Consultar resumen de prestamo y cuotas. |
| `coop.sp_ValidarLogin` | Autenticar, contar fallos, bloquear y auditar logins. |
| `coop.sp_ObtenerUsuarioPorCredenciales` | Validar credenciales para uso interno. |
| `coop.sp_CambiarPassword` | Validar el password actual y generar salt/hash nuevos. |
| `coop.sp_ConsultarAuditoria` | Consultar auditoria con filtros opcionales. |

Los 8 SPs en version inicial estan en `sql/05_transactions.sql`:

`sp_RegistrarDeposito`, `sp_RegistrarRetiro`, `sp_RegistrarTransferencia`,
`sp_PagarCuota`, `sp_SolicitarPrestamo`, `sp_AprobarPrestamo`,
`sp_RechazarPrestamo` y `sp_GenerarAmortizacion`.

Cada uno valida sus parametros y ejecuta `THROW 52099` para marcar la logica
pendiente. Su `CATCH` agrega el nombre del SP y vuelve a lanzar el error como
52199. Por eso, al invocarlos desde SSMS, el numero visible es 52199.

## Cambios respecto al Entregable 1

1. `coop.Empleado` fue extendida con `NombreUsuario`, `PasswordHash`,
   `PasswordSalt`, `UltimoLogin`, `IntentosFallidos` y `BloqueadoHasta`.
2. Se agrego un indice unico filtrado para `NombreUsuario`, permitiendo
   empleados sin credenciales mientras se evita duplicar usuarios asignados.
3. El seed contiene salts y hashes literales pre-calculados para ser
   reproducible.
4. Se retiraron los `DENY SELECT` por tabla que impedian consultar vistas con
   los roles de cajero, oficial y auditor.
5. Se agregaron 3 SPs de autenticacion y `sp_ConsultarAuditoria`.
6. Se crearon los 8 contratos transaccionales en version inicial.
7. La suite de seguridad paso de 7 a 11 casos.
8. El permiso amplio `EXECUTE ON SCHEMA::coop` del API fue reemplazado por
   permisos por objeto sobre `sp_ValidarLogin` y `sp_ConsultarSaldo`.
9. Se implemento la API Node.js con endpoints de login y saldo.

## Autenticacion

### Algoritmo

Los hashes se calculan con:

```sql
HASHBYTES(
    'SHA2_256',
    PasswordSalt + CONVERT(VARBINARY(MAX), @Password)
)
```

`@Password` es `NVARCHAR`, por lo que su conversion binaria usa UTF-16 LE. El
orden es siempre salt seguido del password.

`sp_CambiarPassword` genera un nuevo salt de 32 bytes con
`CRYPT_GEN_RANDOM(32)`. En cambio, el seed usa valores literales para que
reejecutarlo restaure un estado conocido.

### Bloqueo

- Cada password incorrecto incrementa `IntentosFallidos`.
- Al quinto fallo se establece `BloqueadoHasta` por 15 minutos.
- Mientras el bloqueo esta vigente, el SP devuelve `Resultado = BLOQUEADO`.
- Un login exitoso restablece los intentos y elimina el bloqueo.
- Los intentos y resultados se registran en `coop.Auditoria`.

### Usuarios de laboratorio

| Usuario | Password | Rol de aplicacion |
|---|---|---|
| `mlrojas` | `Lab_Cajero_001` | `CAJERO_APP` |
| `cmena` | `Lab_Oficial_001` | `OFICIAL_CREDITO_APP` |
| `asolis` | `Lab_Auditor_001` | `AUDITOR_APP` |
| `lporras` | `Lab_Admin_001` | `ADMIN_APP` |

Estas credenciales son exclusivamente academicas. No deben reutilizarse en
ningun ambiente real.

## Modelo de seguridad

Los roles personalizados son:

- `rol_admin_coop`
- `rol_cajero_coop`
- `rol_oficial_credito_coop`
- `rol_auditor_coop`
- `rol_api_coop`

El API usa `coop_api_login` y su usuario de base `coop_api_user`. Tiene:

- `GRANT EXECUTE` sobre `coop.sp_ValidarLogin`.
- `GRANT EXECUTE` sobre `coop.sp_ConsultarSaldo`.
- `DENY SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre `SCHEMA::coop`.

No puede ejecutar `sp_CambiarPassword`, `sp_ConsultarAuditoria` ni los SPs
transaccionales en version inicial.

## Pruebas de seguridad

`sql/07_security_tests.sql` contiene 11 casos:

1. Cajero ejecuta `sp_ConsultarSaldo`.
2. Cajero no puede borrar datos directamente.
3. Auditor consulta las cuatro vistas.
4. Auditor no puede modificar datos.
5. Oficial ejecuta `sp_ConsultarPrestamo`.
6. API ejecuta `sp_ConsultarSaldo`.
7. API no puede consultar tablas directamente.
8. API ejecuta un login valido.
9. API ejecuta un login con password incorrecto.
10. Se verifica el ownership chaining de `sp_ValidarLogin`.
11. API no puede ejecutar `sp_CambiarPassword`.

Los casos exitosos imprimen `[OK]`; las operaciones prohibidas imprimen
`[DENEGADO ESPERADO]`. El caso 10 debe imprimir `[OK]`, no `[ALERTA]`.

## API

La API usa:

- Node.js 20 o superior.
- Express `4.19.2`.
- `mssql` `11.0.1`.
- `dotenv` `16.4.5`.

Endpoints:

| Metodo y ruta | Stored procedure | Respuestas principales |
|---|---|---|
| `GET /api/health` | Ninguno | 200 |
| `POST /api/auth/login` | `coop.sp_ValidarLogin` | 200, 400, 401, 423, 500 |
| `GET /api/cuentas/:numeroCuenta/saldo` | `coop.sp_ConsultarSaldo` | 200, 404, 500 |

El arranque comprueba primero la conexion a SQL Server y luego muestra:

```text
[db] Conectado a CoopCoreDB como coop_api_login
[server] CoopCore API escuchando en http://localhost:3000
```

Los detalles de instalacion y configuracion estan en `api/README.md`.

## Decisiones tecnicas relevantes

### SPs iniciales sin permisos

No se concede `GRANT EXECUTE` sobre codigo que solo informa que su
implementacion esta pendiente. Los permisos se agregaran junto con la logica
transaccional completa y sus pruebas.

### Eliminacion de `DENY SELECT` por tabla

Los roles de consulta solo reciben `GRANT SELECT` sobre vistas. Sin un `GRANT`
sobre las tablas base ya carecen de acceso directo; los `DENY` por objeto eran
redundantes e interferian con las vistas.

### Seed con hashes literales

El seed debe restaurar siempre las mismas credenciales de laboratorio. Si
generara salts aleatorios en cada ejecucion, las passwords documentadas
dejarian de coincidir con los hashes almacenados.

### API sin `sa`

Conectar la API como `sa` anularia el modelo de permisos. `coop_api_login`
aplica minimo privilegio y limita el impacto de una peticion maliciosa o de un
error en la capa HTTP.

### Permisos del API por objeto

No se usa `GRANT EXECUTE ON SCHEMA::coop`, porque concederia automaticamente
acceso a SPs futuros. Los permisos se asignan de forma explicita a los dos SPs
que necesita la API.

## Orden de ejecucion

1. `sql/00_create_database.sql`
2. `sql/01_schema_tables.sql`
3. `sql/02_seed_data.sql`
4. `sql/03_views.sql`
5. `sql/04_stored_procedures.sql`
6. `sql/05_transactions.sql`
7. `sql/06_security.sql`
8. `sql/07_security_tests.sql`

Los scripts 08 y 09 permanecen reservados para concurrencia y optimizacion.

## Pendiente para fases siguientes

- Implementar transacciones completas en los 8 SPs de
  `sql/05_transactions.sql`.
- Agregar pruebas de concurrencia en `sql/08_concurrency_tests.sql`.
- Definir y medir indices en `sql/09_indexes_optimization.sql`.
- Revisar y actualizar dependencias npm antes de un despliegue no academico.
