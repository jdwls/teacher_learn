import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../services/typing_article_service.dart';

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

  final List<String> _classList = [
    for (var g in ['初一', '初二', '初三'])
      for (var c = 1; c <= 20; c++) '$g${c.toString().padLeft(2, '0')}班',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadArticles();
    _loadSchedule();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  Future<void> _syncConfigToServer() async {
    try {
      await http.post(
        Uri.parse('http://localhost:20020/api/typing-config'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'chinese': {
            'time_limit': _chineseTimeLimit,
            'target_chars': _chineseTargetChars,
            'target_speed': _chineseTargetSpeed,
            'points_per_error': _chinesePointsPerError,
            'random': _chineseRandom,
            'selected_article_index': _chineseSelectedArticleIndex,
          },
          'english': {
            'time_limit': _englishTimeLimit,
            'target_chars': _englishTargetChars,
            'target_speed': _englishTargetSpeed,
            'points_per_error': _englishPointsPerError,
            'random': _englishRandom,
            'selected_article_index': _englishSelectedArticleIndex,
          },
        }),
      );
    } catch (e) {
      print('同步打字配置失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    _buildSectionTitle('学生端控制', '配置学生端打字练习参数。'),
                    const SizedBox(height: 16),
                    _buildConfigSection(),
                  ],
                ),
              ),
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('课表管理', '信息科技 · 周课表'),
                    const SizedBox(height: 16),
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
            ],
          ),
        ),
      ],
    );
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
      builder: (ctx) => AlertDialog(
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
              selected = v;
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

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: const TextStyle(
                fontSize: 20,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700)),
      ],
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
                '$_chineseTargetSpeed 字/分',
                () => _editValue(
                    '中文目标速度',
                    _chineseTargetSpeed,
                    (v) => setState(() {
                          _chineseTargetSpeed = v;
                          _syncConfigToServer();
                        }))),
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
              onChanged: (index) =>
                  setState(() => _chineseSelectedArticleIndex = index),
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
                '$_englishTargetSpeed 字/分',
                () => _editValue(
                    '英文目标速度',
                    _englishTargetSpeed,
                    (v) => setState(() {
                          _englishTargetSpeed = v;
                          _syncConfigToServer();
                        }))),
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
              onChanged: (index) =>
                  setState(() => _englishSelectedArticleIndex = index),
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

  Widget _buildConfigItem(String label, String value, VoidCallback onEdit) {
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
          const SizedBox(width: 8),
          InkWell(
            onTap: onEdit,
            child:
                const Icon(Icons.edit, size: 16, color: AppTheme.primaryBlue),
          ),
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
