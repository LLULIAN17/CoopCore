# Comparacion reproducible de costos estimados

Fuente: planes XML estimados generados por SQL Server con `SET SHOWPLAN_XML ON`.
Cada indice se elimina y recrea dentro de una transaccion que se revierte al finalizar.

| Caso | Indice | Costo antes | Costo despues | Delta | Delta % | Indice elegido despues |
|---|---|---:|---:|---:|---:|---|
| movimientos | `IX_Movimiento_Cuenta_Fecha` | 0.0146728 | 0.0032868 | -0.0113860 | -77.60% | IX_Movimiento_Cuenta_Fecha |
| cuentas_por_socio | `IX_Cuenta_Socio_Saldo` | 0.00328942 | 0.0032842 | -0.00000522 | -0.16% | IX_Cuenta_Socio_Saldo |
| prestamos_por_socio | `IX_Prestamo_Socio_Saldo` | 0.00328942 | 0.0032842 | -0.00000522 | -0.16% | IX_Prestamo_Socio_Saldo |
| cuotas_por_prestamo | `IX_Cuota_Prestamo_Numero_Covering` | 0.00730559 | 0.0032864 | -0.00401919 | -55.02% | IX_Cuota_Prestamo_Numero_Covering |
| auditoria_por_accion | `IX_Auditoria_Accion_Fecha` | 0.0147443 | 0.0033 | -0.0114443 | -77.62% | IX_Auditoria_Accion_Fecha |

Los archivos `.sqlplan` son evidencia original y se pueden abrir directamente en SSMS.
