require('dotenv').config();
const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/auth');
const doctorsRoutes = require('./routes/doctors');
const appointmentsRoutes = require('./routes/appointments');

const app = express();
app.use(cors());
app.use(express.json());

app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

app.use('/api/auth', authRoutes);
app.use('/api', doctorsRoutes);
app.use('/api/appointments', appointmentsRoutes);

app.use((req, res) => res.status(404).json({ error: 'المسار غير موجود' }));

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`Smart Clinic API running on port ${PORT}`));
