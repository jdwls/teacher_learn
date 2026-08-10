import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/server_service.dart';
import '../config/app_config.dart';

enum StudentStatus {
  offline, // 离线
  online, // 在线
  typing, // 打字
  exam, // 小测
}

class StudentStatusInfo {
  final String id;
  final String name;
  final String classId;
  final String computerName;
  final String ip;
  final DateTime registerTime;
  StudentStatus status;
  DateTime lastHeartbeat;

  StudentStatusInfo({
    required this.id,
    required this.name,
    required this.classId,
    required this.computerName,
    required this.ip,
    required this.registerTime,
    this.status = StudentStatus.offline,
    required this.lastHeartbeat,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'class_id': classId,
        'computer_name': computerName,
        'ip': ip,
        'register_time': registerTime.toIso8601String(),
        'status': status.name,
        'last_heartbeat': lastHeartbeat.toIso8601String(),
      };

  factory StudentStatusInfo.fromJson(Map<String, dynamic> json) {
    return StudentStatusInfo(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      classId: json['class_id']?.toString() ?? '',
      computerName: json['computer_name']?.toString() ?? '',
      ip: json['ip']?.toString() ?? '',
      registerTime: json['register_time'] != null
          ? (DateTime.tryParse(json['register_time'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: parseStatus(json['status']?.toString()),
      lastHeartbeat: json['last_heartbeat'] != null
          ? (DateTime.tryParse(json['last_heartbeat'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  static StudentStatus parseStatus(String? status) {
    switch (status) {
      case 'online':
        return StudentStatus.online;
      case 'typing':
        return StudentStatus.typing;
      case 'exam':
        return StudentStatus.exam;
      default:
        return StudentStatus.offline;
    }
  }

  /// 心跳超时阈值（秒）- 使用配置常量
  /// 超过此时间未收到心跳视为离线
  static const int heartbeatTimeoutSeconds = AppConfig.heartbeatTimeoutSeconds;

  bool get isOnline =>
      status != StudentStatus.offline &&
      DateTime.now().difference(lastHeartbeat).inSeconds <
          heartbeatTimeoutSeconds;

  String get statusText {
    if (status == StudentStatus.typing) return '打字中';
    if (status == StudentStatus.exam) return '小测中';
    if (isOnline) return '在线';
    return '离线';
  }

  String get statusIcon {
    if (status == StudentStatus.typing) return '⌨️';
    if (status == StudentStatus.exam) return '📝';
    if (isOnline) return '🟢';
    return '⚫';
  }
}

class StudentStatusProvider extends ChangeNotifier {
  List<StudentStatusInfo> _students = [];
  bool _isLoading = false;
  Timer? _refreshTimer;
  Timer? _debounceTimer;
  bool _isRefreshing = false;
  StreamSubscription? _studentStreamSubscription;

  // 刷新间隔（秒）
  static const int _refreshInterval = 5;
  // 防抖间隔（毫秒）
  static const int _debounceInterval = 3000;

  List<StudentStatusInfo> get students => List.unmodifiable(_students);
  bool get isLoading => _isLoading;

  // 获取特定班级的学生
  List<StudentStatusInfo> getStudentsByClass(String classId) {
    return _students.where((s) => s.classId == classId).toList();
  }

  // 获取在线学生数
  int get onlineCount => _students.where((s) => s.isOnline).length;

  // 获取离线学生数
  int get offlineCount => _students.where((s) => !s.isOnline).length;

  // 获取正在打字的学生数
  int get typingCount =>
      _students.where((s) => s.status == StudentStatus.typing).length;

  // 获取正在考试的学生数
  int get examCount =>
      _students.where((s) => s.status == StudentStatus.exam).length;

  // 启动刷新（从 ServerService 内存中定期读取 + 监听实时流）
  void startRefresh() {
    // 立即加载一次
    _loadStudentsFromServer();

    // 订阅 ServerService 的学生数据流（实时更新：打字、小测等状态变化）
    _studentStreamSubscription?.cancel();
    _studentStreamSubscription =
        ServerService.instance.studentStream.listen((_) {
      _loadStudentsFromServer();
    });

    // 定期从 ServerService 内存刷新（兜底）
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      Duration(seconds: _refreshInterval),
      (_) => _loadStudentsFromServer(),
    );
  }

  // 停止刷新
  void stopRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // 加载学生状态
  Future<void> _loadStudents(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final jsonString = await file.readAsString();
        final data = json.decode(jsonString);
        final List<dynamic> studentsList = data['students'] ?? [];

        final newStudents = studentsList.map((studentData) {
          final student = StudentStatusInfo.fromJson(studentData);

          // 检查心跳时间，如果超过阈值设为离线（与 StudentStatusInfo.heartbeatTimeoutSeconds 保持一致）
          if (DateTime.now().difference(student.lastHeartbeat).inSeconds >
              StudentStatusInfo.heartbeatTimeoutSeconds) {
            student.status = StudentStatus.offline;
          }

          return student;
        }).toList();

        _students = newStudents;
        notifyListeners();
      }
    } catch (e) {
      // 忽略错误
    }
  }

  // 手动刷新（带防抖）
  Future<void> refresh(String filePath) async {
    // 如果正在刷新，忽略此次请求
    if (_isRefreshing) return;

    // 如果有定时器在运行，取消并重新计时
    _debounceTimer?.cancel();

    _isRefreshing = true;
    _isLoading = true;
    notifyListeners();

    await _loadStudents(filePath);

    _isLoading = false;
    notifyListeners();

    // 3秒后允许下一次刷新
    Future.delayed(Duration(milliseconds: _debounceInterval), () {
      _isRefreshing = false;
    });
  }

  // 直接重新加载（从 ServerService 内存中）- 立即执行，无防抖
  void reloadFromServer() {
    // 先强制检测心跳超时，确保离线状态是最新的
    try {
      ServerService.instance.forceCheckHeartbeatTimeout();
    } catch (e) {
      print('检查心跳超时失败: $e');
    }
    _loadStudentsFromServer();
  }

  void _loadStudentsFromServer() {
    try {
      final students = ServerService.instance.connectedStudents;
      _students = students.map((conn) {
        final student = conn.student;

        // 【修复】优先使用 conn.studentStatus（typing/exam 状态）
        // 而不是被无条件覆盖为 online/offline
        StudentStatus status;
        if (conn.studentStatus == 'typing') {
          status = StudentStatus.typing;
        } else if (conn.studentStatus == 'exam') {
          status = StudentStatus.exam;
        } else {
          // 只有在非 typing/exam 时才根据 isOnline 判断
          status = conn.isOnline ? StudentStatus.online : StudentStatus.offline;
        }

        // 检查心跳时间，超过阈值设为离线（与 StudentStatusInfo.heartbeatTimeoutSeconds 保持一致）
        if (DateTime.now().difference(conn.lastHeartbeat).inSeconds >
            StudentStatusInfo.heartbeatTimeoutSeconds) {
          status = StudentStatus.offline;
        }

        return StudentStatusInfo(
          id: student.id,
          name: student.name,
          classId: student.classId,
          computerName: student.computerName,
          ip: student.ip,
          registerTime: student.registerTime,
          status: status,
          lastHeartbeat: conn.lastHeartbeat,
        );
      }).toList();
      notifyListeners();
    } catch (e) {
      // 忽略错误
    }
  }

  // 更新学生状态（同步到 ServerService）
  void updateStudentStatus(String studentId, StudentStatus status) {
    final index = _students.indexWhere((s) => s.id == studentId);
    if (index != -1) {
      _students[index].status = status;
      _students[index].lastHeartbeat = DateTime.now();

      // 同步到 ServerService（确保数据一致性）
      try {
        final statusStr = status.name;
        ServerService.instance.updateStudentStatus(studentId, statusStr);
      } catch (e) {
        print('同步学生状态到ServerService失败: $e');
      }

      notifyListeners();
    }
  }

  @override
  void dispose() {
    // 【P4修复】取消学生数据流订阅并置 null
    _studentStreamSubscription?.cancel();
    _studentStreamSubscription = null;

    // 【P20修复】取消防抖定时器
    _debounceTimer?.cancel();
    _debounceTimer = null;

    // 【P5修复】停止刷新定时器
    _refreshTimer?.cancel();
    _refreshTimer = null;

    // 清空学生列表
    _students = [];

    // 【P5修复】必须调用 super.dispose()
    super.dispose();
  }
}
