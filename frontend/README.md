# Frontend CoopCore

Centro de operaciones construido con React 19 y vinext. La interfaz cubre los
cuatro flujos de cartera: resumen ejecutivo, buscador de morosos, catalogo de
productos financieros y seguimiento de cobranza.

## Ejecutar

Requiere Node.js 22.13 o superior.

```powershell
cd frontend\app
npm install
npm run dev
```

Abra `http://localhost:3000`. La aplicacion inicia con datos de demostracion.
Para consultar SQL Server, ejecute la API en `http://localhost:5000`, obtenga
un JWT mediante `POST /api/auth/login` y use **Conectar API**.

La consulta de los cuatro modulos admite `ADMIN_APP`. Los oficiales de credito
pueden consultar cartera, morosidad y cobranza; crear o actualizar productos
requiere `ADMIN_APP`.

## Validar

```powershell
npm run lint
npm test
```

La aplicacion no replica reglas de negocio. Todas las operaciones persistentes
se ejecutan mediante la API y sus stored procedures.
