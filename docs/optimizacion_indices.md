# Optimizacion de indices - CoopCore

## Punto de partida

Antes de optimizar se preparo y ejecuto la linea base:

- Documento: `docs/analisis_planes_ejecucion.md`
- Script: `sql/09_execution_plan_baseline.sql`
- Evidencia local generada: `docs/evidencias/planes_linea_base_sqlcmd.txt`
- Evidencia posterior generada: `docs/evidencias/planes_post_optimizacion_sqlcmd.txt`
- Salida del script de indices: `docs/evidencias/indexes_optimization_sqlcmd.txt`

La base local se actualizo previamente con los scripts `00` a `06`; la salida
quedo en `docs/evidencias/db_prepare_sqlcmd.txt`.

El volumen del seed es pequeno, por lo que los tiempos y lecturas son bajos.
Aun asi, la linea base permite identificar accesos que creceran con el uso real
del sistema.

## Indices aplicados

Los indices se implementan en `sql/09_indexes_optimization.sql`.

| Indice | Tabla | Casos de linea base | Justificacion |
|---|---|---|---|
| `IX_Movimiento_Cuenta_Fecha` | `coop.Movimiento` | `sp_ConsultarSaldo`, `sp_ConsultarMovimientos` | Apoya busquedas por cuenta y fecha, ultimo movimiento y orden descendente. |
| `IX_Cuenta_Socio_Saldo` | `coop.Cuenta` | `sp_ConsultarSocio` | Apoya agregados por socio en `vw_SociosConsulta`. |
| `IX_Prestamo_Socio_Saldo` | `coop.Prestamo` | `sp_ConsultarSocio` | Apoya conteo y suma de saldos de prestamos por socio. |
| `IX_Cuota_Prestamo_Numero_Covering` | `coop.Cuota` | `sp_ConsultarPrestamo`, `sp_GenerarAmortizacion`, `sp_PagarCuota` | Cubre detalle de cuotas por prestamo y ayuda a agregados por `PrestamoID`. |
| `IX_Auditoria_Accion_Fecha` | `coop.Auditoria` | `sp_ConsultarAuditoria` | Apoya reportes por tipo de evento, especialmente auditoria de `LOGIN`, ordenados por fecha reciente. |

## Observaciones de la linea base

La ejecucion local de `sql/09_execution_plan_baseline.sql` finalizo
correctamente y confirmo:

- La base contenia 18 indices iniciales antes de optimizar, entre llaves
  primarias, `UNIQUE` e indice filtrado de `Empleado.NombreUsuario`.
- El seed local tenia pocas filas: 4 cuentas, 8 movimientos, 2 prestamos,
  8 cuotas y eventos de auditoria.
- `sp_ConsultarMovimientos` y `sp_ConsultarSaldo` acceden a
  `coop.Movimiento`.
- `sp_ConsultarSocio` usa agregados sobre `coop.Cuenta` y `coop.Prestamo`.
- `sp_ConsultarPrestamo` lee y agrega `coop.Cuota`.
- `sp_ConsultarAuditoria` consulta `coop.Auditoria`; el caso por `Accion =
  LOGIN` es el patron mas claro para indexar sin tocar el stored procedure.
- La seccion transaccional aplico `ROLLBACK`, por lo que las operaciones de
  medicion no quedaron permanentes.

## Comparacion cuantitativa antes y despues

Se ejecuto `sql/09_indexes_optimization.sql` contra `.\SQLEXPRESS` y se
crearon cinco indices. Luego se ejecuto nuevamente
`sql/09_execution_plan_baseline.sql`, guardando la salida como
`docs/evidencias/planes_post_optimizacion_sqlcmd.txt`.

Las lecturas logicas salen de las ejecuciones guardadas en
`planes_linea_base_sqlcmd.txt` y `planes_post_optimizacion_sqlcmd.txt`. El costo
estimado sale de planes XML generados por SQL Server con `SET SHOWPLAN_XML ON`.
Cada indice se elimina y recrea dentro de una transaccion independiente que se
revierte al finalizar, de modo que la medicion es repetible y no cambia la base.

