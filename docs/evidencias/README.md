# Evidencias - CoopCore

Capturas y artefactos generados durante la implementacion y prueba del
proyecto.

## Estructura

- `entregable_2_smoke_test.md`: checklist paso a paso para validar el
  Entregable 2 de extremo a extremo.
- `sistema_completo_smoke_test.md`: checklist para validar base de datos,
  seguridad, transacciones y API .NET como sistema completo funcionando.
- `api_http_tests.md`: guia de pruebas HTTP, Swagger y Postman para validar
  JWT, roles, validaciones y endpoints completos de la API.
- `db_prepare_sqlcmd.txt`: salida local de preparacion de `CoopCoreDB` desde
  los scripts del repositorio.
- `planes_linea_base_sqlcmd.txt`: salida local de `STATISTICS IO/TIME` antes
  de optimizar indices.
- `indexes_optimization_sqlcmd.txt`: salida local de creacion idempotente de
  indices.
- `indexes_optimization_idempotent_sqlcmd.txt`: segunda ejecucion del script de
  indices para demostrar que no duplica objetos.
- `planes_post_optimizacion_sqlcmd.txt`: salida local de `STATISTICS IO/TIME`
  despues de aplicar indices.
- `planes/`: diez planes XML antes/despues, comparacion numerica en CSV y
  Markdown, y seis imagenes de evidencia. Los `.sqlplan` se abren en SSMS.
- `entregable_2/`: capturas tomadas manualmente durante el smoke test del
  Entregable 2.

La carpeta `entregable_2/` se completa cuando el equipo genere las capturas.
Este repositorio no incluye imagenes simuladas.

## Regenerar la evidencia de optimizacion

Desde la raiz del repositorio y con `CoopCoreDB` instalada:

```powershell
.\scripts\capture-optimization-evidence.ps1
python .\scripts\render-optimization-plans.py
```

La captura elimina y recrea cada indice dentro de una transaccion reversible;
no deja cambios en los datos ni en la definicion final de la base.

## Convencion de nombres

```text
<entregable>_<numero>_<descripcion-corta>.png
```

Ejemplos:

- `entregable_2_01_ssms_arbol_sps.png`
- `entregable_2_04_security_tests_messages.png`
- `entregable_2_08_npm_start.png`
- `entregable_2_09_curl_login_ok.png`
- `sistema_09_healthcheck.png`
- `sistema_10_login_api.png`

## Evidencias esperadas para el Entregable 2

El smoke test define 15 capturas, numeradas del `01` al `15`. Antes de la
entrega se debe comprobar que:

- Los nombres coincidan con el checklist.
- Las capturas sean legibles y no oculten mensajes relevantes.
- No aparezcan archivos `.env`, passwords personales ni otros secretos.
- Cada captura muestre el resultado final de la prueba, no solo el comando.
