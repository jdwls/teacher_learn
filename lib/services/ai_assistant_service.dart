import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../utils/app_logger.dart';
import '../utils/app_path.dart';

/// AI 学习助手服务（教师端）
///
/// 职责：
///   1. 维护 AI 配置（服务商 / API 地址 / API Key / 模型 / 系统提示词等）
///   2. 代理学生端的提问请求（API Key 只保留在教师端，绝不下发给学生端）
///   3. 持久化学生与 AI 的对话记录（information/manage/ai_history.json）
///
/// 配置文件：information/manage/ai_config.json
/// 历史文件：information/manage/ai_history.json
class AiAssistantService {
  AiAssistantService._();

  static AiAssistantService? _instance;
  static AiAssistantService get instance => _instance ??= AiAssistantService._();

  // ============ 常量 ============

  /// 默认服务商（需求：默认为 DeepSeek）
  static const String providerDeepSeek = 'deepseek';

  /// 其他 OpenAI 兼容服务商（自建 / 中转）
  static const String providerOpenAiCompatible = 'openai_compatible';

  /// DeepSeek 默认 API 地址
  static const String deepSeekBaseUrl = 'https://api.deepseek.com';

  /// DeepSeek 默认模型
  static const String deepSeekModel = 'deepseek-chat';

  /// OpenAI 兼容服务默认 API 地址（占位，教师需按实际服务修改）
  static const String openAiCompatibleBaseUrl = 'https://api.openai.com/v1';

  /// OpenAI 兼容服务默认模型
  static const String openAiCompatibleModel = 'gpt-4o-mini';

  /// 默认系统提示词
  static const String defaultSystemPrompt = '你是「信息科技」课堂的 AI 学习助手，面向初中学生。\n'
      '回答要求：\n'
      '1. 使用简洁易懂的中文，先给结论，再解释原因；\n'
      '2. 涉及代码时给出完整可运行的示例，并逐行注释；\n'
      '3. 回答尽量控制在 400 字以内，条理清晰，必要时分点说明；\n'
      '4. 不讨论与学习无关的闲聊话题，礼貌地引导学生回到学习内容。';

  /// 单条提问最大长度（字符）
  static const int maxMessageLength = 2000;

  /// 每个学生保留的历史消息条数上限
  static const int maxHistoryPerStudent = 200;

  /// 上游请求超时（大模型响应较慢，需放宽）
  static const Duration requestTimeout = Duration(seconds: 90);

  /// 测试连接超时
  static const Duration testTimeout = Duration(seconds: 30);

  /// 默认每人每天提问上限（一节课的合理额度）
  static const int defaultMaxRequestsPerDay = 10;

  /// 兼容旧版「每分钟上限」字段名（读取时回退）
  static const String legacyMinuteLimitKey = 'max_requests_per_minute';

  /// 旧数据（无 session_id）归入的虚拟会话 ID
  static const String legacySessionId = '__legacy__';

  // ============ 状态 ============

  /// 共享 HTTP Client，避免每次请求新建连接
  final http.Client _client = http.Client();

  /// 当前配置（内存镜像，落盘见 [configPath]）
  Map<String, dynamic> _config = defaultConfig();

  /// 每日配额：日期(yyyy-MM-dd) -> { studentId -> 已用次数 }
  Map<String, Map<String, int>> _quotas = {};

  /// 配额文件锁（串行化读改写）
  Future<void>? _quotaLock;

  /// 历史文件锁（串行化读改写，避免并发丢失记录）
  Future<void>? _historyLock;

  // ============ 路径 ============

  /// 测试用目录覆盖：非空时配置与历史都读写该目录，
  /// 避免测试污染真实的 information/manage 数据。
  static String? manageDirOverride;

  String get _manageDir =>
      manageDirOverride ?? path.join(AppPath.informationDir, 'manage');

  /// AI 配置文件路径
  String get configPath => path.join(_manageDir, 'ai_config.json');

  /// AI 对话历史文件路径
  String get historyPath => path.join(_manageDir, 'ai_history.json');

  /// 每日配额文件路径（独立存储，避免学生清空历史后配额被重置）
  String get quotaPath => path.join(_manageDir, 'ai_quota.json');

  // ============ 默认配置 ============

