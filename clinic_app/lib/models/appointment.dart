import 'package:flutter/material.dart';

class Appointment {
  final int id;
  final DateTime appointmentDate;
  final String status; // pending | confirmed | completed | cancelled
  final String? doctorNotes;
  final String? doctorName;
  final String? specialty;
  final String? patientName;
  final int? myRating; // تقييم المريض لهذا الموعد (إن وُجد)

  Appointment({
    required this.id,
    required this.appointmentDate,
    required this.status,
    this.doctorNotes,
    this.doctorName,
    this.specialty,
    this.patientName,
    this.myRating,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as int,
      appointmentDate: DateTime.parse((json['appointment_date'] as String).replaceFirst(' ', 'T')),
      status: json['status'] as String,
      doctorNotes: json['doctor_notes'] as String?,
      doctorName: json['doctor_name'] as String?,
      specialty: json['specialty'] as String?,
      patientName: json['patient_name'] as String?,
      myRating: (json['my_rating'] as num?)?.toInt(),
    );
  }

  bool get isUpcoming => appointmentDate.isAfter(DateTime.now()) && status != 'cancelled';

  // قابل للإلغاء من المريض ما لم يكن مكتملاً أو ملغى مسبقاً
  bool get isCancellable => status == 'pending' || status == 'confirmed';

  bool get canReview => status == 'completed' && myRating == null;

  static String statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'قيد الانتظار';
      case 'confirmed':
        return 'مؤكَّد';
      case 'completed':
        return 'تم الفحص';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  static Color statusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFB26A00); // كهرماني
      case 'confirmed':
        return const Color(0xFF1565C0); // أزرق
      case 'completed':
        return const Color(0xFF2E7D32); // أخضر
      case 'cancelled':
        return const Color(0xFFC62828); // أحمر
      default:
        return const Color(0xFF616161);
    }
  }
}
