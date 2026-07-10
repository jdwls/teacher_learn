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
          final List<dynamic> banks = data['data'] ?? [];
          _exams = banks.asMap().entries.map((entry) {
            final bank = entry.value as Map<String, dynamic>;
            return ExamModel(
              id: '${entry.key}',
              name: bank['name'] ?? '',
              description: '题库: ${bank['name'] ?? ''}',
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
      name: examData['name'] ?? '',
      description: examData['description'],
      duration: examData['duration'],
      totalScore: examData['total_score'],
      status: examData['status'] ?? 'draft',
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
        name: updates['name'] ?? oldExam.name,
        description: updates['description'] ?? oldExam.description,
        duration: updates['duration'] ?? oldExam.duration,
        totalScore: updates['total_score'] ?? oldExam.totalScore,
        status: updates['status'] ?? oldExam.status,
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
