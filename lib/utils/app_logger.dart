/// 日志级别
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// 简单的日志工具类
class AppLogger {
  /// 是否启用日志（生产环境可设为false）
  static bool enabled = true;

  /// 最小日志级别（低于此级别的日志不会输出）
  static LogLevel minLevel = LogLevel.debug;

  /// 调试日志
  static void debug(String message, [String? tag]) {
    _log(LogLevel.debug, message, tag);
  }

  /// 信息日志
  static void info(String message, [String? tag]) {
    _log(LogLevel.info, message, tag);
  }

  /// 警告日志
  static void warning(String message, [String? tag]) {
    _log(LogLevel.warning, message, tag);
  }

  /// 错误日志
  static void error(String message, [String? tag, Object? error]) {
    _log(LogLevel.error, message, tag);
    if (error != null) {
      print('  └─ Error: $error');
    }
  }

  /// 内部日志方法
  static void _log(LogLevel level, String message, String? tag) {
    if (!enabled) return;
    if (level.index < minLevel.index) return;

    final timestamp = DateTime.now().toString().substring(11, 23);
    final levelStr = _levelToString(level);
    final tagStr = tag != null ? '[$tag] ' : '';
    final emoji = _levelToEmoji(level);

    print('$timestamp $emoji $levelStr ${tagStr}$message');
  }

  static String _levelToString(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  static String _levelToEmoji(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍';
      case LogLevel.info:
        return 'ℹ️';
      case LogLevel.warning:
        return '⚠️';
      case LogLevel.error:
        return '❌';
    }
  }
}
