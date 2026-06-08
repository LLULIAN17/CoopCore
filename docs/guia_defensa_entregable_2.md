# Guia de defensa - Entregable 2

> Material de apoyo para la sustentacion oral. Se usa como referencia rapida.

## Mensaje principal

CoopCore tiene 17 stored procedures creados. Nueve estan completamente
funcionales y probados, lo que representa aproximadamente un 53% y supera el
minimo requerido del 40%. Los otros ocho tienen su contrato definitivo, pero
su logica transaccional se implementara en la siguiente fase del curso.

## Flujo de demostracion sugerido (15 minutos)

1. Abrir SSMS con una cuenta administrativa y mostrar `CoopCoreDB`, el esquema
   `coop`, sus 8 tablas, 4 vistas y 17 SPs.
2. Mostrar los cinco roles personalizados en
   `Security > Roles > Database Roles`.
3. Ejecutar `sql/07_security_tests.sql` y mostrar los 11 casos.
4. Resaltar el caso 10: `sp_ValidarLogin` escribe en `coop.Empleado` y
   `coop.Auditoria`, aunque `coop_api_user` tiene escritura directa denegada.
5. Mostrar en `sql/06_security.sql` que el API solo tiene `EXECUTE` sobre
   `sp_ValidarLogin` y `sp_ConsultarSaldo`.
6. Levantar la API:

   ```powershell
   cd api
   npm start
   ```

7. Mostrar el healthcheck y un login exitoso:

   ```powershell
   curl.exe http://localhost:3000/api/health

   curl.exe -X POST http://localhost:3000/api/auth/login `
     -H "Content-Type: application/json" `
     -d '{"nombreUsuario":"mlrojas","password":"Lab_Cajero_001"}'
   ```

8. Repetir el login con un password incorrecto y explicar los estados HTTP
   401 y 423.
9. Consultar el saldo:

   ```powershell
   curl.exe http://localhost:3000/api/cuentas/CTA-10001/saldo
   ```

10. Mostrar los eventos generados:

    ```sql
    SELECT TOP (10)
        AuditoriaID,
        FechaEvento,
        Accion,
        Descripcion,
        UsuarioBD
    FROM coop.Auditoria
    WHERE Accion = N'LOGIN'
    ORDER BY AuditoriaID DESC;
    ```

11. Cerrar mostrando el README y el manual tecnico, destacando la diferencia
    entre los 9 SPs funcionales y los 8 iniciales.

## Preguntas probables

**P: Cuantos SPs tienen y cuantos estan funcionales?**

R: Hay 17 creados. Nueve estan completamente funcionales y probados, cerca del
53%. Los otros ocho estan en version inicial con contrato y validaciones.

**P: Por que `sp_RegistrarDeposito` no esta terminado?**

R: Su implementacion correcta requiere transacciones, control de saldo,
registro inmutable de movimientos y `ROLLBACK`. Esos contenidos corresponden
a la Fase de Transacciones. El SP ya fija su interfaz y falla de forma
explicita para no simular una operacion exitosa.

**P: Por que el error visible es 52199 si el codigo usa 52099?**

R: El SP lanza 52099 para marcar el estado pendiente. Su bloque `CATCH` agrega
contexto al mensaje y lo vuelve a lanzar como 52199. Ese es el numero que ve el
cliente.

**P: Por que el seed tiene hashes literales?**

R: Para que sea reproducible. Reejecutar el seed restaura las mismas
credenciales de laboratorio. Un salt aleatorio en el seed cambiaria el hash en
cada ejecucion.

**P: Como se protege la password?**

R: Con SHA2_256 y un salt de 32 bytes concatenado antes del password. El
password es `NVARCHAR`, por lo que se convierte a UTF-16 LE. Despues de cinco
fallos, la cuenta queda bloqueada durante 15 minutos.

**P: Que pasa si alguien intenta consultar una tabla desde el API?**

R: SQL Server lo deniega. `rol_api_coop` tiene `DENY SELECT`, `INSERT`,
`UPDATE` y `DELETE` sobre el esquema `coop`.

**P: Como demuestra que la API ejecuta SPs y no consultas directas?**

R: Las rutas llaman `request.execute('coop.sp_ValidarLogin')` y
`request.execute('coop.sp_ConsultarSaldo')`. Ademas, los eventos de login se
registran con `UsuarioBD = coop_api_user`, y ese usuario no puede escribir
directamente en las tablas.

**P: Por que la API no se conecta como `sa`?**

R: Por minimo privilegio. `sa` podria ignorar todo el modelo de seguridad. El
login del API solo puede ejecutar dos procedimientos concretos.

**P: Por que no se concedio `EXECUTE` sobre todo el esquema?**

R: Porque cualquier SP agregado en el futuro quedaria expuesto
automaticamente. Los permisos por objeto mantienen una lista explicita de
operaciones autorizadas.

**P: Diferencia entre `coop.Rol` y `rol_cajero_coop`?**

R: `coop.Rol` es una tabla con roles de la aplicacion. `rol_cajero_coop` es un
principal de seguridad de SQL Server que agrupa permisos.

**P: Por que se eliminaron los `DENY SELECT` por tabla?**

R: Interferian con las vistas. Los roles no tienen `GRANT SELECT` sobre las
tablas, por lo que ya carecen de acceso directo. Mantener los `DENY` era
redundante y perjudicaba las consultas autorizadas.

**P: Que es ownership chaining en este proyecto?**

R: El SP y las tablas pertenecen al mismo propietario. SQL Server valida el
permiso de ejecutar el SP y permite que este acceda a los objetos de la misma
cadena sin conceder esos permisos directos al usuario. El caso 10 lo prueba.

## Evidencias a tener listas

- Arbol de SSMS con los 17 SPs.
- Roles personalizados de `CoopCoreDB`.
- Mensajes de los 11 casos de seguridad.
- Resultado del caso 10 con `[OK]`.
- Terminal de `npm start` mostrando la conexion como `coop_api_login`.
- Respuestas HTTP de health, login valido, login invalido, bloqueo y saldo.
- Auditoria con `UsuarioBD = coop_api_user`.
- README y manual tecnico actualizados.
- Historial de los commits del Entregable 2.

## Antes de la defensa

- Reejecutar el seed para restaurar passwords y contadores.
- Confirmar que `mlrojas` no este bloqueado.
- Verificar el puerto o instancia de SQL Server en `api/.env`.
- Ejecutar los 11 casos una vez y guardar la captura.
- Probar los comandos HTTP desde una segunda terminal.
- No mostrar passwords personales ni archivos `.env` reales.