  /// 生成一份默认配置（未启用、DeepSeek、无 Key）
  static Map<String, dynamic> defaultConfig() {
    return {
      'enabled': false,
      'provider': providerDeepSeek,
      'base_url': deepSeekBaseUrl,
      'api_key': '',
      'model': deepSeekModel,
      'system_prompt': defaultSystemPrompt,
      'temperature': 0.7,
      'max_tokens': 2000,
      'context_messages': 10,
      'max_requests_per_day': defaultMaxRequestsPerDay,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// 服务商对应的默认 API 地址
  static String defaultBaseUrlFor(String provider) =>
      provider == providerDeepSeek ? deepSeekBaseUrl : openAiCompatibleBaseUrl;

  /// 服务商对应的默认模型
  static String defaultModelFor(String provider) =>
      provider == providerDeepSeek ? deepSeekModel : openAiCompatibleModel;

  // ============ 配置读取 ============

  /// 是否已启用（学生端是否可见）
  bool get enabled => _config['enabled'] == true;

  /// 当前服务商
  String get provider => _config['provider']?.toString() ?? providerDeepSeek;

  /// 当前 API 地址
  String get baseUrl {
    final raw = (_config['base_url']?.toString() ?? '').trim();
    return raw.isEmpty ? defaultBaseUrlFor(provider) : raw;
  }

  /// 当前模型名
  String get model {
    final raw = (_config['model']?.toString() ?? '').trim();
    return raw.isEmpty ? defaultModelFor(provider) : raw;
  }

  /// 当前 API Key
  String get apiKey => _config['api_key']?.toString() ?? '';

  /// 是否已配置 API Key
  bool get hasApiKey => apiKey.trim().isNotEmpty;

  /// 系统提示词
  String get systemPrompt => (_config['system_prompt']?.toString() ?? '').trim();

  /// 采样温度
  double get temperature => (_config['temperature'] as num?)?.toDouble() ?? 0.7;

  /// 最大输出 token
  int get maxTokens => (_config['max_tokens'] as num?)?.toInt() ?? 2000;

  /// 携带的上下文消息条数
  int get contextMessages =>
      (_config['context_messages'] as num?)?.toInt() ?? 10;

  /// 每名学生每天提问上限（兼容旧的 max_requests_per_minute 字段）
  int get maxRequestsPerDay {
    final value = (_config['max_requests_per_day'] as num?)?.toInt() ??
        (_config[legacyMinuteLimitKey] as num?)?.toInt();
    if (value == null || value <= 0) return defaultMaxRequestsPerDay;
    return value;
  }

  /// 完整配置的只读副本（教师端 UI 使用，含 API Key）
  Map<String, dynamic> get config => Map<String, dynamic>.unmodifiable(_config);

  /// 供学生端读取的公开配置（**不含 API Key**）
  Map<String, dynamic> get publicConfig => {
        'enabled': enabled,
        'provider': provider,
        'model': model,
        'has_api_key': hasApiKey,
      };

  // ============ 初始化 ============

  /// 加载配置 + 确保历史文件存在（教师端启动时调用）
  Future<void> init() async {
    try {
      final file = File(configPath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        if (data is Map<String, dynamic>) {
          // 老配置文件缺少新字段时用默认值补齐
          _config = {...defaultConfig(), ...data};
        }
      } else {
        await saveConfig(_config);
        AppLogger.log('AI 配置文件不存在，已创建默认配置');
      }
    } catch (e) {
      AppLogger.log('加载 AI 配置失败，使用默认配置: $e');
      _config = defaultConfig();
    }

    try {
      final historyFile = File(historyPath);
      if (!await historyFile.exists()) {
        final dir = Directory(_manageDir);
        if (!await dir.exists()) await dir.create(recursive: true);
        await historyFile.writeAsString(
            const JsonEncoder.withIndent('  ').convert({'records': []}),
            flush: true);
        AppLogger.log('AI 历史文件不存在，已创建空文件');
      }
    } catch (e) {
      AppLogger.log('初始化 AI 历史文件失败: $e');
    }

    AppLogger.log('AI 助手配置: enabled=$enabled, provider=$provider, '
        'model=$model, hasKey=$hasApiKey');

    // 加载每日配额（独立文件）
    await _loadQuotas();
  }

  // ============ 每日配额 ============

  /// 本地日期键（yyyy-MM-dd）
  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  /// 某学生今日已用次数
  int todayUsedCount(String studentId) {
    return _quotas[_todayKey()]?[studentId] ?? 0;
  }

  /// 某学生今日剩余次数
  int todayRemainingCount(String studentId) {
    final remaining = maxRequestsPerDay - todayUsedCount(studentId);
    return remaining < 0 ? 0 : remaining;
  }

  /// 今日各学生已用次数（教师端展示用）
  Map<String, int> todayUsage() =>
      Map<String, int>.unmodifiable(_quotas[_todayKey()] ?? const {});

  /// 加载配额文件（自动清理非今日的数据，防止文件无限增长）
  Future<void> _loadQuotas() async {
    try {
      final file = File(quotaPath);
      if (!await file.exists()) return;
      final content = await file.readAsString();
      if (content.trim().isEmpty) return;
      final data = json.decode(content);
      if (data is Map && data['quotas'] is Map) {
        final raw = data['quotas'] as Map;
        final loaded = <String, Map<String, int>>{};
        for (final entry in raw.entries) {
          if (entry.value is! Map) continue;
          final day = entry.key.toString();
          final students = <String, int>{};
          for (final s in (entry.value as Map).entries) {
            final count = (s.value as num?)?.toInt() ?? 0;
            if (count > 0) students[s.key.toString()] = count;
          }
          if (students.isNotEmpty) loaded[day] = students;
        }
        // 只保留今日，历史日期直接丢弃
        final today = _todayKey();
        _quotas = {
          if (loaded.containsKey(today)) today: loaded[today]!
        };
        if (loaded.length != _quotas.length) {
          // 有旧日期被清理，回写一次
          await _saveQuotas();
        }
        AppLogger.log('已加载 AI 每日配额，今日已用学生数: '
            '${_quotas[today]?.length ?? 0}');
      }
    } catch (e) {
      AppLogger.log('加载 AI 配额失败: $e');
      _quotas = {};
    }
  }

  /// 保存配额文件（只写今日数据）
  Future<bool> _saveQuotas() async {
    try {
      final dir = Directory(_manageDir);
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File(quotaPath);
      final tempFile = File('${file.path}.tmp');
      final jsonString = const JsonEncoder.withIndent('  ').convert({
        'quotas': _quotas,
      });
      await tempFile.writeAsString(jsonString, flush: true);
      json.decode(await tempFile.readAsString());
      await tempFile.rename(file.path);
      return true;
    } catch (e) {
      AppLogger.log('保存 AI 配额失败: $e');
      return false;
    }
  }

  /// 原子地「检查 + 扣减」一次配额（一发起就扣）。
  ///
  /// 返回 null 表示扣减成功；返回字符串表示配额已用完（可直接展示给学生）。
  /// 检查与扣减在同一把锁内完成，避免并发请求同时通过检查。
  Future<String?> _tryConsumeQuota(String studentId) async {
    return _withQuotaLock(() async {
      final today = _todayKey();
      final dayMap = _quotas.putIfAbsent(today, () => <String, int>{});
      final used = dayMap[studentId] ?? 0;
      if (used >= maxRequestsPerDay) {
        return '今日 AI 提问次数已用完（$used/$maxRequestsPerDay），明天再来吧';
      }
      dayMap[studentId] = used + 1;
      // 只保留今日，避免跨天数据堆积
      _quotas = {today: dayMap};
      await _saveQuotas();
      return null;
    });
  }

  /// 退还一次配额（仅用于教师端配置类错误，学生无法避免）
  Future<void> _refundQuota(String studentId) async {
    await _withQuotaLock(() async {
      final today = _todayKey();
      final dayMap = _quotas[today];
      if (dayMap == null) return;
      final used = dayMap[studentId] ?? 0;
      if (used <= 0) return;
      dayMap[studentId] = used - 1;
      if (dayMap[studentId] == 0) dayMap.remove(studentId);
      _quotas = {today: dayMap};
      await _saveQuotas();
      AppLogger.log('已退还 1 次 AI 配额（教师端配置错误）: $studentId');
    });
  }

  /// 该状态码是否属于「教师端配置错误」——这类错误应退还配额
  static bool _isTeacherConfigError(int statusCode) =>
      statusCode == 401 || statusCode == 402 || statusCode == 404;

  /// 串行化配额文件的读改写
  Future<T> _withQuotaLock<T>(Future<T> Function() action) async {
    final previous = _quotaLock;
    final current = Completer<void>();
    _quotaLock = current.future;
    if (previous != null) {
      await previous.catchError((_) {});
    }
    try {
      return await action();
    } finally {
      if (!current.isCompleted) current.complete();
      if (identical(_quotaLock, current.future)) {
        _quotaLock = null;
      }
    }
  }

  // ============ 配置保存 ============

  /// 保存配置（tmp 写入 + JSON 回读校验 + rename 原子替换）
  Future<bool> saveConfig(Map<String, dynamic> config) async {
    try {
      final merged = {...defaultConfig(), ...config};

      // 旧版字段迁移：只有 max_requests_per_minute 时把它作为每日上限，
      // 否则 defaultConfig 的默认值会把旧配置覆盖掉。
      if (!config.containsKey('max_requests_per_day') &&
          config.containsKey(legacyMinuteLimitKey)) {
        final legacyValue =
            (config[legacyMinuteLimitKey] as num?)?.toInt() ?? 0;
        if (legacyValue > 0) {
          merged['max_requests_per_day'] = legacyValue;
        }
      }
      merged.remove(legacyMinuteLimitKey);

      merged['provider'] = (merged['provider']?.toString() ?? '').trim().isEmpty
          ? providerDeepSeek
          : merged['provider'].toString().trim();
      merged['base_url'] = merged['base_url']?.toString().trim() ?? '';
      merged['model'] = merged['model']?.toString().trim() ?? '';
      merged['api_key'] = merged['api_key']?.toString().trim() ?? '';
      merged['enabled'] = merged['enabled'] == true;
      merged['updated_at'] = DateTime.now().toIso8601String();

      final dir = Directory(_manageDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File(configPath);
      final tempFile = File('${file.path}.tmp');
      final jsonString = const JsonEncoder.withIndent('  ').convert(merged);
      await tempFile.writeAsString(jsonString, flush: true);
      // 写入后先校验 JSON，再替换正式文件
      json.decode(await tempFile.readAsString());
      await tempFile.rename(file.path);

      _config = merged;
      AppLogger.log('AI 配置已保存: $configPath');
      return true;
    } catch (e) {
      AppLogger.log('保存 AI 配置失败: $e');
      return false;
    }
  }

  // ============ 对话 ============

  /// 统一的请求前置校验（非流式与流式共用）
  ///
  /// 返回 null 表示校验通过；返回 [AiChatResult] 表示应直接返回该失败结果。
  AiChatResult? _validateRequest({
    required String studentId,
    required String message,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return AiChatResult.failure('提问内容不能为空', statusCode: 400);
    }
    if (trimmed.length > maxMessageLength) {
      return AiChatResult.failure('提问内容过长（最多 $maxMessageLength 字）',
          statusCode: 400);
    }
    if (!enabled) {
      return AiChatResult.failure('教师尚未开启 AI 助手', statusCode: 403);
    }
    if (!hasApiKey) {
      return AiChatResult.failure('教师尚未配置 AI 的 API Key', statusCode: 503);
    }
    if (studentId.trim().isEmpty) {
      return AiChatResult.failure('缺少学生身份信息', statusCode: 400);
    }
    return null;
  }

  /// 组装发给上游的 messages（system 提示词 + 当前会话历史 + 本次提问）
  Future<List<Map<String, String>>> _buildUpstreamMessages({
    required String studentId,
    required String message,
    required String sessionId,
  }) async {
    final history = await _recentMessages(studentId, contextMessages, sessionId);
    return [
      if (systemPrompt.isNotEmpty) {'role': 'system', 'content': systemPrompt},
      ...history,
      {'role': 'user', 'content': message.trim()},
    ];
  }

  /// 学生端提问（经教师端代理调用上游大模型，非流式）
  ///
  /// [sessionId] 为空表示新建一个会话，响应会回传实际使用的 session_id。
  /// 返回 [AiChatResult]，失败时 [AiChatResult.error] 为可直接展示给学生的话术。
  Future<AiChatResult> chat({
    required String studentId,
    required String studentName,
    required String classId,
    required String message,
    String sessionId = '',
  }) async {
    // 前置校验
    final invalid = _validateRequest(studentId: studentId, message: message);
    if (invalid != null) return invalid;
    final trimmed = message.trim();

    // 配额：一发起就扣（原子检查 + 扣减）
    final quotaError = await _tryConsumeQuota(studentId);
    if (quotaError != null) {
      return AiChatResult.failure(quotaError, statusCode: 429);
    }

    // 会话：未指定则新建
    final effectiveSessionId = sessionId.trim().isEmpty
        ? '${DateTime.now().millisecondsSinceEpoch}_$studentId'
        : sessionId.trim();

    final messages = await _buildUpstreamMessages(
      studentId: studentId,
      message: trimmed,
      sessionId: effectiveSessionId,
    );

    final requestTime = DateTime.now();
    try {
      final response = await _client
          .post(
            Uri.parse('${_normalizedBaseUrl()}/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: json.encode({
              'model': model,
              'messages': messages,
              'temperature': temperature,
              'max_tokens': maxTokens,
              'stream': false,
            }),
          )
          .timeout(requestTimeout);

      if (response.statusCode != 200) {
        final error =
            _describeHttpError(response.statusCode, _decodeBody(response));
        AppLogger.log('AI 请求失败(${response.statusCode}): $error');
        // 教师端配置类错误退还配额，学生无法避免
        if (_isTeacherConfigError(response.statusCode)) {
          await _refundQuota(studentId);
        }
        return AiChatResult.failure(error, statusCode: 502);
      }

      final reply = _extractReply(_decodeBody(response));
      if (reply.isEmpty) {
        AppLogger.log('AI 返回内容为空: ${_decodeBody(response)}');
        return AiChatResult.failure('AI 未返回有效内容，请重试', statusCode: 502);
      }

      // 记录本次问答（失败不影响返回结果）
      await _appendHistory([
        _buildRecord(studentId, studentName, classId, 'user', trimmed, '',
            requestTime, effectiveSessionId),
        _buildRecord(studentId, studentName, classId, 'assistant', reply, model,
            DateTime.now(), effectiveSessionId),
      ]);

      return AiChatResult.success(
        reply,
        model: model,
        createdAt: requestTime.toIso8601String(),
        sessionId: effectiveSessionId,
        remainingQuota: todayRemainingCount(studentId),
      );
    } on TimeoutException {
      AppLogger.log('AI 请求超时（${requestTimeout.inSeconds}s）');
      return AiChatResult.failure('AI 响应超时，请稍后重试', statusCode: 504);
    } catch (e) {
      AppLogger.log('AI 请求异常: $e');
      return AiChatResult.failure('AI 请求失败: $e', statusCode: 502);
    }
  }

  // ============ 流式对话 ============

  /// 流式提问：逐块产出上游增量内容（SSE 透传）
  ///
  /// 事件顺序：`meta` → `delta` × N → `done`；
  /// 出错时产出 `error` 并结束流。
  ///
  /// 配额在**发起时**即扣减（一发起就扣）；仅教师端配置类错误（401/402/404）
  /// 会退还配额，其余失败不退。
  Stream<AiStreamChunk> chatStream({
    required String studentId,
    required String studentName,
    required String classId,
    required String message,
    String sessionId = '',
  }) async* {
    // 前置校验
    final invalid = _validateRequest(studentId: studentId, message: message);
    if (invalid != null) {
      yield AiStreamChunk.error(invalid.error);
      return;
    }
    final trimmed = message.trim();

    // 配额：一发起就扣（原子检查 + 扣减）
    final quotaError = await _tryConsumeQuota(studentId);
    if (quotaError != null) {
      yield AiStreamChunk.error(quotaError);
      return;
    }

    // 会话：未指定则新建
    final effectiveSessionId = sessionId.trim().isEmpty
        ? '${DateTime.now().millisecondsSinceEpoch}_$studentId'
        : sessionId.trim();

    final messages = await _buildUpstreamMessages(
      studentId: studentId,
      message: trimmed,
      sessionId: effectiveSessionId,
    );

    final requestTime = DateTime.now();
    final replyBuffer = StringBuffer();
    http.StreamedResponse? streamed;

    try {
      // 用 send() 拿流式响应；post() 会把整个响应读完，无法流式
      final request = http.Request(
        'POST',
        Uri.parse('${_normalizedBaseUrl()}/chat/completions'),
      )
        ..headers['Content-Type'] = 'application/json'
        ..headers['Authorization'] = 'Bearer ${apiKey.trim()}'
        ..body = json.encode({
          'model': model,
          'messages': messages,
          'temperature': temperature,
          'max_tokens': maxTokens,
          'stream': true,
        });

      streamed = await _client.send(request).timeout(requestTimeout);
    } on TimeoutException {
      AppLogger.log('AI 流式建连超时（${requestTimeout.inSeconds}s）');
      yield AiStreamChunk.error('AI 响应超时，请稍后重试');
      return;
    } catch (e) {
      AppLogger.log('AI 流式建连异常: $e');
      yield AiStreamChunk.error('AI 请求失败: $e');
      return;
    }

    // 上游返回非 200：读完整 body 解析错误
    if (streamed.statusCode != 200) {
      String body = '';
      try {
        final bytes = await streamed.stream.toBytes();
        body = utf8.decode(bytes, allowMalformed: true);
      } catch (_) {}
      final error = _describeHttpError(streamed.statusCode, body);
      AppLogger.log('AI 流式请求失败(${streamed.statusCode}): $error');
      if (_isTeacherConfigError(streamed.statusCode)) {
        await _refundQuota(studentId);
      }
      yield AiStreamChunk.error(error);
      return;
    }

    // 下发 meta（含会话 ID、模型、扣减后的剩余次数）
    yield AiStreamChunk.meta(
      sessionId: effectiveSessionId,
      model: model,
      remainingQuota: todayRemainingCount(studentId),
    );

    var sawSseData = false;
    var streamFailed = false;

    try {
      // utf8.decoder 有状态，能正确处理跨 chunk 被切断的多字节汉字
      final lines = streamed.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 60));

      await for (final line in lines) {
        final trimmedLine = line.trim();
        if (trimmedLine.isEmpty) continue;

        if (!trimmedLine.startsWith('data:')) {
          // 非 SSE 行（可能是上游直接返回的完整 JSON），先暂存
          if (!sawSseData && trimmedLine.startsWith('{')) {
            replyBuffer.write(trimmedLine);
          }
          continue;
        }

        sawSseData = true;
        final payload = trimmedLine.substring(5).trim();
        if (payload == '[DONE]') break;
        if (payload.isEmpty) continue;

        final delta = _extractStreamDelta(payload);
        if (delta == null) continue;
        if (delta.isEmpty) continue;

        replyBuffer.write(delta);
        yield AiStreamChunk.delta(delta);
      }
    } on TimeoutException {
      AppLogger.log('AI 流式读取超时（块间超过 60 秒）');
      streamFailed = true;
    } catch (e) {
      AppLogger.log('AI 流式读取异常: $e');
      streamFailed = true;
    }

    // 兼容非 SSE 上游：整个响应是一个 JSON，一次性解析并下发
    if (!sawSseData && replyBuffer.isNotEmpty) {
      final whole = _extractReply(replyBuffer.toString());
      if (whole.isNotEmpty) {
        replyBuffer
          ..clear()
          ..write(whole);
        yield AiStreamChunk.delta(whole);
      }
    }

    final fullReply = replyBuffer.toString();
    if (fullReply.isEmpty) {
      yield AiStreamChunk.error(streamFailed ? 'AI 响应中断，请重试' : 'AI 未返回有效内容，请重试');
      return;
    }

    // 落库：即使中途断流也保存已收到的内容，避免学生白费配额
    await _appendHistory([
      _buildRecord(studentId, studentName, classId, 'user', trimmed, '',
          requestTime, effectiveSessionId),
      _buildRecord(studentId, studentName, classId, 'assistant', fullReply,
          model, DateTime.now(), effectiveSessionId),
    ]);

    if (streamFailed) {
      AppLogger.log('AI 流式中断，已保存部分回答（${fullReply.length} 字）');
    }

    yield AiStreamChunk.done();
  }

