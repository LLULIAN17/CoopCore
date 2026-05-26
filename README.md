# CoopCore

Proyecto academico para **BTI23 Bases de Datos II**.

CoopCore modela operaciones de una cooperativa de ahorro y credito usando
**SQL Server** como pieza central del sistema.

## Principio de arquitectura

La base de datos ejecuta la logica de negocio por medio de procedimientos
almacenados. Si existe API, su rol es delgado: solicitar operaciones a la BD.

## Estructura del repositorio

- `sql/`: scripts T-SQL por fases.
- `docs/`: documentacion tecnica y evidencias.
- `api/` (opcional): capa delgada de integracion.
- `frontend/` (opcional): capa cliente opcional.

## Orden sugerido de ejecucion de scripts

1. `sql/00_create_database.sql`
2. `sql/01_schema_tables.sql`
3. `sql/02_seed_data.sql`
4. `sql/03_views.sql`
5. `sql/04_stored_procedures.sql`
6. `sql/06_security.sql`
7. `sql/07_security_tests.sql`
8. `sql/05_transactions.sql` (fase posterior del curso)
9. `sql/08_concurrency_tests.sql` (fase posterior del curso)
10. `sql/09_indexes_optimization.sql` (fase posterior del curso)

## Nota sobre credenciales

Las contrasenas usadas en scripts de seguridad son solo de laboratorio.
No usar ni subir credenciales reales.

## Nota sobre capas opcionales

Las carpetas `api/` y `frontend/` son opcionales en esta etapa y no
reemplazan la logica en base de datos.
