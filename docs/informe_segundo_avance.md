# Informe del segundo avance - CoopCore

Proyecto: **CoopCore**

Curso: **BTI23 Bases de Datos II**

Fecha de cierre: **8 de junio de 2026**

## 1. Introduccion

Durante el segundo avance se amplio CoopCore desde una base de datos con sus
estructuras principales, vistas, seguridad inicial y cinco stored procedures,
hasta una solucion con autenticacion, mayor cobertura de procedimientos,
pruebas de permisos, una API minima y documentacion para la entrega y defensa.

El trabajo se realizo en siete etapas independientes. Cada etapa quedo
registrada en Git mediante un commit especifico, lo cual permite revisar la
evolucion del proyecto y relacionar cada cambio con su objetivo.

## 2. Objetivos del segundo avance

Los objetivos principales fueron:

1. Definir el inventario completo de stored procedures del proyecto.
2. Superar el minimo requerido del 40% de SPs funcionales.
3. Agregar autenticacion segura para los empleados.
4. Fortalecer el modelo de roles y permisos de SQL Server.
5. Comprobar el acceso autorizado y la denegacion de operaciones indebidas.
6. Implementar una API minima que ejecutara stored procedures reales.
7. Documentar el estado del proyecto y preparar la defensa y sus evidencias.

## 3. Resultado general

| Indicador | Resultado |
|---|---:|
| Tablas del esquema `coop` | 8 |
| Vistas | 4 |
| Stored procedures planificados | 17 |
| Stored procedures funcionales | 9 |
| Stored procedures en version inicial | 8 |
| Cobertura funcional | Aproximadamente 53% |
| Minimo academico requerido | 40% |
| Cobertura de creacion de SPs | 100% |
| Roles personalizados de SQL Server | 5 |
| Casos de seguridad preparados | 11 |
| Endpoints HTTP implementados | 3 |
| Commits correspondientes a los siete prompts | 7 |
| Evidencias definidas en el smoke test | 15 |

El resultado funcional de 9 SPs supera en dos procedimientos el minimo de 7
que correspondia al 40% del universo planificado.

## 4. Trabajo realizado

### 4.1 Plan e inventario de stored procedures

Primero se analizo el estado heredado del Entregable 1 y se creo
`docs/entregable_2_plan.md`.

En este documento se:

- Identificaron los cinco SPs que ya existian.
- Definieron cuatro SPs nuevos que debian quedar completamente funcionales.
- Definieron ocho SPs transaccionales que quedarian en version inicial.
- Calculo el porcentaje de cobertura esperado.
- Identificaron riesgos de permisos, ownership chaining y reproducibilidad de
  credenciales.
- Establecio el orden de trabajo de los siguientes prompts.

El universo final quedo definido en 17 procedimientos.

### 4.2 Extension del esquema para autenticacion

La tabla `coop.Empleado` se extendio con estas columnas:

- `NombreUsuario`
- `PasswordHash`
- `PasswordSalt`
- `UltimoLogin`
- `IntentosFallidos`
- `BloqueadoHasta`

Tambien se creo un indice unico filtrado para `NombreUsuario`. El filtro
permite conservar empleados sin usuario asignado, pero impide repetir un
nombre de usuario cuando este se encuentra configurado.

El script `sql/02_seed_data.sql` se actualizo con cuatro usuarios de
laboratorio y hashes reproducibles. Se utilizaron salts y hashes literales
precalculados para que reejecutar el seed siempre restaure las mismas
credenciales academicas.

Ademas, se corrigio un conflicto de permisos: algunos `DENY SELECT` aplicados
directamente sobre tablas interferian con las vistas autorizadas. Se retiraron
esos `DENY` de lectura donde correspondia, sin conceder acceso directo a las
tablas.

### 4.3 Autenticacion mediante stored procedures

Se agregaron tres procedimientos funcionales:

