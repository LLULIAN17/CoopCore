const express = require('express');
const { getPool, sql } = require('../db');

const router = express.Router();

// POST /api/auth/login ejecuta coop.sp_ValidarLogin.
router.post('/login', async (req, res) => {
  const { nombreUsuario, password } = req.body || {};

  if (
    typeof nombreUsuario !== 'string'
    || typeof password !== 'string'
    || !nombreUsuario.trim()
    || !password
  ) {
    return res.status(400).json({
      ok: false,
      mensaje: 'nombreUsuario y password son obligatorios.',
    });
  }

  try {
    const pool = await getPool();
    const request = pool.request();

    request.input(
      'NombreUsuario',
      sql.NVarChar(50),
      nombreUsuario.trim()
    );
    request.input('Password', sql.NVarChar(100), password);

    const result = await request.execute('coop.sp_ValidarLogin');
    const row = result.recordset && result.recordset[0];

    if (!row) {
      return res.status(500).json({
        ok: false,
        mensaje: 'El SP no devolvio un resultado.',
      });
    }

    if (row.Resultado === 'OK') {
      return res.status(200).json({
        ok: true,
        mensaje: row.Mensaje,
        empleado: {
          empleadoId: row.EmpleadoID,
          nombreUsuario: row.NombreUsuario,
          nombre: row.Nombre,
          apellido: row.Apellido,
          correo: row.Correo,
          rol: row.NombreRol,
        },
      });
    }

    if (row.Resultado === 'BLOQUEADO') {
      return res.status(423).json({
        ok: false,
        mensaje: row.Mensaje,
        bloqueadoHasta: row.BloqueadoHasta,
      });
    }

    return res.status(401).json({
      ok: false,
      mensaje: row.Mensaje,
    });
  } catch (err) {
    console.error('[auth/login] error:', err.message);
    return res.status(500).json({
      ok: false,
      mensaje: 'Error al procesar login.',
      detalle: err.message,
    });
  }
});

module.exports = router;
