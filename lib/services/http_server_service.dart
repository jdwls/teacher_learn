import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'typing_article_service.dart';
import '../utils/app_path.dart';

/// HTTP API 服务器服务
class HttpServerService {
  static HttpServerService? _instance;
  static HttpServerService get instance => _instance ??= HttpServerService._();

  HttpServer? _server;
  bool _isTeacherActive = false;
  String? _activeBank; // 当前激活的题库
  String _activeClass = '初一01班'; // 默认活跃班级
  int _examTimeLimit = 30; // 考试时间限制（分钟）
  int _earlySubmitMinutes = 25; // 提前交卷时间（考试开始多少分钟后可交卷）

  // ============ 性能优化：内存缓存与并发控制 ============
  /// 【P6修复】题库缓存（bankName -> data），避免重复读取磁盘，带 LRU 限制
  final Map<String, Map<String, dynamic>> _questionBankCache = {};

  /// 题库缓存最大条目数（防止内存无限增长）
  static const int _maxQuestionBankCacheSize = 50;

  /// 题库加载中的Future缓存（防止100个学生同时请求同一题库时重复读取磁盘）
  final Map<String, Future<Map<String, dynamic>?>> _questionBankLoading = {};

  /// 【P7修复】学生数据缓存（classId -> students list)，避免同步文件I/O阻塞事件循环，带 LRU 限制
  final Map<String, List<Map<String, dynamic>>> _studentCache = {};

  /// 学生数据缓存最大条目数（防止内存无限增长）
  static const int _maxStudentCacheSize = 100;

  /// 学生ID自增计数器（从1开始）
  int _nextStudentId = 1;

  /// 脏数据标记（需要写回文件的班级）
  final Set<String> _dirtyClasses = {};

  /// 批量写入定时器（防抖：500ms内多次修改合并为一次写入）
  Timer? _flushTimer;

  /// 刷新重试计数器（防止无限重试）
  int _flushRetryCount = 0;

  /// 成绩文件锁（防止并发读-改-写丢失数据）- 使用 Completer 链式锁
  final Map<String, Completer<void>?> _scoreFileLocks = {};

  /// 锁超时时间（防止死锁）
  static const _lockTimeout = Duration(seconds: 10);

  /// 【P14修复】最大重试次数（提高以应对暂时性I/O故障）
  static const _maxFlushRetries = 10;

  /// 【Y修复】熔断器状态 - 统计连续失败次数
  int _consecutiveFailures = 0;

  /// 熔断阈值（连续失败超过此值时触发熔断）
  static const int _circuitBreakerThreshold = 5;

  /// 熔断恢复时间（秒）
  static const int _circuitBreakerResetSeconds = 30;

  /// 熔断器是否处于熔断状态
  bool _circuitBreakerOpen = false;

  /// 熔断器恢复定时器
  Timer? _circuitBreakerTimer;

  /// 【Y修复】检查是否可以执行I/O操作
  /// 如果熔断器打开，返回false并拒绝操作
  bool _canPerformIO() {
    if (_circuitBreakerOpen) {
      print('【Y修复】熔断器已打开，拒绝I/O操作，等待恢复...');
      return false;
    }
    return true;
  }

  /// 【Y修复】记录I/O操作成功，重置熔断器
  void _recordIOSuccess() {
    if (_consecutiveFailures > 0) {
      _consecutiveFailures = 0;
      print('【Y修复】I/O操作成功，熔断器重置');
    }
  }

