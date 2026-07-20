require('dotenv').config();
const fs = require('fs');
const path = require('path');
const mysql = require('mysql2/promise');

async function migrate() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
    multipleStatements: true,
  });

  const sql = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');

  console.log('Running schema.sql against', process.env.DB_NAME, 'at', process.env.DB_HOST);
  await connection.query(sql);

  // ترحيلات إضافية غير مُتلِفة: تضيف الأعمدة الجديدة على جدول doctors القائم مسبقاً
  // (CREATE TABLE IF NOT EXISTS لا يعدّل جدولاً موجوداً، لذا نتحقق يدوياً عبر information_schema).
  await ensureColumn(connection, 'doctors', 'work_start_hour', 'TINYINT NOT NULL DEFAULT 9');
  await ensureColumn(connection, 'doctors', 'work_end_hour', 'TINYINT NOT NULL DEFAULT 17');
  await ensureColumn(connection, 'doctors', 'slot_minutes', 'INT NOT NULL DEFAULT 30');

  console.log('Migration complete: tables created/updated and specialties seeded.');

  await connection.end();
}

// يضيف عموداً فقط إن لم يكن موجوداً (idempotent عبر أي عدد من عمليات التشغيل)
async function ensureColumn(connection, table, column, definition) {
  const [rows] = await connection.query(
    `SELECT COUNT(*) AS cnt FROM information_schema.COLUMNS
     WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND COLUMN_NAME = ?`,
    [process.env.DB_NAME, table, column]
  );
  if (rows[0].cnt === 0) {
    await connection.query(`ALTER TABLE \`${table}\` ADD COLUMN \`${column}\` ${definition}`);
    console.log(`  + added column ${table}.${column}`);
  } else {
    console.log(`  = column ${table}.${column} already present`);
  }
}

migrate().catch((err) => {
  console.error('Migration failed:', err.message);
  process.exit(1);
});
