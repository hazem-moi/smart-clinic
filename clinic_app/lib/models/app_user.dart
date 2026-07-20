class AppUser {
  final int id;
  final String fullName;
  final String mail;
  final String role; // 'doctor' or 'patient'
  final int? doctorId;

  AppUser({
    required this.id,
    required this.fullName,
    required this.mail,
    required this.role,
    this.doctorId,
  });

  bool get isDoctor => role == 'doctor';

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as int,
      fullName: json['full_name'] as String,
      mail: json['mail'] as String? ?? '',
      role: json['role'] as String,
      doctorId: json['doctor_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'mail': mail,
        'role': role,
        'doctor_id': doctorId,
      };
}
