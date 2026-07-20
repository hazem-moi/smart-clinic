const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');

const router = express.Router();

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function signToken(user) {
  return jwt.sign(
    { id: user.id, role: user.role, full_name: user.full_name },
    process.env.JWT_SECRET,
    { expiresIn: '7d' }
  );
}

router.post('/register', async (req, res) => {
  const { full_name, mail, password, role, specialty_id, consultation_fee } = req.body;

  if (!full_name || !mail || !password || !role) {
    return res.status(400).json({ error: 'جميع الحقول مطلوبة' });
  }
  if (!EMAIL_RE.test(mail)) {
    return res.status(400).json({ error: 'صيغة البريد الإلكتروني غير صحيحة' });
  }
  if (password.length < 6) {
    return res.status(400).json({ error: 'كلمة السر يجب أن تكون 6 أحرف على الأقل' });
  }
  if (role !== 'doctor' && role !== 'patient') {
    return res.status(400).json({ error: 'نوع الحساب غير صحيح' });
  }
  if (role === 'doctor' && !specialty_id) {
    return res.status(400).json({ error: 'يجب اختيار التخصص للطبيب' });
  }

  const conn = await pool.getConnection();
  try {
    const [existing] = await conn.execute('SELECT id FROM users WHERE mail = ?', [mail]);
    if (existing.length > 0) {
      return res.status(409).json({ error: 'هذا البريد الإلكتروني مسجل مسبقاً' });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    await conn.beginTransaction();
    const [result] = await conn.execute(
      'INSERT INTO users (full_name, mail, password, role) VALUES (?, ?, ?, ?)',
      [full_name, mail, passwordHash, role]
    );
    const userId = result.insertId;
    let doctorId = null;

    if (role === 'doctor') {
      const [doctorResult] = await conn.execute(
        'INSERT INTO doctors (user_id, specialty_id, consultation_fee) VALUES (?, ?, ?)',
        [userId, specialty_id, consultation_fee || 0]
      );
      doctorId = doctorResult.insertId;
    }
    await conn.commit();

    const user = { id: userId, full_name, role, doctor_id: doctorId };
    res.status(201).json({ token: signToken(user), user });
  } catch (err) {
    await conn.rollback();
    console.error(err);
    res.status(500).json({ error: 'تعذر إنشاء الحساب' });
  } finally {
    conn.release();
  }
});

router.post('/login', async (req, res) => {
  const { mail, password } = req.body;
  if (!mail || !password) {
    return res.status(400).json({ error: 'يرجى إدخال البريد الإلكتروني وكلمة السر' });
  }

  try {
    const [rows] = await pool.execute(
      'SELECT u.id, u.full_name, u.mail, u.password, u.role, d.id AS doctor_id FROM users u LEFT JOIN doctors d ON d.user_id = u.id WHERE u.mail = ?',
      [mail]
    );
    if (rows.length === 0) {
      return res.status(401).json({ error: 'البريد الإلكتروني أو كلمة السر غير صحيحة' });
    }

    const user = rows[0];
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(401).json({ error: 'البريد الإلكتروني أو كلمة السر غير صحيحة' });
    }

    const payload = { id: user.id, full_name: user.full_name, role: user.role };
    res.json({
      token: signToken(payload),
      user: {
        id: user.id,
        full_name: user.full_name,
        mail: user.mail,
        role: user.role,
        doctor_id: user.doctor_id || null,
      },
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر تسجيل الدخول' });
  }
});

module.exports = router;