  /// 从一条 SSE data 载荷中提取增量文本
  ///
  /// 返回 null 表示该块无需处理（如仅含 role 的首块）；返回空串表示无内容。
  String? _extractStreamDelta(String payload) {
    try {
      final data = json.decode(payload);
      if (data is! Map) return null;
      final choices = data['choices'];
      if (choices is! List || choices.isEmpty) return null;
      final first = choices.first;
      if (first is! Map) return null;
      final delta = first['delta'];
      if (delta is! Map) {
        // 部分服务商在流式里仍返回 message
        final message = first['message'];
        if (message is Map && message['content'] is String) {
          return message['content'] as String;
        }
        return null;
      }
      final content = delta['content'];
      if (content is String) return content;
      return '';
    } catch (e) {
      AppLogger.log('解析流式块失败: $e');
      return null;
    }
  }

  /// 测试连接（教师端「测试连接」按钮使用，不写入历史）
  Future<AiTestResult> testConnection() async {
    if (!hasApiKey) {
      return AiTestResult.failure('请先填写 API Key');
    }
    try {
      final response = await _client
          .post(
            Uri.parse('${_normalizedBaseUrl()}/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: json.encode({
              'model': model,
              'messages': [
                {
                  'role': 'user',
                  'content': '请只回复两个字：成功',
                }
              ],
              'temperature': 0,
              'max_tokens': 16,
              'stream': false,
            }),
          )
          .timeout(testTimeout);

      if (response.statusCode != 200) {
        return AiTestResult.failure(
            _describeHttpError(response.statusCode, _decodeBody(response)));
      }
      final reply = _extractReply(_decodeBody(response));
      return AiTestResult.success(
          '连接成功，模型回复：${reply.isEmpty ? '(空)' : reply}');
    } on TimeoutException {
      return AiTestResult.failure('连接超时，请检查网络或 API 地址');
    } catch (e) {
      return AiTestResult.failure('连接失败: $e');
    }
  }

  // ============ 历史记录 ============

  /// 读取历史消息（按时间正序，供学生端恢复会话）
  ///
  /// [studentId] / [classId] / [sessionId] 为空表示不按该维度过滤。
  Future<List<Map<String, dynamic>>> loadHistory({
    String? studentId,
    String? classId,
    String? sessionId,
    int limit = 200,
  }) async {
    final records = await _readHistoryRecords();
    final filtered = records.where((r) {
      if (studentId != null &&
          studentId.isNotEmpty &&
          r['student_id']?.toString() != studentId) {
        return false;
      }
      if (classId != null &&
          classId.isNotEmpty &&
          r['class_id']?.toString() != classId) {
        return false;
      }
      if (sessionId != null &&
          sessionId.isNotEmpty &&
          r['session_id']?.toString() != sessionId) {
        return false;
      }
      return true;
    }).toList();

    if (limit <= 0 || filtered.length <= limit) return filtered;
    return filtered.sublist(filtered.length - limit);
  }

  /// 读取某学生的会话列表（按最近时间倒序）
  ///
  /// 每条：session_id / title（首条提问前 20 字）/ last_time / message_count
  /// 旧数据（无 session_id）归入 [legacySessionId]。
  Future<List<Map<String, dynamic>>> loadSessions(String studentId) async {
    if (studentId.trim().isEmpty) return const [];
    final records = await _readHistoryRecords();
    final mine = records
        .where((r) => r['student_id']?.toString() == studentId)
        .where((r) => (r['content']?.toString() ?? '').trim().isNotEmpty)
        .toList();

    // 按 session_id 分组（旧数据归入 legacy）
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final r in mine) {
      final sid = (r['session_id']?.toString() ?? '').trim();
      final key = sid.isEmpty ? legacySessionId : sid;
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(r);
    }

    final sessions = <Map<String, dynamic>>[];
    for (final entry in grouped.entries) {
      final list = entry.value
        ..sort((a, b) => (a['created_at']?.toString() ?? '')
            .compareTo(b['created_at']?.toString() ?? ''));
      // 标题取首条「用户提问」，没有则退化为首条内容
      final firstUser = list.firstWhere(
        (r) => r['role']?.toString() == 'user',
        orElse: () => list.first,
      );
      var title = (firstUser['content']?.toString() ?? '').trim();
      if (title.length > 20) title = '${title.substring(0, 20)}…';
      if (title.isEmpty) title = '未命名对话';

      sessions.add({
        'session_id': entry.key,
        'title': title,
        'last_time': list.last['created_at']?.toString() ?? '',
        'message_count': list.length,
      });
    }

    // 旧数据永远排在最后
    sessions.sort((a, b) {
      if (a['session_id'] == legacySessionId) return 1;
      if (b['session_id'] == legacySessionId) return -1;
      return (b['last_time']?.toString() ?? '')
          .compareTo(a['last_time']?.toString() ?? '');
    });
    return sessions;
  }

  /// 读取历史（按时间倒序，供教师端查看）
  Future<List<Map<String, dynamic>>> loadAllHistory({
    String? classId,
    String? studentId,
    int limit = 200,
  }) async {
    final records = await loadHistory(
      studentId: studentId,
      classId: classId,
      limit: limit,
    );
    return records.reversed.toList();
  }

  /// 清空历史记录（可按学生 / 班级过滤；都不传则清空全部）
  Future<bool> clearHistory({String? studentId, String? classId}) async {
    final hasStudent = studentId != null && studentId.isNotEmpty;
    final hasClass = classId != null && classId.isNotEmpty;

    return _withHistoryLock(() async {
      final records = await _readHistoryRecords();
      // 两个条件都不传 => 清空全部
      final kept = (hasStudent || hasClass)
          ? records.where((r) {
              if (hasStudent && r['student_id']?.toString() == studentId) {
                return false;
              }
              if (hasClass && r['class_id']?.toString() == classId) {
                return false;
              }
              return true;
            }).toList()
          : <Map<String, dynamic>>[];

      final removed = records.length - kept.length;
      if (removed == 0) return true;
      final written = await _writeHistoryRecords(kept);
      if (written) {
        AppLogger.log('已清空 AI 历史记录 $removed 条 '
            '(student=$studentId, class=$classId)');
      }
      return written;
    });
  }

  /// 历史记录中出现过的班级（教师端筛选下拉使用）
  Future<List<String>> historyClassIds() async {
    final records = await _readHistoryRecords();
    final ids = <String>{};
    for (final r in records) {
      final id = r['class_id']?.toString() ?? '';
      if (id.isNotEmpty) ids.add(id);
    }
    final list = ids.toList()..sort();
    return list;
  }

  // ============ 内部实现 ============

  /// 安全解码上游响应体。
  ///
  /// 关键：`http` 包在 `Content-Type` 缺少 `charset` 时按 **latin1** 解码
  /// `response.body`，中文会变成乱码（如「ä½ å¥½」）。很多 OpenAI 兼容
  /// 中转服务只返回 `Content-Type: application/json`（无 charset），
  /// 因此这里统一用 `bodyBytes` + UTF-8 解码。
  String _decodeBody(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } catch (_) {
      // 极端情况下（非 UTF-8 响应）回退到 http 包的默认解码
      return response.body;
    }
  }

  /// 规范化 API 地址：去掉末尾斜杠
  String _normalizedBaseUrl() {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// 取该学生当前会话最近 [limit] 条对话，组装成上游 messages 格式
  ///
  /// [sessionId] 非空时只取该会话的记录，实现「新建对话」的话题隔离。
  Future<List<Map<String, String>>> _recentMessages(
      String studentId, int limit, [String sessionId = '']) async {
    if (limit <= 0) return const [];
    final records = await _readHistoryRecords();
    final mine = records
        .where((r) => r['student_id']?.toString() == studentId)
        .where((r) =>
            sessionId.isEmpty || r['session_id']?.toString() == sessionId)
        .where((r) => r['role'] == 'user' || r['role'] == 'assistant')
        .where((r) => (r['content']?.toString() ?? '').trim().isNotEmpty)
        .toList();
    final start = mine.length > limit ? mine.length - limit : 0;
    return mine
        .sublist(start)
        .map((r) => {
              'role': r['role'].toString(),
              'content': r['content'].toString(),
            })
        .toList();
  }

  /// 构造一条历史记录
  Map<String, dynamic> _buildRecord(
    String studentId,
    String studentName,
    String classId,
    String role,
    String content,
    String model,
    DateTime createdAt,
    String sessionId,
  ) {
    final stamp = createdAt.millisecondsSinceEpoch;
    return {
      'id': '${stamp}_${role}_$studentId',
      'session_id': sessionId,
      'student_id': studentId,
      'student_name': studentName,
      'class_id': classId,
      'role': role,
      'content': content,
      'model': model,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 追加历史记录（文件锁 + 原子写 + 按学生裁剪）
  Future<bool> _appendHistory(List<Map<String, dynamic>> newRecords) async {
    return _withHistoryLock(() async {
      final records = await _readHistoryRecords();
      records.addAll(newRecords);
      return _writeHistoryRecords(_pruneHistory(records));
    });
  }

  /// 每名学生只保留最近 [maxHistoryPerStudent] 条，整体按时间正序
  List<Map<String, dynamic>> _pruneHistory(
      List<Map<String, dynamic>> records) {
    final byStudent = <String, List<Map<String, dynamic>>>{};
    for (final record in records) {
      final key = record['student_id']?.toString() ?? '';
      byStudent.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(record);
    }

    final kept = <Map<String, dynamic>>[];
    for (final list in byStudent.values) {
      if (list.length <= maxHistoryPerStudent) {
        kept.addAll(list);
      } else {
        kept.addAll(list.sublist(list.length - maxHistoryPerStudent));
      }
    }
    kept.sort((a, b) => (a['created_at']?.toString() ?? '')
        .compareTo(b['created_at']?.toString() ?? ''));
    return kept;
  }

  /// 读取历史文件（容错：文件损坏/不存在时返回空列表）
  Future<List<Map<String, dynamic>>> _readHistoryRecords() async {
    try {
      final file = File(historyPath);
      if (!await file.exists()) return [];
      final content = await file.readAsString();
      if (content.trim().isEmpty) return [];
      final data = json.decode(content);
      if (data is Map && data['records'] is List) {
        return (data['records'] as List)
            .whereType<Map>()
            .map((r) => Map<String, dynamic>.from(r))
            .toList();
      }
      return [];
    } catch (e) {
      AppLogger.log('读取 AI 历史失败: $e');
      return [];
    }
  }

  /// 写入历史文件（tmp + JSON 校验 + rename）
  Future<bool> _writeHistoryRecords(List<Map<String, dynamic>> records) async {
    try {
      final dir = Directory(_manageDir);
      if (!await dir.exists()) await dir.create(recursive: true);

      final file = File(historyPath);
      final tempFile = File('${file.path}.tmp');
      final jsonString =
          const JsonEncoder.withIndent('  ').convert({'records': records});
      await tempFile.writeAsString(jsonString, flush: true);
      json.decode(await tempFile.readAsString());
      await tempFile.rename(file.path);
      return true;
    } catch (e) {
      AppLogger.log('写入 AI 历史失败: $e');
      return false;
    }
  }

  /// 串行化历史文件的读改写，避免并发请求互相覆盖
  Future<T> _withHistoryLock<T>(Future<T> Function() action) async {
    final previous = _historyLock;
    final current = Completer<void>();
    _historyLock = current.future;
    if (previous != null) {
      await previous.catchError((_) {});
    }
    try {
      return await action();
    } finally {
      if (!current.isCompleted) current.complete();
      if (identical(_historyLock, current.future)) {
        _historyLock = null;
      }
    }
  }

  /// 从上游响应中提取回答正文
  String _extractReply(String body) {
    try {
      final data = json.decode(body);
      if (data is Map && data['choices'] is List) {
        final choices = data['choices'] as List;
        if (choices.isEmpty) return '';
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String) return content.trim();
          }
        }
      }
    } catch (e) {
      AppLogger.log('解析 AI 响应失败: $e');
    }
    return '';
  }

  /// 把上游 HTTP 错误翻译成学生/教师能看懂的话术
  String _describeHttpError(int statusCode, String body) {
    var detail = '';
    try {
      final data = json.decode(body);
      if (data is Map) {
        final error = data['error'];
        if (error is Map && error['message'] != null) {
          detail = error['message'].toString();
        } else if (data['message'] != null) {
          detail = data['message'].toString();
        }
      }
    } catch (_) {
      // 非 JSON 响应，忽略细节
    }
    final suffix = detail.isEmpty ? '' : '：$detail';

    switch (statusCode) {
      case 400:
        return 'AI 请求参数有误$suffix';
      case 401:
        return 'API Key 无效或已过期$suffix';
      case 402:
        return 'AI 账户余额不足$suffix';
      case 404:
        return 'API 地址或模型不存在$suffix';
      case 429:
        return 'AI 服务请求过于频繁，请稍后再试$suffix';
      default:
        if (statusCode >= 500) {
          return 'AI 服务暂不可用（HTTP $statusCode）$suffix';
        }
        return 'AI 请求失败（HTTP $statusCode）$suffix';
    }
  }
}