| Stored procedure | Funcion |
|---|---|
| `coop.sp_ValidarLogin` | Valida credenciales, registra auditoria y controla intentos fallidos. |
| `coop.sp_ObtenerUsuarioPorCredenciales` | Comprueba credenciales para operaciones internas. |
| `coop.sp_CambiarPassword` | Valida el password actual y genera un salt y hash nuevos. |

El hash se calcula en SQL Server mediante `SHA2_256`, concatenando el salt
antes del password:

```sql
HASHBYTES(
    'SHA2_256',
    PasswordSalt + CONVERT(VARBINARY(MAX), @Password)
)
```

La autenticacion incluye estas reglas:

- Un password incorrecto incrementa `IntentosFallidos`.
- Al quinto fallo se establece un bloqueo de 15 minutos.
- Las solicitudes realizadas durante el bloqueo reciben el resultado
  `BLOQUEADO`.
- Un login exitoso restablece los intentos fallidos.
- Los resultados de autenticacion se registran en `coop.Auditoria`.

Se agrego a la suite de seguridad una comprobacion especifica del ownership
chaining. Esta prueba valida que `coop_api_user` puede ejecutar
`sp_ValidarLogin`, y que el procedimiento puede actualizar `coop.Empleado` e
insertar en `coop.Auditoria`, aunque el usuario del API no posea permisos
directos de escritura sobre esas tablas.

### 4.4 Cobertura completa del inventario de SPs

Se agrego `coop.sp_ConsultarAuditoria` como noveno procedimiento completamente
funcional. Permite consultar eventos de auditoria mediante filtros opcionales.

Los nueve SPs funcionales son:

1. `coop.sp_ConsultarSaldo`
2. `coop.sp_ConsultarMovimientos`
3. `coop.sp_RegistrarSocio`
4. `coop.sp_CrearCuenta`
5. `coop.sp_ConsultarPrestamo`
6. `coop.sp_ValidarLogin`
7. `coop.sp_ObtenerUsuarioPorCredenciales`
8. `coop.sp_CambiarPassword`
9. `coop.sp_ConsultarAuditoria`

Tambien se crearon en `sql/05_transactions.sql` los contratos de ocho
procedimientos transaccionales:

1. `coop.sp_RegistrarDeposito`
2. `coop.sp_RegistrarRetiro`
3. `coop.sp_RegistrarTransferencia`
4. `coop.sp_PagarCuota`
5. `coop.sp_SolicitarPrestamo`
6. `coop.sp_AprobarPrestamo`
7. `coop.sp_RechazarPrestamo`
8. `coop.sp_GenerarAmortizacion`

Estos ocho SPs tienen nombres, parametros y validaciones basicas definidos,
pero no se presentan como funcionales. Cuando reciben parametros validos
lanzan internamente el error `52099` para indicar que la logica transaccional
esta pendiente. Su bloque `CATCH` agrega contexto y expone el error `52199`.

No se concedieron permisos de ejecucion sobre estos procedimientos iniciales.
Los permisos deberan asignarse cuando se implementen las transacciones, el
control de saldos, el registro de movimientos y el manejo de `ROLLBACK`.

### 4.5 Fortalecimiento de la seguridad

El proyecto mantiene cinco roles personalizados:

- `rol_admin_coop`
- `rol_cajero_coop`
- `rol_oficial_credito_coop`
- `rol_auditor_coop`
- `rol_api_coop`

Para la API se reemplazo el permiso amplio de ejecucion sobre todo el esquema
por permisos especificos. `rol_api_coop` solamente puede ejecutar:

- `coop.sp_ValidarLogin`
- `coop.sp_ConsultarSaldo`

El mismo rol tiene denegadas las operaciones directas `SELECT`, `INSERT`,
`UPDATE` y `DELETE` sobre el esquema `coop`. Tampoco puede ejecutar
`sp_CambiarPassword`, `sp_ConsultarAuditoria` ni los procedimientos
transaccionales pendientes.

