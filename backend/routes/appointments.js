const express = require('express');
const pool = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

// حجز موعد جديد (مريض)
router.post('/', requireAuth, requireRole('patient'), async (req, res) => {
  const { doctor_id, appointment_date } = req.body;

  if (!doctor_id || !appointment_date) {
    return res.status(400).json({ error: 'يجب اختيار الطبيب والتاريخ والوقت' });
  }

  // نتوقع توقيتاً محلياً بصيغة "YYYY-MM-DDTHH:mm(:ss)" ونخزّنه كما هو (نصاً محلياً)
  // دون تحويل منطقة زمنية، حتى تتطابق الأوقات مع منطق الخانات المتاحة.
  const m = /^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})/.exec(String(appointment_date));
  if (!m) {
    return res.status(400).json({ error: 'صيغة التاريخ غير صحيحة' });
  }
  const datePart = `${m[1]}-${m[2]}-${m[3]}`;
  const mysqlDate = `${datePart} ${m[4]}:${m[5]}:00`;

  const today = new Date().toISOString().slice(0, 10);
  if (datePart < today) {
    return res.status(400).json({ error: 'لا يمكن حجز موعد في تاريخ ماضٍ' });
  }

  try {
    const [doctorRows] = await pool.execute('SELECT id FROM doctors WHERE id = ?', [doctor_id]);
    if (doctorRows.length === 0) {
      return res.status(404).json({ error: 'الطبيب غير موجود' });
    }

    const [result] = await pool.execute(
      'INSERT INTO appointments (patient_id, doctor_id, appointment_date, status) VALUES (?, ?, ?, ?)',
      [req.user.id, doctor_id, mysqlDate, 'pending']
    );
    res.status(201).json({ id: result.insertId, message: 'تم حجز الموعد بنجاح' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'هذا الموعد محجوز مسبقاً لدى هذا الطبيب، يرجى اختيار وقت آخر' });
    }
    console.error(err);
    res.status(500).json({ error: 'تعذر حجز الموعد' });
  }
});

// الأوقات المحجوزة لطبيب في يوم معيّن (لتوليد الخانات المتاحة على العميل)
router.get('/booked', requireAuth, async (req, res) => {
  const doctorId = Number(req.query.doctor_id);
  const dateStr = req.query.date;
  if (!doctorId || !dateStr) {
    return res.status(400).json({ error: 'يجب تحديد الطبيب والتاريخ' });
  }

  try {
    const [rows] = await pool.query(
      `SELECT TIME_FORMAT(appointment_date, '%H:%i') AS t
       FROM appointments
       WHERE doctor_id = ? AND DATE(appointment_date) = ? AND status <> 'cancelled'`,
      [doctorId, dateStr]
    );
    res.json(rows.map((r) => r.t));
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر جلب الأوقات المحجوزة' });
  }
});

// مواعيد مريض معيّن (قادمة وسابقة)
router.get('/patient/:id', requireAuth, async (req, res) => {
  const patientId = Number(req.params.id);
  if (req.user.role !== 'patient' || req.user.id !== patientId) {
    return res.status(403).json({ error: 'لا تملك صلاحية عرض هذه المواعيد' });
  }

  try {
    const [rows] = await pool.query(
      `SELECT a.id, a.appointment_date, a.status, a.doctor_notes,
              u.full_name AS doctor_name, s.name AS specialty,
              rv.rating AS my_rating
       FROM appointments a
       JOIN doctors d ON d.id = a.doctor_id
       JOIN users u ON u.id = d.user_id
       JOIN specialties s ON s.id = d.specialty_id
       LEFT JOIN reviews rv ON rv.appointment_id = a.id
       WHERE a.patient_id = ?
       ORDER BY a.appointment_date DESC`,
      [patientId]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر جلب المواعيد' });
  }
});

// مواعيد طبيب معيّن (اليوم افتراضياً)
router.get('/doctor/:id', requireAuth, requireRole('doctor'), async (req, res) => {
  const doctorId = Number(req.params.id);

  try {
    const [ownRows] = await pool.execute('SELECT id FROM doctors WHERE id = ? AND user_id = ?', [doctorId, req.user.id]);
    if (ownRows.length === 0) {
      return res.status(403).json({ error: 'لا تملك صلاحية عرض هذه المواعيد' });
    }

    const onlyToday = req.query.date === 'today';
    const dateFilter = onlyToday ? 'AND DATE(a.appointment_date) = CURDATE()' : '';

    const [rows] = await pool.query(
      `SELECT a.id, a.appointment_date, a.status, a.doctor_notes,
              u.full_name AS patient_name
       FROM appointments a
       JOIN users u ON u.id = a.patient_id
       WHERE a.doctor_id = ? ${dateFilter}
       ORDER BY a.appointment_date ASC`,
      [doctorId]
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر جلب المواعيد' });
  }
});

// تحديث حالة الموعد (طبيب فقط)
router.patch('/:id/status', requireAuth, requireRole('doctor'), async (req, res) => {
  const { status } = req.body;
  const allowed = ['pending', 'confirmed', 'completed', 'cancelled'];
  if (!allowed.includes(status)) {
    return res.status(400).json({ error: 'حالة غير صحيحة' });
  }

  try {
    const [rows] = await pool.execute(
      `SELECT a.id FROM appointments a JOIN doctors d ON d.id = a.doctor_id
       WHERE a.id = ? AND d.user_id = ?`,
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(403).json({ error: 'لا تملك صلاحية تعديل هذا الموعد' });
    }

    await pool.execute('UPDATE appointments SET status = ? WHERE id = ?', [status, req.params.id]);
    res.json({ message: 'تم تحديث حالة الموعد' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر تحديث الحالة' });
  }
});

// كتابة الملاحظة الطبية / الوصفة (طبيب فقط)
router.patch('/:id/notes', requireAuth, requireRole('doctor'), async (req, res) => {
  const { doctor_notes } = req.body;
  if (!doctor_notes || !doctor_notes.trim()) {
    return res.status(400).json({ error: 'الرجاء كتابة ملاحظة قبل الحفظ' });
  }

  try {
    const [rows] = await pool.execute(
      `SELECT a.id FROM appointments a JOIN doctors d ON d.id = a.doctor_id
       WHERE a.id = ? AND d.user_id = ?`,
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(403).json({ error: 'لا تملك صلاحية تعديل هذا الموعد' });
    }

    await pool.execute(
      "UPDATE appointments SET doctor_notes = ?, status = 'completed' WHERE id = ?",
      [doctor_notes.trim(), req.params.id]
    );
    res.json({ message: 'تم حفظ الملاحظة الطبية' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر حفظ الملاحظة' });
  }
});

// إلغاء الموعد (المريض صاحب الموعد فقط، وقبل إتمامه)
router.patch('/:id/cancel', requireAuth, requireRole('patient'), async (req, res) => {
  try {
    const [rows] = await pool.execute(
      'SELECT status FROM appointments WHERE id = ? AND patient_id = ?',
      [req.params.id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(403).json({ error: 'لا تملك صلاحية إلغاء هذا الموعد' });
    }
    if (rows[0].status === 'completed' || rows[0].status === 'cancelled') {
      return res.status(400).json({ error: 'لا يمكن إلغاء هذا الموعد' });
    }

    await pool.execute("UPDATE appointments SET status = 'cancelled' WHERE id = ?", [req.params.id]);
    res.json({ message: 'تم إلغاء الموعد' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر إلغاء الموعد' });
  }
});

module.exports = router;
