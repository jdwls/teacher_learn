import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/typing_article_service.dart';
import '../services/http_server_service.dart';

/// 学生端控制页面
class TypingControlPage extends StatefulWidget {
  const TypingControlPage({super.key});

  @override
  State<TypingControlPage> createState() => _TypingControlPageState();
}

class _TypingControlPageState extends State<TypingControlPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _chineseTimeLimit = 5;
  int _chineseTargetChars = 100;
  int _chineseTargetSpeed = 20;
  double _chinesePointsPerError = 1.0;
  bool _chineseRandom = true;
  int _englishTimeLimit = 5;
  int _englishTargetChars = 500;
  int _englishTargetSpeed = 100;
  double _englishPointsPerError = 0.2;
  bool _englishRandom = true;
  List<Map<String, dynamic>> _chineseArticles = [];
  List<Map<String, dynamic>> _englishArticles = [];
  int? _chineseSelectedArticleIndex;
  int? _englishSelectedArticleIndex;
  final List<String> _weekdays = ['周一', '周二', '周三', '周四', '周五'];
  final List<Map<String, String>> _periods = [
    {'time': '08:00-08:45'},
    {'time': '08:55-09:40'},
    {'time': '10:00-10:45'},
    {'time': '10:55-11:40'},
    {'time': '14:00-14:45'},
    {'time': '14:55-15:40'},
    {'time': '16:00-16:45'},
    {'time': '16:55-17:40'},
  ];
  List<List<String>> _schedule = List.generate(8, (_) => List.filled(5, ''));

  // 在线升级
  bool _onlineUpdateEnabled = false;
  bool _onlineForceUpdate = false;
  final TextEditingController _targetVersionController =
      TextEditingController();

  final List<String> _classList = [
    for (var g in ['初一', '初二', '初三'])
      for (var c = 1; c <= 20; c++) '$g${c.toString().padLeft(2, '0')}班',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadArticles();
    _loadSchedule();
    _onlineUpdateEnabled = HttpServerService.instance.onlineUpdateEnabled;
    _onlineForceUpdate = HttpServerService.instance.onlineForceUpdate;
    _targetVersionController.text =
        HttpServerService.instance.targetVersion;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _targetVersionController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:20020/api/schedule'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final scheduleData = data['data'] as Map<String, dynamic>;
          final periods = scheduleData['periods'] as List<dynamic>?;
          final days = scheduleData['days'] as Map<String, dynamic>?;
          if (!mounted) return;
          setState(() {
            if (periods != null) {
              for (int i = 0; i < periods.length && i < _periods.length; i++) {
                _periods[i]['time'] = periods[i]['time'] ?? _periods[i]['time'];
              }
            }
            if (days != null) {
              for (int d = 0; d < _weekdays.length; d++) {
                final dayData = days[_weekdays[d]] as List<dynamic>?;
                if (dayData != null) {
                  for (int p = 0; p < dayData.length && p < 8; p++) {
                    _schedule[p][d] = dayData[p]?.toString() ?? '';
                  }
                }
              }
            }
          });
        }
      }
    } catch (e) {
      print('加载课表失败: $e');
    }
  }

  Future<void> _saveSchedule() async {
    try {
      final data = {
        'periods': _periods,
        'days': {
          for (int d = 0; d < _weekdays.length; d++)
            _weekdays[d]: List.generate(8, (p) => _schedule[p][d]),
        },
      };
      final response = await http
          .post(
            Uri.parse('http://localhost:20020/api/schedule'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(data),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('课表已保存'),
            backgroundColor: AppTheme.primaryBlue,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('保存失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _loadArticles() {
    _chineseArticles = TypingArticleService.getAllArticles('chinese');
    _englishArticles = TypingArticleService.getAllArticles('english');
    _loadConfigFromServer();
  }

  Future<void> _loadConfigFromServer() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:20020/api/typing-config'))
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final config = data['data'] as Map<String, dynamic>;
          final chinese = config['chinese'] as Map<String, dynamic>? ?? {};
          final english = config['english'] as Map<String, dynamic>? ?? {};
          if (!mounted) return;
          setState(() {
            _chineseTimeLimit = chinese['time_limit'] ?? _chineseTimeLimit;
            _chineseTargetChars =
                chinese['target_chars'] ?? _chineseTargetChars;
            _chineseTargetSpeed =
                chinese['target_speed'] ?? _chineseTargetSpeed;
            _chinesePointsPerError =
                (chinese['points_per_error'] as num?)?.toDouble() ??
                    _chinesePointsPerError;
            _chineseRandom = chinese['random'] ?? _chineseRandom;
            _chineseSelectedArticleIndex = chinese['selected_article_index'];
            _englishTimeLimit = english['time_limit'] ?? _englishTimeLimit;
            _englishTargetChars =
                english['target_chars'] ?? _englishTargetChars;
            _englishTargetSpeed =
                english['target_speed'] ?? _englishTargetSpeed;
            _englishPointsPerError =
                (english['points_per_error'] as num?)?.toDouble() ??
                    _englishPointsPerError;
            _englishRandom = english['random'] ?? _englishRandom;
            _englishSelectedArticleIndex = english['selected_article_index'];
          });
        }
      }
    } catch (e) {
      print('加载打字配置失败: $e');
    }
  }

  Future<bool> _syncConfigToServer() async {
    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:20020/api/typing-config'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'chinese': {
                'time_limit': _chineseTimeLimit,
                'target_chars': _chineseTargetChars,
                'target_speed': _chineseTimeLimit > 0
                    ? (_chineseTargetChars / _chineseTimeLimit).round()
                    : _chineseTargetSpeed,
                'points_per_error': _chinesePointsPerError,
                'random': _chineseRandom,
                'selected_article_index': _chineseSelectedArticleIndex,
              },
              'english': {
                'time_limit': _englishTimeLimit,
                'target_chars': _englishTargetChars,
                'target_speed': _englishTimeLimit > 0
                    ? (_englishTargetChars / _englishTimeLimit).round()
                    : _englishTargetSpeed,
                'points_per_error': _englishPointsPerError,
                'random': _englishRandom,
                'selected_article_index': _englishSelectedArticleIndex,
              },
            }),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return true;
      }
      print('同步打字配置失败: HTTP ${response.statusCode}');
    } catch (e) {
      print('同步打字配置失败: $e');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('配置保存失败，请检查网络连接'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryBlue,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            tabs: const [
              Tab(text: '打字配置'),
              Tab(text: '课表管理'),
              Tab(text: '在线升级'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildConfigSection(),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildScheduleTable(),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _saveSchedule,
                        icon: const Icon(Icons.save),
                        label: const Text('保存课表'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Tab 3: 在线升级
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOnlineUpdatePanel(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== Tab 3: 在线升级 ====================

  /// 在线升级面板（包文件名 / 强制升级 / 总开关 / 学生端版本分布）
  Widget _buildOnlineUpdatePanel() {
    final svc = HttpServerService.instance;
    final packageName = svc.onlinePackageName;
    final packageInfo = svc.onlinePackageInfo;
    final distribution = svc.studentVersionDistribution;
    final totalStudents = distribution.values.fold(0, (a, b) => a + b);
    final hasPackage = packageName.isNotEmpty && packageInfo != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 是否升级开关
          Row(
            children: [
              const Icon(Icons.system_update,
                  size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              const Text('学生端在线升级',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const Spacer(),
              const Text('学生端主动检查升级',
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              const SizedBox(width: 8),
              Switch(
                value: _onlineUpdateEnabled,
                onChanged: _toggleOnlineUpdate,
                activeColor: AppTheme.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 强制升级开关
          Row(
            children: [
              const Icon(Icons.priority_high,
                  size: 20, color: Color(0xFFEA580C)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('强制升级',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    SizedBox(height: 2),
                    Text('开启后学生端发现新版本会跳过允许弹窗直接进入升级',
                        style: TextStyle(
                            fontSize: 11, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              Switch(
                value: _onlineForceUpdate,
                onChanged: (v) => _toggleForceUpdate(v),
                activeColor: AppTheme.primaryBlue,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 升级包文件名（只读展示，来自目录自动扫描）
          Row(
            children: [
              const Icon(Icons.folder_zip,
                  size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              const Text('升级包文件名:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD6DBE8)),
                  ),
                  child: Text(
                    hasPackage
                        ? packageName
                        : '未在 student_online_update/ 目录找到 zip 升级包',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasPackage
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (hasPackage) ...[
                const SizedBox(width: 12),
                Text(
                  '目标版本 ${packageInfo.version.isEmpty ? '未知' : packageInfo.version}'
                  ' · ${(packageInfo.size / 1024 / 1024).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _refreshOnlinePackages,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('重新扫描'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 目标学生端版本（教师输入，必填；与学生实际版本不一致即更新，含降级）
          Row(
            children: [
              const Icon(Icons.verified,
                  size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              const Text('目标学生端版本:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _targetVersionController,
                  keyboardType: TextInputType.text,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9a-zA-Z\.\-_]')),
                  ],
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: '如 1.1.0（必填）',
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFD6DBE8)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(color: Color(0xFFD6DBE8)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _startOnlineUpdate,
                icon: const Icon(Icons.system_update_alt, size: 18),
                label: const Text('开始升级'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
              '学生端会与该目标版本比对，版本不一致即自动更新（支持降级）。开始升级前请确认升级目录内已放入整包 zip。',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          const Text(
              '升级包放置说明：将整包 zip 放入 student_online_update/ 文件夹即可，系统自动识别最新 zip，无需填写文件名。',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          // 学生端当前版本信息
          Row(
            children: [
              const Icon(Icons.devices, size: 20, color: AppTheme.primaryBlue),
              const SizedBox(width: 12),
              const Text('学生端当前版本信息',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              Text(
                totalStudents == 0 ? '暂无上报' : '共 $totalStudents 台已上报',
                style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (distribution.isEmpty)
            const Text(
              '学生端连接后会定期上报当前版本，这里将显示每个版本的学生机数量。',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in distribution.entries)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD6DBE8)),
                    ),
                    child: Text(
                      '${entry.key}：${entry.value} 台',
                      style: const TextStyle(
                          fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// 切换在线升级开关
  Future<void> _toggleOnlineUpdate(bool enabled) async {
    setState(() {
      _onlineUpdateEnabled = enabled;
    });
    await HttpServerService.instance.setOnlineUpdateEnabled(enabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enabled ? '已开启学生端在线升级' : '已关闭学生端在线升级'),
          backgroundColor: enabled ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// 切换强制升级开关
  Future<void> _toggleForceUpdate(bool force) async {
    setState(() {
      _onlineForceUpdate = force;
    });
    await HttpServerService.instance.setOnlineForceUpdate(force);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(force ? '已开启强制升级' : '已关闭强制升级'),
          backgroundColor: force ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  /// 重新扫描升级包目录（教师端手动触发）
  Future<void> _refreshOnlinePackages() async {
    await HttpServerService.instance.refreshOnlinePackages();
    if (mounted) setState(() {});
  }

  /// 下发目标学生端版本（教师端「开始升级」按钮）
  ///
  /// 前置校验（任一为空则不能升级）：
  ///   1. 目标版本号已填写；
  ///   2. student_online_update 目录内存在升级包 zip。
  Future<void> _startOnlineUpdate() async {
    final version = _targetVersionController.text.trim();
    if (version.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('请先填写目标学生端版本号'),
        backgroundColor: Colors.orange,
      ));
      return;
    }
    final svc = HttpServerService.instance;
    final ok = await svc.setOnlineTargetVersion(version);
    if (!mounted) return;
    if (ok) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('已下发目标版本 $version，学生端将自动比对并更新'),
        backgroundColor: Colors.green,
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('无法升级：升级目录内没有升级包，请先放入整包 zip'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Widget _buildScheduleTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: isWide ? constraints.maxWidth : 480,
              ),
              child: Table(
                border:
                    TableBorder.all(color: const Color(0xFFE2E8F0), width: 1),
                columnWidths: {
                  0: FixedColumnWidth(isWide ? 140 : 100),
                  for (int i = 1; i <= 5; i++)
                    i: FlexColumnWidth(isWide ? 1 : 0.8),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withAlpha(26)),
                    children: [
                      _buildHeaderCell('时间'),
                      ..._weekdays.map((d) => _buildHeaderCell(d)),
                    ],
                  ),
                  for (int p = 0; p < 4; p++) _buildScheduleRow(p),
                  TableRow(
                    decoration: BoxDecoration(color: Colors.grey[100]),
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: const Center(
                          child: Text('午休',
                              style: TextStyle(
                                  fontSize: 18,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      for (int i = 0; i < 5; i++)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          color: Colors.grey[100],
                        ),
                    ],
                  ),
                  for (int p = 4; p < 8; p++) _buildScheduleRow(p),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(text,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ),
    );
  }

  TableRow _buildScheduleRow(int periodIndex) {
    return TableRow(
      children: [
        InkWell(
          onTap: () => _editTime(periodIndex),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Center(
              child: Text(_periods[periodIndex]['time']!,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
            ),
          ),
        ),
        for (int d = 0; d < 5; d++)
          InkWell(
            onTap: () => _editScheduleCell(periodIndex, d),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Center(
                child: Text(
                  _schedule[periodIndex][d].isEmpty
                      ? '-'
                      : _schedule[periodIndex][d],
                  style: TextStyle(
                    fontSize: 18,
                    color: _schedule[periodIndex][d].isEmpty
                        ? Colors.grey[300]
                        : AppTheme.textPrimary,
                    fontWeight: _schedule[periodIndex][d].isEmpty
                        ? FontWeight.w500
                        : FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _editScheduleCell(int period, int day) {
    String? selected =
        _schedule[period][day].isEmpty ? null : _schedule[period][day];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, dialogSetState) => AlertDialog(
          title: Text('选择班级 · ${_weekdays[day]} ${_periods[period]['time']}'),
          content: SizedBox(
            width: 300,
            child: DropdownButtonFormField<String>(
              value: selected,
              hint: const Text('选择班级'),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('（空）', style: TextStyle(color: Colors.grey)),
                ),
                ..._classList.map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c),
                    )),
              ],
              onChanged: (v) {
                dialogSetState(() {
                  selected = v;
                });
              },
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _schedule[period][day] = selected ?? '';
                });
                Navigator.pop(ctx);
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  void _editTime(int periodIndex) {
    final controller =
        TextEditingController(text: _periods[periodIndex]['time']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑第${periodIndex + 1}节时间'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '如 08:00-08:45',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _periods[periodIndex]['time'] = controller.text;
              });
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('打字配置',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 21)),
          const SizedBox(height: 16),
          _buildConfigRow('中文打字配置', [
            _buildConfigItem(
                '时间限制',
                '$_chineseTimeLimit 分钟',
                () => _editValue(
                    '中文时间限制',
                    _chineseTimeLimit,
                    (v) => setState(() {
                          _chineseTimeLimit = v;
                          _syncConfigToServer();
                        }))),
            _buildConfigItem(
                '满分字数',
                '$_chineseTargetChars 字',
                () => _editValue(
                    '中文满分字数',
                    _chineseTargetChars,
                    (v) => setState(() {
                          _chineseTargetChars = v;
                          _syncConfigToServer();
                        }))),
            _buildConfigItem(
                '目标速度',
                '${_chineseTimeLimit > 0 ? (_chineseTargetChars / _chineseTimeLimit).round() : _chineseTargetSpeed} 字/分',
                null),
            _buildConfigItem(
                '每错扣分',
                '$_chinesePointsPerError 分',
                () => _editDoubleValue(
                    '中文每错扣分',
                    _chinesePointsPerError,
                    (v) => setState(() {
                          _chinesePointsPerError = v;
                          _syncConfigToServer();
                        }))),
          ]),
          const SizedBox(height: 12),
          _buildSwitchItem('中文文章随机', _chineseRandom, (v) {
            setState(() {
              _chineseRandom = v;
              if (v) _chineseSelectedArticleIndex = null;
            });
            _syncConfigToServer();
          }),
          if (!_chineseRandom) ...[
            const SizedBox(height: 12),
            _buildArticleDropdown(
              articles: _chineseArticles,
              selectedIndex: _chineseSelectedArticleIndex,
              label: '选择中文文章',
              onChanged: (index) {
                setState(() => _chineseSelectedArticleIndex = index);
                _syncConfigToServer();
              },
            ),
          ],
          const Divider(height: 24),
          _buildConfigRow('英文打字配置', [
            _buildConfigItem(
                '时间限制',
                '$_englishTimeLimit 分钟',
                () => _editValue(
                    '英文时间限制',
                    _englishTimeLimit,
                    (v) => setState(() {
                          _englishTimeLimit = v;
                          _syncConfigToServer();
                        }))),
            _buildConfigItem(
                '满分字符',
                '$_englishTargetChars 字符',
                () => _editValue(
                    '英文满分字符',
                    _englishTargetChars,
                    (v) => setState(() {
                          _englishTargetChars = v;
                          _syncConfigToServer();
                        }))),
            _buildConfigItem(
                '目标速度',
                '${_englishTimeLimit > 0 ? (_englishTargetChars / _englishTimeLimit).round() : _englishTargetSpeed} 字/分',
                null),
            _buildConfigItem(
                '每错扣分',
                '$_englishPointsPerError 分',
                () => _editDoubleValue(
                    '英文每错扣分',
                    _englishPointsPerError,
                    (v) => setState(() {
                          _englishPointsPerError = v;
                          _syncConfigToServer();
                        }))),
          ]),
          const SizedBox(height: 12),
          _buildSwitchItem('英文文章随机', _englishRandom, (v) {
            setState(() {
              _englishRandom = v;
              if (v) _englishSelectedArticleIndex = null;
            });
            _syncConfigToServer();
          }),
          if (!_englishRandom) ...[
            const SizedBox(height: 12),
            _buildArticleDropdown(
              articles: _englishArticles,
              selectedIndex: _englishSelectedArticleIndex,
              label: '选择英文文章',
              onChanged: (index) {
                setState(() => _englishSelectedArticleIndex = index);
                _syncConfigToServer();
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildArticleDropdown({
    required List<Map<String, dynamic>> articles,
    required int? selectedIndex,
    required String label,
    required ValueChanged<int?> onChanged,
  }) {
    if (articles.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFDBA74)),
        ),
        child: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange, size: 16),
            SizedBox(width: 8),
            Text('暂无文章，请先导入',
                style: TextStyle(
                    fontSize: 20,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<int>(
        value: selectedIndex,
        hint: Text(label,
            style: const TextStyle(
                fontSize: 20,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700)),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
        menuMaxHeight: 250,
        items: List.generate(articles.length, (index) {
          final article = articles[index];
          final title = article['title'] ?? '文章 ${index + 1}';
          return DropdownMenuItem<int>(
            value: index,
            child: Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          );
        }),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildConfigRow(String title, List<Widget> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
        const SizedBox(height: 8),
        Wrap(spacing: 16, runSpacing: 8, children: items),
      ],
    );
  }

  Widget _buildConfigItem(String label, String value, VoidCallback? onEdit) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 17,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 20)),
            ],
          ),
          if (onEdit != null) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: onEdit,
              child:
                  const Icon(Icons.edit, size: 16, color: AppTheme.primaryBlue),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchItem(
      String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryBlue,
          ),
        ],
      ),
    );
  }

  void _editValue(String label, int current, Function(int) onChanged) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑$label'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final value = int.tryParse(controller.text);
              if (value != null && value > 0) {
                onChanged(value);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _editDoubleValue(
      String label, double current, Function(double) onChanged) {
    final controller = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑$label'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              if (value != null && value > 0) {
                onChanged(value);
                Navigator.pop(ctx);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
