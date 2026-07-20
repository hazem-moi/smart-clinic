# العيادة الذكية (Smart Clinic)

تطبيق حجز مواعيد بين المرضى والأطباء، مبني بـ Flutter (موبايل + ويب) مع واجهة برمجية Node.js/Express وقاعدة بيانات MySQL.

- المستودع: https://github.com/hazem-moi/smart-clinic
- الـ API المنشور: https://smart-clinic-ci4r.onrender.com/api (قاعدة البيانات: Clever Cloud MySQL)

## البنية

```
hm/
├── backend/        Node.js + Express API
│   ├── server.js
│   ├── db.js
│   ├── db/schema.sql   تعريف الجداول الأربعة + تخصصات أولية
│   ├── db/migrate.js   تنفيذ schema.sql على القاعدة السحابية
│   ├── db/seed.js      إنشاء حسابات تجريبية (أطباء + مريض)
│   ├── middleware/auth.js
│   └── routes/{auth,doctors,appointments}.js
├── clinic_app/     مشروع Flutter (Android + Web)
└── deliverables/   التقرير وسيناريو الفيديو وملف الـ APK النهائي
```

## تشغيل الخادم محلياً

```
cd backend
npm install
cp .env.example .env   # ثم عدّل بيانات القاعدة السحابية
npm run migrate        # إنشاء الجداول
npm run seed           # إنشاء حسابات تجريبية (كلمة السر: 123456)
npm start
```

## تشغيل تطبيق Flutter

```
cd clinic_app
flutter pub get
flutter run -d chrome
```

رابط الخادم مضبوط افتراضياً في `lib/services/api_service.dart` على الرابط المنشور أعلاه؛ يمكن تجاوزه عبر `--dart-define=API_URL=...` عند الحاجة.

## بناء الـ APK

```
cd clinic_app
flutter build apk --release
```

الملف الناتج: `clinic_app/build/app/outputs/flutter-apk/app-release.apk`

## حسابات تجريبية (بعد تشغيل npm run seed)

كلمة السر لجميع الحسابات: `123456`

| البريد | الدور | التخصص |
|---|---|---|
| samer.doctor@clinic.com | طبيب | أطفال |
| kareem.doctor@clinic.com | طبيب | أطفال |
| layla.doctor@clinic.com | طبيب | قلبية |
| nouraldin.doctor@clinic.com | طبيب | قلبية |
| omar.doctor@clinic.com | طبيب | أسنان |
| yasmin.doctor@clinic.com | طبيب | أسنان |
| rana.doctor@clinic.com | طبيب | جلدية |
| tarek.doctor@clinic.com | طبيب | جلدية |
| heba.doctor@clinic.com | طبيب | عيون |
| ziad.doctor@clinic.com | طبيب | عيون |
| patient@clinic.com | مريض | — |
| sara.patient@clinic.com | مريض | — |
| ahmad.patient@clinic.com | مريض | — |
| lina.patient@clinic.com | مريض | — |
| yousef.patient@clinic.com | مريض | — |
| rahaf.patient@clinic.com | مريض | — |
