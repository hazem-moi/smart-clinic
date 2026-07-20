-- =========================================================
-- قاعدة بيانات "العيادة الذكية" (Smart Clinic)
-- 4 جداول رئيسية: users, specialties, doctors, appointments
-- =========================================================

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(120) NOT NULL,
  mail VARCHAR(150) NOT NULL UNIQUE,
  password VARCHAR(255) NOT NULL,
  role ENUM('doctor', 'patient') NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS specialties (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS doctors (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL UNIQUE,
  specialty_id INT NOT NULL,
  consultation_fee DECIMAL(10, 2) NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (specialty_id) REFERENCES specialties(id)
);

CREATE TABLE IF NOT EXISTS appointments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  appointment_date DATETIME NOT NULL,
  status ENUM('pending', 'confirmed', 'completed', 'cancelled') NOT NULL DEFAULT 'pending',
  doctor_notes TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (doctor_id) REFERENCES doctors(id) ON DELETE CASCADE,
  UNIQUE KEY uniq_doctor_slot (doctor_id, appointment_date)
);

-- =========================================================
-- بيانات أولية (Seed Data)
-- =========================================================

INSERT IGNORE INTO specialties (id, name) VALUES
  (1, 'أطفال'),
  (2, 'قلبية'),
  (3, 'أسنان'),
  (4, 'جلدية'),
  (5, 'عيون');

-- بيانات المستخدمين التجريبيين (بكلمات سر مشفّرة فعلياً) تُدرَج عبر backend/db/seed.js
-- لأن bcrypt يتطلب توليد الهاش برمجياً وليس كنص ثابت في ملف SQL.
