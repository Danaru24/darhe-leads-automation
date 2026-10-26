// Crea la base de datos y la tabla public.leads_calificados SOLO si no existen.
// Se ejecuta desde entrypoint.sh usando el driver `pg` que ya viene dentro de n8n
// (la imagen hardened de n8n no trae psql ni apk).
const fs = require('fs');
const { Client } = require('pg');

const cfg = {
  host: process.env.DB_POSTGRESDB_HOST || 'postgres',
  port: Number(process.env.DB_POSTGRESDB_PORT || 5432),
  user: process.env.DB_POSTGRESDB_USER,
  password: process.env.DB_POSTGRESDB_PASSWORD,
};
const dbName = process.env.DB_POSTGRESDB_DATABASE || 'darhe_crm';
const schemaFile = process.env.SCHEMA_FILE || '/sql/01_supabase_schema.sql';

async function withRetry(fn, tries = 15) {
  for (let i = 1; ; i++) {
    try { return await fn(); }
    catch (e) {
      if (i >= tries) throw e;
      console.log(`   Postgres no disponible (intento ${i}/${tries}): ${e.message}`);
      await new Promise(r => setTimeout(r, 2000));
    }
  }
}

(async () => {
  // 1) Base de datos
  await withRetry(async () => {
    const admin = new Client({ ...cfg, database: 'postgres' });
    await admin.connect();
    const { rowCount } = await admin.query('SELECT 1 FROM pg_database WHERE datname = $1', [dbName]);
    if (rowCount === 0) {
      await admin.query(`CREATE DATABASE "${dbName.replace(/"/g, '')}"`);
      console.log(`-> Base de datos "${dbName}" creada.`);
    } else {
      console.log(`-> Base de datos "${dbName}" ya existe.`);
    }
    await admin.end();
  });

  // 2) Tabla (el .sql usa CREATE TABLE / INDEX IF NOT EXISTS, es idempotente)
  const db = new Client({ ...cfg, database: dbName });
  await db.connect();
  const { rows } = await db.query("SELECT to_regclass('public.leads_calificados') AS t");
  if (rows[0].t) {
    console.log('-> Tabla public.leads_calificados ya existe. No se modifica.');
  } else {
    await db.query(fs.readFileSync(schemaFile, 'utf8'));
    console.log('-> Tabla public.leads_calificados creada desde', schemaFile);
  }
  await db.end();
})().catch(e => { console.error('!! Error inicializando Postgres:', e.message); process.exit(1); });
