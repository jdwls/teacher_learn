import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/exam_model.dart';

class ExamProvider extends ChangeNotifier {
  List<ExamModel> _exams = [];
  ExamModel? _currentExam;
  bool _isLoading = false;
  String? _error;

  List<ExamModel> get exams => _exams;
  ExamModel? get currentExam => _currentExam;
  ExamModel? get selectedExam => _currentExam;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectExam(ExamModel exam) {
    _currentExam = exam;
    notifyListeners();
  }

  // 兼容别名
  Future<bool> addExam(Map<String, dynamic> examData) => createExam(examData);

  Future<void> loadExams() async {
    // 延迟到下一个帧，避免在 build 阶段调用 notifyListeners
    await Future.delayed(const Duration(milliseconds: 1));

    _isLoading = true;
    notifyListeners();

    try {
      // 从HTTP API获取题库列表作为考试列表
      final response = await http
          .get(
            Uri.parse('http://localhost:20020/api/question-banks'),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final banks = data['data'] is List ? data['data'] as List : <dynamic>[];
          _exams = banks.asMap().entries.where((entry) => entry.value is Map).map((entry) {
            final bank = Map<String, dynamic>.from(entry.value as Map);
            final bankName = bank['name']?.toString() ?? '';
            return ExamModel(
              id: '${entry.key}',
              name: bankName,
              description: '题库: $bankName',
              duration: 300,
              totalScore: 100,
              status: 'published',
              createdAt: DateTime.now(),
            );
          }).toList();
        }
      }
    } catch (e) {
      _exams = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> createExam(Map<String, dynamic> examData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final newExam = ExamModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: examData['name']?.toString() ?? '',
      description: examData['description']?.toString(),
      duration: examData['duration'] is num
          ? (examData['duration'] as num).toInt()
          : int.tryParse(examData['duration']?.toString() ?? ''),
      totalScore: examData['total_score'] is num
          ? (examData['total_score'] as num).toInt()
          : int.tryParse(examData['total_score']?.toString() ?? ''),
      status: examData['status']?.toString() ?? 'draft',
      createdAt: DateTime.now(),
    );
    _exams.add(newExam);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> updateExam(String examId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final index = _exams.indexWhere((e) => e.id == examId);
    if (index != -1) {
      final oldExam = _exams[index];
      _exams[index] = ExamModel(
        id: oldExam.id,
        name: updates['name']?.toString() ?? oldExam.name,
        description: updates['description']?.toString() ?? oldExam.description,
        duration: updates['duration'] is num
            ? (updates['duration'] as num).toInt()
            : int.tryParse(updates['duration']?.toString() ?? '') ?? oldExam.duration,
        totalScore: updates['total_score'] is num
            ? (updates['total_score'] as num).toInt()
            : int.tryParse(updates['total_score']?.toString() ?? '') ?? oldExam.totalScore,
        status: updates['status']?.toString() ?? oldExam.status,
        createdAt: oldExam.createdAt,
        updatedAt: DateTime.now(),
      );
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<bool> deleteExam(String examId) async {
    _exams.removeWhere((e) => e.id == examId);
    notifyListeners();
    return true;
  }

  void setCurrentExam(ExamModel? exam) {
    _currentExam = exam;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
