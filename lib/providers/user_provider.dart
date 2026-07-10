import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class UserProvider extends ChangeNotifier {
  List<UserModel> _users = [];
  UserModel? _selectedUser;
  bool _isLoading = false;
  String? _error;

  UserProvider();

  List<UserModel> get users => _users;
  List<UserModel> get students => _users.where((u) => u.isStudent).toList();
  List<UserModel> get teachers => _users.where((u) => u.isTeacher).toList();
  UserModel? get selectedUser => _selectedUser;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectUser(UserModel user) {
    _selectedUser = user;
    notifyListeners();
  }

  void clearSelection() {
    _selectedUser = null;
    notifyListeners();
  }

  // 兼容别名
  Future<bool> addUser(Map<String, dynamic> userData) => createUser(userData);

  Future<void> loadUsers({String? role, String? classId}) async {
    // 延迟到下一个帧，避免在 build 阶段调用 notifyListeners
    await Future.delayed(const Duration(milliseconds: 1));

    _isLoading = true;
    notifyListeners();

    try {
      // 从HTTP API获取当前活跃班级的学生数据
      final classResponse = await http.get(
        Uri.parse('http://localhost:20020/api/active-class'),
      ).timeout(const Duration(seconds: 5));

      String activeClass = '初一01班';
      if (classResponse.statusCode == 200) {
        final classData = json.decode(classResponse.body);
        if (classData['success'] == true) {
          activeClass = classData['class_id'] ?? '初一01班';
        }
      }

      // 从成绩汇总API获取学生列表（如果有成绩数据）
      final encodedClassId = Uri.encodeComponent(activeClass);
      final summaryResponse = await http.get(
        Uri.parse('http://localhost:20020/api/score/summary/$encodedClassId'),
      ).timeout(const Duration(seconds: 10));

      if (summaryResponse.statusCode == 200) {
        final summaryData = json.decode(summaryResponse.body);
        if (summaryData['success'] == true) {
          // 从成绩记录中提取学生信息（去重）
          final studentMap = <String, UserModel>{};
          final examRecords = List<Map<String, dynamic>>.from(
              (summaryData['exam_records'] ?? []).cast<Map<String, dynamic>>());
          for (final record in examRecords) {
            final studentId = record['student_id']?.toString() ?? '';
            final studentName = record['student_name']?.toString() ?? '';
            if (studentId.isNotEmpty && !studentMap.containsKey(studentId)) {
              studentMap[studentId] = UserModel(
                id: studentId,
                name: studentName,
                role: 'student',
                classId: activeClass,
              );
            }
          }
          _users = studentMap.values.toList();
        }
      }

      if (_users.isEmpty) {
        _loadMockData();
      }

      // 从 SharedPreferences 读取学生端注册的设备信息
      await _loadStudentDeviceInfo();
    } catch (e) {
      // 发生错误，使用模拟数据
      _loadMockData();
    }

    // 过滤
    if (role != null) {
      _users = _users.where((u) => u.role == role).toList();
    }
    if (classId != null) {
      _users = _users.where((u) => u.classId == classId).toList();
    }

    _isLoading = false;
    notifyListeners();
  }

  // 从 SharedPreferences 读取学生端注册的设备信息
  Future<void> _loadStudentDeviceInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final registeredStudents =
          prefs.getStringList('registered_students') ?? [];

      // 更新现有用户或添加新用户
      for (final studentData in registeredStudents) {
        final parts = studentData.split('|');
        if (parts.length >= 4) {
          final id = parts[0];
          final name = parts[1];
          final classId = parts[2];
          final computerName = parts[3];
          final ip = parts.length > 4 ? parts[4] : '';

          // 检查是否已存在
          final existingIndex = _users.indexWhere((u) => u.id == id);
          if (existingIndex != -1) {
            // 更新现有用户
            final existing = _users[existingIndex];
            _users[existingIndex] = UserModel(
              id: existing.id,
              name: existing.name,
              role: existing.role,
              classId: existing.classId ?? classId,
              computerName: computerName,
              ip: ip,
              password: existing.password,
              createdAt: existing.createdAt,
              updatedAt: DateTime.now(),
            );
          } else {
            // 添加新用户
            _users.add(UserModel(
              id: id,
              name: name,
              role: 'student',
              classId: classId,
              computerName: computerName,
              ip: ip,
              createdAt: DateTime.now(),
            ));
          }
        }
      }
    } catch (e) {
      // 忽略错误
    }
  }

  void _loadMockData() {
    // 默认空数据，不显示任何学生
    _users = [];
  }

  Future<bool> createUser(Map<String, dynamic> userData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final newUser = UserModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: userData['name'] ?? '',
      role: userData['role'] ?? 'student',
      classId: userData['class_id'],
      computerName: userData['computer_name'],
      ip: userData['ip'],
      password: userData['password'],
      createdAt: DateTime.now(),
    );
    _users.add(newUser);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> updates) async {
    final index = _users.indexWhere((u) => u.id == userId);
    if (index != -1) {
      final oldUser = _users[index];
      _users[index] = UserModel(
        id: oldUser.id,
        name: updates['name'] ?? oldUser.name,
        role: updates['role'] ?? oldUser.role,
        classId: updates['class_id'] ?? oldUser.classId,
        computerName: updates['computer_name'] ?? oldUser.computerName,
        ip: updates['ip'] ?? oldUser.ip,
        password: updates['password'] ?? oldUser.password,
        createdAt: oldUser.createdAt,
        updatedAt: DateTime.now(),
      );
    }
    notifyListeners();
    return true;
  }

  Future<bool> deleteUser(String userId) async {
    _users.removeWhere((u) => u.id == userId);
    notifyListeners();
    return true;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}