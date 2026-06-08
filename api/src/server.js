require('dotenv').config();
const express = require('express');

const { getPool } = require('./db');
const authRoutes = require('./routes/auth');
const cuentasRoutes = require('./routes/cuentas');

const app = express();

app.use(express.json());

app.get('/api/health', (req, res) => {
  res.status(200).json({ ok: true, ts: new Date().toISOString() });
});

app.use('/api/auth', authRoutes);
app.use('/api/cuentas', cuentasRoutes);

app.use((req, res) => {
  res.status(404).json({ ok: false, mensaje: 'Ruta no encontrada.' });
});

app.use((err, req, res, next) => {
  console.error('[server] error global:', err);
  res.status(500).json({ ok: false, mensaje: 'Error interno.' });
});

const port = parseInt(process.env.API_PORT || '3000', 10);

async function start() {
  try {
    await getPool();

    app.listen(port, () => {
      console.log(
        `[server] CoopCore API escuchando en http://localhost:${port}`
      );
    });
  } catch (err) {
    console.error('[server] No se pudo iniciar la API:', err.message);
    process.exitCode = 1;
  }
}

start();
