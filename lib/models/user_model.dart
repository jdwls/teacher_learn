class UserModel {
  final String id;
  final String name;
  final String role;
  final String? classId;
  final String? computerName;
  final String? ip;
  final String? password;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.role,
    this.classId,
    this.computerName,
    this.ip,
    this.password,
    this.createdAt,
    this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      classId: json['class_id']?.toString(),
      computerName: json['computer_name']?.toString(),
      ip: json['ip']?.toString(),
      password: json['password']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'class_id': classId,
      'computer_name': computerName,
      'ip': ip,
      'password': password,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isStudent => role.toLowerCase() == 'student';
  bool get isTeacher => role.toLowerCase() == 'teacher';
}
