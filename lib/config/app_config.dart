/// 应用配置常量
class AppConfig {
  // ============ 服务器配置 ============

  /// HTTP API 服务器端口
  static const int httpServerPort = 20020;

  /// Socket 服务器端口
  static const int socketServerPort = 20021;

  /// 服务器启动超时时间（秒）
  static const int serverStartTimeoutSeconds = 10;

  // ============ 心跳配置 ============

  /// 心跳超时时间（秒）- 超过此时间未收到心跳视为断开
  static const int heartbeatTimeoutSeconds = 15;

  /// 心跳检测间隔（秒）
  static const int heartbeatCheckIntervalSeconds = 5;

  // ============ 缓存配置 ============

  /// 题库缓存最大条目数
  static const int maxQuestionBankCacheSize = 50;

  /// 学生数据缓存最大条目数
  static const int maxStudentCacheSize = 100;

  // ============ 文件操作配置 ============

  /// 锁超时时间（秒）
  static const int lockTimeoutSeconds = 10;

  /// 最大重试次数
  static const int maxFlushRetries = 10;

  /// 熔断阈值（连续失败次数）
  static const int circuitBreakerThreshold = 5;

  /// 熔断恢复时间（秒）
  static const int circuitBreakerResetSeconds = 30;

  /// 防抖写入延迟（毫秒）
  static const int debounceWriteDelayMs = 500;

  /// 批量通知延迟（毫秒）
  static const int debounceNotifyDelayMs = 500;

  // ============ HTTP 配置 ============

  /// HTTP 请求超时时间（秒）
  static const int httpRequestTimeoutSeconds = 10;

  /// 最大请求体大小（字节）
  static const int maxBodySize = 10 * 1024 * 1024; // 10MB

  // ============ 输入验证配置 ============

  /// 最大名称长度
  static const int maxNameLength = 50;

  /// 最大密码长度
  static const int maxPasswordLength = 128;

  // ============ UI 配置 ============

  /// 刷新间隔（秒）
  static const int refreshIntervalSeconds = 5;

  /// 防抖间隔（毫秒）
  static const int debounceIntervalMs = 3000;

  // ============ 学生状态配置 ============

  /// 学生状态：在线
  static const String statusOnline = 'online';

  /// 学生状态：离线
  static const String statusOffline = 'offline';

  /// 学生状态：打字中
  static const String statusTyping = 'typing';

  /// 学生状态：小测中
  static const String statusExam = 'exam';

  // ============ 在线升级配置 ============

  /// 学生端在线升级检查间隔（分钟）
  static const int studentUpdateCheckIntervalMinutes = 30;

  /// 学生端在线升级文件目录名
  static const String studentOnlineUpdateDirName = 'student_online_update';
}
