# Analisis de planes de ejecucion - Linea base antes de optimizar

## Requerimiento

El proximo avance solicita:

```text
Sistema completo funcionando. Analisis de planes de ejecucion documentado antes de optimizar.
```

Este documento registra la **linea base previa a cualquier optimizacion**.
Antes de crear indices, cambiar consultas o ajustar stored procedures, se debe
ejecutar `sql/09_execution_plan_baseline.sql` en SSMS y guardar las evidencias.

La comparacion final ya fue completada y esta documentada con cifras en
`docs/optimizacion_indices.md`. Los planes XML antes/despues estan en
`docs/evidencias/planes/` y se regeneran con
`scripts/capture-optimization-evidence.ps1`.

## Estado antes de optimizar

- `sql/09_indexes_optimization.sql` se mantiene sin indices nuevos.
- No se modifican consultas ni stored procedures en esta etapa.
- La base actual ya contiene llaves primarias, restricciones `UNIQUE` e indice
  filtrado `UQ_Empleado_NombreUsuario`.
- La medicion debe hacerse despues de ejecutar los scripts `00` a `06`.
- Para datos transaccionales, ejecutar antes `sql/10_revision3_tests.sql` ayuda
  a poblar movimientos, prestamos, cuotas y auditoria.

## Ejecucion local registrada

Se ejecuto la linea base con `sqlcmd` contra `.\SQLEXPRESS` despues de
actualizar la base local con los scripts `00` a `06`.

Evidencias generadas:

- `docs/evidencias/db_prepare_sqlcmd.txt`
- `docs/evidencias/planes_linea_base_sqlcmd.txt`
- `docs/evidencias/indexes_optimization_sqlcmd.txt`
- `docs/evidencias/planes_post_optimizacion_sqlcmd.txt`

Resultado:

- La linea base finalizo correctamente.
- La seccion transaccional aplico `ROLLBACK`.
- No se crearon indices durante la linea base.
- Debido al volumen pequeno del seed, las lecturas logicas fueron bajas, pero
  se identificaron tablas que creceran con el uso: `Movimiento`, `Cuota`,
  `Auditoria`, `Cuenta` y `Prestamo`.
- En la comparacion posterior se ajusto el indice de auditoria para priorizar
  el patron medido por `Accion = LOGIN`.

## Como capturar evidencia en SSMS

1. Abrir `sql/09_execution_plan_baseline.sql`.
2. Activar **Include Actual Execution Plan** con `Ctrl + M`.
3. Ejecutar el script completo o por secciones.
4. Revisar la pestana **Messages** para `SET STATISTICS IO` y
   `SET STATISTICS TIME`.
5. Guardar capturas del plan grafico y de mensajes.
6. No aplicar indices ni cambios de rendimiento hasta completar esta evidencia.

Metricas que se deben registrar por cada caso:

- Operadores principales del plan: `Index Seek`, `Index Scan`, `Table Scan`,
  `Nested Loops`, `Hash Match`, `Sort`, `Key Lookup`.
- Tablas que muestran mas `logical reads`.
- Si aparece `scan` sobre tablas que creceran mucho.
- Si aparecen `sort` o agregaciones costosas.
- Costo estimado relativo de la consulta dentro del lote.
- Tiempo CPU y tiempo transcurrido.

## Casos base de lectura

| Caso | Stored procedure | Tablas/vistas principales | Predicados importantes | Que observar |
|---|---|---|---|---|
| 1 | `coop.sp_ValidarLogin` | `Empleado`, `Rol`, `Auditoria` | `Empleado.NombreUsuario` | Debe usar el indice filtrado de usuario; revisar escritura en auditoria. |
| 2 | `coop.sp_ConsultarSocio` | `vw_SociosConsulta`, `Socio`, `Cuenta`, `Prestamo` | `Cedula` o `SocioID` | Revisar agregados por socio y si las subconsultas agrupan muchas filas. |
| 3 | `coop.sp_ConsultarSaldo` | `Cuenta`, `Socio`, `ProductoFinanciero`, `Movimiento` | `Cuenta.NumeroCuenta`, `Movimiento.CuentaID` | Revisar busqueda por numero de cuenta y calculo de ultimo movimiento. |
| 4 | `coop.sp_ConsultarMovimientos` | `vw_MovimientosAuditoria`, `Movimiento`, `Cuenta`, `Socio`, `Empleado` | `NumeroCuenta`, rango de fechas | Revisar orden por fecha y lecturas sobre movimientos. |
| 5 | `coop.sp_ConsultarPrestamo` | `Prestamo`, `vw_PrestamosResumen`, `Cuota`, `Socio`, `ProductoFinanciero` | `NumeroPrestamo`, `PrestamoID` | Revisar agregados de cuotas y lectura del detalle de cuotas. |
| 6 | `coop.sp_ConsultarAuditoria` | `Auditoria`, `Empleado` | fecha, entidad, accion, empleado | Revisar filtros opcionales y orden descendente por evento. |

