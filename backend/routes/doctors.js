const express = require('express');
const pool = require('../db');

const router = express.Router();

router.get('/specialties', async (req, res) => {
  try {
    const [rows] = await pool.query('SELECT id, name FROM specialties ORDER BY name');
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر جلب التخصصات' });
  }
});

router.get('/doctors', async (req, res) => {
  try {
    const [rows] = await pool.query(
      `SELECT d.id, u.full_name, s.name AS specialty, d.consultation_fee,
              d.work_start_hour, d.work_end_hour, d.slot_minutes,
              ROUND(AVG(r.rating), 1) AS avg_rating, COUNT(r.id) AS reviews_count
       FROM doctors d
       JOIN users u ON u.id = d.user_id
       JOIN specialties s ON s.id = d.specialty_id
       LEFT JOIN reviews r ON r.doctor_id = d.id
       GROUP BY d.id, u.full_name, s.name, d.consultation_fee,
                d.work_start_hour, d.work_end_hour, d.slot_minutes
       ORDER BY u.full_name`
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر جلب قائمة الأطباء' });
  }
});

module.exports = router;
