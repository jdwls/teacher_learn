import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/statistics_provider.dart';
import '../providers/auth_provider.dart';
import '../services/question_bank_config_service.dart';
import '../services/question_bank_service.dart';
import '../theme/app_theme.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 排序状态
  int _sortColumnIndex = 2; // 默认按得分排序
  bool _sortAscending = false; // 默认降序

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _initData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听首页同步的题库变化（延迟到下一帧避免在build期间调用setState）
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<StatisticsProvider>();
      final currentBank = await QuestionBankConfigService.getSelectedBank();
      if (currentBank != null &&
          currentBank != provider.selectedExamName &&
          provider.bankList.contains(currentBank)) {
        provider.selectExamName(currentBank);
      }
    });
  }

  Future<void> _initData() async {
    final provider = context.read<StatisticsProvider>();
    final authProvider = context.read<AuthProvider>();

    await Future.wait([
      provider.loadClassList(),
      provider.loadBankList(),
    ]);

    final defaultClass = authProvider.selectedClassLabel;
    final defaultBank = await QuestionBankConfigService.getSelectedBank();

    if (defaultClass != null && provider.classList.contains(defaultClass)) {
      provider.selectClass(defaultClass);
    } else if (provider.classList.isNotEmpty) {
      provider.selectClass(provider.classList.first);
    }

    if (defaultBank != null && provider.bankList.contains(defaultBank)) {
      provider.selectExamName(defaultBank);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildTopBar(),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textSecondary,
            indicatorColor: AppTheme.primaryBlue,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 21),
            tabs: const [
              Tab(text: '课堂小测'),
              Tab(text: '中文打字'),
              Tab(text: '英文打字'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTab('exam'),
              _buildTab('chinese'),
              _buildTab('english'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: [
          _buildClassSelector(),
          const SizedBox(width: 12),
          _buildBankSelector(),
          const SizedBox(width: 12),
          _buildDateSelector(),
          const Spacer(),
          // 班级错题按钮
          ElevatedButton.icon(
            onPressed: _showClassWrongQuestionsDialog,
            icon: const Icon(Icons.error_outline, size: 18),
            label: const Text('班级错题',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerRed,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('刷新',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassSelector() {
    return Consumer<StatisticsProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('班级',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderMain),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider.selectedClass,
                  hint: const Text('选择班级',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 18)),
                  menuMaxHeight: 48.0 * 5,
                  items: provider.classList
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) provider.selectClass(v);
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBankSelector() {
    return Consumer<StatisticsProvider>(
      builder: (context, provider, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('题库',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue),
                borderRadius: BorderRadius.circular(8),
                color: AppTheme.primaryBlue.withAlpha(15),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  value: provider.selectedExamName,
                  hint: const Text('全部题库',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 18)),
                  menuMaxHeight: 48.0 * 5,
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('全部题库',
                          style: TextStyle(
                              fontSize: 18, color: AppTheme.textSecondary)),
                    ),
                    ...provider.bankList
                        .map((name) => DropdownMenuItem<String?>(
                              value: name,
                              child: Text(
                                  name.length > 7
                                      ? '题库 ${name.substring(0, 7)}...'
                                      : '题库 $name',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: AppTheme.primaryBlue,
                                      fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1),
                            )),
                  ],
                  onChanged: (v) => provider.selectExamName(v),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateSelector() {
    return Consumer<StatisticsProvider>(
      builder: (context, provider, _) {
        final dateRange = provider.selectedDateRange;
        final String displayText;
        if (dateRange != null) {
          final startStr =
              '${dateRange.start.year}-${dateRange.start.month.toString().padLeft(2, '0')}-${dateRange.start.day.toString().padLeft(2, '0')}';
          final endStr =
              '${dateRange.end.year}-${dateRange.end.month.toString().padLeft(2, '0')}-${dateRange.end.day.toString().padLeft(2, '0')}';
          displayText = startStr == endStr ? startStr : '$startStr ~ $endStr';
        } else {
          displayText = '全部日期';
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('日期',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textSecondary)),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showDateRangeDialog(provider, dateRange),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(
                      color: dateRange != null
                          ? AppTheme.primaryBlue
                          : AppTheme.borderMain),
                  borderRadius: BorderRadius.circular(8),
                  color: dateRange != null
                      ? AppTheme.primaryBlue.withAlpha(15)
                      : Colors.white,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.date_range,
                        size: 18,
                        color: dateRange != null
                            ? AppTheme.primaryBlue
                            : AppTheme.textSecondary),
                    const SizedBox(width: 6),
                    Text(displayText,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: dateRange != null
                                ? AppTheme.primaryBlue
                                : AppTheme.textSecondary)),
                    if (dateRange != null) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: () => provider.selectDateRange(null),
                        child: Icon(Icons.close,
                            size: 16, color: AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDateRangeDialog(
      StatisticsProvider provider, DateTimeRange? currentRange) {
    DateTime startDate = currentRange?.start ?? DateTime.now();
    DateTime endDate = currentRange?.end ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String formatDate(DateTime d) =>
              '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.date_range,
                          color: AppTheme.primaryBlue, size: 24),
                      const SizedBox(width: 8),
                      const Text('选择日期范围',
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // 开始日期
                  const Text('开始日期',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('zh', 'CN'),
                      );
                      if (picked != null) {
                        setDialogState(() => startDate = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryBlue),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.primaryBlue.withAlpha(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 10),
                          Text(formatDate(startDate),
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 结束日期
                  const Text('结束日期',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            endDate.isBefore(startDate) ? startDate : endDate,
                        firstDate: startDate,
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        locale: const Locale('zh', 'CN'),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.primaryBlue),
                        borderRadius: BorderRadius.circular(8),
                        color: AppTheme.primaryBlue.withAlpha(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 10),
                          Text(formatDate(endDate),
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 按钮行
                  Row(
                    children: [
                      if (currentRange != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              provider.selectDateRange(null);
                              Navigator.pop(ctx);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.textSecondary,
                              side:
                                  const BorderSide(color: AppTheme.borderMain),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('清除筛选',
                                style: TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      if (currentRange != null) const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (!endDate.isBefore(startDate)) {
                              provider.selectDateRange(DateTimeRange(
                                  start: startDate, end: endDate));
                              Navigator.pop(ctx);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('确认',
                              style: TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _refreshData() {
    final p = context.read<StatisticsProvider>();
    if (p.selectedClass != null) {
      p.loadStatistics(p.selectedClass!);
    }
  }

  Widget _buildTab(String type) {
    return Consumer<StatisticsProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (provider.error != null) {
          return _buildErrorWidget(provider);
        }
        if (provider.selectedClass == null) {
          return _buildEmptyWidget('请先选择一个班级');
        }

        final overview = type == 'exam'
            ? provider.examOverview
            : type == 'chinese'
                ? provider.chineseTypingOverview
                : provider.englishTypingOverview;
        final rankings = type == 'exam'
            ? provider.examRankings
            : type == 'chinese'
                ? provider.chineseTypingRankings
                : provider.englishTypingRankings;

        if (overview.participantCount == 0 && rankings.isEmpty) {
          return _buildEmptyWidget(
              '暂无${type == 'exam' ? '课堂小测' : type == 'chinese' ? '中文打字' : '英文打字'}数据');
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOverviewCards(overview),
              const SizedBox(height: 20),
              _buildBarChart(overview),
              const SizedBox(height: 20),
              _buildRankingTable(rankings, type, provider),
            ],
          ),
        );
      },
    );
  }

  // ============ 概览卡片 ============

  Widget _buildOverviewCards(StatsOverview overview) {
    return Row(
      children: [
        Expanded(
            child: _buildStatCard('参与人数', '${overview.participantCount}',
                Icons.people, AppTheme.primaryBlue)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
                '平均分',
                overview.averageScore.toStringAsFixed(1),
                Icons.analytics,
                AppTheme.warningOrange)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard('最高分', '${overview.highestScore}',
                Icons.emoji_events, AppTheme.successGreen)),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard('最低分', '${overview.lowestScore}',
                Icons.trending_down, AppTheme.dangerRed)),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withAlpha(20),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  // ============ 柱状统计图（10分一段）============

  Widget _buildBarChart(StatsOverview overview) {
    final provider = context.read<StatisticsProvider>();
    final scores = provider.examScores;
    if (scores.isEmpty) return const SizedBox.shrink();
    final segments = _calculateBarDistribution(scores);
    if (segments.isEmpty) return const SizedBox.shrink();

    final maxCount =
        segments.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b);
    const barColors = [
      Color(0xFFEF4444), // 0-9
      Color(0xFFF97316), // 10-19
      Color(0xFFF59E0B), // 20-29
      Color(0xFFF59E0B), // 30-39
      Color(0xFFF59E0B), // 40-49
      Color(0xFFF59E0B), // 50-59
      Color(0xFFF97316), // 60-69
      Color(0xFF3B82F6), // 70-79
      Color(0xFF3B82F6), // 80-89
      Color(0xFF10B981), // 90-100
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('分数段分布',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(segments.length, (i) {
                final seg = segments[i];
                final count = seg['count'] as int;
                final label = seg['label'] as String;
                final ratio = maxCount > 0 ? count / maxCount : 0.0;
                final color = i < barColors.length
                    ? barColors[i]
                    : AppTheme.textSecondary;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        // 数值
                        if (count > 0)
                          Flexible(
                            child: Text('$count',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: color)),
                          ),
                        const SizedBox(height: 4),
                        // 柱子
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: ratio,
                            child: Container(
                              decoration: BoxDecoration(
                                color: color.withAlpha(180),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(4)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        // 标签
                        Flexible(
                          child: Text(label,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textSecondary),
                              textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _calculateBarDistribution(List<int> scores) {
    final segments = [
      {'label': '0-9', 'min': 0, 'max': 10},
      {'label': '10-19', 'min': 10, 'max': 20},
      {'label': '20-29', 'min': 20, 'max': 30},
      {'label': '30-39', 'min': 30, 'max': 40},
      {'label': '40-49', 'min': 40, 'max': 50},
      {'label': '50-59', 'min': 50, 'max': 60},
      {'label': '60-69', 'min': 60, 'max': 70},
      {'label': '70-79', 'min': 70, 'max': 80},
      {'label': '80-89', 'min': 80, 'max': 90},
      {'label': '90-100', 'min': 90, 'max': 101},
    ];
    return segments.map((seg) {
      final minVal = seg['min'] as int;
      final maxVal = seg['max'] as int;
      final count = scores.where((s) => s >= minVal && s < maxVal).length;
      return {
        'label': seg['label'] as String,
        'count': count,
      };
    }).toList();
  }

  // ============ 学生排名表格 ============

  Widget _buildRankingTable(
      List<StudentSummary> rankings, String type, StatisticsProvider provider) {
    if (rankings.isEmpty) return const SizedBox.shrink();

    // 排序
    final sorted = List<StudentSummary>.from(rankings);
    sorted.sort((a, b) {
      int cmp;
      switch (_sortColumnIndex) {
        case 0: // 序号（按原始顺序即得分排名）
          cmp = a.avgScore.compareTo(b.avgScore);
          break;
        case 1: // 姓名
          cmp = a.studentName.compareTo(b.studentName);
          break;
        case 2: // 得分
          cmp = a.avgScore.compareTo(b.avgScore);
          break;
        default:
          cmp = a.avgScore.compareTo(b.avgScore);
      }
      return _sortAscending ? cmp : -cmp;
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(8),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 表头（可排序）
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                  top: BorderSide(color: Color(0xFFE2E8F0)),
                  bottom: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(children: [
              _buildSortableHeader('序号', 50, 0),
              _buildSortableHeader('姓名', 100, 1),
              _buildSortableHeader('得分', 80, 2),
              if (type != 'exam') ...[
                _buildTableHeader('速度', 80),
                _buildTableHeader('准确率', 60),
              ],
              if (type == 'exam') _buildTableHeader('题目详情', null),
            ]),
          ),
          ...List.generate(sorted.length,
              (i) => _buildTableRow(sorted[i], i + 1, type, provider)),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSortableHeader(String text, double width, int columnIndex) {
    final isActive = _sortColumnIndex == columnIndex;
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_sortColumnIndex == columnIndex) {
            _sortAscending = !_sortAscending;
          } else {
            _sortColumnIndex = columnIndex;
            _sortAscending = columnIndex == 1; // 姓名升序，其他降序
          }
        });
      },
      child: SizedBox(
        width: width,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isActive
                          ? AppTheme.primaryBlue
                          : AppTheme.textSecondary)),
            ),
            const SizedBox(width: 2),
            Icon(
              isActive
                  ? (_sortAscending ? Icons.arrow_upward : Icons.arrow_downward)
                  : Icons.unfold_more,
              size: 14,
              color: isActive
                  ? AppTheme.primaryBlue
                  : AppTheme.textSecondary.withAlpha(102),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text, double? width) {
    final widget = Text(text,
        style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textSecondary));
    if (width != null) {
      return SizedBox(width: width, child: widget);
    }
    return Expanded(child: widget);
  }

  Widget _buildTableRow(StudentSummary student, int rank, String type,
      StatisticsProvider provider) {
    return GestureDetector(
      onTap: () {
        if (type == 'exam') {
          _showStudentWrongQuestionsDialog(
              student.studentId, student.studentName, provider);
        } else {
          _showTypingDetailDialog(
              student.studentId, student.studentName, type, provider);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(children: [
          SizedBox(
            width: 50,
            child: Text('$rank',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ),
          SizedBox(
            width: 100,
            child: Text(student.studentName,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
          ),
          SizedBox(
            width: 80,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _getScoreColor(student.avgScore).withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(student.avgScore.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: _getScoreColor(student.avgScore))),
            ),
          ),
          if (type != 'exam') ...[
            SizedBox(
              width: 80,
              child: Text(
                  '${provider.getStudentTypingAvgSpeed(student.studentId, type)}字/分',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ),
            SizedBox(
              width: 60,
              child: Text(
                  '${provider.getStudentTypingAvgAccuracy(student.studentId, type)}%',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ),
          ],
          if (type == 'exam')
            Expanded(
              child: _buildQuestionDetailRow(student.studentId, provider),
            ),
        ]),
      ),
    );
  }

  Widget _buildQuestionDetailRow(
      String studentId, StatisticsProvider provider) {
    final wrongRecords = provider.getStudentWrongQuestions(studentId);
    if (wrongRecords.isEmpty) {
      return const Text('暂无记录',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary));
    }

    // 找到最高分的提交（wrong_count 最少的记录）
    final best = wrongRecords.reduce((a, b) {
      final aWrong = (a['wrong_count'] as num?)?.toInt() ?? 999;
      final bWrong = (b['wrong_count'] as num?)?.toInt() ?? 999;
      return aWrong <= bWrong ? a : b;
    });
    final wrongs =
        (best['wrong_questions'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final wrongCount = (best['wrong_count'] as num?)?.toInt() ?? wrongs.length;
    final totalCount = (best['total_count'] as num?)?.toInt() ?? 0;
    final correctCount = totalCount - wrongCount;

    // 使用 (question_number, question_type) 组合作为唯一标识
    // 因为不同题型可能有相同的 question_number（如选择题第1题、匹配题第1题）
    // 只从 wrong_questions 中去重，得到实际的错题数
    final wrongKeys = <String>{};
    for (final w in wrongs) {
      final qNum = w['question_number']?.toString() ?? '';
      final qType = w['question_type']?.toString() ?? '';
      wrongKeys.add('$qNum:$qType');
    }
    final actualWrongCount = wrongKeys.length;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        // 显示正确题数
        ...List.generate(correctCount, (_) {
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.successGreen.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              '√',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.successGreen,
              ),
            ),
          );
        }),
        // 显示错题数
        ...List.generate(actualWrongCount, (_) {
          return Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.dangerRed.withAlpha(20),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              '×',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.dangerRed,
              ),
            ),
          );
        }),
      ],
    );
  }

  // ============ 学生错题对话框 ============

  void _showStudentWrongQuestionsDialog(
      String studentId, String studentName, StatisticsProvider provider) {
    final wrongRecords = provider.getStudentWrongQuestions(studentId);

    // 找到最高分的提交（wrong_count 最少）
    Map<String, dynamic>? bestRecord;
    if (wrongRecords.isNotEmpty) {
      bestRecord = wrongRecords.reduce((a, b) {
        final aWrong = (a['wrong_count'] as num?)?.toInt() ?? 999;
        final bWrong = (b['wrong_count'] as num?)?.toInt() ?? 999;
        return aWrong <= bWrong ? a : b;
      });
    }

    // 默认只显示最高分的错题
    final displayRecords =
        bestRecord != null ? [bestRecord] : <Map<String, dynamic>>[];
    bool showAllRecords = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final records = showAllRecords ? wrongRecords : displayRecords;
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 550,
              constraints: const BoxConstraints(maxHeight: 600),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person,
                          color: AppTheme.primaryBlue, size: 24),
                      const SizedBox(width: 8),
                      Text('$studentName 的错题详情',
                          style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      // 切换按钮：最高分 / 全部
                      if (wrongRecords.length > 1)
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.borderMain),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildRecordModeButton(
                                '最高分',
                                !showAllRecords,
                                () => setDialogState(
                                    () => showAllRecords = false),
                              ),
                              _buildRecordModeButton(
                                '全部${wrongRecords.length}次',
                                showAllRecords,
                                () =>
                                    setDialogState(() => showAllRecords = true),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoChip('姓名', studentName),
                          const SizedBox(height: 8),
                          _buildInfoChip(
                              '题库',
                              provider.selectedExamName != null
                                  ? '题库 ${provider.selectedExamName}'
                                  : '全部'),
                          if (bestRecord != null) ...[
                            const SizedBox(height: 8),
                            _buildInfoChip(
                              '最高分',
                              '${((bestRecord['total_count'] as num?)?.toInt() ?? 0) - ((bestRecord['wrong_count'] as num?)?.toInt() ?? 0)}/${bestRecord['total_count']?.toString() ?? '-'}',
                            ),
                          ],
                        ]),
                  ),
                  const SizedBox(height: 16),
                  if (records.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text('暂无错题记录',
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 18,
                                fontWeight: FontWeight.w600)),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (ctx, i) =>
                            _buildWrongRecordCard(records[i]),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecordModeButton(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return RichText(
      text: TextSpan(children: [
        TextSpan(
            text: '$label: ',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary)),
        TextSpan(
            text: value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary)),
      ]),
    );
  }

  Widget _buildWrongRecordCard(Map<String, dynamic> record) {
    final wrongs =
        (record['wrong_questions'] as List?)?.cast<Map<String, dynamic>>() ??
            [];
    final total = (record['total_count'] as num?)?.toInt() ?? 0;
    final wrongCount = (record['wrong_count'] as num?)?.toInt() ?? 0;
    final examName = record['exam_name']?.toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const SizedBox(width: 8),
            Text('错 $wrongCount 正确 $total 题',
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
            const Spacer(),
            Text(_formatTime(record['submit_time']?.toString() ?? ''),
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary)),
          ]),
          const SizedBox(height: 12),
          ...wrongs.map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppTheme.dangerRed.withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      alignment: Alignment.center,
                      child: const Text('×',
                          style: TextStyle(
                              fontSize: 16,
                              color: AppTheme.dangerRed,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildWrongQuestionDetail(w, examName),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  /// 构建单个错题详情（包含选项显示）
  Widget _buildWrongQuestionDetail(Map<String, dynamic> w, String? examName) {
    final qType = w['question_type']?.toString() ?? '';
    final qNum = w['question_number']?.toString() ?? '';
    final studentAnswer = w['student_answer']?.toString() ?? '未作答';
    final correctAnswer = w['correct_answer']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '第$qNum题 ${w['question_text'] ?? ''}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        // 如果是选择题，显示选项
        if (qType == 'choice' && examName != null && examName.isNotEmpty)
          FutureBuilder<Map<String, String>?>(
            future: _loadQuestionOptions(qNum, examName),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data != null) {
                return _buildOptionsDisplay(
                  snapshot.data!,
                  correctAnswer: correctAnswer,
                  studentAnswer: studentAnswer,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('学生答案: ${_formatAnswer(studentAnswer, qType)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dangerRed)),
            const SizedBox(height: 4),
            Text('正确答案: ${_formatAnswer(correctAnswer, qType)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successGreen)),
          ],
        ),
      ],
    );
  }

  // ============ 班级错题总览对话框 ============

  void _showClassWrongQuestionsDialog() {
    final provider = context.read<StatisticsProvider>();
    final allWrongQuestions = provider.filteredWrongQuestions;

    // 对每个学生只取最高分的提交（wrong_count 最少）
    final Map<String, Map<String, dynamic>> studentBestRecords = {};
    for (final record in allWrongQuestions) {
      final studentId = record['student_id']?.toString() ?? '';
      final wrongCount = (record['wrong_count'] as num?)?.toInt() ?? 999;
      if (!studentBestRecords.containsKey(studentId)) {
        studentBestRecords[studentId] = record;
      } else {
        final existingWrong =
            (studentBestRecords[studentId]!['wrong_count'] as num?)?.toInt() ??
                999;
        if (wrongCount < existingWrong) {
          studentBestRecords[studentId] = record;
        }
      }
    }
    final wrongQuestions = studentBestRecords.values.toList();

    if (wrongQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('暂无班级错题数据',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      );
      return;
    }

    // 按题号聚合错题
    final Map<String, Map<String, dynamic>> aggregated = {};
    String? examName;
    for (final record in wrongQuestions) {
      final wrongs =
          (record['wrong_questions'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      // 获取题库名称
      if (examName == null) {
        examName = record['exam_name']?.toString();
      }
      for (final w in wrongs) {
        final qNum = w['question_number']?.toString() ?? '';
        final qType = w['question_type']?.toString() ?? '';
        final key = '${qType}_$qNum';
        if (!aggregated.containsKey(key)) {
          aggregated[key] = {
            'question_number': qNum,
            'question_type': qType,
            'question_text': w['question_text']?.toString() ?? '',
            'correct_answer': w['correct_answer']?.toString() ?? '',
            'score': w['score'] ?? 0,
            'wrong_students': <String>[],
            'correct_students': <String>[],
            'exam_name': examName,
          };
        }
        final studentName = record['student_name']?.toString() ?? '';
        if (studentName.isNotEmpty &&
            !(aggregated[key]!['wrong_students'] as List<String>)
                .contains(studentName)) {
          (aggregated[key]!['wrong_students'] as List<String>).add(studentName);
        }
      }
    }

    // 获取所有学生
    final rankings = provider.examRankings;
    final allStudents = rankings.map((r) => r.studentName).toSet();

    // 标记答对的学生
    for (final entry in aggregated.values) {
      final wrongSet = (entry['wrong_students'] as List<String>).toSet();
      entry['correct_students'] = allStudents.difference(wrongSet).toList();
    }

    final allEntries = aggregated.values.toList();

    // 排序状态
    int sortMode = 0; // 0=按题号, 1=按错的人多排序

    // 排序函数
    List<Map<String, dynamic>> sortEntries(
        List<Map<String, dynamic>> entries, int mode) {
      final sorted = List<Map<String, dynamic>>.from(entries);
      sorted.sort((a, b) {
        if (mode == 0) {
          // 按题号排序
          final aNum =
              int.tryParse(a['question_number']?.toString() ?? '0') ?? 0;
          final bNum =
              int.tryParse(b['question_number']?.toString() ?? '0') ?? 0;
          return aNum.compareTo(bNum);
        } else {
          // 按错的人数排序（降序）
          final aCount = (a['wrong_students'] as List).length;
          final bCount = (b['wrong_students'] as List).length;
          return bCount.compareTo(aCount);
        }
      });
      return sorted;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final entries = sortEntries(allEntries, sortMode);
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              width: 700,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.dangerRed, size: 24),
                      const SizedBox(width: 8),
                      const Text('班级错题总览',
                          style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary)),
                      const Spacer(),
                      // 排序按钮
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderMain),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildSortModeButton(
                              '按题号',
                              sortMode == 0,
                              () => setDialogState(() => sortMode = 0),
                            ),
                            _buildSortModeButton(
                              '按错的多',
                              sortMode == 1,
                              () => setDialogState(() => sortMode = 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text('共 ${entries.length} 道错题',
                          style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary)),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 22),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: entries.length,
                      itemBuilder: (ctx, i) =>
                          _buildAggregatedWrongCard(entries[i]),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortModeButton(
      String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  /// 格式化答案文本：排序题用箭头连接
  String _formatAnswer(String answer, String questionType) {
    if (questionType == 'sequential' && answer.isNotEmpty) {
      return answer.split(', ').join(' → ');
    }
    return answer;
  }

  /// 从题库加载选择题选项
  Future<Map<String, String>?> _loadQuestionOptions(
      String questionNumber, String? examName) async {
    if (examName == null || examName.isEmpty) return null;

    try {
      final questions =
          await QuestionBankService.loadQuestionsFromBank(examName);
      final qNum = int.tryParse(questionNumber) ?? 0;
      if (qNum > 0 && qNum <= questions.length) {
        final question = questions[qNum - 1];
        return {
          'A': question['optionA']?.toString() ?? '',
          'B': question['optionB']?.toString() ?? '',
          'C': question['optionC']?.toString() ?? '',
          'D': question['optionD']?.toString() ?? '',
        };
      }
    } catch (e) {
      print('加载选项失败: $e');
    }
    return null;
  }

  /// 构建选项显示组件
  Widget _buildOptionsDisplay(
    Map<String, String> options, {
    String? correctAnswer,
    String? studentAnswer,
  }) {
    final optionLabels = ['A', 'B', 'C', 'D'];

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: optionLabels.map((label) {
          final optionText = options[label] ?? '';
          if (optionText.isEmpty) return const SizedBox.shrink();

          final isCorrect = correctAnswer != null &&
              correctAnswer.toUpperCase().contains(label);
          final isWrong = studentAnswer != null &&
              studentAnswer.toUpperCase().contains(label) &&
              !isCorrect;

          Color textColor = AppTheme.textPrimary;
          Color bgColor = Colors.transparent;
          FontWeight fontWeight = FontWeight.w600;

          if (isCorrect) {
            textColor = AppTheme.successGreen;
            bgColor = AppTheme.successGreen.withAlpha(20);
            fontWeight = FontWeight.w700;
          } else if (isWrong) {
            textColor = AppTheme.dangerRed;
            bgColor = AppTheme.dangerRed.withAlpha(20);
            fontWeight = FontWeight.w700;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label. ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: fontWeight,
                    color: textColor,
                  ),
                ),
                Expanded(
                  child: Text(
                    optionText,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: fontWeight,
                      color: textColor,
                    ),
                  ),
                ),
                if (isCorrect)
                  Icon(Icons.check_circle,
                      color: AppTheme.successGreen, size: 18)
                else if (isWrong)
                  Icon(Icons.cancel, color: AppTheme.dangerRed, size: 18),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAggregatedWrongCard(Map<String, dynamic> entry) {
    final qNum = entry['question_number']?.toString() ?? '';
    final qType = entry['question_type']?.toString() ?? '';
    final qText = entry['question_text']?.toString() ?? '';
    final correctAnswer = entry['correct_answer']?.toString() ?? '';
    final wrongStudents = (entry['wrong_students'] as List<String>);
    final correctStudents = (entry['correct_students'] as List<String>);
    final score = entry['score'] ?? 0;
    final examName = entry['exam_name']?.toString();

    final typeLabel = {
          'choice': '选择题',
          'matching': '连线题',
          'sequential': '排序题',
          'fill': '填空题',
        }[qType] ??
        qType;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 题目头部
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$typeLabel 第$qNum题',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withAlpha(20),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('分值: $score',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.warningOrange)),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                  '${wrongStudents.length}人答错 / ${correctStudents.length}人答对',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary)),
            ),
          ]),
          const SizedBox(height: 12),
          // 题干
          if (qText.isNotEmpty)
            Text(qText,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          // 如果是选择题，显示选项（只显示正确答案高亮）
          if (qType == 'choice' && examName != null && examName.isNotEmpty)
            FutureBuilder<Map<String, String>?>(
              future: _loadQuestionOptions(qNum, examName),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return _buildOptionsDisplay(
                    snapshot.data!,
                    correctAnswer: correctAnswer,
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          // 正确答案
          Row(children: [
            const Icon(Icons.check_circle,
                color: AppTheme.successGreen, size: 18),
            const SizedBox(width: 4),
            Expanded(
              child: Text('正确答案: ${_formatAnswer(correctAnswer, qType)}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.successGreen)),
            ),
          ]),
          const SizedBox(height: 12),
          // 答对的学生
          if (correctStudents.isNotEmpty) ...[
            const Text('答对的学生:',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.successGreen)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: correctStudents
                  .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successGreen)),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 8),
          ],
          // 答错的学生
          if (wrongStudents.isNotEmpty) ...[
            const Text('答错的学生:',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dangerRed)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: wrongStudents
                  .map((name) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerRed.withAlpha(20),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.dangerRed)),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  // ============ 打字详情弹窗 ============

  void _showTypingDetailDialog(String studentId, String studentName,
      String type, StatisticsProvider provider) {
    final records = provider.getStudentTypingRecords(studentId, type);
    final typeName = type == 'chinese' ? '中文打字' : '英文打字';
    final avgSpeed = provider.getStudentTypingAvgSpeed(studentId, type);
    final avgAccuracy = provider.getStudentTypingAvgAccuracy(studentId, type);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 650,
          constraints: const BoxConstraints(maxHeight: 600),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.keyboard,
                      color: AppTheme.primaryBlue, size: 24),
                  const SizedBox(width: 8),
                  Text('$studentName 的$typeName详情',
                      style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 22),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Flexible(child: _buildInfoChip('平均速度', '$avgSpeed 字/分')),
                  const SizedBox(width: 16),
                  Flexible(child: _buildInfoChip('平均准确率', '$avgAccuracy%')),
                  const SizedBox(width: 16),
                  Flexible(child: _buildInfoChip('总次数', '${records.length} 次')),
                ]),
              ),
              const SizedBox(height: 16),
              if (records.isEmpty)
                const Expanded(
                  child: Center(
                    child: Text('暂无打字记录',
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 18,
                            fontWeight: FontWeight.w600)),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    children: [
                      // 表头
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          border: Border(
                              bottom: BorderSide(color: Color(0xFFE2E8F0))),
                        ),
                        child: Row(children: [
                          SizedBox(
                              width: 55,
                              child: Text('得分',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                          SizedBox(
                              width: 55,
                              child: Text('速度',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                          SizedBox(
                              width: 55,
                              child: Text('准确率',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                          SizedBox(
                              width: 55,
                              child: Text('用时',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                          SizedBox(
                              width: 55,
                              child: Text('正确',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                          SizedBox(
                              width: 55,
                              child: Text('错误',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                          Expanded(
                              child: Text('提交时间',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textSecondary))),
                        ]),
                      ),
                      // 数据行
                      Expanded(
                        child: ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (ctx, i) {
                            final r = records[i];
                            final score = (r['score'] as num?)?.toInt() ?? 0;
                            final speed = (r['speed'] as num?)?.toInt() ?? 0;
                            final accuracy =
                                (r['accuracy'] as num?)?.toInt() ?? 0;
                            final elapsed =
                                (r['elapsed_seconds'] as num?)?.toInt() ?? 0;
                            final correct =
                                (r['correct_chars'] as num?)?.toInt() ?? 0;
                            final errorCount =
                                (r['error_count'] as num?)?.toInt() ?? 0;
                            final submitTime =
                                r['submit_time']?.toString() ?? '';

                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(
                                    bottom:
                                        BorderSide(color: Color(0xFFF1F5F9))),
                              ),
                              child: Row(children: [
                                SizedBox(
                                    width: 55,
                                    child: Text('$score',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: _getScoreColor(
                                                score.toDouble())))),
                                SizedBox(
                                    width: 55,
                                    child: Text('$speed',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600))),
                                SizedBox(
                                    width: 55,
                                    child: Text('$accuracy%',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600))),
                                SizedBox(
                                    width: 55,
                                    child: Text('${elapsed}s',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600))),
                                SizedBox(
                                    width: 55,
                                    child: Text('$correct',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.successGreen))),
                                SizedBox(
                                    width: 55,
                                    child: Text('$errorCount',
                                        style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: errorCount > 0
                                                ? AppTheme.dangerRed
                                                : AppTheme.textSecondary))),
                                Expanded(
                                    child: Text(_formatTime(submitTime),
                                        style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.textSecondary))),
                              ]),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ 辅助方法 ============

  Color _getScoreColor(double score) {
    if (score >= 90) return const Color(0xFF10B981);
    if (score >= 80) return const Color(0xFF3B82F6);
    if (score >= 70) return const Color(0xFFF59E0B);
    if (score >= 60) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      print('时间格式化失败: $e');
      return isoTime;
    }
  }

  Widget _buildEmptyWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bar_chart,
              size: 64, color: AppTheme.textSecondary.withAlpha(80)),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(StatisticsProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.dangerRed),
          const SizedBox(height: 16),
          Text(provider.error!,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            label: const Text('重试',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            style: AppTheme.primaryButtonStyle,
          ),
        ],
      ),
    );
  }
}
