import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../utils/app_path.dart';
import '../services/question_bank_config_service.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';
import '../providers/exam_provider.dart';
import '../providers/question_provider.dart';
import '../providers/student_status_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/student_status_widget.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _selectedGrade = '初一';
  String _selectedClass = '01班';
  List<String> _questionBanks = [];
  String? _selectedBank;
  int _classTotalCount = 0; // 班级总人数

  final List<String> _grades = ['初一', '初二', '初三'];
  final List<String> _classes =
      List.generate(20, (i) => '${(i + 1).toString().padLeft(2, '0')}班');

  @override
  void initState() {
    super.initState();
    _loadQuestionBanks();
    // 从 AuthProvider 恢复之前选择的班级
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreClassSelection();
    });
  }

  /// 从 AuthProvider 恢复班级选择（仅恢复UI状态，不自动设置服务器活跃班级）
  void _restoreClassSelection() {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final savedClass = authProvider.selectedClassLabel;
    if (savedClass != null && savedClass.isNotEmpty) {
      // 解析 "初一01班" 为 grade="初一", class="01班"
      final gradeMatch = RegExp(r'^(初[一二三])').firstMatch(savedClass);
      if (gradeMatch != null) {
        final grade = gradeMatch.group(1)!;
        final classPart = savedClass.substring(grade.length);
        if (_grades.contains(grade) && _classes.contains(classPart)) {
          setState(() {
            _selectedGrade = grade;
            _selectedClass = classPart;
          });
          // 加载班级总人数
          _loadClassTotalCount(savedClass);
        }
      }
    } else {
      // 如果没有保存的班级，加载默认班级的总人数
      _loadClassTotalCount('$_selectedGrade$_selectedClass');
    }
    // 不再自动设置服务器活跃班级，仅在点击同步按钮时根据是否有在线学生决定
  }

  bool _dataLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 防止重复加载：只在首次调用时加载数据
    if (!_dataLoaded) {
      _dataLoaded = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }
  }

  /// 加载题库列表
  void _loadQuestionBanks() async {
    final dir = Directory(AppPath.questionBankDir);
    if (!dir.existsSync()) return;

    final banks = <String>[];
    for (final entity in dir.listSync()) {
      if (entity is Directory) {
        banks.add(entity.path.split(Platform.pathSeparator).last);
      }
    }

    if (!mounted) return;
    setState(() {
      _questionBanks = banks;
      // 默认选择第一个题库
      if (_selectedBank == null && banks.isNotEmpty) {
        _selectedBank = banks.first;
      }
    });
    // 题库加载完成后恢复之前的选择（延迟到下一帧确保 context 可用）
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreBankSelection();
    });
  }

  /// 从 JSON 文件恢复题库选择
  void _restoreBankSelection() async {
    if (!mounted) return;
    final savedBank = await QuestionBankConfigService.getSelectedBank();
    if (savedBank != null &&
        savedBank.isNotEmpty &&
        _questionBanks.contains(savedBank)) {
      setState(() {
        _selectedBank = savedBank;
      });
      // 自动同步题库到学生端
      _syncBankToStudents(savedBank);
    }
  }

  /// 同步题库到学生端
  void _syncBankToStudents(String bankName) async {
    try {
      await http.post(
        Uri.parse('http://localhost:20020/api/active-bank'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'bank': bankName}),
      );
      print('自动同步题库: $bankName 到学生端');
    } catch (e) {
      // 忽略错误
    }
  }

  /// 保存班级选择到 AuthProvider
  void _saveClassSelection() {
    if (!mounted) return;
    final classLabel = '$_selectedGrade$_selectedClass';
    final authProvider = context.read<AuthProvider>();
    authProvider.setSelectedClass(classLabel);
    // 加载班级总人数
    _loadClassTotalCount(classLabel);
  }

  /// 加载班级总人数
  void _loadClassTotalCount(String classLabel) async {
    try {
      final file =
          File('${AppPath.projectRoot}/information/$classLabel/use_list.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        final List<dynamic> students = data['students'] ?? [];
        if (mounted) {
          setState(() {
            _classTotalCount = students.length;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _classTotalCount = 0;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _classTotalCount = 0;
        });
      }
    }
  }

  /// 设置活跃班级到HTTP服务器
  void _setActiveClass() async {
    final classLabel = '$_selectedGrade$_selectedClass';
    try {
      await http.post(
        Uri.parse('http://localhost:20020/api/active-class'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'class_id': classLabel}),
      );
    } catch (e) {
      // 忽略错误
    }
  }

  void _loadData() {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final examProvider = context.read<ExamProvider>();
    final questionProvider = context.read<QuestionProvider>();

    userProvider.loadUsers();
    examProvider.loadExams();
    questionProvider.loadQuestions();

    // 从 ServerService 内存中刷新学生状态
    final studentStatusProvider = context.read<StudentStatusProvider>();
    studentStatusProvider.reloadFromServer();
  }

  /// 同步到学生端
  /// - 如果当前班级有学生已登录（在线），只同步题库，不修改学生数据
  /// - 如果当前班级没有学生在线，同步班级和题库（供下次登录使用）
  void _syncToStudents() async {
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一个题库'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 检查当前班级是否有学生在线
    final classLabel = '$_selectedGrade$_selectedClass';
    final studentStatusProvider = context.read<StudentStatusProvider>();
    final classStudents = studentStatusProvider.getStudentsByClass(classLabel);
    final hasOnlineStudents = classStudents.any((s) => s.isOnline);

    try {
      if (hasOnlineStudents) {
        // 【情况A】有学生在线，只同步题库
        // 注意：这里只更新题库配置，不触碰学生数据文件
        final response = await http.post(
          Uri.parse('http://localhost:20020/api/active-bank'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'bank': _selectedBank}),
        );

        if (response.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已同步题库 "$_selectedBank" 到在线学生'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      } else {
        // 【情况B】没有学生在线，同步班级和题库
        // 这里更新的是服务器的配置，不是学生数据文件
        await http.post(
          Uri.parse('http://localhost:20020/api/active-class'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'class_id': classLabel}),
        );

        final response = await http.post(
          Uri.parse('http://localhost:20020/api/active-bank'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'bank': _selectedBank}),
        );

        if (response.statusCode == 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('已同步班级 "$classLabel" 和题库 "$_selectedBank"（学生登录后将使用此配置）'),
              backgroundColor: AppTheme.successGreen,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        return Column(
          children: [
            // 顶部卡片
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: isNarrow ? _buildNarrowToolbar() : _buildWideToolbar(),
            ),
            const SizedBox(height: 8),
            // 在线成员区域
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildStudentCards(),
              ),
            ),
          ],
        );
      },
    );
  }

  /// 宽屏工具栏布局
  Widget _buildWideToolbar() {
    return Row(
      children: [
        // 年级选择
        _buildLabel('年级'),
        const SizedBox(width: 4),
        Flexible(
          flex: 2,
          child: _buildSelector(
            hint: '年级',
            value: _selectedGrade,
            items: _grades,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedGrade = value;
                });
                _saveClassSelection();
                // 不再自动设置服务器活跃班级，仅在点击同步按钮时生效
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // 班级选择
        _buildLabel('班级'),
        const SizedBox(width: 4),
        Flexible(
          flex: 2,
          child: _buildSelector(
            hint: '班级',
            value: _selectedClass,
            items: _classes,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedClass = value;
                });
                _saveClassSelection();
                // 不再自动设置服务器活跃班级，仅在点击同步按钮时生效
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        // 学生状态统计
        Flexible(
          flex: 5,
          child: Consumer<StudentStatusProvider>(
            builder: (context, provider, _) {
              // 计算当前班级的在线、打字、小测人数
              final classLabel = '$_selectedGrade$_selectedClass';
              final classStudents = provider.getStudentsByClass(classLabel);
              final onlineCount = classStudents
                  .where((s) =>
                      s.isOnline &&
                      s.status != StudentStatus.typing &&
                      s.status != StudentStatus.exam)
                  .length;
              final typingCount = classStudents
                  .where((s) => s.status == StudentStatus.typing)
                  .length;
              final examCount = classStudents
                  .where((s) => s.status == StudentStatus.exam)
                  .length;
              // 离线人数 = 班级总人数 - 在线 - 打字 - 小测
              final offlineCount =
                  _classTotalCount - onlineCount - typingCount - examCount;

              return Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  _buildStatusChip(
                    '在线: $onlineCount',
                    Colors.green,
                  ),
                  _buildStatusChip(
                    '离线: ${offlineCount >= 0 ? offlineCount : 0}',
                    Colors.grey,
                  ),
                  _buildStatusChip(
                    '打字: $typingCount',
                    Colors.blue,
                  ),
                  _buildStatusChip(
                    '小测: $examCount',
                    Colors.orange,
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        // 题库选择
        _buildLabel('题库'),
        const SizedBox(width: 4),
        Flexible(
          flex: 2,
          child: _buildBankSelector(),
        ),
        const SizedBox(width: 12),
        // 同步按钮
        ElevatedButton.icon(
          onPressed: _syncToStudents,
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('同步'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // 刷新按钮
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('刷新'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  /// 窄屏工具栏布局（自动换行）
  Widget _buildNarrowToolbar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 年级选择
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabel('年级'),
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: _buildSelector(
                hint: '年级',
                value: _selectedGrade,
                items: _grades,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedGrade = value;
                    });
                    _saveClassSelection();
                    // 不再自动设置服务器活跃班级，仅在点击同步按钮时生效
                  }
                },
              ),
            ),
          ],
        ),
        // 班级选择
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabel('班级'),
            const SizedBox(width: 4),
            SizedBox(
              width: 80,
              child: _buildSelector(
                hint: '班级',
                value: _selectedClass,
                items: _classes,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedClass = value;
                    });
                    _saveClassSelection();
                    // 不再自动设置服务器活跃班级，仅在点击同步按钮时生效
                  }
                },
              ),
            ),
          ],
        ),
        // 学生状态统计
        Consumer<StudentStatusProvider>(
          builder: (context, provider, _) {
            // 计算当前班级的在线、打字、小测人数
            final classLabel = '$_selectedGrade$_selectedClass';
            final classStudents = provider.getStudentsByClass(classLabel);
            final onlineCount = classStudents
                .where((s) =>
                    s.isOnline &&
                    s.status != StudentStatus.typing &&
                    s.status != StudentStatus.exam)
                .length;
            final typingCount = classStudents
                .where((s) => s.status == StudentStatus.typing)
                .length;
            final examCount = classStudents
                .where((s) => s.status == StudentStatus.exam)
                .length;
            // 离线人数 = 班级总人数 - 在线 - 打字 - 小测
            final offlineCount =
                _classTotalCount - onlineCount - typingCount - examCount;

            return Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                _buildStatusChip(
                  '在线: $onlineCount',
                  Colors.green,
                ),
                _buildStatusChip(
                  '离线: ${offlineCount >= 0 ? offlineCount : 0}',
                  Colors.grey,
                ),
                _buildStatusChip(
                  '打字: $typingCount',
                  Colors.blue,
                ),
                _buildStatusChip(
                  '小测: $examCount',
                  Colors.orange,
                ),
              ],
            );
          },
        ),
        // 题库选择
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLabel('题库'),
            const SizedBox(width: 4),
            SizedBox(
              width: 100,
              child: _buildBankSelector(),
            ),
          ],
        ),
        // 同步按钮
        ElevatedButton.icon(
          onPressed: _syncToStudents,
          icon: const Icon(Icons.sync, size: 16),
          label: const Text('同步'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.successGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
        // 刷新按钮
        ElevatedButton.icon(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('刷新'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildStatusChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSelector({
    required String hint,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderMain),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value.isEmpty ? null : value,
          hint: Text(
            hint,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          isExpanded: true,
          menuMaxHeight: 48.0 * 5,
          items: items.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(
                item,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  /// 题库选择器
  Widget _buildBankSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryBlue),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.primaryBlue.withAlpha(26),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedBank,
          hint: Text(
            '选择',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          isExpanded: true,
          menuMaxHeight: 48.0 * 5,
          items: _questionBanks.map((bank) {
            return DropdownMenuItem<String>(
              value: bank,
              child: Text(
                bank.length > 7 ? '${bank.substring(0, 7)}...' : bank,
                style:
                    const TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _selectedBank = value;
              });
              // 持久化题库选择到 JSON 文件
              QuestionBankConfigService.setSelectedBank(value);
              // 自动同步题库到学生端
              _syncBankToStudents(value);
            }
          },
        ),
      ),
    );
  }

  Widget _buildStudentCards() {
    final classLabel = '$_selectedGrade$_selectedClass';
    return StudentStatusWidget(classFilter: classLabel);
  }
}
