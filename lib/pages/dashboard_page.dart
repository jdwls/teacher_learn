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
  bool _isSyncing = false; // 同步按钮互斥锁
  bool _isCollecting = false; // 收卷按钮互斥锁
  bool _examEntryDisabled = false; // 是否禁止进入课堂小测（全局锁）
  Set<String> _selectedStudentIds = <String>{}; // 已勾选学生

  /// 题库下拉的特殊项：此时无法进入课堂小测
  static const String _noExamOption = '__NO_EXAM__';

  final List<String> _grades = ['初一', '初二', '初三'];
  final List<String> _classes =
      List.generate(20, (i) => '${(i + 1).toString().padLeft(2, '0')}班');

  @override
  void initState() {
    super.initState();
    _loadQuestionBanks();
    _loadExamControlState();
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
      // 只恢复 UI 选择，不自动同步到服务器（避免覆盖外部设置）
    }
  }

  /// 加载课堂小测全局锁状态
  Future<void> _loadExamControlState() async {
    try {
      final response = await http
          .get(Uri.parse('http://localhost:20020/api/exam-control'))
          .timeout(const Duration(seconds: 5));
      if (!mounted || response.statusCode != 200) return;
      final data = json.decode(response.body);
      if (data['success'] == true) {
        setState(() {
          _examEntryDisabled = data['exam_entry_disabled'] == true;
        });
      }
    } catch (e) {
      debugPrint('加载课堂小测状态失败: $e');
    }
  }

  /// 设置/解除课堂小测全局锁
  Future<bool> _setExamControl(bool disabled) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:20020/api/exam-control'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'disabled': disabled}),
          )
          .timeout(const Duration(seconds: 10));
      if (!mounted) return false;
      if (_isResponseOk(response)) {
        setState(() => _examEntryDisabled = disabled);
        return true;
      }
      _showSnack('设置课堂小测状态失败', isError: true);
    } catch (e) {
      if (mounted) _showSnack('设置课堂小测状态失败: $e', isError: true);
    }
    return false;
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppTheme.successGreen,
      ),
    );
  }

  /// 当前班级实际勾选人数
  int _selectedCountOfCurrentClass() {
    final classStudents = context
        .read<StudentStatusProvider>()
        .getStudentsByClass('$_selectedGrade$_selectedClass');
    final ids = classStudents.map((s) => s.id).toSet();
    return _selectedStudentIds.where(ids.contains).length;
  }

  /// 对勾选学生下发收卷指令
  Future<void> _collectPapers() async {
    if (_isCollecting) return;
    if (_examEntryDisabled) {
      _showSnack('当前已锁定课堂小测，无法收卷', isError: true);
      return;
    }

    final classLabel = '$_selectedGrade$_selectedClass';
    final classStudents = context
        .read<StudentStatusProvider>()
        .getStudentsByClass(classLabel);
    final validIds = classStudents.map((s) => s.id).toSet();
    final targets = _selectedStudentIds.where(validIds.contains).toList();
    if (targets.isEmpty) {
      _showSnack('请先勾选要收卷的学生', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认收卷'),
        content: Text(
            '确定对已选 ${targets.length} 名学生收卷？\n仅正在课堂小测页面的学生会立即交卷。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('确定收卷'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCollecting = true);
    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:20020/api/exam-collect'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'class_id': classLabel,
              'student_ids': targets,
            }),
          )
          .timeout(const Duration(seconds: 10));
      if (!_isResponseOk(response)) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final data = json.decode(response.body);
      if (!mounted) return;
      setState(() => _selectedStudentIds.clear());
      _showSnack(
          '收卷指令已发送（${data['count'] ?? targets.length} 人，仅小测页学生生效）');
    } catch (e) {
      if (mounted) _showSnack('收卷失败: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isCollecting = false);
    }
  }

  /// 同步题库到学生端
  Future<String?> _syncBankToStudents(String bankName) async {
    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:20020/api/active-bank'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'bank': bankName}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          return '同步成功';
        }
        return '服务器返回错误';
      }
      return 'HTTP ${response.statusCode}';
    } catch (e) {
      return '网络错误: $e';
    }
  }

  /// 保存班级选择到 AuthProvider
  void _saveClassSelection() {
    if (!mounted) return;
    // 切换班级时清空勾选，避免把上一个班级的选择带到新班级
    setState(() => _selectedStudentIds.clear());
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

  /// 同步到学生端。配置只影响后续登录和新打开的小测，已有会话保持不变。
  void _syncToStudents() async {
    if (_isSyncing) return;
    if (_examEntryDisabled) {
      _showSnack('当前为「此时无法进入课堂小测」，请先选择真实题库');
      return;
    }
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择一个题库'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() => _isSyncing = true);

    final classLabel = '$_selectedGrade$_selectedClass';

    try {
      final response = await http
          .post(
            Uri.parse('http://localhost:20020/api/sync-config'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'class_id': classLabel, 'bank': _selectedBank}),
          )
          .timeout(const Duration(seconds: 10));
      if (!_isResponseOk(response)) {
        throw Exception('同步班级和题库失败（HTTP ${response.statusCode}）');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('已同步班级 "$classLabel" 和题库 "$_selectedBank"（仅影响后续登录和新小测）'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('同步失败: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // 无论成功、失败还是提前返回，都要复位同步状态，避免按钮永久卡在"同步中"
      if (mounted) {
        setState(() => _isSyncing = false);
      } else {
        _isSyncing = false;
      }
    }
  }

  /// 校验服务器响应：状态码 200 且 body 中 success == true
  bool _isResponseOk(http.Response response) {
    if (response.statusCode != 200) return false;
    try {
      final data = json.decode(response.body);
      return data is Map && data['success'] == true;
    } catch (_) {
      return false;
    }
  }

  void _loadData() {
    if (!mounted) return;
    final userProvider = context.read<UserProvider>();
    final examProvider = context.read<ExamProvider>();

    userProvider.loadUsers();
    examProvider.loadExams();

    // 点击刷新：重新读取当前班级的 use_list.json 学生列表并显示到表格
    final studentStatusProvider = context.read<StudentStatusProvider>();
    studentStatusProvider.refresh(
      '${AppPath.projectRoot}/information/$_selectedGrade$_selectedClass/use_list.json',
    );
    // 同时从 ServerService 内存刷新在线状态（会与上面读到的列表合并）
    studentStatusProvider.reloadFromServer();

    // 重新读取班级名册（information/<班级>/use_list.json），更新班级总人数
    _loadClassTotalCount('$_selectedGrade$_selectedClass');
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
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              child: isNarrow ? _buildNarrowToolbar() : _buildWideToolbar(),
            ),
            // 在线成员区域
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
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
            onPressed:
                (_isSyncing || _examEntryDisabled) ? null : _syncToStudents,
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(_isSyncing ? '同步中…' : '同步'),
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
      ),
    );
  }

  /// 窄屏工具栏布局（自动换行）
  Widget _buildNarrowToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
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
                    }
                  },
                ),
              ),
            ],
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
            onPressed:
                (_isSyncing || _examEntryDisabled) ? null : _syncToStudents,
            icon: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.sync, size: 16),
            label: Text(_isSyncing ? '同步中…' : '同步'),
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
      ),
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
    final selectedValue = _examEntryDisabled ? _noExamOption : _selectedBank;
    final bankItems = <DropdownMenuItem<String>>[
      ..._questionBanks.map((bank) {
        return DropdownMenuItem<String>(
          value: bank,
          child: Text(
            bank.length > 7 ? '${bank.substring(0, 7)}...' : bank,
            style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        );
      }),
      DropdownMenuItem<String>(
        value: _noExamOption,
        child: Text(
          '此时无法进入课堂小测',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppTheme.dangerRed,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.primaryBlue),
        borderRadius: BorderRadius.circular(8),
        color: AppTheme.primaryBlue.withAlpha(26),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          hint: Text(
            '选择',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          isExpanded: true,
          menuMaxHeight: 48.0 * 6,
          items: bankItems,
          onChanged: (value) async {
            if (value == null) return;

            // 选择「此时无法进入课堂小测」：只设置全局锁，不改变真实题库
            if (value == _noExamOption) {
              if (_examEntryDisabled) return;
              final ok = await _setExamControl(true);
              if (ok) {
                _showSnack('已设置：学生此时无法进入课堂小测');
              }
              return;
            }

            // 从全局锁切回真实题库：先解锁
            if (_examEntryDisabled) {
              final unlocked = await _setExamControl(false);
              if (!unlocked) return;
            }

            setState(() {
              _selectedBank = value;
            });
            // 持久化题库选择到 JSON 文件
            QuestionBankConfigService.setSelectedBank(value);
            // 同步题库到学生端
            _syncBankToStudents(value).then((result) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result ?? '同步成功'),
                    backgroundColor:
                        result == '同步成功' ? Colors.green : Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildStudentCards() {
    final classLabel = '$_selectedGrade$_selectedClass';
    final selectedCount = _selectedCountOfCurrentClass();
    final canCollect =
        !_isCollecting && !_examEntryDisabled && selectedCount > 0;

    return Column(
      children: [
        // 勾选与收卷操作栏
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Text(
                '已选 $selectedCount 人',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
              if (_examEntryDisabled) ...[
                const SizedBox(width: 12),
                Text(
                  '课堂小测已锁定',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dangerRed,
                  ),
                ),
              ],
              const Spacer(),
              ElevatedButton.icon(
                onPressed: canCollect ? _collectPapers : null,
                icon: _isCollecting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.inventory_2_outlined, size: 16),
                label: Text(
                  _isCollecting ? '收卷中…' : '收卷',
                  style: const TextStyle(fontSize: 12),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: StudentStatusWidget(
            classFilter: classLabel,
            selectedIds: _selectedStudentIds,
            onSelectionChanged: (ids) =>
                setState(() => _selectedStudentIds = ids),
          ),
        ),
      ],
    );
  }
}
