# Buscador de clientes morosos

La ampliacion incorpora una consulta de cartera vencida basada en cuotas cuyo
vencimiento ya paso y que aun tienen monto pendiente. No depende de que el
prestamo haya sido marcado manualmente como `MORA`: tambien detecta prestamos
`ACTIVO` con cuotas atrasadas.

## Componentes

- `sql/11_busqueda_clientes_morosos.sql`: indice de apoyo, stored procedure y
  permisos de minimo privilegio.
- `sql/12_busqueda_clientes_morosos_tests.sql`: casos reproducibles con la data
  semilla.
- `GET /api/clientes-morosos`: endpoint protegido para `ADMIN_APP` y
  `OFICIAL_CREDITO_APP`.
- `ClientesMorososController`, `MorosidadService` e `IMorosidadService`: nueva
  capa funcional de la API.

## Filtros

| Parametro | Predeterminado | Descripcion |
|---|---:|---|
| `termino` | vacio | Coincidencia parcial por cedula, nombre, correo, telefono o numero de prestamo. `%`, `_` y `\` se buscan como texto. |
| `fechaCorte` | fecha actual del servidor SQL | Fecha usada para calcular el atraso, en formato `yyyy-MM-dd`. |
| `diasMoraMinimos` | `1` | Antiguedad minima de la cuota vencida, entre 1 y 3650 dias. |
| `pagina` | `1` | Pagina solicitada. |
| `tamanoPagina` | `20` | Registros por pagina, entre 1 y 100. |

Ejemplo:

```http
GET /api/clientes-morosos?termino=SO-1002&fechaCorte=2026-02-01&diasMoraMinimos=30&pagina=1&tamanoPagina=20
Authorization: Bearer <TOKEN_OFICIAL_CREDITO>
```

Cada resultado representa un cliente y muestra los prestamos afectados,
cantidad de cuotas vencidas, primera y ultima fecha vencida, dias maximos de
mora, monto vencido y saldo de los prestamos morosos. El nivel de riesgo se
clasifica por la mayor antiguedad: `BAJO` (1-29), `MEDIO` (30-59), `ALTO`
(60-89) y `CRITICO` (90 dias o mas).

## Instalacion y prueba

```powershell
sqlcmd -S .\SQLEXPRESS -E -No -C -b -i sql\11_busqueda_clientes_morosos.sql
sqlcmd -S .\SQLEXPRESS -E -No -C -b -i sql\12_busqueda_clientes_morosos_tests.sql
dotnet build api\coopcore-api\coopcore-api\coopcore-api.csproj
```
