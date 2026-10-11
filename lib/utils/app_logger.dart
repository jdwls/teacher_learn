import 'package:flutter/foundation.dart';

/// 统一日志出口：
/// - debug（调试）模式才打印；release 模式默认静默，避免 185 处 print 拖慢高频路径
/// - 如需在 release 中保留，可在此集中改为写日志文件
class AppLogger {
  static void log(Object? message) {
    if (kDebugMode) {
      debugPrint(message?.toString());
    }
  }
}