/// AI 提问结果
class AiChatResult {
  final bool success;
  final String reply;
  final String model;
  final String createdAt;
  final String error;
  final int statusCode;

  /// 本次问答所属会话 ID（新建会话时由服务端生成）
  final String sessionId;

  /// 本次成功后该学生今日剩余提问次数
  final int remainingQuota;

  const AiChatResult({
    required this.success,
    this.reply = '',
    this.model = '',
    this.createdAt = '',
    this.error = '',
    this.statusCode = 200,
    this.sessionId = '',
    this.remainingQuota = -1,
  });

  factory AiChatResult.success(
    String reply, {
    String model = '',
    String createdAt = '',
    String sessionId = '',
    int remainingQuota = -1,
  }) =>
      AiChatResult(
        success: true,
        reply: reply,
        model: model,
        createdAt: createdAt,
        sessionId: sessionId,
        remainingQuota: remainingQuota,
      );

  factory AiChatResult.failure(String error, {int statusCode = 500}) =>
      AiChatResult(success: false, error: error, statusCode: statusCode);
}

/// 流式事件的类型
enum AiStreamEventType {
  /// 流开始：携带会话 ID / 模型 / 剩余配额
  meta,

  /// 增量文本
  delta,

  /// 正常结束
  done,

  /// 出错
  error,
}

