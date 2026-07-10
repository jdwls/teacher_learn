import 'package:flutter/foundation.dart';
import '../models/question_model.dart';
import '../services/api_service.dart';

class QuestionProvider extends ChangeNotifier {
  final ApiService _apiService;
  List<QuestionModel> _questions = [];
  QuestionModel? _selectedQuestion;
  bool _isLoading = false;
  String? _error;

  QuestionProvider({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  List<QuestionModel> get questions => _questions;
  List<QuestionModel> get mathQuestions =>
      _questions.where((q) => q.chapter?.contains('数学') ?? false).toList();
  List<QuestionModel> get chineseQuestions =>
      _questions.where((q) => q.chapter?.contains('语文') ?? false).toList();
  List<QuestionModel> get englishQuestions =>
      _questions.where((q) => q.chapter?.contains('英语') ?? false).toList();
  QuestionModel? get selectedQuestion => _selectedQuestion;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectQuestion(QuestionModel question) {
    _selectedQuestion = question;
    notifyListeners();
  }

  void clearSelection() {
    _selectedQuestion = null;
    notifyListeners();
  }

  // 兼容别名
  Future<bool> addQuestion(Map<String, dynamic> questionData) =>
      createQuestion(questionData);

  Future<void> loadQuestions({String? type, String? difficulty}) async {
    // 延迟到下一个帧，避免在 build 阶段调用 notifyListeners
    await Future.delayed(const Duration(milliseconds: 1));

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get('/questions');
      if (response.containsKey('data')) {
        final List<dynamic> data = response['data'];
        _questions = data.map((json) => QuestionModel.fromJson(json)).toList();
      }
    } catch (e) {
      // API失败时使用模拟数据
      _loadMockQuestions();
    }

    _isLoading = false;
    notifyListeners();
  }

  void _loadMockQuestions() {
    _questions = [
      // 数学题
      QuestionModel(
        id: 'q1',
        content: '1 + 1 = ?',
        type: 'single',
        options: '1\n2\n3\n4',
        correctAnswer: '2',
        score: 20,
        difficulty: 'easy',
        chapter: '数学-第一章',
      ),
      QuestionModel(
        id: 'q2',
        content: '5 × 3 = ?',
        type: 'single',
        options: '10\n12\n15\n18',
        correctAnswer: '15',
        score: 20,
        difficulty: 'easy',
        chapter: '数学-第一章',
      ),
      QuestionModel(
        id: 'q3',
        content: '10 ÷ 2 = ?',
        type: 'single',
        options: '3\n4\n5\n6',
        correctAnswer: '5',
        score: 20,
        difficulty: 'easy',
        chapter: '数学-第一章',
      ),
      QuestionModel(
        id: 'q4',
        content: '8 + 7 = ?',
        type: 'single',
        options: '13\n14\n15\n16',
        correctAnswer: '15',
        score: 20,
        difficulty: 'medium',
        chapter: '数学-第二章',
      ),
      QuestionModel(
        id: 'q5',
        content: '20 - 8 = ?',
        type: 'single',
        options: '10\n11\n12\n13',
        correctAnswer: '12',
        score: 20,
        difficulty: 'medium',
        chapter: '数学-第二章',
      ),
      // 语文题
      QuestionModel(
        id: 'q6',
        content: '"春风又绿江南岸"的下一句是？',
        type: 'single',
        options: '明月何时照我还\n春风不度玉门关\n春眠不觉晓\n春江水暖鸭先知',
        correctAnswer: '明月何时照我还',
        score: 20,
        difficulty: 'medium',
        chapter: '语文-第一单元',
      ),
      QuestionModel(
        id: 'q7',
        content: '下列哪个是象形字？',
        type: 'single',
        options: '日\n江\n河\n湖',
        correctAnswer: '日',
        score: 20,
        difficulty: 'easy',
        chapter: '语文-第一单元',
      ),
      QuestionModel(
        id: 'q8',
        content: '"举头望明月"的上一句是？',
        type: 'single',
        options: '床前明月光\n疑是地上霜\n举头望明月\n低头思故乡',
        correctAnswer: '床前明月光',
        score: 20,
        difficulty: 'medium',
        chapter: '语文-第二单元',
      ),
      // 英语题
      QuestionModel(
        id: 'q9',
        content: 'How do you say "你好" in English?',
        type: 'single',
        options: 'Hello\nGoodbye\nThank you\nYes',
        correctAnswer: 'Hello',
        score: 20,
        difficulty: 'easy',
        chapter: '英语-第一单元',
      ),
      QuestionModel(
        id: 'q10',
        content: 'What is the plural of "apple"?',
        type: 'single',
        options: 'Apples\nApple\nAppled\nAppleing',
        correctAnswer: 'Apples',
        score: 20,
        difficulty: 'easy',
        chapter: '英语-第一单元',
      ),
    ];
  }

  Future<bool> createQuestion(Map<String, dynamic> questionData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post('/questions', questionData);
      if (response.containsKey('success') && response['success'] == true) {
        final newQuestion =
            QuestionModel.fromJson(response['data'] ?? questionData);
        _questions.add(newQuestion);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      // API失败时使用模拟创建
      final newQuestion = QuestionModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: questionData['content'] ?? '',
        type: questionData['type'] ?? 'single',
        options: questionData['options'],
        correctAnswer: questionData['correct_answer'],
        score: questionData['score'] ?? 20,
        difficulty: questionData['difficulty'] ?? 'medium',
        chapter: questionData['chapter'],
      );
      _questions.add(newQuestion);
      _isLoading = false;
      notifyListeners();
      return true;
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> updateQuestion(
      String questionId, Map<String, dynamic> updates) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.put('/questions/$questionId', updates);

      final index = _questions.indexWhere((q) => q.id == questionId);
      if (index != -1) {
        final oldQuestion = _questions[index];
        _questions[index] = QuestionModel(
          id: oldQuestion.id,
          content: updates['content'] ?? oldQuestion.content,
          type: updates['type'] ?? oldQuestion.type,
          options: updates['options'] ?? oldQuestion.options,
          correctAnswer: updates['correct_answer'] ?? oldQuestion.correctAnswer,
          score: updates['score'] ?? oldQuestion.score,
          difficulty: updates['difficulty'] ?? oldQuestion.difficulty,
          chapter: updates['chapter'] ?? oldQuestion.chapter,
          analysis: updates['analysis'] ?? oldQuestion.analysis,
          createdAt: oldQuestion.createdAt,
          updatedAt: DateTime.now(),
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteQuestion(String questionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _apiService.delete('/questions/$questionId');
      _questions.removeWhere((q) => q.id == questionId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
