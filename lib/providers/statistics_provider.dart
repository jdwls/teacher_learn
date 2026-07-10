import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// 学生成绩汇总（用于排名）
class StudentSummary {
  final String studentId;
  final String studentName;
  int totalScore;
  int totalCount;
  int totalPoints;
  int maxScore;

  StudentSummary({
    required this.studentId,
    required this.studentName,
    this.totalScore = 0,
    this.totalCount = 0,
    this.totalPoints = 0,
    this.maxScore = 0,
  });

  double get avgScore => maxScore > 0 ? maxScore.toDouble() : 0;
}

/// 分数段统计
class ScoreSegment {
  final String label;
  final int count;
  final double percentage;

  ScoreSegment({
    required this.label,
    required this.count,
    required this.percentage,
  });
}

/// 统计概览数据
class StatsOverview {
  final int participantCount;
  final double averageScore;
  final int highestScore;
  final int lowestScore;
  final int totalSubmissions;
  final List<ScoreSegment> distribution;

  StatsOverview({
    required this.participantCount,
    required this.averageScore,
    required this.highestScore,
    required this.lowestScore,
    required this.totalSubmissions,
    required this.distribution,
  });

  static StatsOverview empty() => StatsOverview(
        participantCount: 0,
        averageScore: 0,
        highestScore: 0,
        lowestScore: 0,
        totalSubmissions: 0,
        distribution: [],
      );
}

/// 统计数据 Provider
/// 对接真实 API：/api/score/summary/<class_id>
class StatisticsProvider extends ChangeNotifier {
  // 原始数据
  List<Map<String, dynamic>> _examRecords = [];
  List<Map<String, dynamic>> _typingRecords = [];
  List<Map<String, dynamic>> _wrongQuestions = [];

  // 班级列表
  List<String> _classList = [];
  String? _selectedClass;
  String? _selectedExamName; // 选中的题库名称（null 表示全部）
  DateTimeRange? _selectedDateRange; // 选中的日期范围（null 表示全部）

  bool _isLoading = false;
  String? _error;

