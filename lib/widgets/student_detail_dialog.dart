import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_theme.dart';

/// 学生详情弹窗：打字成绩 / 小测成绩 / AI 对话
///
/// 数据来源：
///   - `GET /api/student-detail/<student_id>` → exam_results / typing_results
///   - `GET /api/ai/history?student_id=`      → AI 对话（按会话分组）
class StudentDetailDialog extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentDetailDialog({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  /// 便捷打开方式
  static Future<void> show(
    BuildContext context, {
    required String studentId,
    required String studentName,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => StudentDetailDialog(
        studentId: studentId,
        studentName: studentName,
      ),
    );
  }

  @override
  State<StudentDetailDialog> createState() => _StudentDetailDialogState();
}

class _StudentDetailDialogState extends State<StudentDetailDialog> {
  static const int _apiPort = 20020;

  bool _isLoading = true;
  String? _error;

  List<Map<String, dynamic>> _typingResults = [];
  List<Map<String, dynamic>> _examResults = [];
  List<Map<String, dynamic>> _aiMessages = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _baseUrl => 'http://localhost:$_apiPort/api';

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final detail = await _fetchStudentDetail();
      final ai = await _fetchAiHistory();
      if (!mounted) return;
      setState(() {
        _typingResults = detail.typing;
        _examResults = detail.exam;
        _aiMessages = ai;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '加载失败: $e';
      });
    }
  }

  /// 拉取打字与小测成绩（一次请求拿两项）
  Future<({List<Map<String, dynamic>> typing, List<Map<String, dynamic>> exam})>
      _fetchStudentDetail() async {
    final response = await http
        .get(Uri.parse(
            '$_baseUrl/student-detail/${Uri.encodeComponent(widget.studentId)}'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    // 用 bodyBytes 解码，避免响应缺 charset 时中文乱码
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['success'] != true) {
      throw Exception(data['error']?.toString() ?? '接口返回失败');
    }
    List<Map<String, dynamic>> toList(dynamic value) =>
        (value as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
    return (
      typing: toList(data['typing_results']),
      exam: toList(data['exam_results']),
    );
  }

  /// 拉取 AI 对话记录
  Future<List<Map<String, dynamic>>> _fetchAiHistory() async {
    final response = await http
        .get(Uri.parse('$_baseUrl/ai/history'
            '?student_id=${Uri.encodeQueryComponent(widget.studentId)}&limit=500'))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return [];
    final data =
        json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (data['success'] != true) return [];
    return (data['records'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// 清空该生全部 AI 对话记录（不影响每日提问次数）
  Future<void> _clearAiHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空'),
        content: Text('确定清空「${widget.studentName}」的全部 AI 对话记录吗？'
            '\n此操作不可撤销（不影响每日提问次数）。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: AppTheme.dangerButtonStyle,
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http
          .delete(Uri.parse('$_baseUrl/ai/history'
              '?student_id=${Uri.encodeQueryComponent(widget.studentId)}'))
          .timeout(const Duration(seconds: 10));
      final data =
          json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      if (!mounted) return;
      if (data['success'] == true) {
        setState(() => _aiMessages = []);
        _showSnack('对话记录已清空');
      } else {
        _showSnack(data['error']?.toString() ?? '清空失败', isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('清空失败: $e', isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.dangerRed : AppTheme.successGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 620),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return SizedBox(
        height: 300,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 40, color: AppTheme.dangerRed),
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: AppTheme.dangerRed)),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _load, child: const Text('重试')),
            ],
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const TabBar(
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryBlue,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: [
              Tab(text: '打字成绩'),
              Tab(text: '小测成绩'),
              Tab(text: 'AI 对话'),
            ],
          ),
          const Divider(height: 1),
          Flexible(
            child: TabBarView(
              children: [
                _buildTypingTab(),
                _buildExamTab(),
                _buildAiTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person,
                size: 20, color: AppTheme.primaryBlue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.studentName,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary),
                ),
                Text(
                  '打字 ${_typingResults.length} 条 · '
                  '小测 ${_examResults.length} 条 · '
                  'AI 对话 ${_aiMessages.length} 条',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: '刷新',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 20),
            tooltip: '关闭',
          ),
        ],
      ),
    );
  }

  // ==================== Tab 1：打字成绩 ====================

  Widget _buildTypingTab() {
    if (_typingResults.isEmpty) {
      return _buildEmpty('暂无打字成绩记录');
    }
    final sorted = List<Map<String, dynamic>>.from(_typingResults)
      ..sort((a, b) => (b['submit_time']?.toString() ?? '')
          .compareTo(a['submit_time']?.toString() ?? ''));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = sorted[index];
        final type = (r['type']?.toString() ?? '').toLowerCase();
        final typeLabel = type == 'chinese'
            ? '中文打字'
            : type == 'english'
                ? '英文打字'
                : (type.isEmpty ? '打字' : type);
        final typeColor = type == 'chinese'
            ? const Color(0xFF3B82F6)
            : const Color(0xFF22C55E);
        final score = _asDouble(r['score']);
        final speed = _asDouble(r['speed'] ?? r['wpm'] ?? r['cpm']);
        final accuracy = _asDouble(r['accuracy']);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(typeLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: typeColor)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _buildMetric('得分', score.toStringAsFixed(1)),
                    if (speed > 0)
                      _buildMetric('速度', '${speed.toStringAsFixed(0)} 字/分'),
                    if (accuracy > 0)
                      _buildMetric('正确率', '${accuracy.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
              Text(
                _formatTime(r['submit_time']?.toString() ?? ''),
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==================== Tab 2：小测成绩 ====================

  Widget _buildExamTab() {
    if (_examResults.isEmpty) {
      return _buildEmpty('暂无小测成绩记录');
    }
    final sorted = List<Map<String, dynamic>>.from(_examResults)
      ..sort((a, b) => (b['submit_time']?.toString() ?? '')
          .compareTo(a['submit_time']?.toString() ?? ''));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: sorted.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final r = sorted[index];
        final score = _asDouble(r['score']);
        final points = (r['points'] as num?)?.toInt() ?? 0;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['exam_name']?.toString() ?? '未命名小测',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(r['submit_time']?.toString() ?? ''),
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _buildMetric('得分', score.toStringAsFixed(1)),
              const SizedBox(width: 16),
              _buildMetric('积分', '+$points'),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style:
                const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ],
    );
  }

  Widget _buildEmpty(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined,
              size: 40, color: AppTheme.textSecondary.withAlpha(128)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ==================== Tab 3：AI 对话 ====================

  Widget _buildAiTab() {
    if (_aiMessages.isEmpty) {
      return _buildEmpty('暂无 AI 对话记录');
    }

    // 按会话分组（无 session_id 归入「历史对话（旧）」）
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final m in _aiMessages) {
      final sid = (m['session_id']?.toString() ?? '').trim();
      final key = sid.isEmpty ? '__legacy__' : sid;
      grouped.putIfAbsent(key, () => <Map<String, dynamic>>[]).add(m);
    }
    final sessionIds = grouped.keys.toList()
      ..sort((a, b) {
        if (a == '__legacy__') return 1;
        if (b == '__legacy__') return -1;
        return (grouped[b]!.last['created_at']?.toString() ?? '')
            .compareTo(grouped[a]!.last['created_at']?.toString() ?? '');
      });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Text(
                '共 ${sessionIds.length} 个会话 · ${_aiMessages.length} 条消息',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _clearAiHistory,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('清空该生 AI 记录'),
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: sessionIds.length,
            itemBuilder: (context, index) {
              final sid = sessionIds[index];
              final messages = grouped[sid]!
                ..sort((a, b) => (a['created_at']?.toString() ?? '')
                    .compareTo(b['created_at']?.toString() ?? ''));
              return _buildSessionGroup(sid, messages);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionGroup(String sessionId, List<Map<String, dynamic>> messages) {
    final isLegacy = sessionId == '__legacy__';
    final firstUser = messages.firstWhere(
      (m) => m['role']?.toString() == 'user',
      orElse: () => messages.first,
    );
    var title = (firstUser['content']?.toString() ?? '').trim();
    if (title.length > 24) title = '${title.substring(0, 24)}…';
    if (title.isEmpty) title = '未命名对话';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: messages.length <= 6,
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(
            isLegacy ? '历史对话（旧）' : title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${messages.length} 条消息 · '
            '${_formatTime(messages.last['created_at']?.toString() ?? '')}',
            style: const TextStyle(
                fontSize: 11, color: AppTheme.textSecondary),
          ),
          children: messages.map(_buildAiMessageTile).toList(),
        ),
      ),
    );
  }

  Widget _buildAiMessageTile(Map<String, dynamic> message) {
    final isUser = message['role']?.toString() == 'user';
    final accent = isUser ? AppTheme.primaryBlue : const Color(0xFF8B5CF6);
    final content = message['content']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                  size: 13, color: accent),
              const SizedBox(width: 5),
              Text(
                isUser ? '学生提问' : 'AI 回答',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: accent),
              ),
              const Spacer(),
              Text(
                _formatTime(message['created_at']?.toString() ?? ''),
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SelectableText(
            content,
            style: const TextStyle(
                fontSize: 12.5, height: 1.5, color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoTime) {
    if (isoTime.isEmpty) return '-';
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.year}/${dt.month}/${dt.day} '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }
}
