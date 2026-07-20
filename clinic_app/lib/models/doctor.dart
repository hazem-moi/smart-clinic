class Doctor {
  final int id;
  final String fullName;
  final String specialty;
  final double consultationFee;
  final int workStartHour;
  final int workEndHour;
  final int slotMinutes;
  final double? avgRating;
  final int reviewsCount;

  Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.consultationFee,
    this.workStartHour = 9,
    this.workEndHour = 17,
    this.slotMinutes = 30,
    this.avgRating,
    this.reviewsCount = 0,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      specialty: json['specialty'] as String,
      consultationFee: double.parse(json['consultation_fee'].toString()),
      workStartHour: (json['work_start_hour'] as num?)?.toInt() ?? 9,
      workEndHour: (json['work_end_hour'] as num?)?.toInt() ?? 17,
      slotMinutes: (json['slot_minutes'] as num?)?.toInt() ?? 30,
      avgRating: json['avg_rating'] == null ? null : double.parse(json['avg_rating'].toString()),
      reviewsCount: (json['reviews_count'] as num?)?.toInt() ?? 0,
    );
  }
}

class Specialty {
  final int id;
  final String name;

  Specialty({required this.id, required this.name});

  factory Specialty.fromJson(Map<String, dynamic> json) {
    return Specialty(id: json['id'] as int, name: json['name'] as String);
  }
}
