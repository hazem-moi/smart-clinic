import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/doctor.dart';
import '../models/appointment.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);
  @override
  String toString() => message;
}

// استجابة غير-JSON تحديداً (عادة الخادم لم يُكمل الإحماء بعد)، بخلاف أخطاء
// العمل المعتادة (صلاحيات، تحقق، إلخ) القادمة من الخادم كـ JSON صالح.
class _ServerWarmingUpException extends ApiException {
  _ServerWarmingUpException() : super('الخادم قيد الإحماء، يرجى الانتظار قليلاً والمحاولة مرة أخرى');
}

class ApiService {
  // يمكن تغيير الرابط عند التشغيل عبر: --dart-define=API_URL=https://your-api.onrender.com/api
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://smart-clinic-ci4r.onrender.com/api',
  );

  final String? token;
  ApiService({this.token});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  // الجسم قد يكون كائناً (تسجيل الدخول، الحجز...) أو مصفوفة (قوائم الأطباء
  // والمواعيد)، لذا لا نفرض نوعاً معيناً هنا؛ كل دالة تُحوِّل الناتج بحسب مسارها.
  dynamic _decode(http.Response res) {
    dynamic body;
    try {
      body = jsonDecode(res.body);
    } catch (_) {
      throw _ServerWarmingUpException();
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    }
    final message = body is Map<String, dynamic> ? body['error'] as String? : null;
    throw ApiException(message ?? 'حدث خطأ غير متوقع');
  }

  // نفس منطق GET + فك الترميز، مع إعادة محاولة واحدة تلقائية إن كان السبب تحديداً
  // استجابة غير-JSON (عادة اتصال قاعدة البيانات الأول بعد إيقاظ الخادم من سكونه)،
  // دون إعادة محاولة أخطاء العمل الفعلية (صلاحيات، تحقق...).
  Future<dynamic> _getJson(Uri uri) async {
    try {
      final res = await http.get(uri, headers: _headers);
      return _decode(res);
    } on _ServerWarmingUpException {
      await Future.delayed(const Duration(seconds: 4));
      final res = await http.get(uri, headers: _headers);
      return _decode(res);
    }
  }

  // يُستدعى عند بدء التطبيق لإيقاظ الخادم واتصال قاعدة البيانات مبكراً (خطط Render
  // المجانية تُسكِن الخادم بعد فترة خمول). يستهدف عمداً مساراً يستعلم القاعدة فعلياً
  // (وليس /health) لأن إنشاء أول اتصال بقاعدة البيانات هو الجزء الأبطأ عادة.
  Future<void> wakeUp() async {
    try {
      await http.get(Uri.parse('$baseUrl/specialties')).timeout(const Duration(seconds: 60));
    } catch (_) {
      // تجاهل أي خطأ هنا؛ الهدف مجرد تنبيه الخادم، والمحاولات الفعلية لاحقاً ستُظهر الخطأ إن استمر.
    }
  }

  Future<Map<String, dynamic>> login(String mail, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'mail': mail, 'password': password}),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String fullName,
    required String mail,
    required String password,
    required String role,
    int? specialtyId,
    double? consultationFee,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'full_name': fullName,
        'mail': mail,
        'password': password,
        'role': role,
        if (specialtyId != null) 'specialty_id': specialtyId,
        if (consultationFee != null) 'consultation_fee': consultationFee,
      }),
    );
    return _decode(res) as Map<String, dynamic>;
  }

  Future<List<Specialty>> fetchSpecialties() async {
    final list = await _getJson(Uri.parse('$baseUrl/specialties')) as List<dynamic>;
    return list.map((e) => Specialty.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Doctor>> fetchDoctors() async {
    final list = await _getJson(Uri.parse('$baseUrl/doctors')) as List<dynamic>;
    return list.map((e) => Doctor.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> bookAppointment({required int doctorId, required DateTime dateTime}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/appointments'),
      headers: _headers,
      body: jsonEncode({
        'doctor_id': doctorId,
        'appointment_date': dateTime.toIso8601String(),
      }),
    );
    _decode(res);
  }

  Future<List<Appointment>> fetchPatientAppointments(int patientId) async {
    final uri = Uri.parse('$baseUrl/appointments/patient/$patientId');
    final list = await _getJson(uri) as List<dynamic>;
    return list.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Appointment>> fetchDoctorAppointments(int doctorId, {bool todayOnly = false}) async {
    final uri = Uri.parse('$baseUrl/appointments/doctor/$doctorId${todayOnly ? '?date=today' : ''}');
    final list = await _getJson(uri) as List<dynamic>;
    return list.map((e) => Appointment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> updateAppointmentStatus(int appointmentId, String status) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/appointments/$appointmentId/status'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    _decode(res);
  }

  Future<void> saveDoctorNotes(int appointmentId, String notes) async {
    final res = await http.patch(
      Uri.parse('$baseUrl/appointments/$appointmentId/notes'),
      headers: _headers,
      body: jsonEncode({'doctor_notes': notes}),
    );
    _decode(res);
  }
}
