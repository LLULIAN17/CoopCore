# Ampliacion funcional del 50%

Fecha de entrega: **15 de agosto de 2026**.

## Criterio medible

La linea base de CoopCore tenia seis modulos funcionales: autenticacion,
socios, cuentas, prestamos, morosidad y auditoria. La entrega agrega cartera,
productos financieros y cobranza. El resultado es de 6 a 9 modulos:

```text
(9 - 6) / 6 * 100 = 50%
```

El incremento se mide por capacidades completas y verificables, no por numero
de lineas o cambios cosmeticos.

## Modulos agregados

| Modulo | Capacidades | SQL | API |
|---|---|---|---|
| Cartera | Indicadores, distribucion de riesgo y vencimientos a 30 dias | `coop.sp_ConsultarDashboardCartera` | `GET /api/cartera/dashboard` |
| Productos financieros | Buscar, crear y actualizar el catalogo con auditoria | `coop.sp_BuscarProductosFinancieros`, `coop.sp_GuardarProductoFinanciero` | `GET`, `POST`, `PUT /api/productos-financieros` |
| Cobranza | Priorizar alertas y registrar contactos o compromisos | `coop.sp_ConsultarAlertasCobranza`, `coop.sp_RegistrarGestionCobranza` | `GET /api/cobranza/alertas`, `POST /api/cobranza/gestiones` |

El buscador de morosos incorporado en la misma entrega complementa estos
flujos mediante `GET /api/clientes-morosos`.

## Seguridad

- `ADMIN_APP` puede consultar todos los modulos y administrar productos.
- `OFICIAL_CREDITO_APP` puede consultar cartera y morosidad, y gestionar
  cobranza.
- `CAJERO_APP` puede consultar productos, sin modificarlos.
- Todas las rutas requieren JWT y la API se conecta con `coop_api_login`.
- Las escrituras usan transacciones, auditoria y validaciones en SQL Server.

## Instalacion

Despues de preparar los scripts `00` a `10`, ejecutar en orden:

```powershell
sqlcmd -S .\SQLEXPRESS -E -No -C -b -i "sql\11_busqueda_clientes_morosos.sql,sql\13_dashboard_cartera.sql,sql\14_productos_financieros.sql,sql\15_alertas_cobranza.sql"
```

Las pruebas no dejan productos ni gestiones temporales porque las operaciones
de escritura se ejecutan dentro de transacciones reversibles:

```powershell
sqlcmd -S .\SQLEXPRESS -E -No -C -b -i sql\12_busqueda_clientes_morosos_tests.sql
sqlcmd -S .\SQLEXPRESS -E -No -C -b -i sql\16_ampliacion_50_tests.sql
```

## Verificacion realizada

| Capa | Comando | Resultado esperado |
|---|---|---|
| SQL Server | `sqlcmd ... sql\16_ampliacion_50_tests.sql` | 5 pruebas completadas |
| API | `dotnet build ... -c Release` | 0 errores y 0 advertencias |
| Frontend | `npm test` en `frontend/app` | build de produccion y prueba HTML aprobados |

La interfaz puede operar con datos de demostracion o conectarse a los cuatro
contratos de cartera mediante una URL de API y un JWT.
