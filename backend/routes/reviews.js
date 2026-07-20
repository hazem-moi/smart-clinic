const express = require('express');
const pool = require('../db');
const { requireAuth, requireRole } = require('../middleware/auth');

const router = express.Router();

// تقييم الطبيب بعد إتمام الفحص (المريض صاحب الموعد، مرة واحدة لكل موعد)
router.post('/', requireAuth, requireRole('patient'), async (req, res) => {
  const { appointment_id, rating, comment } = req.body;
  const r = Number(rating);

  if (!appointment_id || !Number.isInteger(r) || r < 1 || r > 5) {
    return res.status(400).json({ error: 'يرجى اختيار تقييم من 1 إلى 5' });
  }

  try {
    const [rows] = await pool.execute(
      'SELECT doctor_id, status FROM appointments WHERE id = ? AND patient_id = ?',
      [appointment_id, req.user.id]
    );
    if (rows.length === 0) {
      return res.status(403).json({ error: 'لا تملك صلاحية تقييم هذا الموعد' });
    }
    if (rows[0].status !== 'completed') {
      return res.status(400).json({ error: 'يمكن التقييم بعد إتمام الفحص فقط' });
    }

    await pool.execute(
      'INSERT INTO reviews (appointment_id, patient_id, doctor_id, rating, comment) VALUES (?, ?, ?, ?, ?)',
      [appointment_id, req.user.id, rows[0].doctor_id, r, comment && comment.trim() ? comment.trim() : null]
    );
    res.status(201).json({ message: 'شكراً لتقييمك' });
  } catch (err) {
    if (err.code === 'ER_DUP_ENTRY') {
      return res.status(409).json({ error: 'لقد قيّمت هذا الموعد مسبقاً' });
    }
    console.error(err);
    res.status(500).json({ error: 'تعذر حفظ التقييم' });
  }
});

module.exports = router;
