# Smoke test - Entregable 2

Checklist paso a paso para validar que el Entregable 2 funciona de extremo a
extremo antes de la sustentacion oral.

Tiempo estimado: 30 minutos.

> Nota de vigencia: este smoke test pertenece al Entregable 2. La seccion de
> Node.js/Express queda como evidencia historica; la API oficial actual esta en
> `api/coopcore-api` y usa .NET 10.

## Pre-requisitos

- [ ] SQL Server esta en ejecucion y SSMS 22 esta instalado.
- [ ] Node.js 20 o superior esta instalado.
- [ ] El repositorio esta clonado y `git status` no muestra cambios
      inesperados.
- [ ] Los scripts del Entregable 1 y 2 se ejecutaron en este orden:
  1. `sql/00_create_database.sql`
  2. `sql/01_schema_tables.sql`
  3. `sql/02_seed_data.sql`
  4. `sql/03_views.sql`
  5. `sql/04_stored_procedures.sql`
  6. `sql/05_transactions.sql`
  7. `sql/06_security.sql`

## Seccion 1 - Verificacion en SSMS

### 1.1 Verificar SPs creados

- [ ] Expandir `CoopCoreDB > Programmability > Stored Procedures`.
- [ ] Confirmar 17 SPs en el esquema `coop`.
- [ ] Guardar la captura como
      `entregable_2_01_ssms_arbol_sps.png`.

### 1.2 Verificar roles

- [ ] Expandir `CoopCoreDB > Security > Roles > Database Roles`.
- [ ] Confirmar estos cinco roles:
      `rol_admin_coop`, `rol_cajero_coop`, `rol_oficial_credito_coop`,
      `rol_auditor_coop` y `rol_api_coop`.
- [ ] Guardar la captura como `entregable_2_02_ssms_roles.png`.

### 1.3 Verificar columnas de autenticacion

- [ ] Ejecutar:

  ```sql
  SELECT
      Cedula,
      NombreUsuario,
      DATALENGTH(PasswordHash) AS LenHash,
      DATALENGTH(PasswordSalt) AS LenSalt,
      IntentosFallidos
  FROM coop.Empleado;
  ```

- [ ] Confirmar cuatro filas con `LenHash = 32`, `LenSalt = 32` e
      `IntentosFallidos = 0`.
- [ ] Guardar la captura como `entregable_2_03_empleados_auth.png`.

### 1.4 Ejecutar la suite completa de seguridad

- [ ] Abrir `sql/07_security_tests.sql`.
- [ ] Ejecutar el script completo.
- [ ] Revisar la pestana **Messages**: los 11 casos deben terminar con `[OK]`
      o `[DENEGADO ESPERADO]`.
- [ ] Confirmar que no aparezca ningun `[ERROR]`.
- [ ] Confirmar especialmente que el **CASO 10** muestre `[OK]` para el
      ownership chaining. Si muestra `[ALERTA]`, detener el smoke test y
      corregir la configuracion antes de tomar la evidencia.
- [ ] Guardar la captura como
      `entregable_2_04_security_tests_messages.png`.

### 1.5 Probar `sp_ConsultarAuditoria`

- [ ] Ejecutar:

  ```sql
  EXEC coop.sp_ConsultarAuditoria @Accion = N'LOGIN';
  ```

- [ ] Confirmar que devuelve los registros generados por los casos 8 y 9.
- [ ] Guardar la captura como
      `entregable_2_05_consultar_auditoria.png`.

### 1.6 Probar un SP en version inicial

- [ ] Ejecutar:

  ```sql
  EXEC coop.sp_RegistrarDeposito
      @NumeroCuenta = N'CTA-10001',
      @Monto = 100,
      @CedulaEmpleado = N'EM-0101';
  ```

- [ ] Confirmar el error `52199` y el mensaje de implementacion pendiente.
- [ ] Registrar este resultado como esperado: demuestra que el contrato del SP
      existe, pero no simula una transaccion exitosa.
- [ ] Guardar la captura como
      `entregable_2_06_sp_version_inicial.png`.

## Seccion 2 - API

### 2.1 Instalar dependencias

- [ ] Desde la raiz del repositorio, ejecutar:

  ```powershell
  Set-Location api
  npm install
  ```

- [ ] Confirmar que la instalacion termina sin errores.
- [ ] Guardar la captura como `entregable_2_07_npm_install.png`.

### 2.2 Configurar el entorno

- [ ] Si `api/.env` no existe, ejecutar:

  ```powershell
  Copy-Item .env.example .env
  ```

- [ ] Ajustar la instancia o puerto de SQL Server cuando corresponda.
- [ ] Ejecutar `git status --short` y confirmar que `.env` no aparece porque
      esta incluido en `.gitignore`.
- [ ] No incluir el contenido de `.env` en ninguna captura.

### 2.3 Iniciar la API

- [ ] Ejecutar:

  ```powershell
  npm start
  ```

- [ ] Confirmar estos mensajes:

  ```text
  [db] Conectado a CoopCoreDB como coop_api_login
  [server] CoopCore API escuchando en http://localhost:3000
  ```

- [ ] Guardar la captura como `entregable_2_08_npm_start.png`.
- [ ] Mantener esta terminal abierta durante las siguientes pruebas.

