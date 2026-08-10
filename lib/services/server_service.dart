import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import '../utils/app_path.dart';
import '../config/app_config.dart';

class ServerService {
  static ServerService? _instance;
  static ServerService get instance => _instance ??= ServerService._();

  /// 使用 Map 存储学生连接（key=studentId），O(1) 查找，避免 List.indexWhere 的 O(n) 开销
  final Map<String, StudentConnection> _connectedStudentsMap = {};
  final _studentController =
      StreamController<List<StudentConnection>>.broadcast();

  /// 当前活跃的 Socket 连接（用于服务器关闭时清理）
  final List<Socket> _activeSockets = [];

  /// ServerSocket 实例（用于服务器关闭时释放端口）
  ServerSocket? _serverSocket;

  // 学生数据根目录（information/）
  static String get _informationRoot => AppPath.informationDir;

  // 端口号 - Socket 服务器端口
  static const int _socketPort = 20021;

  /// 防抖写入定时器（避免每次心跳都写文件）
  Timer? _saveDebounceTimer;
  bool _needsSave = false;

  /// 批量通知定时器（合并多次心跳为一次UI刷新，降低Flutter重建频率）
  Timer? _notifyDebounceTimer;
  bool _needsNotify = false;

  /// 心跳超时检测定时器（独立检测断开连接）
  Timer? _heartbeatTimeoutTimer;

  /// 心跳超时时间（秒）- 使用配置常量
  static const _heartbeatTimeoutSeconds = AppConfig.heartbeatTimeoutSeconds;

  ServerService._();

  Stream<List<StudentConnection>> get studentStream =>
      _studentController.stream;

  /// 获取连接学生列表的不可变视图（基于Map）
  List<StudentConnection> get connectedStudents =>
      List.unmodifiable(_connectedStudentsMap.values);

  // ============ 按班级分文件管理 ============

