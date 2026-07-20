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
      `SELECT d.id, u.full_name, s.name AS specialty, d.consultation_fee
       FROM doctors d
       JOIN users u ON u.id = d.user_id
       JOIN specialties s ON s.id = d.specialty_id
       ORDER BY u.full_name`
    );
    res.json(rows);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'تعذر جلب قائمة الأطباء' });
  }
});

module.exports = router;
