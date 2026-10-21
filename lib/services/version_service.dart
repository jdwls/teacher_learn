import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../utils/app_logger.dart';
import '../utils/app_path.dart';

/// 教师端版本管理
/// 版本号由 information/manage/version_teacher.json 控制，修改后重启教师端生效
class VersionService {
  static const String defaultVersion = '1.0.0';

  static String? _cachedVersion;

  /// 版本配置文件路径
  static String get versionFilePath =>
      path.join(AppPath.informationDir, 'manage', 'version_teacher.json');

  /// 读取版本号；文件不存在时自动创建默认配置
  static Future<String> loadVersion({bool forceReload = false}) async {
    if (!forceReload && _cachedVersion != null) return _cachedVersion!;

    final file = File(versionFilePath);
    try {
      if (!await file.exists()) {
        await _writeDefaultVersion();
        _cachedVersion = defaultVersion;
        return defaultVersion;
      }

      final content = await file.readAsString();
      final data = json.decode(content);
      final version =
          data is Map ? (data['version']?.toString().trim() ?? '') : '';
      if (version.isEmpty) {
        AppLogger.log('版本配置缺少 version 字段，使用默认版本 $defaultVersion');
        _cachedVersion = defaultVersion;
      } else {
        _cachedVersion = version;
      }
    } catch (e) {
      AppLogger.log('读取版本配置失败，使用默认版本: $e');
      _cachedVersion = defaultVersion;
    }

    return _cachedVersion!;
  }

  /// 清理内存缓存（下次读取重新访问文件）
  static void clearCache() {
    _cachedVersion = null;
  }

  static Future<void> _writeDefaultVersion() async {
    try {
      final file = File(versionFilePath);
      await file.parent.create(recursive: true);
      final data = {
        'version': defaultVersion,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(data),
      );
      AppLogger.log('已创建教师端版本配置: $versionFilePath');
    } catch (e) {
      AppLogger.log('创建版本配置失败: $e');
    }
  }
}