  /// 获取所有班级列表（扫描information目录下包含use_list.json的子目录）
  List<String> _getAllClassIds() {
    final dir = Directory(_informationRoot);
    if (!dir.existsSync()) return [];
    final classes = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        final useListFile = File(path.join(entity.path, 'use_list.json'));
        if (useListFile.existsSync()) {
          classes.add(path.basename(entity.path));
        }
      }
    }
    return classes;
  }

  /// 获取班级文件路径（新结构：information/初一XX班/use_list.json）
  String _getClassFilePath(String classId) {
    return path.join(_informationRoot, classId, 'use_list.json');
  }

  /// 保存学生到班级文件
  /// 【修复】写入前先读取现有文件，合并数据后再写入
  /// 这样 HttpServerService 写入的 last_login 等字段不会被覆盖
  Future<void> _saveStudentToClassFile(
      String classId, List<Map<String, dynamic>> students) async {
    try {
      final dir = Directory(path.join(_informationRoot, classId));
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final file = File(_getClassFilePath(classId));

      // 【修复】读取现有文件，保留已有的字段（如 last_login、points 等）
      Map<String, dynamic> existingData = {};
      if (await file.exists()) {
        try {
          final existingContent = await file.readAsString();
          existingData = json.decode(existingContent) as Map<String, dynamic>;
        } catch (e) {
          // 文件损坏或格式错误，使用空数据
          print('读取班级 $classId 现有文件失败，使用新数据: $e');
        }
      }

      // 合并学生数据：以 ServerService 内存数据为主（更新心跳、在线状态）
      // 但保留每个学生在文件中已有的其他字段
      final existingStudents = (existingData['students'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // 构建 id -> existingStudent 的 Map 用于快速查找
      final Map<String, Map<String, dynamic>> existingStudentsMap = {};
      for (final s in existingStudents) {
        final id = s['id'] as String?;
        if (id != null) {
          existingStudentsMap[id] = s;
        }
      }

      // 合并：使用 students 中的基础信息，但从 existingData 补充缺失字段
      final mergedStudents = <Map<String, dynamic>>[];
      final processedIds = <String>{};
      for (final s in students) {
        final studentId = s['id'] as String?;
        if (studentId == null) continue;
        processedIds.add(studentId);

        final existing = existingStudentsMap[studentId];
        if (existing != null) {
          // 合并：保留已有字段，仅更新 ServerService 管理的字段
          final merged = Map<String, dynamic>.from(existing);
          merged['last_heartbeat'] = s['last_heartbeat'];
          merged['is_online'] = s['is_online'];
          merged['computer_name'] =
              s['computer_name'] ?? existing['computer_name'];
          merged['ip'] = s['ip'] ?? existing['ip'];
          // points 以文件中已有的为准（HttpServerService 管理积分）
          if (s['points'] != null && existing['points'] != null) {
            // 如果现有分数不同，以现有文件为准（避免覆盖）
            merged['points'] = existing['points'];
          } else if (s['points'] != null) {
            merged['points'] = s['points'];
          }
          mergedStudents.add(merged);
        } else {
          // 新学生（不在现有文件中）
          mergedStudents.add(Map<String, dynamic>.from(s));
        }
      }
      // 【修复】保留文件中独有但内存中没有的学生（防止因内存不完整而丢失数据）
      for (final existing in existingStudents) {
        final studentId = existing['id'] as String?;
        if (studentId != null && !processedIds.contains(studentId)) {
          mergedStudents.add(Map<String, dynamic>.from(existing));
        }
      }

      final data = {
        'class_id': classId,
        'students': mergedStudents,
        'updated_at': DateTime.now().toIso8601String()
      };
      // 【P12修复】添加 flush:true 确保数据写入磁盘
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
        flush: true,
      );
    } catch (e) {
      print('保存班级 $classId 数据失败: $e');
    }
  }

  /// 保存所有学生（根据class_id分发到不同班级文件）
  Future<void> _saveStudentsToFile() async {
    try {
      // 如果内存中没有学生数据，不要覆盖文件
      if (_connectedStudentsMap.isEmpty) {
        print('内存中无学生数据，跳过保存（防止覆盖已有文件）');
        return;
      }

      // 按班级分组
      final Map<String, List<Map<String, dynamic>>> classGroups = {};
      for (final conn in _connectedStudentsMap.values) {
        final classId = conn.student.classId;
        if (!classGroups.containsKey(classId)) {
          classGroups[classId] = [];
        }
        classGroups[classId]!.add({
          'id': conn.student.id,
          'name': conn.student.name,
          'password': conn.student.password,
          'class_id': conn.student.classId,
          'computer_name': conn.student.computerName,
          'ip': conn.student.ip,
          'points': conn.points,
          'register_time': conn.student.registerTime.toIso8601String(),
          'last_heartbeat': conn.lastHeartbeat.toIso8601String(),
          'is_online': conn.isOnline,
          // 不再持久化 status（typing/exam 是瞬态，重启后应重置）
        });
      }

      // 保存每个班级
      for (final entry in classGroups.entries) {
        await _saveStudentToClassFile(entry.key, entry.value);
      }

      print('已保存 ${_connectedStudentsMap.length} 条学生记录到各班级文件');
    } catch (e) {
      print('保存学生记录失败: $e');
    }
  }

  // 启动服务器 - 仅启动 Socket 服务器
  Future<void> startServer() async {
    try {
      // 加载已有的学生记录
      await _loadStudentsFromFile();

      // 启动Socket服务器用于学生状态同步
      await _startSocketServer();

      // 启动心跳超时检测（每5秒检测一次）
      _startHeartbeatTimeoutCheck();
    } catch (e) {
      print('服务器启动失败: $e');
    }
  }

  /// 启动心跳超时检测定时器
  void _startHeartbeatTimeoutCheck() {
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkHeartbeatTimeout(),
    );
  }

  /// 立即检查心跳超时（公开方法，供刷新按钮调用）
  void forceCheckHeartbeatTimeout() {
    _checkHeartbeatTimeout();
  }

  /// 检查心跳超时（超过15秒未收到心跳视为断开）
  void _checkHeartbeatTimeout() {
    final now = DateTime.now();
    final timeout = Duration(seconds: _heartbeatTimeoutSeconds);
    bool needsNotify = false;

    for (final entry in _connectedStudentsMap.entries) {
      final conn = entry.value;
      if (conn.isOnline && now.difference(conn.lastHeartbeat) > timeout) {
        conn.isOnline = false;
        needsNotify = true;
        print('学生 ${conn.student.name} 心跳超时，已设为离线');
      }
    }

    if (needsNotify) {
      _debouncedSave();
      _debouncedNotify();
    }
  }

  bool _isTeacherActive = false;

  void setTeacherActive() {
    _isTeacherActive = true;
    print('教师端已激活');
  }

  // 重新加载学生数据
  void reloadStudents() {
    _loadStudentsFromFile();
  }

  void setTeacherInactive() {
    _isTeacherActive = false;
    print('教师端已停用');
  }

  bool get isTeacherActive => _isTeacherActive;

  // 从所有班级JSON文件加载学生记录
  Future<void> _loadStudentsFromFile() async {
    try {
      _connectedStudentsMap.clear();

      for (final classId in _getAllClassIds()) {
        final file = File(_getClassFilePath(classId));
        if (!await file.exists()) continue;

        final jsonString = await file.readAsString();
        final data = json.decode(jsonString);
        final List<dynamic> studentsList = data['students'] ?? [];

        for (final studentData in studentsList) {
          final studentId = studentData['id'] ?? '';
          if (studentId.isEmpty) continue;

          final student = StudentInfo(
            id: studentId,
            name: studentData['name'] ?? '',
            password: studentData['password'] ?? '',
            classId: studentData['class_id'] ?? '',
            computerName: studentData['computer_name'] ?? '',
            ip: studentData['ip'] ?? '',
            registerTime: studentData['register_time'] != null
                ? DateTime.parse(studentData['register_time'])
                : DateTime.now(),
          );

          _connectedStudentsMap[studentId] = StudentConnection(
            student: student,
            socket: null,
            lastHeartbeat: studentData['last_heartbeat'] != null
                ? DateTime.parse(studentData['last_heartbeat'])
                : DateTime.now(),
            isOnline: studentData['is_online'] ?? false,
            // 不从文件读取 status（重启后统一重置为离线，由实时 Socket 消息重新设置）
            studentStatus:
                (studentData['is_online'] ?? false) ? 'online' : 'offline',
            points: studentData['points'] ?? 0,
          );
        }
      }

      print('已加载 ${_connectedStudentsMap.length} 条学生记录');
    } catch (e) {
      print('加载学生记录失败: $e');
    }
  }

  // 启动Socket服务器
  Future<void> _startSocketServer() async {
    try {
      _serverSocket = await ServerSocket.bind('0.0.0.0', _socketPort);
      print('Socket服务器启动在端口 $_socketPort');

      _serverSocket!.listen((socket) {
        _activeSockets.add(socket);
        _handleSocketConnection(socket);
      });
    } catch (e) {
      print('Socket服务器启动失败: $e');
    }
  }

  // 处理Socket连接（带TCP分包缓冲）
  void _handleSocketConnection(Socket socket) {
    String? studentId;
    String messageBuffer = ''; // TCP消息缓冲区

    socket.listen(
      (data) {
        messageBuffer += utf8.decode(data);
        // 按换行符分割消息（协议：每条JSON消息以\n结尾）
        while (messageBuffer.contains('\n')) {
          final splitIndex = messageBuffer.indexOf('\n');
          final message = messageBuffer.substring(0, splitIndex);
          messageBuffer = messageBuffer.substring(splitIndex + 1);
          if (message.isEmpty) continue;
          try {
            final jsonData = json.decode(message);
            studentId = jsonData['student_id'];
            final type = jsonData['type'];

            if (type == 'heartbeat') {
              // O(1) 查找，同时处理学生不在列表中的情况
              final conn = _getOrAddStudent(studentId);
              if (conn != null) {
                conn.lastHeartbeat = DateTime.now();
                conn.isOnline = true;
                conn.socket = socket;
                // 支持心跳消息中携带状态信息（如 typing、exam、online）
                if (jsonData['status'] != null) {
                  conn.studentStatus = jsonData['status'];
                }
                socket.write('${json.encode({'type': 'ack'})}\n');
                _debouncedSave(); // 防抖保存，避免频繁写磁盘
                _debouncedNotify(); // 批量通知UI刷新
              }
            } else if (type == 'status_update') {
              final conn = _getOrAddStudent(studentId);
              if (conn != null) {
                conn.studentStatus = jsonData['status'] ?? 'online';
                conn.lastHeartbeat = DateTime.now();
                socket.write('${json.encode({'type': 'status_ack'})}\n');
                _debouncedSave(); // 防抖保存
                _debouncedNotify(); // 批量通知UI刷新
              }
            }
          } catch (e) {
            // 忽略解析错误，记录日志（脱敏：仅显示消息长度，不打印原始内容）
            final msgLen = message.length;
            print('JSON解析错误: $e, 消息长度: $msgLen 字符');
          }
        }
      },
      onError: (error) {
        // 安全处理：确保studentId不为null
        if (studentId != null) {
          final conn = _connectedStudentsMap[studentId];
          if (conn != null) {
            conn.isOnline = false;
            _debouncedSave();
            _debouncedNotify();
          }
        }
        _activeSockets.remove(socket);
        socket.close();
      },
      onDone: () {
        // 安全处理：确保studentId不为null
        if (studentId != null) {
          final conn = _connectedStudentsMap[studentId];
          if (conn != null) {
            conn.isOnline = false;
            _debouncedSave();
            _debouncedNotify();
          }
        }
        _activeSockets.remove(socket);
      },
    );
  }

  /// O(1) 获取或添加学生连接（替代原来的 List.indexWhere + _tryAddStudentFromFiles）
  StudentConnection? _getOrAddStudent(String? studentId) {
    if (studentId == null) return null;

    // 先从内存Map中查找
    if (_connectedStudentsMap.containsKey(studentId)) {
      return _connectedStudentsMap[studentId];
    }

    // 内存中不存在，从文件异步加载（不阻塞事件循环）
    _tryAddStudentFromFilesAsync(studentId);
    return null;
  }

  /// 异步从班级文件中查找学生并添加到内存Map（不阻塞事件循环）
  Future<void> _tryAddStudentFromFilesAsync(String studentId) async {
    try {
      for (final classId in _getAllClassIds()) {
        final file = File(_getClassFilePath(classId));
        if (!await file.exists()) continue;

        final jsonString = await file.readAsString();
        final data = json.decode(jsonString);
        final List<dynamic> studentsList = data['students'] ?? [];

        for (final studentData in studentsList) {
          if (studentData['id'] == studentId) {
            final student = StudentInfo(
              id: studentData['id'] ?? '',
              name: studentData['name'] ?? '',
              password: studentData['password'] ?? '',
              classId: studentData['class_id'] ?? '',
              computerName: studentData['computer_name'] ?? '',
              ip: studentData['ip'] ?? '',
              registerTime: studentData['register_time'] != null
                  ? DateTime.parse(studentData['register_time'])
                  : DateTime.now(),
            );

            _connectedStudentsMap[studentId] = StudentConnection(
              student: student,
              socket: null,
              lastHeartbeat: DateTime.now(),
              isOnline: true,
              studentStatus: 'online',
              points: studentData['points'] ?? 0,
            );
            print('自动添加学生到在线列表: ${student.name} (ID: $studentId)');
            _debouncedNotify();
            return;
          }
        }
      }
    } catch (e) {
      print('查找学生失败: $e');
    }
  }

  /// 防抖保存（合并多次心跳为一次写入，避免100个学生每3秒心跳=33次/秒文件写入）
  void _debouncedSave() {
    _needsSave = true;
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(seconds: 2), () {
      if (_needsSave) {
        _needsSave = false;
        _saveStudentsToFile();
      }
    });
  }

  /// 批量通知UI刷新（合并多次心跳为一次Stream通知，降低Flutter重建频率）
  void _debouncedNotify() {
    _needsNotify = true;
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_needsNotify) {
        _needsNotify = false;
        _studentController.add(List.unmodifiable(_connectedStudentsMap.values));
      }
    });
  }

  /// 强制保存（服务器关闭前调用）
  Future<void> _forceSave() async {
    _saveDebounceTimer?.cancel();
    _needsSave = false;
    // 【P15修复】无条件保存，确保 stopServer 时数据一定落盘
    await _saveStudentsToFile();
  }

  /// 更新学生状态（从 StudentStatusProvider 调用）
  void updateStudentStatus(String studentId, String status) {
    if (_connectedStudentsMap.containsKey(studentId)) {
      final conn = _connectedStudentsMap[studentId]!;
      conn.studentStatus = status;
      conn.lastHeartbeat = DateTime.now();
      conn.isOnline = true;
      _debouncedSave();
      _debouncedNotify();
      print('ServerService: 学生 $studentId 状态更新为 $status');
    }
  }

  // 停止服务器（异步，确保数据写入完成，关闭所有Socket连接）
  Future<void> stopServer() async {
    _saveDebounceTimer?.cancel();
    _notifyDebounceTimer?.cancel();

    // 【P3修复】取消心跳超时检测定时器
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;

    // 【P11修复】先复制列表再遍历，避免并发修改问题
    final socketsToClose = List<Socket>.from(_activeSockets);
    final closedCount = socketsToClose.length;

    // 关闭所有活跃的Socket连接
    for (final socket in socketsToClose) {
      try {
        await socket.close();
      } catch (e) {
        // 忽略Socket关闭错误（可能是已经断开的连接）
      }
    }
    _activeSockets.clear();

    // 关闭ServerSocket，释放端口
    if (_serverSocket != null) {
      try {
        await _serverSocket!.close();
        _serverSocket = null;
        print('ServerSocket 已关闭，端口 $_socketPort 已释放');
      } catch (e) {
        print('ServerSocket 关闭失败: $e');
      }
    }

    // 强制保存所有未写入的数据
    await _forceSave();
    print('服务器已停止，已关闭 $closedCount 个Socket连接');
  }

  void dispose() {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    _notifyDebounceTimer?.cancel();
    _notifyDebounceTimer = null;
    _heartbeatTimeoutTimer?.cancel();
    _heartbeatTimeoutTimer = null;

    // 【P2修复】关闭所有活跃的Socket连接
    for (final socket in _activeSockets) {
      try {
        socket.close();
      } catch (e) {
        // 忽略错误
      }
    }
    _activeSockets.clear();

    // 【P2修复】关闭ServerSocket释放端口
    _serverSocket?.close();
    _serverSocket = null;

    _studentController.close();
  }
}

