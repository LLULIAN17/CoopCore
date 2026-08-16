# CoopCore Centro de Operaciones

Aplicacion React para visualizar y operar los modulos de cartera, morosidad,
productos financieros y cobranza de CoopCore.

## Desarrollo local

```bash
npm install
npm run dev
```

Abra `http://localhost:3000`. La interfaz incluye datos de demostracion y puede
conectarse a `http://localhost:5000` mediante la opcion **Conectar API**. Para
usar datos reales se requiere un JWT emitido por `POST /api/auth/login`.

## Comandos

- `npm run dev`: servidor local.
- `npm run lint`: validacion estatica.
- `npm test`: build de produccion y prueba del HTML generado.
- `npm run build`: salida compatible con Sites/Cloudflare.

Las reglas de negocio y escrituras permanecen en SQL Server. Este cliente solo
consume los contratos HTTP expuestos por la API .NET.
