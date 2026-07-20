require('dotenv').config();
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');

const DEMO_PASSWORD = '123456';

const demoUsers = [
  // أطباء - أطفال (specialty 1)
  { full_name: 'د. سامر خليل', mail: 'samer.doctor@clinic.com', role: 'doctor', specialty_id: 1, fee: 15000 },
  { full_name: 'د. كريم عبدالله', mail: 'kareem.doctor@clinic.com', role: 'doctor', specialty_id: 1, fee: 16000 },
  // أطباء - قلبية (specialty 2)
  { full_name: 'د. ليلى حسن', mail: 'layla.doctor@clinic.com', role: 'doctor', specialty_id: 2, fee: 25000 },
  { full_name: 'د. نور الدين حمزة', mail: 'nouraldin.doctor@clinic.com', role: 'doctor', specialty_id: 2, fee: 27000 },
  // أطباء - أسنان (specialty 3)
  { full_name: 'د. عمر فارس', mail: 'omar.doctor@clinic.com', role: 'doctor', specialty_id: 3, fee: 20000 },
  { full_name: 'د. ياسمين قاسم', mail: 'yasmin.doctor@clinic.com', role: 'doctor', specialty_id: 3, fee: 19000 },
  // أطباء - جلدية (specialty 4)
  { full_name: 'د. رنا يوسف', mail: 'rana.doctor@clinic.com', role: 'doctor', specialty_id: 4, fee: 18000 },
  { full_name: 'د. طارق سلامة', mail: 'tarek.doctor@clinic.com', role: 'doctor', specialty_id: 4, fee: 17000 },
  // أطباء - عيون (specialty 5)
  { full_name: 'د. هبة مراد', mail: 'heba.doctor@clinic.com', role: 'doctor', specialty_id: 5, fee: 22000 },
  { full_name: 'د. زياد نجار', mail: 'ziad.doctor@clinic.com', role: 'doctor', specialty_id: 5, fee: 21000 },

  // مرضى
  { full_name: 'محمد أحمد', mail: 'patient@clinic.com', role: 'patient' },
  { full_name: 'سارة إبراهيم', mail: 'sara.patient@clinic.com', role: 'patient' },
  { full_name: 'أحمد الشامي', mail: 'ahmad.patient@clinic.com', role: 'patient' },
  { full_name: 'لينا خوري', mail: 'lina.patient@clinic.com', role: 'patient' },
  { full_name: 'يوسف حداد', mail: 'yousef.patient@clinic.com', role: 'patient' },
  { full_name: 'رهف عيسى', mail: 'rahaf.patient@clinic.com', role: 'patient' },
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