// 学生连接信息
class StudentConnection {
  StudentInfo student;
  Socket? socket;
  DateTime lastHeartbeat;
  bool isOnline;
  String studentStatus; // 在线、离线、打字中、小测中
  int points; // 积分

  StudentConnection({
    required this.student,
    this.socket,
    required this.lastHeartbeat,
    this.isOnline = true,
    this.studentStatus = 'online',
    this.points = 0,
  });
}

// 学生信息
class StudentInfo {
  final String id;
  final String name;
  final String password;
  final String classId;
  final String computerName;
  final String ip;
  final DateTime registerTime;

  StudentInfo({
    required this.id,
    required this.name,
    required this.password,
    required this.classId,
    required this.computerName,
    required this.ip,
    required this.registerTime,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'password': password,
        'class_id': classId,
        'computer_name': computerName,
        'ip': ip,
        'register_time': registerTime.toIso8601String(),
      };

  factory StudentInfo.fromJson(Map<String, dynamic> json) {
    return StudentInfo(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      password: json['password'] ?? '',
      classId: json['class_id'] ?? '',
      computerName: json['computer_name'] ?? '',
      ip: json['ip'] ?? '',
      registerTime: json['register_time'] != null
          ? DateTime.parse(json['register_time'])
          : DateTime.now(),
    );
  }
}
