class Doctor {
  final int id;
  final String fullName;
  final String specialty;
  final double consultationFee;

  Doctor({
    required this.id,
    required this.fullName,
    required this.specialty,
    required this.consultationFee,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      specialty: json['specialty'] as String,
      consultationFee: double.parse(json['consultation_fee'].toString()),
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
