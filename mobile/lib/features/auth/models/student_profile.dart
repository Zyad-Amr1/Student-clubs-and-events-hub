class StudentProfile {
  const StudentProfile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.universityId,
    required this.accountType,
    required this.isActive,
    required this.createdAt,
  });

  final String id;
  final String fullName;
  final String email;
  final String universityId;
  final String accountType;
  final bool isActive;
  final DateTime createdAt;

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: _requiredString(json, 'id'),
      fullName: _requiredString(json, 'full_name'),
      email: _requiredString(json, 'email'),
      universityId: _requiredString(json, 'university_id'),
      accountType: _requiredString(json, 'account_type'),
      isActive: json['is_active'] as bool? ?? false,
      createdAt: DateTime.parse(_requiredString(json, 'created_at')),
    );
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.isEmpty) {
      throw FormatException('The profile response is missing "$key".');
    }
    return value;
  }
}