| Indice | Lecturas antes | Lecturas despues | Delta lecturas | Costo antes | Costo despues | Delta costo | Cambio principal del plan |
|---|---:|---:|---:|---:|---:|---:|---|
| `IX_Movimiento_Cuenta_Fecha` | 2 | 2 | 0.00% | 0.01467280 | 0.00328680 | -77.60% | `Clustered Index Scan + Sort` pasa a `Index Seek`. |
| `IX_Cuenta_Socio_Saldo` | 2 | 2 | 0.00% | 0.00328942 | 0.00328420 | -0.16% | `Clustered Index Scan` pasa a `Index Seek`; el seed es de cuatro cuentas. |
| `IX_Prestamo_Socio_Saldo` | 2 | 2 | 0.00% | 0.00328942 | 0.00328420 | -0.16% | `Clustered Index Scan` pasa a `Index Seek`; el seed es de dos prestamos. |
| `IX_Cuota_Prestamo_Numero_Covering` | 12 | 4 | -66.67% | 0.00730559 | 0.00328640 | -55.02% | Se elimina el acceso adicional al indice clustered; queda un `Index Seek` cubierto. |
| `IX_Auditoria_Accion_Fecha` | 3 | 4 | +33.33% | 0.01474430 | 0.00330000 | -77.62% | `Clustered Index Scan + Sort` pasa a `Index Seek`; la lectura adicional es una pagina en un seed pequeno. |

La evidencia muestra por que no conviene defender solo milisegundos o lecturas
con un seed academico pequeno. En tres casos las lecturas permanecen casi
constantes, pero el plan cambia de escaneo a busqueda y elimina ordenamientos.
En `Cuota` coinciden la mejora estructural, la baja de lecturas y una reduccion
de costo estimado de 55.02%.

Archivos verificables:

- `docs/evidencias/planes/resumen_costos_estimados.csv`: cifras completas.
- `docs/evidencias/planes/resumen_costos_estimados.md`: tabla generada.
- `docs/evidencias/planes/*_antes.sqlplan` y `*_despues.sqlplan`: planes XML
  originales, abribles en SSMS.
- `docs/evidencias/planes/*_comparacion.png`: comparaciones visuales por indice.
- `scripts/capture-optimization-evidence.ps1`: captura reproducible.
- `scripts/render-optimization-plans.py`: renderizado reproducible.

La mejora no debe defenderse solo por milisegundos, porque el seed academico es
pequeno. La defensa debe enfocarse en que cada indice responde a un acceso
medido y a una tabla que crecera con el sistema.

## Como comparar antes vs despues

1. Ejecutar `sql/09_execution_plan_baseline.sql` y guardar la salida como
   evidencia previa.
2. Ejecutar `sql/09_indexes_optimization.sql`.
3. Ejecutar de nuevo `sql/09_execution_plan_baseline.sql`.
4. Comparar:
   - `logical reads` por tabla.
   - Operadores `Index Seek`, `Index Scan`, `Table Scan`.
   - `Sort`, `Hash Match` y agregados.
   - Tiempo CPU y tiempo transcurrido.
   - Si los nuevos indices aparecen en el plan real.

Con el seed pequeno, la mejora puede no verse como reduccion grande de tiempo.
La defensa debe explicar que el valor de los indices aparece cuando crecen
`Movimiento`, `Cuota`, `Auditoria`, `Cuenta` y `Prestamo`.

## Riesgos y limites

- Cada indice mejora lectura, pero agrega costo a operaciones `INSERT` y
  `UPDATE`.
- Por eso se limitaron los cambios a cinco indices relacionados con casos
  medidos.
- Los predicados opcionales de `sp_ConsultarAuditoria` pueden limitar el uso
  perfecto de un solo indice. Por eso se optimizo el patron medido por
  `Accion`; si crecen las consultas por entidad/empleado, una mejora futura
  seria un indice separado para ese patron o busquedas dinamicas controladas.
- No se cambiaron stored procedures en esta fase para mantener el alcance
  pequeno y defendible.

## Evidencia disponible para entrega

La carpeta `docs/evidencias/planes/` contiene diez planes XML originales, cinco
comparaciones visuales y un resumen general. Las visualizaciones no simulan la
interfaz de SSMS: resumen datos extraidos de los `.sqlplan`, que son la fuente
primaria y pueden abrirse en SSMS para inspeccionar el arbol completo.
