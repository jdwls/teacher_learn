import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = false;
  String? _error;
  String? _selectedClassLabel;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get selectedClassLabel => _selectedClassLabel;

  Future<void> initialize() async {
    // 使用 addPostFrameCallback 避免在 build 阶段调用 notifyListeners
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _isLoading = true;
      notifyListeners();

      try {
        // 恢复上次保存的班级选择
        final prefs = await SharedPreferences.getInstance();
        _selectedClassLabel = prefs.getString('selected_class_label');
        _isLoggedIn = true;
      } catch (e) {
        _error = e.toString();
      }

      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> setSelectedClass(String classLabel) async {
    // 使用 addPostFrameCallback 避免在 build 阶段调用 notifyListeners
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _selectedClassLabel = classLabel;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_class_label', classLabel);
      notifyListeners();
    });
  }

  // 题库选择现在通过 QuestionBankConfigService 管理

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // 静态方法，用于获取教师端选择的班级
  static String getDefaultClass() {
    return '初一01班';
  }
}
