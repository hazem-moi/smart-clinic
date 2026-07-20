require('dotenv').config();
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const DEMO_PASSWORD = '123456';

const demoUsers = [
  { full_name: 'د. سامر خليل', mail: 'samer.doctor@clinic.com', role: 'doctor', specialty_id: 1, fee: 15000 },
  { full_name: 'د. ليلى حسن', mail: 'layla.doctor@clinic.com', role: 'doctor', specialty_id: 2, fee: 25000 },
  { full_name: 'د. عمر فارس', mail: 'omar.doctor@clinic.com', role: 'doctor', specialty_id: 3, fee: 20000 },
  { full_name: 'د. رنا يوسف', mail: 'rana.doctor@clinic.com', role: 'doctor', specialty_id: 4, fee: 18000 },
  { full_name: 'محمد أحمد', mail: 'patient@clinic.com', role: 'patient' },
];

async function seed() {
  const connection = await mysql.createConnection({
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT) || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : undefined,
  });

  const passwordHash = await bcrypt.hash(DEMO_PASSWORD, 10);

  for (const u of demoUsers) {
    const [existing] = await connection.execute('SELECT id FROM users WHERE mail = ?', [u.mail]);
    let userId;
    if (existing.length > 0) {
      userId = existing[0].id;
      console.log('User already exists, skipping insert:', u.mail);
    } else {
      const [result] = await connection.execute(
        'INSERT INTO users (full_name, mail, password, role) VALUES (?, ?, ?, ?)',
        [u.full_name, u.mail, passwordHash, u.role]
      );
      userId = result.insertId;
      console.log('Created user:', u.mail, '(id', userId, ')');
    }

    if (u.role === 'doctor') {
      const [existingDoctor] = await connection.execute('SELECT id FROM doctors WHERE user_id = ?', [userId]);
      if (existingDoctor.length === 0) {
        await connection.execute(
          'INSERT INTO doctors (user_id, specialty_id, consultation_fee) VALUES (?, ?, ?)',
          [userId, u.specialty_id, u.fee]
        );
        console.log('  -> linked as doctor, specialty_id', u.specialty_id);
      }
    }
  }

  console.log('\nSeed complete. Demo password for all accounts:', DEMO_PASSWORD);
  await connection.end();
}

seed().catch((err) => {
  console.error('Seed failed:', err.message);
  process.exit(1);
});