  /// 【Y修复】记录I/O操作失败，触发熔断器
  void _recordIOFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _circuitBreakerThreshold &&
        !_circuitBreakerOpen) {
      _circuitBreakerOpen = true;
      print('【Y修复】熔断器已打开！连续失败次数: $_consecutiveFailures');
      // 30秒后尝试恢复
      _circuitBreakerTimer?.cancel();
      _circuitBreakerTimer =
          Timer(const Duration(seconds: _circuitBreakerResetSeconds), () {
        _circuitBreakerOpen = false;
        _consecutiveFailures = 0;
        print('【Y修复】熔断器恢复，重新允许I/O操作');
      });
    }
  }

  /// 积分兑换配置（类成员变量，服务器重启前持久化）
  Map<String, dynamic> pointsExchangeConfig = {
    'items': [],
    'exchange_records': [],
  };

  String get pointsExchangeConfigPath =>
      path.join(_informationRoot, 'manage', 'points_exchange.json');

  Future<void> _loadPointsExchangeConfig() async {
    try {
      final file = File(pointsExchangeConfigPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        pointsExchangeConfig = data;
        print('已从本地加载积分兑换配置: $pointsExchangeConfigPath');
      } else {
        await _savePointsExchangeConfig();
        print('积分兑换配置文件不存在，已创建默认配置');
      }
    } catch (e) {
      print('加载积分兑换配置失败: $e');
    }
  }

  Future<void> _savePointsExchangeConfig() async {
    try {
      final manageDir = Directory(path.join(_informationRoot, 'manage'));
      if (!await manageDir.exists()) {
        await manageDir.create(recursive: true);
      }
      final file = File(pointsExchangeConfigPath);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(pointsExchangeConfig));
      print('已保存积分兑换配置到本地: $pointsExchangeConfigPath');
    } catch (e) {
      print('保存积分兑换配置失败: $e');
    }
  }

  /// 打字配置（类成员变量，服务器重启前持久化）
  Map<String, dynamic> typingConfig = {
    'chinese': {
      'time_limit': 5,
      'target_chars': 100,
      'target_speed': 20,
      'points_per_error': 1.0,
      'random': true,
      'selected_article_index': null,
    },
    'english': {
      'time_limit': 5,
      'target_chars': 500,
      'target_speed': 100,
      'points_per_error': 0.2,
      'random': true,
      'selected_article_index': null,
    },
  };

  HttpServerService._();

  /// 防御路径遍历 + 非法字符净化
  /// 【修复】保留文件扩展名（.），避免图片文件名被破坏
  @visibleForTesting
  String sanitizeFileName(String input) {
    if (input.isEmpty) return 'unknown';
    var sanitized =
        input.replaceAll('..', '').replaceAll('/', '_').replaceAll('\\', '_');
    // 保留 . 字符以支持文件扩展名，但限制连续多个 . 的情况
    sanitized =
        sanitized.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9\-_.]'), '_');
    // 合并连续的下划线和点
    sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
    sanitized = sanitized.replaceAll(RegExp(r'\.+'), '.');
    if (sanitized.length > 100) {
      sanitized = sanitized.substring(0, 100);
    }
    sanitized = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
    sanitized = sanitized.replaceAll(RegExp(r'^\.+|\.+$'), '');
    if (sanitized.isEmpty) sanitized = 'unknown';
    return sanitized;
  }

  String get _typingConfigPath =>
      path.join(_informationRoot, 'manage', 'typing_config.json');

  Future<void> _loadTypingConfig() async {
    try {
      final file = File(_typingConfigPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        if (data.containsKey('chinese') && data['chinese'] is Map) {
          typingConfig['chinese'] = data['chinese'];
        }
        if (data.containsKey('english') && data['english'] is Map) {
          typingConfig['english'] = data['english'];
        }
        print('已从本地加载打字配置: $_typingConfigPath');
      } else {
        await _saveTypingConfig();
        print('打字配置文件不存在，已创建默认配置');
      }
    } catch (e) {
      print('加载打字配置失败: $e');
    }
  }

  Future<void> _saveTypingConfig() async {
    try {
      final manageDir = Directory(path.join(_informationRoot, 'manage'));
      if (!await manageDir.exists()) {
        await manageDir.create(recursive: true);
      }
      final file = File(_typingConfigPath);
      await file.writeAsString(
          const JsonEncoder.withIndent('  ').convert(typingConfig));
      print('已保存打字配置到本地: $_typingConfigPath');
    } catch (e) {
      print('保存打字配置失败: $e');
    }
  }

  bool get isRunning => _server != null;
  bool get isTeacherActive => _isTeacherActive;
  String? get activeBank => _activeBank;
  String? get activeClass => _activeClass;

  String get _projectRoot => AppPath.projectRoot;

  String get questionBankDir => path.join(_projectRoot, '题库');
  String get _informationRoot => path.join(_projectRoot, 'information');

  String _getClassDir(String classId) =>
      path.join(_informationRoot, sanitizeFileName(classId));
  Future<void> _ensureClassDir(String classId) async {
    final dir = Directory(_getClassDir(classId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  String _getScoreClassDir(String classId) => _getClassDir(classId);
  Future<void> _ensureScoreDir(String classId) async =>
      _ensureClassDir(classId);
  String _getClassFilePath(String classId) =>
      path.join(_getClassDir(classId), 'use_list.json');

  Future<void> _withScoreFileLock(String classId, String fileName,
      void Function(Map<String, dynamic> data) updater) async {
    final lockKey =
        '${sanitizeFileName(classId)}/${sanitizeFileName(fileName)}';
    final previous = _scoreFileLocks[lockKey];
    if (previous != null && !previous.isCompleted) {
      try {
        await previous.future.timeout(_lockTimeout, onTimeout: () {
          _scoreFileLocks.remove(lockKey);
          print('警告: 锁超时强制释放，可能存在数据竞争: $lockKey');
        });
      } catch (e) {}
    }
    final completer = Completer<void>();
    _scoreFileLocks[lockKey] = completer;
    try {
      final data = await _readScoreFileAsync(classId, fileName);
      if (!data.containsKey('records') || data['records'] == null) {
        data['records'] = <Map<String, dynamic>>[];
      }
      updater(data);
      await _writeScoreFile(classId, fileName, data);
    } catch (e) {
      print('成绩文件操作失败: $e');
    } finally {
      if (!completer.isCompleted) completer.complete();
      if (_scoreFileLocks[lockKey] == completer)
        _scoreFileLocks.remove(lockKey);
    }
  }

  Future<Map<String, dynamic>> _readScoreFileAsync(
      String classId, String fileName) async {
    try {
      final file = File(path.join(_getScoreClassDir(classId), fileName));
      if (!await file.exists()) return {'records': []};
      final content = await file.readAsString();
      return json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      return {'records': []};
    }
  }

  Future<void> _writeScoreFile(
      String classId, String fileName, Map<String, dynamic> data) async {
    if (!_canPerformIO()) {
      print('【Y修复】熔断器打开中，跳过成绩文件写入');
      return;
    }
    try {
      await _ensureScoreDir(classId);
      final file = File(path.join(_getScoreClassDir(classId), fileName));
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data),
          flush: true);
      _recordIOSuccess();
    } catch (e) {
      _recordIOFailure();
      print('写入成绩文件失败: $e');
    }
  }

  final Map<String, int> _studentPointsCache = {};
  final Map<String, int> _todayPointsCache = {};

  /// 同步学生总积分：从成绩表中累加所有积分（与学生端得分×10%规则一致）
  Future<void> _syncStudentTotalPoints(String classId, String studentId) async {
    try {
      int totalPoints = 0;

      // 累加小测积分
      final examData = await _readScoreFileAsync(classId, '小测成绩表.json');
      for (final r in (examData['records'] as List<dynamic>? ?? [])) {
        final record = r as Map<String, dynamic>;
        if (record['student_id'] == studentId) {
          totalPoints += (record['points'] as int?) ?? 0;
        }
      }

      // 累加打字积分
      final typingData = await _readScoreFileAsync(classId, '中英文打字成绩表.json');
      for (final r in (typingData['records'] as List<dynamic>? ?? [])) {
        final record = r as Map<String, dynamic>;
        if (record['student_id'] == studentId) {
          totalPoints += (record['points'] as int?) ?? 0;
        }
      }

      _studentPointsCache[studentId] = totalPoints;

      final students = loadClassStudents(classId);
      final index = students.indexWhere((s) => s['id'] == studentId);
      if (index != -1) {
        students[index]['points'] = totalPoints;
        _studentCache[classId] = students;
        _dirtyClasses.add(classId);
        _scheduleFlush();
        print('同步积分: $studentId 总积分=$totalPoints');
      }
    } catch (e) {
      print('同步积分失败: $e');
    }
  }

  Future<void> _initStudentPointsCache() async {
    try {
      for (final classId in getAllClassIds()) {
        final students = loadClassStudents(classId);
        for (final s in students) {
          final studentId = s['id'] as String?;
          if (studentId == null) continue;
          _studentPointsCache[studentId] = (s['points'] as int?) ?? 0;
          _todayPointsCache[studentId] = 0;
        }
      }
      print('学生积分缓存已初始化，共 ${_studentPointsCache.length} 条');
    } catch (e) {
      print('初始化学生积分缓存失败: $e');
    }
  }

  String? _findClassByStudentId(String studentId) {
    for (final classId in getAllClassIds()) {
      final students = loadClassStudents(classId);
      for (final s in students) {
        if (s['id'] == studentId) return classId;
      }
    }
    return null;
  }

  Middleware addCorsHeaders() {
    return createMiddleware(
      requestHandler: (Request request) {
        if (request.method == 'OPTIONS')
          return Response.ok('', headers: _corsHeaders);
        return null;
      },
      responseHandler: (Response response) =>
          response.change(headers: _corsHeaders),
    );
  }

  Map<String, String> get _corsHeaders => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
      };

  static const int _maxBodySize = 10 * 1024 * 1024;
  Middleware limitBodySize() {
    return createMiddleware(
      requestHandler: (Request request) {
        final contentLength = request.contentLength;
        if (contentLength != null && contentLength > _maxBodySize) {
          print('警告: 请求体过大 ($contentLength bytes)，已拒绝');
          return Response(413,
              body: json.encode({'error': '请求体过大，最大支持 10MB'}),
              headers: {'Content-Type': 'application/json; charset=utf-8'});
        }
        return null;
      },
    );
  }

  static const int _maxNameLength = 50;
  static const int _maxPasswordLength = 128;

  Response? _validateInputLength(
      String name, String password, String classId, String bankName) {
    if (name.length > _maxNameLength)
      return jsonResponse(
          {'success': false, 'error': '姓名过长（最多 $_maxNameLength 字符）'},
          status: 400);
    if (password.length > _maxPasswordLength)
      return jsonResponse(
          {'success': false, 'error': '密码过长（最多 $_maxPasswordLength 字符）'},
          status: 400);
    if (classId.length > _maxNameLength)
      return jsonResponse(
          {'success': false, 'error': '班级名称过长（最多 $_maxNameLength 字符）'},
          status: 400);
    if (bankName.length > _maxNameLength)
      return jsonResponse(
          {'success': false, 'error': '题库名称过长（最多 $_maxNameLength 字符）'},
          status: 400);
    return null;
  }

  Future<Map<String, dynamic>?> loadQuestionBank(String bankName) async {
    if (_questionBankCache.containsKey(bankName))
      return _questionBankCache[bankName];
    if (_questionBankLoading.containsKey(bankName))
      return _questionBankLoading[bankName];
    final future = _doLoadQuestionBank(bankName);
    _questionBankLoading[bankName] = future;
    try {
      return await future;
    } finally {
      _questionBankLoading.remove(bankName);
    }
  }

  Future<Map<String, dynamic>?> _doLoadQuestionBank(String bankName) async {
    final bankPath = path.join(questionBankDir, bankName, '题库.json');
    final file = File(bankPath);
    if (await file.exists()) {
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      _questionBankCache[bankName] = data;
      return data;
    }
    return null;
  }

  void clearQuestionBankCache([String? bankName]) {
    if (bankName != null) {
      _questionBankCache.remove(bankName);
      _questionBankLoading.remove(bankName);
    } else {
      _questionBankCache.clear();
      _questionBankLoading.clear();
    }
    _enforceCacheLimit(_questionBankCache, _maxQuestionBankCacheSize);
  }

  void clearStudentCache([String? classId]) {
    if (classId != null) {
      _studentCache.remove(classId);
    } else {
      _studentCache.clear();
    }
    _enforceCacheLimit(_studentCache, _maxStudentCacheSize);
  }

  void _enforceCacheLimit(Map cache, int maxSize) {
    while (cache.length > maxSize) {
      final firstKey = cache.keys.first;
      cache.remove(firstKey);
      print('缓存超过上限(${maxSize})，移除: $firstKey');
    }
  }

  Future<List<String>> getAllClassIdsAsync() async {
    final dir = Directory(_informationRoot);
    if (!await dir.exists()) return [];
    final classes = <String>[];
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final useListFile = File(path.join(entity.path, 'use_list.json'));
        if (await useListFile.exists()) {
          classes.add(path.basename(entity.path));
        }
      }
    }
    return classes;
  }

  List<String> getAllClassIds() {
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

  List<Map<String, dynamic>> loadClassStudents(String classId) {
    if (_studentCache.containsKey(classId)) return _studentCache[classId]!;
    // 缓存未命中时，从磁盘同步加载
    try {
      final file = File(_getClassFilePath(classId));
      if (!file.existsSync()) return [];
      final content = file.readAsStringSync();
      final data = json.decode(content) as Map<String, dynamic>;
      final students =
          (data['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      _studentCache[classId] = students;
      return students;
    } catch (e) {
      print('同步加载班级 $classId 学生数据失败: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadClassStudentsAsync(
      String classId) async {
    if (_studentCache.containsKey(classId)) return _studentCache[classId]!;
    try {
      final file = File(_getClassFilePath(classId));
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      final students =
          (data['students'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ??
              [];
      _studentCache[classId] = students;
      return students;
    } catch (e) {
      return [];
    }
  }

  Future<void> saveStudentToClass(
      String classId, Map<String, dynamic> student) async {
    try {
      final dir = Directory(_informationRoot);
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final students = loadClassStudents(classId);
      final index = students.indexWhere((s) => s['id'] == student['id']);
      if (index != -1) {
        students[index] = student;
      } else {
        students.add(student);
      }
      _studentCache[classId] = students;
      _dirtyClasses.add(classId);
      _scheduleFlush();
    } catch (e) {
      print('保存学生到班级 $classId 失败: $e');
    }
  }

  void _scheduleFlush() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(milliseconds: 500), _flushDirtyClasses);
  }

  /// 【修复】刷新脏数据时，合并已有文件数据后再写入
  /// 避免覆盖 ServerService 写入的 last_heartbeat、is_online 等字段
  Future<void> _flushDirtyClasses() async {
    final classesToFlush = _dirtyClasses.toList();
    _dirtyClasses.clear();
    final dir = Directory(_informationRoot);
    if (!dir.existsSync()) dir.createSync(recursive: true);

    for (final classId in classesToFlush) {
      try {
        // 【修复】确保班级目录存在，避免 PathNotFoundException
        await _ensureClassDir(classId);
        final students = _studentCache[classId] ?? [];
        final filePath = _getClassFilePath(classId);
        final file = File(filePath);

        // 【修复】读取磁盘上的现有文件，保留 ServerService 管理的字段
        Map<String, dynamic> existingData = {};
        if (await file.exists()) {
          try {
            final existingContent = await file.readAsString();
            existingData = json.decode(existingContent) as Map<String, dynamic>;
          } catch (e) {
            print('读取班级 $classId 现有文件失败，使用缓存数据: $e');
          }
        }

        // 构建 id -> existingStudent 的 Map
        final existingStudents = (existingData['students'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        final Map<String, Map<String, dynamic>> existingStudentsMap = {};
        for (final s in existingStudents) {
          final id = s['id'] as String?;
          if (id != null) existingStudentsMap[id] = s;
        }

        // 合并：缓存数据为主（HttpServerService 管理的字段），保留已有字段
        final mergedStudents = <Map<String, dynamic>>[];
        final processedIds = <String>{};
        for (final s in students) {
          final studentId = s['id'] as String?;
          if (studentId == null) continue;
          processedIds.add(studentId);

          final existing = existingStudentsMap[studentId];
          if (existing != null) {
            // 合并：保留 ServerService 管理的字段（last_heartbeat、is_online）
            final merged = Map<String, dynamic>.from(existing);
            // 更新 HttpServerService 管理的字段
            merged['name'] = s['name'];
            merged['password'] = s['password'];
            merged['computer_name'] =
                s['computer_name'] ?? existing['computer_name'];
            merged['ip'] = s['ip'] ?? existing['ip'];
            merged['points'] = s['points'] ?? existing['points'];
            merged['last_login'] = s['last_login'] ?? existing['last_login'];
            merged['register_time'] =
                s['register_time'] ?? existing['register_time'];
            mergedStudents.add(merged);
          } else {
            mergedStudents.add(Map<String, dynamic>.from(s));
          }
        }
        // 【修复】保留文件中独有但缓存中没有的学生（防止因缓存不完整而丢失数据）
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
        await File(filePath).writeAsString(
            const JsonEncoder.withIndent('  ').convert(data),
            flush: true);
      } catch (e) {
        print('刷新班级 $classId 数据失败: $e');
        _dirtyClasses.add(classId);
      }
    }
    if (_dirtyClasses.isNotEmpty && _flushRetryCount < _maxFlushRetries) {
      _flushRetryCount++;
      _scheduleFlush();
    } else if (_dirtyClasses.isNotEmpty) {
      print('警告: 脏数据刷新失败已达上限(${_flushRetryCount}次)，尝试紧急保存...');
      for (final classId in _dirtyClasses) {
        try {
          final students = _studentCache[classId] ?? [];
          final data = {
            'class_id': classId,
            'students': students,
            'updated_at': DateTime.now().toIso8601String(),
            'emergency_save': true
          };
          final emergencyFile = File(_getClassFilePath(classId) + '.emergency');
          await emergencyFile
              .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
          print('紧急保存班级 $classId 数据到: ${emergencyFile.path}');
        } catch (e) {
          print('紧急保存失败: $e');
        }
      }
      _dirtyClasses.clear();
      _flushRetryCount = 0;
    }
  }

  Future<void> _flushAllDirty() async {
    _flushTimer?.cancel();
    await _flushDirtyClasses();
  }

  List<Map<String, dynamic>> loadAllStudents() {
    final allStudents = <Map<String, dynamic>>[];
    for (final classId in getAllClassIds()) {
      allStudents.addAll(loadClassStudents(classId));
    }
    return allStudents;
  }

  Future<Map<String, dynamic>?> findStudentByDevice(
      String computerName, String ip) async {
    if (_activeClass.isNotEmpty) {
      // 使用异步版本，缓存为空时会自动从磁盘文件加载
      final students = await loadClassStudentsAsync(_activeClass);
      for (final s in students) {
        if (s['computer_name'] == computerName && s['ip'] == ip) return s;
      }
      return null;
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateStudentPoints(
      String studentId, int delta) async {
    for (final classId in getAllClassIds()) {
      final students = loadClassStudents(classId);
      final index = students.indexWhere((s) => s['id'] == studentId);
      if (index != -1) {
        final currentPoints = students[index]['points'] as int? ?? 0;
        students[index]['points'] = currentPoints + delta;
        _studentCache[classId] = students;
        _dirtyClasses.add(classId);
        _scheduleFlush();
        return {'points': students[index]['points']};
      }
    }
    return null;
  }

  Response jsonResponse(Map<String, dynamic> data, {int status = 200}) {
    return Response(status, body: json.encode(data), headers: {
      'Content-Type': 'application/json; charset=utf-8',
      ..._corsHeaders
    });
  }

  /// 启动服务器
  Future<void> startServer(int port) async {
    if (_server != null) return;

    final dir = Directory(_informationRoot);
    if (!await dir.exists()) await dir.create(recursive: true);

    await _loadTypingConfig();
    await _loadPointsExchangeConfig();

    // 【修复】启动时预填充 _studentCache，避免登录时找不到已有学生
    await _preloadStudentCache();

    print('启动 HTTP API 服务器...');
    print('题库目录: $questionBankDir');
    print('学生数据目录: $_informationRoot');

    final router = Router();

    // 健康检查
    router.get(
        '/api/health',
        (Request request) => jsonResponse(
            {'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}));

    // 教师状态检查
    router.get('/api/teacher/status',
        (Request request) => jsonResponse({'active': _isTeacherActive}));

    // ============ 认证 API ============

    router.post('/api/auth/login', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        final password = data['password'] as String? ?? '';
        final computerName = data['computer_name'] as String? ?? '';
        final ip = data['ip'] as String? ?? '';

        if (name.isEmpty || password.isEmpty) {
          return jsonResponse({'success': false, 'message': '姓名和密码不能为空'},
              status: 400);
        }

        final loginError = _validateInputLength(name, password, '', '');
        if (loginError != null) return loginError;

        if (_activeClass.isNotEmpty) {
          final students = loadClassStudents(_activeClass);
          for (final s in students) {
            if (s['name'] == name && s['password'] == password) {
              // 保留学生原始班级，不受 _activeClass 影响
              final originalClassId = s['class_id'] as String? ?? _activeClass;
              s['computer_name'] = computerName;
              s['ip'] = ip;
              s['last_login'] = DateTime.now().toIso8601String();
              // 保存到学生原始班级，而不是 _activeClass
              await saveStudentToClass(originalClassId, s);
              return jsonResponse({
                'success': true,
                'data': {
                  'user': {
                    'id': s['id'],
                    'name': s['name'],
                    'role': 'student',
                    'class_id': s['class_id'],
                    'computer_name': computerName,
                    'ip': ip,
                    'points': s['points'] ?? 0,
                  },
                  'token':
                      'student_${s['id']}_${DateTime.now().millisecondsSinceEpoch}',
                }
              });
            }
          }
        }

        return jsonResponse(
            {'success': false, 'message': '姓名或密码错误，请确认已在当前班级注册'},
            status: 401);
      } catch (e) {
        return jsonResponse({'success': false, 'message': '登录失败: $e'},
            status: 500);
      }
    });

    router.post('/api/auth/register', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final name = data['name'] as String? ?? '';
        final password = data['password'] as String? ?? '';
        final classId = data['class_id'] as String? ?? '';
        final computerName = data['computer_name'] as String? ?? '';
        final ip = data['ip'] as String? ?? '';

        if (name.isEmpty || password.isEmpty || classId.isEmpty) {
          return jsonResponse({'success': false, 'message': '姓名、密码和班级不能为空'},
              status: 400);
        }

        final registerError = _validateInputLength(name, password, classId, '');
        if (registerError != null) return registerError;

        final existingStudents = loadClassStudents(classId);
        final existingIndex =
            existingStudents.indexWhere((s) => s['name'] == name);
        if (existingIndex != -1) {
          final existing = existingStudents[existingIndex];
          existing['password'] = password;
          existing['computer_name'] = computerName;
          existing['ip'] = ip;
          existing['last_login'] = DateTime.now().toIso8601String();
          await saveStudentToClass(classId, existing);
          return jsonResponse({
            'success': true,
            'data': {
              'user': {
                'id': existing['id'],
                'name': existing['name'],
                'role': 'student',
                'class_id': classId,
                'computer_name': computerName,
                'ip': ip,
                'points': existing['points'] ?? 0,
              },
              'token':
                  'student_${existing['id']}_${DateTime.now().millisecondsSinceEpoch}',
            }
          });
        }

        final studentId = (_nextStudentId++).toString();
        final student = {
          'id': studentId,
          'name': name,
          'password': password,
          'class_id': classId,
          'computer_name': computerName,
          'ip': ip,
          'points': 0,
          'register_time': DateTime.now().toIso8601String(),
          'last_login': DateTime.now().toIso8601String(),
        };
        await saveStudentToClass(classId, student);
        print('学生注册成功: $name (班级: $classId)');
        return jsonResponse({
          'success': true,
          'data': {
            'user': {
              'id': studentId,
              'name': name,
              'role': 'student',
              'class_id': classId,
              'computer_name': computerName,
              'ip': ip,
              'points': 0,
            },
            'token':
                'student_${studentId}_${DateTime.now().millisecondsSinceEpoch}',
          }
        });
      } catch (e) {
        return jsonResponse({'success': false, 'message': '注册失败: $e'},
            status: 500);
      }
    });

    // ============ 打字配置 API ============

    router.get(
        '/api/typing-config',
        (Request request) =>
            jsonResponse({'success': true, 'data': typingConfig}));

    router.get('/api/typing-config/<type>', (Request request, String type) {
      if (type != 'chinese' && type != 'english')
        return jsonResponse({'success': false, 'error': '类型无效'}, status: 400);
      return jsonResponse({'success': true, 'data': typingConfig[type]});
    });

    router.post('/api/typing-config', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        if (data.containsKey('chinese')) {
          final chinese = data['chinese'] as Map<String, dynamic>;
          typingConfig['chinese'] = {
            'time_limit':
                chinese['time_limit'] ?? typingConfig['chinese']['time_limit'],
            'target_chars': chinese['target_chars'] ??
                typingConfig['chinese']['target_chars'],
            'target_speed': chinese['target_speed'] ??
                typingConfig['chinese']['target_speed'],
            'points_per_error': chinese['points_per_error'] ??
                typingConfig['chinese']['points_per_error'],
            'random': chinese['random'] ?? typingConfig['chinese']['random'],
            'selected_article_index': chinese['selected_article_index'],
          };
        }
        if (data.containsKey('english')) {
          final english = data['english'] as Map<String, dynamic>;
          typingConfig['english'] = {
            'time_limit':
                english['time_limit'] ?? typingConfig['english']['time_limit'],
            'target_chars': english['target_chars'] ??
                typingConfig['english']['target_chars'],
            'target_speed': english['target_speed'] ??
                typingConfig['english']['target_speed'],
            'points_per_error': english['points_per_error'] ??
                typingConfig['english']['points_per_error'],
            'random': english['random'] ?? typingConfig['english']['random'],
            'selected_article_index': english['selected_article_index'],
          };
        }
        print('打字配置已更新: $typingConfig');
        return jsonResponse({'success': true, 'data': typingConfig});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '更新配置失败: $e'},
            status: 500);
      }
    });

    // 教师激活/停用控制
    router.post('/api/teacher/activate', (Request request) {
      _isTeacherActive = true;
      print('教师端已激活（通过 API）');
      return jsonResponse({'success': true, 'active': true});
    });

    router.post('/api/teacher/deactivate', (Request request) {
      _isTeacherActive = false;
      print('教师端已停用（通过 API）');
      return jsonResponse({'success': true, 'active': false});
    });

    // 获取当前活跃班级
    router.get(
        '/api/active-class',
        (Request request) =>
            jsonResponse({'success': true, 'class_id': _activeClass}));

    // 设置当前活跃班级
    router.post('/api/active-class', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        _activeClass = (data['class_id'] as String?) ?? '初一01班';
        print('设置活跃班级: $_activeClass');
        return jsonResponse({'success': true, 'class_id': _activeClass});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '设置失败: $e'},
            status: 500);
      }
    });

    // 获取已有班级列表
    router.get(
        '/api/student/classes',
        (Request request) =>
            jsonResponse({'success': true, 'classes': getAllClassIds()}));

    // 获取题库列表
    router.get('/api/question-banks', (Request request) async {
      final dir = Directory(questionBankDir);
      if (!await dir.exists())
        return jsonResponse({'success': true, 'data': []});
      final banks = <Map<String, dynamic>>[];
      await for (final entity in dir.list()) {
        if (entity is Directory) {
          banks.add({'name': path.basename(entity.path), 'path': entity.path});
        }
      }
      return jsonResponse({'success': true, 'data': banks});
    });

    // 获取当前激活的题库
    router.get(
        '/api/active-bank',
        (Request request) =>
            jsonResponse({'success': true, 'bank': _activeBank ?? ''}));

    // 设置激活的题库
    router.post('/api/active-bank', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        _activeBank = data['bank'] as String?;

        // 从题库文件读取考试时间限制和提前交卷时间
        if (_activeBank != null) {
          _examTimeLimit = await _loadExamTimeLimitFromBank(_activeBank!);
          _earlySubmitMinutes =
              await _loadEarlySubmitMinutesFromBank(_activeBank!);
        }

        clearQuestionBankCache();
        print(
            '激活题库: $_activeBank, 考试时间: $_examTimeLimit 分钟, 提前交卷: $_earlySubmitMinutes 分钟');
        return jsonResponse({
          'success': true,
          'bank': _activeBank ?? '',
          'exam_time_limit': _examTimeLimit,
          'early_submit_minutes': _earlySubmitMinutes,
        });
      } catch (e) {
        return jsonResponse({'success': false, 'error': '设置失败: $e'},
            status: 500);
      }
    });

    // 同步题库文件到学生端（题库JSON + 操作题文件夹）
    router.post('/api/sync-bank-files', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final bankName = data['bank'] as String?;

        if (bankName == null || bankName.isEmpty) {
          return jsonResponse({'success': false, 'error': '缺少题库名称'},
              status: 400);
        }

        // 读取题库JSON
        final bankPath = path.join(questionBankDir, bankName, '题库.json');
        final bankFile = File(bankPath);
        if (!await bankFile.exists()) {
          return jsonResponse({'success': false, 'error': '题库不存在'},
              status: 404);
        }

        final bankContent = await bankFile.readAsString();

        // 收集操作题文件列表
        final operationPath = path.join(questionBankDir, bankName, '操作题');
        final operationDir = Directory(operationPath);
        final operationFiles = <Map<String, dynamic>>[];

        if (await operationDir.exists()) {
          await for (final entity in operationDir.list(recursive: true)) {
            if (entity is File) {
              final relativePath =
                  entity.path.substring(operationDir.path.length + 1);
              final fileContent = await entity.readAsBytes();
              final base64Content = base64Encode(fileContent);
              operationFiles.add({
                'path': relativePath.replaceAll('\\', '/'),
                'content': base64Content,
              });
            }
          }
        }

        print('同步题库文件: $bankName, 操作题文件数: ${operationFiles.length}');

        return jsonResponse({
          'success': true,
          'bank_name': bankName,
          'bank_content': bankContent, // 题库JSON原始内容
          'operation_files': operationFiles,
        });
      } catch (e) {
        print('同步题库文件失败: $e');
        return jsonResponse({'success': false, 'error': '同步失败: $e'},
            status: 500);
      }
    });

    // 获取考试时间限制
    router.get(
        '/api/exam-time-limit',
        (Request request) => jsonResponse({
              'success': true,
              'exam_time_limit': _examTimeLimit,
            }));

    // 获取提前交卷时间（考试开始多少分钟后可交卷）
    router.get(
        '/api/early-submit-minutes',
        (Request request) => jsonResponse({
              'success': true,
              'early_submit_minutes': _earlySubmitMinutes,
            }));

    // 获取指定题库内容
    router.get('/api/question-banks/<bank_name>',
        (Request request, String bankName) async {
      // 【修复】对 bankName 进行 URL 解码，确保中文字符和特殊字符正确处理
      final decodedBankName = Uri.decodeComponent(bankName);
      print('获取题库内容: $bankName -> 解码后: $decodedBankName');
      final data = await loadQuestionBank(decodedBankName);
      if (data == null) {
        print(
            '题库文件不存在: ${path.join(questionBankDir, decodedBankName, '题库.json')}');
        return jsonResponse({'success': false, 'error': '题库不存在'}, status: 404);
      }
      return jsonResponse({'success': true, 'data': data});
    });

    // 获取学生详细数据
    router.get('/api/student-detail/<student_id>',
        (Request request, String studentId) async {
      try {
        Map<String, dynamic>? studentInfo;
        for (final classId in getAllClassIds()) {
          final students = loadClassStudents(classId);
          for (final s in students) {
            if (s['id'] == studentId) {
              studentInfo = Map<String, dynamic>.from(s);
              studentInfo['class_id'] = classId;
              break;
            }
          }
          if (studentInfo != null) break;
        }

        final examResults = <Map<String, dynamic>>[];
        final resolvedClassId = studentInfo?['class_id'] as String? ??
            _findClassByStudentId(studentId);
        if (resolvedClassId != null) {
          final examData =
              await _readScoreFileAsync(resolvedClassId, '小测成绩表.json');
          for (final r in (examData['records'] as List<dynamic>? ?? [])) {
            final record = r as Map<String, dynamic>;
            if (record['student_id'] == studentId) examResults.add(record);
          }

          final typingData =
              await _readScoreFileAsync(resolvedClassId, '中英文打字成绩表.json');
          final typingResults = <Map<String, dynamic>>[];
          for (final r in (typingData['records'] as List<dynamic>? ?? [])) {
            final record = r as Map<String, dynamic>;
            if (record['student_id'] == studentId) typingResults.add(record);
          }

          final wrongData =
              await _readScoreFileAsync(resolvedClassId, '错题记录.json');
          final wrongQuestions = <Map<String, dynamic>>[];
          for (final r in (wrongData['records'] as List<dynamic>? ?? [])) {
            final record = r as Map<String, dynamic>;
            if (record['student_id'] == studentId) wrongQuestions.add(record);
          }

          final pointsData =
              await _readScoreFileAsync(resolvedClassId, '积分增加详细表.json');
          final pointsRecords = <Map<String, dynamic>>[];
          for (final r in (pointsData['records'] as List<dynamic>? ?? [])) {
            final record = r as Map<String, dynamic>;
            if (record['student_id'] == studentId) pointsRecords.add(record);
          }

          return jsonResponse({
            'success': true,
            'student': studentInfo,
            'exam_results': examResults,
            'typing_results': typingResults,
            'wrong_questions': wrongQuestions,
            'points_records': pointsRecords,
          });
        }

        return jsonResponse({
          'success': true,
          'student': studentInfo,
          'exam_results': [],
          'typing_results': [],
          'wrong_questions': [],
          'points_records': []
        });
      } catch (e) {
        return jsonResponse({'success': false, 'error': '获取学生详情失败: $e'},
            status: 500);
      }
    });

    // 学生端通过IP和电脑名称查找学生信息
    router.post('/api/student/find', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final computerName = data['computer_name'] ?? '';
        final ip = data['ip'] ?? '';
        final foundStudent = await findStudentByDevice(computerName, ip);
        if (foundStudent != null) {
          return jsonResponse({'student': foundStudent});
        } else {
          return jsonResponse({'student': null});
        }
      } catch (e) {
        return jsonResponse({'success': false, 'error': '查找失败: $e'},
            status: 500);
      }
    });

    // 学生注册接口
    router.post('/api/student/register', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final classId = data['class_id'] as String? ?? '';
        if (classId.isEmpty)
          return jsonResponse({'success': false, 'error': '缺少class_id'},
              status: 400);

        final student = {
          'id': data['id'] ?? (_nextStudentId++).toString(),
          'name': data['name'] ?? '',
          'password': data['password'] ?? '',
          'class_id': classId,
          'computer_name': data['computer_name'] ?? '',
          'ip': data['ip'] ?? '',
          'points': 0,
          'register_time': DateTime.now().toIso8601String(),
        };
        await saveStudentToClass(classId, student);
        print('学生已注册到班级 $classId: ${student['name']}');
        return jsonResponse(
            {'success': true, 'message': '注册成功', 'student': student});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '注册失败: $e'},
            status: 500);
      }
    });

    // 更新学生积分
    router.post('/api/student/update-points', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final studentId = data['student_id'] as String? ?? '';
        final delta = data['delta'] as int? ?? 0;
        if (studentId.isEmpty)
          return jsonResponse({'success': false, 'error': '缺少student_id'},
              status: 400);

        final result = await updateStudentPoints(studentId, delta);
        if (result != null) {
          return jsonResponse({'success': true, 'points': result['points']});
        } else {
          return jsonResponse({'success': false, 'error': '学生不存在'},
              status: 404);
        }
      } catch (e) {
        return jsonResponse({'success': false, 'error': '更新积分失败: $e'},
            status: 500);
      }
    });

    // 获取打字文章列表
    router.get('/api/typing-articles/<type>', (Request request, String type) {
      if (type != 'chinese' && type != 'english')
        return jsonResponse(
            {'success': false, 'error': '类型无效，支持 chinese 和 english'},
            status: 400);
      final articles = TypingArticleService.getAllArticles(type);
      return jsonResponse({'success': true, 'data': articles});
    });

    // 获取随机打字文章
    router.get('/api/typing-articles/<type>/random',
        (Request request, String type) async {
      if (type != 'chinese' && type != 'english')
        return jsonResponse(
            {'success': false, 'error': '类型无效，支持 chinese 和 english'},
            status: 400);
      final article = await TypingArticleService.getRandomArticle(type);
      if (article == null)
        return jsonResponse({'success': false, 'error': '暂无文章'}, status: 404);
      return jsonResponse({'success': true, 'content': article});
    });

    // ============ 成绩数据 API ============

    /// 学生端提交答题数据
    router.post('/api/exam/submit', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final studentId = data['student_id'] as String? ?? '';
        final studentName = data['student_name'] as String? ?? '';
        final bankName = data['bank_name'] as String? ?? '';
        final score = data['score'] as int? ?? 0;
        final classId = data['class_id'] as String? ?? '';
        final questionsDetail =
            data['questions_detail'] as List<dynamic>? ?? [];

        if (studentId.isEmpty) {
          return jsonResponse({'success': false, 'error': '缺少student_id'},
              status: 400);
        }

        final resolvedClassId =
            classId.isNotEmpty ? classId : _findClassByStudentId(studentId);
        if (resolvedClassId == null) {
          return jsonResponse({'success': false, 'error': '找不到学生班级'},
              status: 404);
        }

        // 计算积分
        final points = (score * 0.1).round();

        // 保存到小测成绩表
        await _withScoreFileLock(resolvedClassId, '小测成绩表.json', (examData) {
          final records = (examData['records'] as List<dynamic>?) ?? [];
          records.add({
            'student_id': studentId,
            'student_name': studentName,
            'exam_name': bankName,
            'score': score,
            'points': points,
            'submit_time': DateTime.now().toIso8601String(),
          });
        });

        // 保存错题记录
        final wrongQuestions =
            questionsDetail.where((q) => q['is_correct'] == false).toList();
        final wrongCount = wrongQuestions.length;
        final totalCount = questionsDetail.length;

        await _withScoreFileLock(resolvedClassId, '错题记录.json', (wrongData) {
          final records = (wrongData['records'] as List<dynamic>?) ?? [];
          records.add({
            'student_id': studentId,
            'student_name': studentName,
            'exam_name': bankName,
            'submit_time': DateTime.now().toIso8601String(),
            'wrong_questions': wrongQuestions,
            'wrong_count': wrongCount,
            'total_count': totalCount,
          });
        });

        // 同步积分
        if (points > 0) {
          await _syncStudentTotalPoints(resolvedClassId, studentId);
        }

        // 返回教师端权威积分值，供学生端同步
        final totalPoints = _studentPointsCache[studentId] ?? 0;

        print('答卷已保存: $studentName - $bankName - 得分$score');
        return jsonResponse({
          'success': true,
          'message': '提交成功',
          'data': {
            'score': score,
            'points': points,
            'total_points': totalPoints,
          }
        });
      } catch (e) {
        return jsonResponse({'success': false, 'error': '提交答卷失败: $e'},
            status: 500);
      }
    });

    router.post('/api/score/exam', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final studentId = data['student_id'] as String? ?? '';
        final studentName = data['student_name'] as String? ?? '';
        final examName = data['exam_name'] as String? ?? '';
        final score = data['score'] as int? ?? 0;
        final points = data['points'] as int? ?? 0;
        final classId = data['class_id'] as String? ?? '';

        if (studentId.isEmpty)
          return jsonResponse({'success': false, 'error': '缺少student_id'},
              status: 400);

        final resolvedClassId =
            classId.isNotEmpty ? classId : _findClassByStudentId(studentId);
        if (resolvedClassId == null)
          return jsonResponse({'success': false, 'error': '找不到学生班级'},
              status: 404);

        await _withScoreFileLock(resolvedClassId, '小测成绩表.json', (examData) {
          final records = (examData['records'] as List<dynamic>?) ?? [];
          records.add({
            'student_id': studentId,
            'student_name': studentName,
            'exam_name': examName,
            'score': score,
            'points': points,
            'submit_time': DateTime.now().toIso8601String(),
          });
        });

        if (points > 0)
          await _syncStudentTotalPoints(resolvedClassId, studentId);

        print('小测成绩已保存: $studentName - $examName - 得分$score');
        return jsonResponse({'success': true});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '保存小测成绩失败: $e'},
            status: 500);
      }
    });

    router.post('/api/score/typing', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final studentId = data['student_id'] as String? ?? '';
        final studentName = data['student_name'] as String? ?? '';
        final type = data['type'] as String? ?? '';
        final score = data['score'] as int? ?? 0;
        final points = data['points'] as int? ?? 0;
        final classId = data['class_id'] as String? ?? '';
        final speed = data['speed'] as int? ?? 0;
        final accuracy = data['accuracy'] as int? ?? 0;
        final elapsedSeconds = data['elapsed_seconds'] as int? ?? 0;
        final correctChars = data['correct_chars'] as int? ?? 0;
        final totalChars = data['total_chars'] as int? ?? 0;
        final errorCount = data['error_count'] as int? ?? 0;

        if (studentId.isEmpty)
          return jsonResponse({'success': false, 'error': '缺少student_id'},
              status: 400);

        final resolvedClassId =
            classId.isNotEmpty ? classId : _findClassByStudentId(studentId);
        if (resolvedClassId == null)
          return jsonResponse({'success': false, 'error': '找不到学生班级'},
              status: 404);

        await _withScoreFileLock(resolvedClassId, '中英文打字成绩表.json',
            (typingData) {
          final records = (typingData['records'] as List<dynamic>?) ?? [];
          records.add({
            'student_id': studentId,
            'student_name': studentName,
            'type': type,
            'score': score,
            'points': points,
            'speed': speed,
            'accuracy': accuracy,
            'elapsed_seconds': elapsedSeconds,
            'correct_chars': correctChars,
            'total_chars': totalChars,
            'error_count': errorCount,
            'submit_time': DateTime.now().toIso8601String(),
          });
        });

        if (points > 0)
          await _syncStudentTotalPoints(resolvedClassId, studentId);

        // 返回教师端权威积分值，供学生端同步
        final totalPoints = _studentPointsCache[studentId] ?? 0;

        final typeName = type == 'chinese' ? '中文打字' : '英文打字';
        print('打字成绩已保存: $studentName - $typeName - 得分$score');
        return jsonResponse({
          'success': true,
          'total_points': totalPoints,
        });
      } catch (e) {
        return jsonResponse({'success': false, 'error': '保存打字成绩失败: $e'},
            status: 500);
      }
    });

    router.post('/api/score/points', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final studentId = data['student_id'] as String? ?? '';
        final studentName = data['student_name'] as String? ?? '';
        final points = data['points'] as int? ?? 0;
        final classId = data['class_id'] as String? ?? '';

        if (studentId.isEmpty)
          return jsonResponse({'success': false, 'error': '缺少student_id'},
              status: 400);

        final resolvedClassId =
            classId.isNotEmpty ? classId : _findClassByStudentId(studentId);
        if (resolvedClassId == null)
          return jsonResponse({'success': false, 'error': '找不到学生班级'},
              status: 404);

        await _withScoreFileLock(resolvedClassId, '积分增加详细表.json', (pointsData) {
          final records = (pointsData['records'] as List<dynamic>?) ?? [];
          final today = DateTime.now().toString().substring(0, 10);
          final existingIndex = records.indexWhere(
              (r) => r['student_id'] == studentId && r['date'] == today);
          if (existingIndex != -1) {
            final existing = records[existingIndex] as Map<String, dynamic>;
            existing['points'] = (existing['points'] as int? ?? 0) + points;
          } else {
            records.add({
              'student_id': studentId,
              'student_name': studentName,
              'points': points,
              'date': today
            });
          }
        });

        print('积分变动已保存: $studentName +$points');
        return jsonResponse({'success': true});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '保存积分变动失败: $e'},
            status: 500);
      }
    });

    // 获取班级成绩汇总
    router.get('/api/score/summary/<class_id>',
        (Request request, String classId) async {
      try {
        final decodedClassId = Uri.decodeComponent(classId);
        print('获取成绩汇总: $classId -> $decodedClassId');
        final examData =
            await _readScoreFileAsync(decodedClassId, '小测成绩表.json');
        final typingData =
            await _readScoreFileAsync(decodedClassId, '中英文打字成绩表.json');
        final pointsData =
            await _readScoreFileAsync(decodedClassId, '积分增加详细表.json');
        final detailData =
            await _readScoreFileAsync(decodedClassId, '学生成绩详细情况表.json');
        final wrongData =
            await _readScoreFileAsync(decodedClassId, '错题记录.json');

        return jsonResponse({
          'success': true,
          'exam_records': examData['records'] ?? [],
          'typing_records': typingData['records'] ?? [],
          'points_records': pointsData['records'] ?? [],
          'detail_records': detailData['records'] ?? [],
          'wrong_questions': wrongData['records'] ?? [],
        });
      } catch (e) {
        return jsonResponse({'success': false, 'error': '获取成绩汇总失败: $e'},
            status: 500);
      }
    });

    // 获取课表
    router.get('/api/schedule', (Request request) async {
      try {
        final scheduleFile = File(
            path.join(_projectRoot, 'information', 'manage', 'schedule.json'));
        if (await scheduleFile.exists()) {
          final content = json.decode(await scheduleFile.readAsString());
          return jsonResponse({'success': true, 'data': content});
        }
        return jsonResponse({'success': true, 'data': null});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '获取课表失败: $e'},
            status: 500);
      }
    });

    // 保存课表
    router.post('/api/schedule', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final scheduleDir =
            Directory(path.join(_projectRoot, 'information', 'manage'));
        if (!scheduleDir.existsSync()) scheduleDir.createSync(recursive: true);
        final scheduleFile = File(path.join(scheduleDir.path, 'schedule.json'));
        await scheduleFile
            .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
        return jsonResponse({'success': true});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '保存课表失败: $e'},
            status: 500);
      }
    });

    // ============ 积分兑换 API ============

    // 获取积分兑换商品列表
    router.get('/api/points-exchange', (Request request) {
      return jsonResponse({
        'success': true,
        'data': pointsExchangeConfig,
      });
    });

    // 更新积分兑换商品配置（教师端）
    router.post('/api/points-exchange', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        pointsExchangeConfig = data;
        await _savePointsExchangeConfig();
        print('积分兑换配置已更新');
        return jsonResponse({'success': true, 'data': pointsExchangeConfig});
      } catch (e) {
        return jsonResponse({'success': false, 'error': '更新积分兑换配置失败: $e'},
            status: 500);
      }
    });

    // 学生兑换商品
    router.post('/api/points-exchange/redeem', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final studentId = data['student_id'] as String? ?? '';
        final studentName = data['student_name'] as String? ?? '';
        final itemId = data['item_id'] as int? ?? 0;

        if (studentId.isEmpty) {
          return jsonResponse({'success': false, 'error': '缺少student_id'},
              status: 400);
        }
        if (itemId == 0) {
          return jsonResponse({'success': false, 'error': '缺少item_id'},
              status: 400);
        }

        // 查找兑换商品
        final items = (pointsExchangeConfig['items'] as List<dynamic>? ?? []);
        final itemIndex = items.indexWhere((i) => i['id'] == itemId);
        if (itemIndex == -1) {
          return jsonResponse({'success': false, 'error': '商品不存在'},
              status: 404);
        }

        final item = items[itemIndex] as Map<String, dynamic>;

        // 检查商品是否启用
        if (item['enabled'] != true) {
          return jsonResponse({'success': false, 'error': '该商品已下架'});
        }

        // 检查库存
        final stock = item['stock'] as int? ?? -1;
        if (stock != -1 && stock <= 0) {
          return jsonResponse({'success': false, 'error': '商品库存不足'});
        }

        final pointsCost = item['points_cost'] as int? ?? 0;

        // 查找学生并检查积分
        String? studentClassId;
        Map<String, dynamic>? studentData;
        for (final classId in getAllClassIds()) {
          final students = loadClassStudents(classId);
          for (final s in students) {
            if (s['id'] == studentId) {
              studentClassId = classId;
              studentData = s;
              break;
            }
          }
          if (studentData != null) break;
        }

        if (studentData == null || studentClassId == null) {
          return jsonResponse({'success': false, 'error': '学生不存在'},
              status: 404);
        }

        final currentPoints = studentData['points'] as int? ?? 0;
        if (currentPoints < pointsCost) {
          return jsonResponse({
            'success': false,
            'error': '积分不足，需要 $pointsCost 积分，当前 $currentPoints 积分'
          });
        }

        // 扣减学生积分
        studentData['points'] = currentPoints - pointsCost;
        _studentCache[studentClassId] = loadClassStudents(studentClassId);
        final students = _studentCache[studentClassId]!;
        final sIndex = students.indexWhere((s) => s['id'] == studentId);
        if (sIndex != -1) {
          students[sIndex]['points'] = currentPoints - pointsCost;
        }
        _dirtyClasses.add(studentClassId);
        _scheduleFlush();

        // 扣减库存
        if (stock != -1) {
          item['stock'] = stock - 1;
        }

        // 写入兑换记录
        final records =
            (pointsExchangeConfig['exchange_records'] as List<dynamic>? ?? []);
        records.add({
          'student_id': studentId,
          'student_name': studentName,
          'item_id': itemId,
          'item_name': item['name'] ?? '',
          'points_cost': pointsCost,
          'exchange_time': DateTime.now().toIso8601String(),
        });
        pointsExchangeConfig['exchange_records'] = records;

        await _savePointsExchangeConfig();

        // 更新积分缓存
        _studentPointsCache[studentId] = currentPoints - pointsCost;

        print('学生 $studentName 兑换商品 ${item['name']}，消耗 $pointsCost 积分');
        return jsonResponse({
          'success': true,
          'message': '兑换成功',
          'points': currentPoints - pointsCost,
          'item_name': item['name'] ?? '',
          'points_cost': pointsCost,
        });
      } catch (e) {
        return jsonResponse({'success': false, 'error': '兑换失败: $e'},
            status: 500);
      }
    });

    // 获取兑换记录
    router.get('/api/points-exchange/records', (Request request) {
      final records = pointsExchangeConfig['exchange_records'] ?? [];
      return jsonResponse({
        'success': true,
        'records': records,
      });
    });

    // 静态文件服务
    final filesMiddleware = createMiddleware(
      requestHandler: (Request request) async {
        final reqPath = request.url.path;
        if (reqPath.startsWith('files/')) {
          String relativePath = reqPath.substring(6);
          final decodedPath = Uri.decodeComponent(relativePath);
          // 安全检查：拒绝包含路径遍历的请求
          // 不能仅用 replaceAll('..', '')，因为 "....//" 替换后变成 "../"
          if (decodedPath.contains('..')) {
            print('警告: 静态文件路径包含遍历字符，已拒绝: $decodedPath');
            return Response.forbidden('访问被拒绝');
          }
          final absolutePath =
              path.normalize(path.join(questionBankDir, decodedPath));
          if (!absolutePath.startsWith(path.normalize(questionBankDir))) {
            print('警告: 静态文件路径越界，已拒绝: $decodedPath');
            return Response.forbidden('访问被拒绝');
          }
          final file = File(absolutePath);
          print(
              '静态文件请求: $decodedPath -> $absolutePath, 存在: ${file.existsSync()}');
          if (file.existsSync()) {
            final contentType = _getContentType(decodedPath);
            final bytes = await file.readAsBytes();
            return Response.ok(bytes, headers: {'Content-Type': contentType});
          }
          return Response.notFound('文件不存在: $absolutePath');
        }
        return null;
      },
    );

    final handler = const Pipeline()
        .addMiddleware(addCorsHeaders())
        .addMiddleware(limitBodySize())
        .addMiddleware(logRequests())
        .addMiddleware(filesMiddleware)
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, '0.0.0.0', port);
    print('HTTP API 服务器已启动: http://localhost:${_server!.port}');
    print('静态文件: http://localhost:${_server!.port}/files/');
  }

  String _getContentType(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.pdf':
        return 'application/pdf';
      case '.json':
        return 'application/json';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> stopServer() async {
    if (_server != null) {
      await _flushAllDirty();
      await _server!.close(force: true);
      _server = null;
      print('HTTP API 服务器已停止');
    }
  }

  Future<void> dispose() async {
    if (_server != null) {
      try {
        await _server!.close(force: true);
        _server = null;
        print('HttpServerService: HTTP 服务器已关闭');
      } catch (e) {
        print('HttpServerService: 关闭 HTTP 服务器失败: $e');
      }
    }
    await _flushAllDirty();
    _flushTimer?.cancel();
    _flushTimer = null;
    _questionBankCache.clear();
    _questionBankLoading.clear();
    _studentCache.clear();
    _studentPointsCache.clear();
    _todayPointsCache.clear();
    _dirtyClasses.clear();
    _scoreFileLocks.clear();
    print('HttpServerService 已释放');
  }

  /// 设置教师激活状态
  void setTeacherActive(bool active) {
    _isTeacherActive = active;
    print(active ? '教师端已激活' : '教师端已停用');
  }

  /// 设置活跃班级（内部方法，供 main.dart 直接调用，避免 HTTP 回环）
  void setActiveClass(String className) {
    _activeClass = className;
    print('活跃班级已设置: $className');
  }

  /// 从题库文件读取考试时间限制
  Future<int> _loadExamTimeLimitFromBank(String bankName) async {
    try {
      final bankPath = path.join(questionBankDir, bankName, '题库.json');
      final file = File(bankPath);
      if (!await file.exists()) {
        return 30; // 默认30分钟
      }
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      return data['examTimeLimit'] as int? ?? 30;
    } catch (e) {
      print('读取题库考试时间限制失败: $e');
      return 30; // 默认30分钟
    }
  }

  /// 从题库文件读取提前交卷时间（考试开始多少分钟后可交卷）
  Future<int> _loadEarlySubmitMinutesFromBank(String bankName) async {
    try {
      final bankPath = path.join(questionBankDir, bankName, '题库.json');
      final file = File(bankPath);
      if (!await file.exists()) {
        return 25; // 默认25分钟
      }
      final content = await file.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      return data['earlySubmitMinutes'] as int? ?? 25;
    } catch (e) {
      print('读取题库提前交卷时间失败: $e');
      return 25; // 默认25分钟
    }
  }

  /// 【修复】启动时预填充 _studentCache，从磁盘加载所有班级学生数据
  /// 避免登录时因缓存为空而找不到已有学生，导致重复注册
  Future<void> _preloadStudentCache() async {
    try {
      final classIds = getAllClassIds();
      int totalLoaded = 0;
      for (final classId in classIds) {
        final file = File(_getClassFilePath(classId));
        if (!await file.exists()) continue;
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        final students = (data['students'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>() ??
            [];
        _studentCache[classId] = students;
        totalLoaded += students.length;
      }
      print('已预填充学生缓存: ${classIds.length} 个班级，共 $totalLoaded 名学生');

      // 初始化学生ID自增计数器：扫描所有现有学生ID，找到最大值
      int maxId = 0;
      for (final students in _studentCache.values) {
        for (final s in students) {
          final idStr = s['id']?.toString() ?? '';
          final idNum = int.tryParse(idStr) ?? 0;
          if (idNum > maxId) maxId = idNum;
        }
      }
      _nextStudentId = maxId + 1;
      print('学生ID自增计数器已初始化: 起始值=$_nextStudentId (最大现有ID=$maxId)');
    } catch (e) {
      print('预填充学生缓存失败: $e');
    }
  }
}
