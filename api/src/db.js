const sql = require('mssql');
require('dotenv').config();

const instanceName = process.env.DB_INSTANCE;
const port = parseInt(process.env.DB_PORT || '1433', 10);

if (!instanceName && !Number.isInteger(port)) {
  throw new Error('DB_PORT debe ser un numero entero.');
}

const config = {
  server: process.env.DB_SERVER || 'localhost',
  database: process.env.DB_NAME || 'CoopCoreDB',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  options: {
    encrypt: process.env.DB_ENCRYPT !== 'false',
    trustServerCertificate: process.env.DB_TRUST_SERVER_CERT !== 'false',
    ...(instanceName ? { instanceName } : {}),
  },
  connectionTimeout: 10000,
  requestTimeout: 15000,
  pool: {
    max: 10,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

if (!instanceName) {
  config.port = port;
}

let poolPromise = null;

function getPool() {
  if (!poolPromise) {
    poolPromise = new sql.ConnectionPool(config)
      .connect()
      .then((pool) => {
        console.log(
          `[db] Conectado a ${config.database} como ${config.user}`
        );
        return pool;
      })
      .catch((err) => {
        console.error('[db] Error al conectar:', err.message);
        poolPromise = null;
        throw err;
      });
  }

  return poolPromise;
}

module.exports = { getPool, sql };
