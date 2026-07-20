class Appointment {
  final int id;
  final DateTime appointmentDate;
  final String status; // pending | confirmed | completed | cancelled
  final String? doctorNotes;
  final String? doctorName;
  final String? specialty;
  final String? patientName;

  Appointment({
    required this.id,
    required this.appointmentDate,
    required this.status,
    this.doctorNotes,
    this.doctorName,
    this.specialty,
    this.patientName,
  });

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as int,
      appointmentDate: DateTime.parse(json['appointment_date'] as String),
      status: json['status'] as String,
      doctorNotes: json['doctor_notes'] as String?,
      doctorName: json['doctor_name'] as String?,
      specialty: json['specialty'] as String?,
      patientName: json['patient_name'] as String?,
    );
  }

  bool get isUpcoming => appointmentDate.isAfter(DateTime.now()) && status != 'cancelled';

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
}