Esta configuracion aplica el principio de minimo privilegio y evita que un SP
agregado en el futuro quede expuesto automaticamente al API.

### 4.6 Ampliacion de las pruebas de seguridad

`sql/07_security_tests.sql` paso de 7 a 11 casos:

1. El cajero puede ejecutar `sp_ConsultarSaldo`.
2. El cajero no puede borrar datos directamente.
3. El auditor puede consultar las cuatro vistas.
4. El auditor no puede modificar datos.
5. El oficial de credito puede ejecutar `sp_ConsultarPrestamo`.
6. El API puede ejecutar `sp_ConsultarSaldo`.
7. El API no puede consultar tablas directamente.
8. El API puede ejecutar un login valido.
9. El API puede ejecutar un login con password incorrecto.
10. El ownership chaining permite que `sp_ValidarLogin` escriba de forma
    controlada.
11. El API no puede ejecutar `sp_CambiarPassword`.

Los casos autorizados deben mostrar `[OK]` y los accesos prohibidos deben
mostrar `[DENEGADO ESPERADO]`. El caso 10 es especialmente importante porque
demuestra que la escritura ocurre dentro del procedimiento autorizado, no por
acceso directo del usuario del API.

### 4.7 Implementacion de la API minima

Se creo una API en Node.js con:

- Node.js 20 o superior.
- Express `4.19.2`.
- `mssql` `11.0.1`.
- `dotenv` `16.4.5`.

La API se conecta a SQL Server como `coop_api_login`, nunca como `sa`. Sus
rutas no incluyen consultas SQL directas ni duplican la logica de negocio.
Cada operacion de datos llama al stored procedure correspondiente mediante
`request.execute(...)`.

| Metodo y ruta | Stored procedure | Funcion |
|---|---|---|
| `GET /api/health` | Ninguno | Comprueba que el proceso HTTP esta activo. |
| `POST /api/auth/login` | `coop.sp_ValidarLogin` | Valida las credenciales de un empleado. |
| `GET /api/cuentas/:numeroCuenta/saldo` | `coop.sp_ConsultarSaldo` | Devuelve los datos y saldo de una cuenta. |

La API transforma los resultados de SQL Server a respuestas HTTP claras:

- `200`: operacion exitosa.
- `400`: parametros incompletos.
- `401`: credenciales invalidas.
- `404`: cuenta inexistente.
- `423`: cuenta temporalmente bloqueada.
- `500`: error interno.

Se agrego `api/.env.example` como plantilla de configuracion y se actualizo
`.gitignore` para impedir que `api/.env` y otras configuraciones locales con
secretos sean versionadas.

### 4.8 Documentacion y preparacion de la defensa

Se actualizaron:

- `README.md`
- `docs/manual_tecnico.md`
- `api/README.md`

Tambien se crearon:

- `docs/guia_defensa_entregable_2.md`
- `docs/evidencias/README.md`
- `docs/evidencias/entregable_2_smoke_test.md`

La guia de defensa contiene un flujo sugerido de demostracion, preguntas
probables y respuestas tecnicas. El smoke test describe la validacion completa
en SQL Server, la API, la auditoria, el bloqueo de usuarios y el historial de
Git.

Se definieron 15 capturas con nombres estandarizados para organizar las
evidencias del avance.

## 5. Arquitectura resultante

La arquitectura conserva a SQL Server como nucleo del sistema:

```text
Cliente HTTP
    |
    v
API Node.js / Express
    |
    | request.execute(...)
    v
Stored procedures de CoopCoreDB
    |
    v
Tablas, vistas y auditoria del esquema coop
```

La separacion de responsabilidades es:

- SQL Server contiene los datos, permisos y reglas de negocio.
- Los stored procedures exponen operaciones controladas.
- La API valida la peticion HTTP y traduce el resultado a JSON.
- Los usuarios y roles de SQL Server limitan el acceso a cada operacion.

## 6. Archivos principales modificados o creados