/// 一个流式事件（教师端内部 + SSE 传输格式）
class AiStreamChunk {
  final AiStreamEventType type;

  /// delta 时有效：本次增量文本
  final String content;

  /// meta 时有效：实际使用的会话 ID
  final String sessionId;

  /// meta 时有效：模型名
  final String model;

  /// meta 时有效：扣减后的今日剩余次数
  final int remainingQuota;

  /// error 时有效：可直接展示的错误话术
  final String error;

  const AiStreamChunk({
    required this.type,
    this.content = '',
    this.sessionId = '',
    this.model = '',
    this.remainingQuota = -1,
    this.error = '',
  });

  factory AiStreamChunk.meta({
    required String sessionId,
    required String model,
    required int remainingQuota,
  }) =>
      AiStreamChunk(
        type: AiStreamEventType.meta,
        sessionId: sessionId,
        model: model,
        remainingQuota: remainingQuota,
      );

  factory AiStreamChunk.delta(String content) =>
      AiStreamChunk(type: AiStreamEventType.delta, content: content);

  factory AiStreamChunk.done() => const AiStreamChunk(
        type: AiStreamEventType.done,
      );

  factory AiStreamChunk.error(String error) =>
      AiStreamChunk(type: AiStreamEventType.error, error: error);

  /// 转成 SSE 的 JSON 载荷
  Map<String, dynamic> toJson() {
    switch (type) {
      case AiStreamEventType.meta:
        return {
          'type': 'meta',
          'session_id': sessionId,
          'model': model,
          'remaining_quota': remainingQuota,
        };
      case AiStreamEventType.delta:
        return {'type': 'delta', 'content': content};
      case AiStreamEventType.done:
        return {'type': 'done'};
      case AiStreamEventType.error:
        return {'type': 'error', 'message': error};
    }
  }
}

/// AI 连接测试结果
class AiTestResult {
  final bool success;
  final String message;

  const AiTestResult({required this.success, required this.message});

  factory AiTestResult.success(String message) =>
      AiTestResult(success: true, message: message);

  factory AiTestResult.failure(String message) =>
      AiTestResult(success: false, message: message);
}