## Casos base transaccionales

Estos procedimientos modifican datos. El script de linea base los ejecuta
dentro de una transaccion externa y hace `ROLLBACK` al final para evitar dejar
datos permanentes.

| Caso | Stored procedure | Tablas principales | Que observar |
|---|---|---|---|
| 7 | `coop.sp_RegistrarDeposito` | `Cuenta`, `Empleado`, `Movimiento`, `Auditoria` | Busqueda de cuenta, bloqueo `UPDLOCK/HOLDLOCK`, insercion de movimiento. |
| 8 | `coop.sp_RegistrarRetiro` | `Cuenta`, `Empleado`, `Movimiento`, `Auditoria` | Validacion de saldo y actualizacion de cuenta. |
| 9 | `coop.sp_RegistrarTransferencia` | `Cuenta`, `Empleado`, `Movimiento`, `Auditoria` | Lectura de dos cuentas y orden de bloqueos. |
| 10 | `coop.sp_SolicitarPrestamo` | `Socio`, `ProductoFinanciero`, `Empleado`, `Prestamo`, `Auditoria` | Generacion de numero unico y busquedas por cedula/codigo. |
| 11 | `coop.sp_AprobarPrestamo` | `Prestamo`, `Empleado`, `Auditoria` | Busqueda por numero de prestamo y actualizacion de estado. |
| 12 | `coop.sp_GenerarAmortizacion` | `Prestamo`, `Cuota`, `Auditoria` | Validacion de cuotas existentes e inserciones repetidas. |
| 13 | `coop.sp_PagarCuota` | `Prestamo`, `Cuota`, `Cuenta`, `Movimiento`, `Auditoria` | Busqueda de cuota por prestamo/numero y actualizaciones múltiples. |
| 14 | `coop.sp_RechazarPrestamo` | `Prestamo`, `Empleado`, `Auditoria` | Busqueda por numero de prestamo y cambio de estado. |

## Consultas con mayor probabilidad de optimizacion futura

Estas observaciones son hipotesis iniciales, no cambios aplicados:

- `sp_ConsultarMovimientos`: puede requerir indice sobre movimientos por cuenta
  y fecha si la tabla crece.
- `sp_ConsultarAuditoria`: puede requerir indice por fecha, accion, entidad o
  empleado si auditoria acumula muchos eventos.
- `vw_SociosConsulta`: sus agregados por `SocioID` pueden encarecerse con muchas
  cuentas y prestamos.
- `vw_PrestamosResumen`: sus agregados sobre cuotas pueden encarecerse con
  muchos prestamos y cuotas.
- Procedimientos transaccionales de cuenta usan `NumeroCuenta`; ya existe una
  restriccion unica, pero se debe validar el plan real.

## Evidencias sugeridas

Guardar capturas o planes con nombres como:

```text
planes_01_validar_login_pre.png
planes_02_consultar_socio_pre.png
planes_03_consultar_saldo_pre.png
planes_04_consultar_movimientos_pre.png
planes_05_consultar_prestamo_pre.png
planes_06_consultar_auditoria_pre.png
planes_07_transacciones_cuentas_pre.png
planes_08_transacciones_prestamos_pre.png
planes_09_statistics_io_time_pre.png
```

Tambien se pueden guardar planes en formato `.sqlplan` desde SSMS para
compararlos despues de optimizar.

## Criterio para pasar a optimizacion

Solo se debe avanzar a `sql/09_indexes_optimization.sql` cuando:

- El script de linea base fue ejecutado.
- Las capturas o planes antes de optimizar fueron guardados.
- Se identificaron consultas con lecturas altas, `scan` costosos, `sort`
  evitables o agregados que creceran con el volumen de datos.
- Cada optimizacion propuesta puede relacionarse con un caso medido en esta
  linea base.