| Area | Archivos |
|---|---|
| Planificacion | `docs/entregable_2_plan.md` |
| Esquema y seed | `sql/01_schema_tables.sql`, `sql/02_seed_data.sql` |
| Stored procedures | `sql/04_stored_procedures.sql`, `sql/05_transactions.sql` |
| Seguridad y pruebas | `sql/06_security.sql`, `sql/07_security_tests.sql` |
| API | `api/package.json`, `api/src/db.js`, `api/src/server.js`, `api/src/routes/auth.js`, `api/src/routes/cuentas.js` |
| Configuracion | `.gitignore`, `api/.env.example` |
| Documentacion | `README.md`, `api/README.md`, `docs/manual_tecnico.md`, `docs/guia_defensa_entregable_2.md` |
| Evidencias | `docs/evidencias/README.md`, `docs/evidencias/entregable_2_smoke_test.md` |

## 7. Historial de los siete prompts originales

| Paso | Commit | Descripcion |
|---:|---|---|
| 1 | `1ce3f40` | Plan e inventario de SPs del Entregable 2. |
| 2 | `9baac99` | Columnas de autenticacion, seed con hashes y ajuste de permisos de vistas. |
| 3 | `d9da3d9` | SPs de autenticacion y pruebas de ownership chaining. |
| 4 | `97e835b` | Nueve SPs funcionales y ocho en version inicial. |
| 5 | `71168ea` | API minima para login y consulta de saldo. |
| 6 | `43da60c` | README, manual tecnico y guia de defensa. |
| 7 | `51e3e72` | Smoke test y checklist de 15 evidencias. |

Todos estos commits fueron enviados a la rama `main` del repositorio de
GitHub.

## 8. Validaciones realizadas durante la implementacion

Durante el desarrollo se verifico de forma estatica que:

- Existen 17 nombres unicos de stored procedures.
- Los nueve SPs funcionales estan documentados.
- Los ocho SPs iniciales estan claramente identificados.
- La suite contiene 11 casos de seguridad numerados.
- La API llama a los SPs mediante `request.execute(...)`.
- El usuario del API solo recibe permisos sobre dos procedimientos.
- `api/.env` esta excluido por `.gitignore`.
- Los documentos Markdown tienen bloques de codigo balanceados.
- El smoke test enumera 15 capturas unicas, del `01` al `15`.
- La rama `main` quedo sincronizada con `origin/main` despues de cada prompt.

## 9. Estado actual y trabajo pendiente

La implementacion y documentacion planificadas para el segundo avance estan
completas. Sin embargo, antes de la entrega final el equipo debe ejecutar
manualmente el smoke test en su entorno de SQL Server y guardar las 15
capturas reales en:

```text
docs/evidencias/entregable_2/
```

Para fases posteriores quedan pendientes:

- Implementar la logica transaccional completa de los ocho SPs de
  `sql/05_transactions.sql`.
- Agregar pruebas de concurrencia en `sql/08_concurrency_tests.sql`.
- Analizar y crear indices en `sql/09_indexes_optimization.sql`.
- Revisar y actualizar las dependencias npm antes de un despliegue fuera del
  ambiente academico.

## 10. Conclusion

El segundo avance transformo CoopCore en una solucion mas completa y
demostrable. El proyecto ahora cuenta con autenticacion, bloqueo temporal,
auditoria, permisos de minimo privilegio, cobertura total del inventario de
stored procedures, una API conectada mediante un usuario restringido y una
suite ampliada de pruebas de seguridad.

La meta academica fue superada: se alcanzo aproximadamente un 53% de SPs
funcionales frente al 40% requerido, y los 17 procedimientos planificados ya
existen. La documentacion permite explicar con transparencia cuales
operaciones estan completas y cuales se implementaran en la fase
transaccional.

Con la ejecucion del smoke test y la incorporacion de las capturas reales, el
segundo avance queda preparado para su entrega y sustentacion.