  // Getters
  List<String> get classList => _classList;
  String? get selectedClass => _selectedClass;
  String? get selectedExamName => _selectedExamName;
  DateTimeRange? get selectedDateRange => _selectedDateRange;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// 加载班级列表
  Future<void> loadClassList() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://localhost:20020/api/student/classes'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _classList = List<String>.from(data['classes'] ?? []);
          notifyListeners();
        }
      }
    } catch (e) {
      print('加载班级列表失败: $e');
    }
  }

  /// 设置当前班级并加载数据
  Future<void> selectClass(String classId) async {
    _selectedClass = classId;
    notifyListeners();
    await loadStatistics(classId);
  }

  /// 加载指定班级的统计数据
  Future<void> loadStatistics(String classId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final encodedClassId = Uri.encodeComponent(classId);
      final response = await http
          .get(
            Uri.parse(
                'http://localhost:20020/api/score/summary/$encodedClassId'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _examRecords = List<Map<String, dynamic>>.from(
              (data['exam_records'] ?? []).cast<Map<String, dynamic>>());
          _typingRecords = List<Map<String, dynamic>>.from(
              (data['typing_records'] ?? []).cast<Map<String, dynamic>>());
          _wrongQuestions = List<Map<String, dynamic>>.from(
              (data['wrong_questions'] ?? []).cast<Map<String, dynamic>>());
        } else {
          _error = data['error'] ?? '加载失败';
        }
      } else {
        _error = '服务器返回错误: ${response.statusCode}';
      }
    } catch (e) {
      _error = '连接服务器失败: $e';
      print('加载统计数据失败: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ============ 日期筛选辅助方法 ============

  /// 判断记录的提交时间是否在选中日期范围内
  bool _isInDateRange(Map<String, dynamic> record) {
    if (_selectedDateRange == null) return true;
    final timeStr = record['submit_time']?.toString() ?? '';
    if (timeStr.isEmpty) return true;
    final submitTime = DateTime.tryParse(timeStr);
    if (submitTime == null) return true;
    final start = DateTime(_selectedDateRange!.start.year,
        _selectedDateRange!.start.month, _selectedDateRange!.start.day);
    final end = DateTime(_selectedDateRange!.end.year,
        _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
    return !submitTime.isBefore(start) && !submitTime.isAfter(end);
  }

  /// 获取日期筛选后的打字记录
  List<Map<String, dynamic>> get _dateFilteredTypingRecords {
    if (_selectedDateRange == null) return _typingRecords;
    return _typingRecords.where(_isInDateRange).toList();
  }

  /// 选择日期范围
  void selectDateRange(DateTimeRange? dateRange) {
    _selectedDateRange = dateRange;
    notifyListeners();
  }

  // ============ 课堂小测统计 ============

  /// 获取过滤后的小测记录（按题库和日期筛选）
  List<Map<String, dynamic>> get _filteredExamRecords {
    var records = _examRecords;
    if (_selectedExamName != null) {
      records =
          records.where((r) => r['exam_name'] == _selectedExamName).toList();
    }
    if (_selectedDateRange != null) {
      records = records.where(_isInDateRange).toList();
    }
    return records;
  }

  /// 获取课堂小测概览
  StatsOverview get examOverview {
    return _calculateOverview(_filteredExamRecords, 'score');
  }

  /// 获取当前筛选后的小测分数列表（用于10分段柱状图）
  List<int> get examScores {
    return _filteredExamRecords
        .map((r) => (r['score'] as num?)?.toInt() ?? 0)
        .where((s) => s > 0)
        .toList();
  }

  /// 获取课堂小测学生排名（同一学生多次小测取平均分）
  List<StudentSummary> get examRankings {
    return _calculateRankings(_filteredExamRecords, 'score');
  }

  /// 获取课堂小测的考试名称列表（用于筛选）
  List<String> get examNames {
    final names = <String>{};
    for (final record in _examRecords) {
      final name = record['exam_name']?.toString() ?? '';
      if (name.isNotEmpty) names.add(name);
    }
    return names.toList();
  }

  /// 获取过滤后的错题记录（按题库和日期筛选）
  List<Map<String, dynamic>> get filteredWrongQuestions {
    var records = _wrongQuestions;
    if (_selectedExamName != null) {
      records =
          records.where((r) => r['exam_name'] == _selectedExamName).toList();
    }
    if (_selectedDateRange != null) {
      records = records.where(_isInDateRange).toList();
    }
    return records;
  }

  /// 选择题库筛选
  void selectExamName(String? examName) {
    _selectedExamName = examName;
    notifyListeners();
  }

  /// 获取指定学生的错题记录（按当前题库筛选）
  List<Map<String, dynamic>> getStudentWrongQuestions(String studentId) {
    final filtered = filteredWrongQuestions;
    return filtered.where((r) => r['student_id'] == studentId).toList();
  }

  /// 获取指定学生的提交次数（按当前题库筛选）
  int getStudentSubmitCount(String studentId) {
    return _filteredExamRecords
        .where((r) => r['student_id'] == studentId)
        .length;
  }

  /// 获取学生打字平均速度
  int getStudentTypingAvgSpeed(String studentId, String type) {
    final filtered = _dateFilteredTypingRecords
        .where((r) => r['student_id'] == studentId && r['type'] == type)
        .toList();
    if (filtered.isEmpty) return 0;
    int totalSpeed = 0;
    int count = 0;
    for (final r in filtered) {
      final speed = (r['speed'] as num?)?.toInt() ?? 0;
      if (speed > 0) {
        totalSpeed += speed;
        count++;
      }
    }
    return count > 0 ? (totalSpeed / count).round() : 0;
  }

  /// 获取学生打字平均准确率
  int getStudentTypingAvgAccuracy(String studentId, String type) {
    final filtered = _dateFilteredTypingRecords
        .where((r) => r['student_id'] == studentId && r['type'] == type)
        .toList();
    if (filtered.isEmpty) return 0;
    int totalAccuracy = 0;
    int count = 0;
    for (final r in filtered) {
      final accuracy = (r['accuracy'] as num?)?.toInt() ?? 0;
      if (accuracy > 0) {
        totalAccuracy += accuracy;
        count++;
      }
    }
    return count > 0 ? (totalAccuracy / count).round() : 0;
  }

  /// 获取学生打字详细记录列表
  List<Map<String, dynamic>> getStudentTypingRecords(
      String studentId, String type) {
    return _dateFilteredTypingRecords
        .where((r) => r['student_id'] == studentId && r['type'] == type)
        .toList();
  }

  /// 获取题库列表（从 HTTP API）
  List<String> _bankList = [];
  List<String> get bankList => _bankList;

  Future<void> loadBankList() async {
    try {
      final response = await http
          .get(
            Uri.parse('http://localhost:20020/api/question-banks'),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _bankList = (data['data'] as List<dynamic>?)
                  ?.map((b) => b['name']?.toString() ?? '')
                  .where((n) => n.isNotEmpty)
                  .toList() ??
              [];
          notifyListeners();
        }
      }
    } catch (e) {
      // ignore
    }
  }

  // ============ 中文打字统计 ============

  /// 获取中文打字概览
  StatsOverview get chineseTypingOverview {
    final filtered = _dateFilteredTypingRecords
        .where((r) => r['type'] == 'chinese')
        .toList();
    return _calculateOverview(filtered, 'score');
  }

  /// 获取中文打字学生排名
  List<StudentSummary> get chineseTypingRankings {
    final filtered = _dateFilteredTypingRecords
        .where((r) => r['type'] == 'chinese')
        .toList();
    return _calculateRankings(filtered, 'score');
  }

  // ============ 英文打字统计 ============

  /// 获取英文打字概览
  StatsOverview get englishTypingOverview {
    final filtered = _dateFilteredTypingRecords
        .where((r) => r['type'] == 'english')
        .toList();
    return _calculateOverview(filtered, 'score');
  }

  /// 获取英文打字学生排名
  List<StudentSummary> get englishTypingRankings {
    final filtered = _dateFilteredTypingRecords
        .where((r) => r['type'] == 'english')
        .toList();
    return _calculateRankings(filtered, 'score');
  }

  // ============ 通用计算方法 ============

  /// 计算概览统计
  StatsOverview _calculateOverview(
      List<Map<String, dynamic>> records, String scoreField) {
    if (records.isEmpty) return StatsOverview.empty();

    final scores = records
        .map((r) => (r[scoreField] as num?)?.toInt() ?? 0)
        .where((s) => s > 0)
        .toList();

    if (scores.isEmpty) return StatsOverview.empty();

    // 参与学生数（去重）
    final studentIds = <String>{};
    for (final record in records) {
      studentIds.add(record['student_id']?.toString() ?? '');
    }

    final avg = scores.reduce((a, b) => a + b) / scores.length;
    final highest = scores.reduce((a, b) => a > b ? a : b);
    final lowest = scores.reduce((a, b) => a < b ? a : b);

    // 分数段分布
    final distribution = _calculateDistribution(scores);

    return StatsOverview(
      participantCount: studentIds.length,
      averageScore: avg,
      highestScore: highest,
      lowestScore: lowest,
      totalSubmissions: records.length,
      distribution: distribution,
    );
  }

  /// 计算分数段分布
  List<ScoreSegment> _calculateDistribution(List<int> scores) {
    final segments = [
      {'label': '90-100', 'min': 90, 'max': 101, 'color': 0},
      {'label': '80-89', 'min': 80, 'max': 90, 'color': 1},
      {'label': '70-79', 'min': 70, 'max': 80, 'color': 2},
      {'label': '60-69', 'min': 60, 'max': 70, 'color': 3},
      {'label': '0-59', 'min': 0, 'max': 60, 'color': 4},
    ];

    final total = scores.length;
    return segments.map((seg) {
      final minVal = seg['min'] as int;
      final maxVal = seg['max'] as int;
      final count = scores.where((s) => s >= minVal && s < maxVal).length;
      final pct = total > 0 ? count / total * 100 : 0.0;
      return ScoreSegment(
        label: seg['label'] as String,
        count: count,
        percentage: pct,
      );
    }).toList();
  }

  /// 计算学生排名（同一学生多次取平均分，按平均分降序排列）
  List<StudentSummary> _calculateRankings(
      List<Map<String, dynamic>> records, String scoreField) {
    final studentMap = <String, StudentSummary>{};

    for (final record in records) {
      final studentId = record['student_id']?.toString() ?? '';
      final studentName = record['student_name']?.toString() ?? '';
      final score = (record[scoreField] as num?)?.toInt() ?? 0;
      final points = (record['points'] as num?)?.toInt() ?? 0;

      if (studentId.isEmpty) continue;

      if (!studentMap.containsKey(studentId)) {
        studentMap[studentId] = StudentSummary(
          studentId: studentId,
          studentName: studentName,
        );
      }

      final summary = studentMap[studentId]!;
      summary.totalScore += score;
      summary.totalCount += 1;
      summary.totalPoints += points;
      if (score > summary.maxScore) summary.maxScore = score;
    }

    // 按平均分降序排列
    final rankings = studentMap.values.toList();
    rankings.sort((a, b) => b.avgScore.compareTo(a.avgScore));
    return rankings;
  }

  // ============ 学生详细数据 ============

  // 选中查看详情的学生ID
  String? _selectedStudentId;
  Map<String, dynamic>? _studentDetail;
  bool _isLoadingDetail = false;

  String? get selectedStudentId => _selectedStudentId;
  Map<String, dynamic>? get studentDetail => _studentDetail;
  bool get isLoadingDetail => _isLoadingDetail;

  /// 加载学生详细数据
  Future<void> loadStudentDetail(String studentId) async {
    _selectedStudentId = studentId;
    _isLoadingDetail = true;
    _studentDetail = null;
    notifyListeners();

    try {
      final response = await http
          .get(
            Uri.parse('http://localhost:20020/api/student-detail/$studentId'),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _studentDetail = data['data'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      print('加载学生详情失败: $e');
    }

    _isLoadingDetail = false;
    notifyListeners();
  }

  /// 关闭学生详情面板
  void closeStudentDetail() {
    _selectedStudentId = null;
    _studentDetail = null;
    _isLoadingDetail = false;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
