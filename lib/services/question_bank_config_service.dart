import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// 题库配置服务 - 管理题库选择的本地 JSON 存储
class QuestionBankConfigService {
  static const String _configFileName = 'question_bank_config.json';

  /// 获取配置目录路径
  static String _getConfigDir() {
    final projectRoot = Directory.current.path;
    return path.join(projectRoot, 'information', 'manage');
  }

  /// 获取配置文件路径
  static String _getConfigFilePath() {
    return path.join(_getConfigDir(), _configFileName);
  }

  /// 加载题库配置
  static Future<Map<String, dynamic>> loadConfig() async {
    try {
      final configPath = _getConfigFilePath();
      final file = File(configPath);

      if (await file.exists()) {
        final content = await file.readAsString();
        return json.decode(content) as Map<String, dynamic>;
      }
    } catch (e) {
      print('加载题库配置失败: $e');
    }

    // 返回默认配置
    return {
      'selected_bank': null,
      'last_sync_time': null,
    };
  }

  /// 保存题库配置
  static Future<bool> saveConfig({
    String? selectedBank,
    String? lastSyncTime,
  }) async {
    try {
      final configPath = _getConfigFilePath();
      final file = File(configPath);

      // 确保目录存在
      final dir = file.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      // 加载现有配置（如果存在）
      Map<String, dynamic> config = {};
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          config = json.decode(content) as Map<String, dynamic>;
        } catch (e) {
          // 配置文件损坏，使用空配置
        }
      }

      // 更新配置
      if (selectedBank != null) {
        config['selected_bank'] = selectedBank;
      }
      if (lastSyncTime != null) {
        config['last_sync_time'] = lastSyncTime;
      }
      config['updated_at'] = DateTime.now().toIso8601String();

      // 保存配置
      final jsonString = const JsonEncoder.withIndent('  ').convert(config);
      await file.writeAsString(jsonString, flush: true);

      print('题库配置已保存: $configPath');
      return true;
    } catch (e) {
      print('保存题库配置失败: $e');
      return false;
    }
  }

  /// 获取当前选中的题库
  static Future<String?> getSelectedBank() async {
    final config = await loadConfig();
    return config['selected_bank'] as String?;
  }

  /// 设置当前选中的题库
  static Future<bool> setSelectedBank(String bankName) async {
    return saveConfig(selectedBank: bankName);
  }
}
