const express = require('express');
const { getPool, sql } = require('../db');

const router = express.Router();

// GET /api/cuentas/:numeroCuenta/saldo ejecuta coop.sp_ConsultarSaldo.
router.get('/:numeroCuenta/saldo', async (req, res) => {
  const numeroCuenta = String(req.params.numeroCuenta || '').trim();

  if (!numeroCuenta) {
    return res.status(400).json({
      ok: false,
      mensaje: 'numeroCuenta es obligatorio.',
    });
  }

  try {
    const pool = await getPool();
    const request = pool.request();

    request.input('NumeroCuenta', sql.NVarChar(30), numeroCuenta);

    const result = await request.execute('coop.sp_ConsultarSaldo');
    const row = result.recordset && result.recordset[0];

    if (!row) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Cuenta no encontrada.',
      });
    }

    return res.status(200).json({
      ok: true,
      cuenta: row,
    });
  } catch (err) {
    console.error('[cuentas/saldo] error:', err.message);

    if (err.number === 52050 || err.message.includes('no existe')) {
      return res.status(404).json({
        ok: false,
        mensaje: 'Cuenta no encontrada.',
      });
    }

    return res.status(500).json({
      ok: false,
      mensaje: 'Error al consultar saldo.',
      detalle: err.message,
    });
  }
});

module.exports = router;