### 2.4 Probar el healthcheck

- [ ] En otra terminal, ejecutar:

  ```powershell
  curl.exe -i http://localhost:3000/api/health
  ```

- [ ] Confirmar HTTP `200` y un JSON con `ok: true` y `ts`.

### 2.5 Probar un login exitoso

- [ ] Ejecutar:

  ```powershell
  curl.exe -i -X POST http://localhost:3000/api/auth/login `
    -H "Content-Type: application/json" `
    -d '{"nombreUsuario":"mlrojas","password":"Lab_Cajero_001"}'
  ```

- [ ] Confirmar HTTP `200`, `ok: true` y
      `empleado.rol: "CAJERO_APP"`.
- [ ] Guardar la captura como `entregable_2_09_curl_login_ok.png`.

### 2.6 Probar un login fallido

- [ ] Ejecutar:

  ```powershell
  curl.exe -i -X POST http://localhost:3000/api/auth/login `
    -H "Content-Type: application/json" `
    -d '{"nombreUsuario":"mlrojas","password":"incorrecto"}'
  ```

- [ ] Confirmar HTTP `401`, `ok: false` y el mensaje
      `Credenciales invalidas.`.
- [ ] Guardar la captura como `entregable_2_10_curl_login_fail.png`.

### 2.7 Verificar la auditoria del API desde SSMS

- [ ] Ejecutar:

  ```sql
  SELECT TOP (5) *
  FROM coop.Auditoria
  WHERE Accion = N'LOGIN'
  ORDER BY FechaEvento DESC;
  ```

- [ ] Confirmar registros con `UsuarioBD = N'coop_api_user'`. Esto demuestra
      que el API ejecuto el SP con su login restringido, no con `sa`.
- [ ] Guardar la captura como
      `entregable_2_11_auditoria_post_api.png`.

### 2.8 Consultar un saldo

- [ ] Ejecutar:

  ```powershell
  curl.exe -i http://localhost:3000/api/cuentas/CTA-10001/saldo
  ```

- [ ] Confirmar HTTP `200`, `ok: true` y los datos de la cuenta.
- [ ] Guardar la captura como `entregable_2_12_curl_saldo.png`.

### 2.9 Consultar una cuenta inexistente

- [ ] Ejecutar:

  ```powershell
  curl.exe -i http://localhost:3000/api/cuentas/NO-EXISTE/saldo
  ```

- [ ] Confirmar HTTP `404`, `ok: false` y el mensaje
      `Cuenta no encontrada.`.
- [ ] Guardar la captura como `entregable_2_13_curl_saldo_404.png`.

## Seccion 3 - Bloqueo por intentos fallidos

Esta seccion es opcional, pero se recomienda para la defensa.

### 3.1 Provocar el bloqueo

- [ ] Confirmar primero que `mlrojas` tiene `IntentosFallidos = 0` y
      `BloqueadoHasta IS NULL`.
- [ ] Ejecutar cinco veces el login del punto 2.6 con password incorrecto.
- [ ] Confirmar que el quinto fallo todavia devuelve HTTP `401`, pero deja la
      cuenta bloqueada durante 15 minutos.
- [ ] Ejecutar una sexta solicitud, incluso con el password correcto.
- [ ] Confirmar HTTP `423`, `ok: false`, el mensaje de cuenta bloqueada y
      `bloqueadoHasta`.
- [ ] Guardar la captura como `entregable_2_14_curl_bloqueado.png`.

### 3.2 Restaurar el usuario de laboratorio

- [ ] Ejecutar en SSMS:

  ```sql
  UPDATE coop.Empleado
  SET IntentosFallidos = 0,
      BloqueadoHasta = NULL
  WHERE NombreUsuario = N'mlrojas';
  ```

- [ ] Confirmar que se actualizo una fila.

## Seccion 4 - Historial de Git

### 4.1 Revisar los commits

- [ ] Desde la raiz del repositorio, ejecutar:

  ```powershell
  git log --oneline -10
  ```

- [ ] Confirmar al menos estos siete commits del Entregable 2:
  1. `docs: plan e inventario de stored procedures para Entregable 2`
  2. `feat(auth): columnas de autenticacion, seed con hashes literales...`
  3. `feat(auth): SPs de autenticacion con ownership chaining probado`
  4. `feat(sp): 100% de SPs planificados (9 funcionales + 8 en version inicial)`
  5. `feat(api): API minima con endpoints de login y consulta de saldo`
  6. `43da60c` - documentacion del estado de SPs y API.
  7. `docs: smoke test y checklist de evidencias para Entregable 2`
- [ ] Guardar la captura como `entregable_2_15_git_log.png`.

## Cierre

- [ ] Las 15 capturas estan en `docs/evidencias/entregable_2/`.
- [ ] Los nombres de las capturas coinciden con este checklist.
- [ ] Ninguna captura muestra secretos o credenciales personales.
- [ ] La API fue detenida al terminar las pruebas.
- [ ] El usuario `mlrojas` quedo desbloqueado.
- [ ] El equipo reviso las evidencias y esta listo para la sustentacion.
- [ ] La entrega final incluye la URL de GitHub, el historial de commits, la
      carpeta de evidencias y el informe del segundo avance.
