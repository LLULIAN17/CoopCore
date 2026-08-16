/*
  Pruebas manuales del buscador de clientes morosos.
  Requiere ejecutar primero sql/11_busqueda_clientes_morosos.sql.
*/

USE CoopCoreDB;
GO

PRINT N'Prueba 1 - Listado a fecha fija con los datos semilla';
EXEC coop.sp_BuscarClientesMorosos
    @FechaCorte = '2026-02-01',
    @DiasMoraMinimos = 1,
    @Pagina = 1,
    @TamanoPagina = 20;
GO

PRINT N'Prueba 2 - Busqueda por cedula';
EXEC coop.sp_BuscarClientesMorosos
    @Termino = N'SO-1002',
    @FechaCorte = '2026-02-01';
GO

PRINT N'Prueba 3 - Busqueda por numero de prestamo';
EXEC coop.sp_BuscarClientesMorosos
    @Termino = N'PR-20001',
    @FechaCorte = '2026-02-01';
GO

PRINT N'Prueba 4 - Resultado vacio valido';
EXEC coop.sp_BuscarClientesMorosos
    @Termino = N'CLIENTE-INEXISTENTE',
    @FechaCorte = '2026-02-01';
GO

PRINT N'Prueba 5 - Los comodines se tratan como texto';
EXEC coop.sp_BuscarClientesMorosos
    @Termino = N'%',
    @FechaCorte = '2026-02-01';
GO
