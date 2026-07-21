# Diagnostico inicial - Revision 3

## Objetivo de la revision

La Revision 3 solicita que el proyecto CoopCore demuestre al menos el 80% de
stored procedures completos y que las transacciones explicitas esten
implementadas en los procedimientos operativos de cuentas y prestamos.

## Estado revisado

- Rama local revisada: `main`.
- Estado inicial de Git: limpio antes de cambios.
- Base de datos objetivo: `CoopCoreDB`.
- Esquema principal: `coop`.
- API oficial: `api/coopcore-api` con .NET 10.
- Script principal de procedimientos base: `sql/04_stored_procedures.sql`.
- Script principal de transacciones: `sql/05_transactions.sql`.
- Script principal de seguridad: `sql/06_security.sql`.

## Inventario de stored procedures

Total detectado por `CREATE OR ALTER PROCEDURE`: **18 stored procedures**.

Calculo del 80%:

```text
18 * 0.80 = 14.4
Minimo requerido redondeado hacia arriba = 15 stored procedures completos
```

## Procedimientos completos al inicio

Los siguientes 10 procedimientos ya tienen logica funcional en
`sql/04_stored_procedures.sql`:

1. `coop.sp_ValidarLogin`
2. `coop.sp_ObtenerUsuarioPorCredenciales`
3. `coop.sp_CambiarPassword`
4. `coop.sp_ConsultarSocio`
5. `coop.sp_ConsultarSaldo`
6. `coop.sp_ConsultarMovimientos`
7. `coop.sp_RegistrarSocio`
8. `coop.sp_CrearCuenta`
9. `coop.sp_ConsultarPrestamo`
10. `coop.sp_ConsultarAuditoria`

## Procedimientos pendientes al inicio

Los siguientes 8 procedimientos existen en `sql/05_transactions.sql`, pero al
inicio de la Revision 3 solo validan parametros y lanzan `THROW 52099` con
mensaje de implementacion pendiente:

1. `coop.sp_RegistrarDeposito`
2. `coop.sp_RegistrarRetiro`
3. `coop.sp_RegistrarTransferencia`
4. `coop.sp_PagarCuota`
5. `coop.sp_SolicitarPrestamo`
6. `coop.sp_AprobarPrestamo`
7. `coop.sp_RechazarPrestamo`
8. `coop.sp_GenerarAmortizacion`

## Procedimientos que requieren transaccion explicita

Estos 8 procedimientos deben quedar con `BEGIN TRY`, `BEGIN TRANSACTION`,
`COMMIT TRANSACTION`, `BEGIN CATCH`, `ROLLBACK TRANSACTION` condicionado por
`@@TRANCOUNT > 0`, validaciones de negocio, auditoria y un `SELECT` final util:

1. `coop.sp_RegistrarDeposito`
2. `coop.sp_RegistrarRetiro`
3. `coop.sp_RegistrarTransferencia`
4. `coop.sp_PagarCuota`
5. `coop.sp_SolicitarPrestamo`
6. `coop.sp_AprobarPrestamo`
7. `coop.sp_RechazarPrestamo`
8. `coop.sp_GenerarAmortizacion`

## Brecha para cumplir el 80%

- Completos al inicio: **10/18**.
- Minimo para 80%: **15/18**.
- Brecha minima: **5 procedimientos adicionales**.
- Meta recomendada para la revision: completar los **8 procedimientos**
  transaccionales y dejar **18/18** completos.

## Observaciones de seguridad y repositorio

- `sql/06_security.sql` aun no concede permisos sobre los 8 procedimientos
  transaccionales porque estaban en version inicial.
- `.gitignore` ya excluia `bin/`, `obj/`, `node_modules/`, logs y archivos
  locales; se agrego `.vs/` para cubrir archivos temporales de Visual Studio.
- La API .NET 10 debe mantenerse como una sola implementacion oficial en
  `api/coopcore-api`; no se debe restaurar la API Node.js/Express del segundo
  avance como implementacion vigente.
