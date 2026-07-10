import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/http_server_service.dart';
import '../utils/app_path.dart';

/// 学生管理页面（包含学生管理和班级管理两个Tab）
class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _httpService = HttpServerService.instance;

  // 积分兑换数据
  List<Map<String, dynamic>> _exchangeItems = [];
  List<Map<String, dynamic>> _exchangeRecords = [];
  final _itemNameController = TextEditingController();
  final _itemPointsController = TextEditingController();
  final _itemStockController = TextEditingController();
  // 时间筛选
  DateTime? _filterDate;

  // 班级数据
  List<String> _allClassIds = [];
  List<String> _grades = [];
  String? _selectedGrade;
  String? _selectedClassId;
  List<Map<String, dynamic>> _students = [];

  // 编辑区控制器
  Map<String, dynamic>? _editingStudent;
  final _editNameController = TextEditingController();
  final _editPasswordController = TextEditingController();
  final _editComputerController = TextEditingController();
  final _editIpController = TextEditingController();
  final _editPointsController = TextEditingController();
  String? _editSelectedClassId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadClassData();
    _loadPointsExchangeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _editNameController.dispose();
    _editPasswordController.dispose();
    _editComputerController.dispose();
    _editIpController.dispose();
    _editPointsController.dispose();
    super.dispose();
  }

  void _loadClassData() {
    _allClassIds = _httpService.getAllClassIds();
    final gradeSet = <String>{};
    for (final classId in _allClassIds) {
      final grade = _extractGrade(classId);
      if (grade.isNotEmpty) gradeSet.add(grade);
    }
    _grades = gradeSet.toList()..sort();

    if (_grades.isNotEmpty) {
      _selectedGrade = _grades.first;
      _updateClassList();
    }
  }

  String _extractGrade(String classId) {
    final match = RegExp(r'^[^\d]+').firstMatch(classId);
    return match?.group(0) ?? '';
  }

  void _updateClassList() {
    if (_selectedGrade == null) return;
    final classIds =
        _allClassIds.where((id) => id.startsWith(_selectedGrade!)).toList();
    if (classIds.isNotEmpty) {
      _selectedClassId = classIds.first;
      _editSelectedClassId ??= _selectedClassId;
      _loadStudents();
    }
  }

  void _loadStudents() {
    if (_selectedClassId == null) {
      _students = [];
      return;
    }
    _students = _httpService.loadClassStudents(_selectedClassId!);
  }

  List<String> _getClassIdsForGrade() {
    if (_selectedGrade == null) return [];
    return _allClassIds.where((id) => id.startsWith(_selectedGrade!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab 栏
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
            tabs: const [
              Tab(text: '学生管理'),
              Tab(text: '班级管理'),
              Tab(text: '积分兑换'),
            ],
          ),
        ),
        // Tab 内容
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: 学生管理
              _buildStudentManagementTab(),
              // Tab 2: 班级管理
              _buildClassManagementTab(),
              // Tab 3: 积分兑换
              _buildPointsExchangeTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ==================== Tab 1: 学生管理 ====================

  Widget _buildStudentManagementTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('学生管理', '管理班级学生信息。'),
              const SizedBox(height: 16),
              _buildStudentContent(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentContent() {
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
          _buildClassSelector(),
          const SizedBox(height: 24),
          _buildEditPanel(),
          const SizedBox(height: 24),
          _buildButtonRow(),
          const SizedBox(height: 24),
          _buildStudentTable(),
        ],
      ),
    );
  }

  // ==================== Tab 2: 班级管理 ====================

  Widget _buildClassManagementTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 700;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('班级管理', '管理班级信息，支持班级升级。'),
              const SizedBox(height: 16),
              if (isWide)
                _buildWideClassLayout()
              else
                _buildNarrowClassLayout(),
            ],
          ),
        );
      },
    );
  }

  /// 宽屏布局：左侧班级列表，右侧操作面板
  Widget _buildWideClassLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：班级列表
        Expanded(
          flex: 3,
          child: _buildClassListCard(),
        ),
        const SizedBox(width: 16),
        // 右侧：升级说明
        Expanded(
          flex: 2,
          child: _buildUpgradeInfoCard(),
        ),
      ],
    );
  }

  /// 窄屏布局：上下排列
  Widget _buildNarrowClassLayout() {
    return Column(
      children: [
        _buildClassListCard(),
        const SizedBox(height: 16),
        _buildUpgradeInfoCard(),
      ],
    );
  }

  Widget _buildClassListCard() {
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
          Row(
            children: [
              const Icon(Icons.class_, size: 20, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              const Text('班级列表',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: AppTheme.textPrimary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEA580C).withAlpha(26),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('共 ${_allClassIds.length} 个班级',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEA580C))),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {
                  setState(() => _loadClassData());
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('已刷新'), backgroundColor: Colors.green),
                  );
                },
                icon: const Icon(Icons.refresh, size: 20),
                tooltip: '刷新',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_allClassIds.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('暂无班级数据',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _allClassIds.map((classId) {
                return _buildClassCard(classId);
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildClassCard(String classId) {
    final students = _httpService.loadClassStudents(classId);
    final nextClassId = _getNextGradeClass(classId);
    final canUpgrade = nextClassId != null;

    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(26),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(classId,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.primaryBlue)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.people, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text('${students.length} 名学生',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 12),
          if (canUpgrade)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showUpgradeClassDialog(classId, nextClassId),
                icon: const Icon(Icons.upgrade, size: 16),
                label: Text('升级到 $nextClassId'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('最高年级，无法升级',
                    style:
                        TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUpgradeInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDBA74)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: Color(0xFFEA580C)),
              SizedBox(width: 8),
              Text('升级说明',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Color(0xFFEA580C))),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoItem('初一 → 初二', '将初一班级升级为初二班级'),
          _buildInfoItem('初二 → 初三', '将初二班级升级为初三班级'),
          _buildInfoItem('初三', '最高年级，无法继续升级'),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDBA74)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber, size: 18, color: Color(0xFFEA580C)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '升级操作会将班级内所有学生的班级信息一并更新，并删除原班级目录。此操作不可撤销。',
                    style: TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFEA580C),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: '$title：',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: AppTheme.textPrimary)),
                TextSpan(
                    text: desc,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// 获取升级后的班级名称
  String? _getNextGradeClass(String classId) {
    final match = RegExp(r'^(初[一二三])(\d+班)$').firstMatch(classId);
    if (match == null) return null;
    final grade = match.group(1)!;
    final classNum = match.group(2)!;
    switch (grade) {
      case '初一':
        return '初二$classNum';
      case '初二':
        return '初三$classNum';
      default:
        return null;
    }
  }

  /// 显示班级升级确认对话框
  void _showUpgradeClassDialog(String oldClassId, String newClassId) {
    final students = _httpService.loadClassStudents(oldClassId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认升级班级'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(oldClassId,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3B82F6))),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, color: AppTheme.textSecondary),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(newClassId,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF10B981))),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '此操作将把 ${students.length} 名学生从 $oldClassId 升级到 $newClassId',
              style:
                  const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            if (students.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '学生: ${students.map((s) => s['name'] ?? '').join('、')}',
                  style: const TextStyle(fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _upgradeClass(oldClassId, newClassId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
            ),
            child: const Text('确认升级'),
          ),
        ],
      ),
    );
  }

  /// 执行班级升级
  Future<void> _upgradeClass(String oldClassId, String newClassId) async {
    try {
      final students = _httpService.loadClassStudents(oldClassId);

      // 更新所有学生的 class_id
      for (final student in students) {
        student['class_id'] = newClassId;
      }

      // 保存到新班级目录
      if (students.isNotEmpty) {
        // 逐个保存学生到新班级
        for (final student in students) {
          await _httpService.saveStudentToClass(newClassId, student);
        }
      } else {
        final dir = Directory('${AppPath.informationDir}/$newClassId');
        if (!dir.existsSync()) {
          dir.createSync(recursive: true);
        }
        final newData = {
          'class_id': newClassId,
          'students': [],
          'updated_at': DateTime.now().toIso8601String(),
        };
        final file = File('${dir.path}/use_list.json');
        await file
            .writeAsString(const JsonEncoder.withIndent('  ').convert(newData));
      }

      // 删除旧班级目录
      final oldDir = Directory('${AppPath.informationDir}/$oldClassId');
      if (oldDir.existsSync()) {
        oldDir.deleteSync(recursive: true);
      }

      // 清除缓存
      _httpService.clearStudentCache(oldClassId);
      _httpService.clearStudentCache(newClassId);

      // 刷新界面
      setState(() {
        _loadClassData();
        _loadStudents();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('$oldClassId → $newClassId 升级成功（${students.length}名学生）'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('升级失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ==================== 共用组件 ====================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
      ],
    );
  }

  // 年级/班级选择器
  Widget _buildClassSelector() {
    return Row(
      children: [
        Expanded(
          child: _buildDropdown<String>(
            value: _selectedGrade,
            hint: '选择年级',
            items: _grades,
            itemLabel: (g) => g,
            onChanged: (grade) {
              setState(() {
                _selectedGrade = grade;
                _updateClassList();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildDropdown<String>(
            value: _selectedClassId,
            hint: '选择班级',
            items: _getClassIdsForGrade(),
            itemLabel: (id) => id,
            onChanged: (classId) {
              setState(() {
                _selectedClassId = classId;
                _loadStudents();
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        IconButton(
          onPressed: () {
            _loadClassData();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('已刷新'),
                backgroundColor: Colors.green,
              ),
            );
          },
          icon: const Icon(Icons.refresh),
          tooltip: '刷新',
        ),
      ],
    );
  }

  // 编辑区
  Widget _buildEditPanel() {
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
          Row(
            children: [
              const Text('学生信息',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              if (_editingStudent != null) ...[
                const SizedBox(width: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withAlpha(26),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('编辑模式',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_editNameController, '姓名')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_editPasswordController, '密码')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_editComputerController, '电脑名称')),
              const SizedBox(width: 12),
              Expanded(child: _buildTextField(_editIpController, 'IP 地址')),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildTextField(_editPointsController, '积分')),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDropdown<String>(
                  value: _editSelectedClassId,
                  hint: '选择班级',
                  items: _allClassIds,
                  itemLabel: (id) => id,
                  onChanged: (classId) {
                    setState(() {
                      _editSelectedClassId = classId;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 按钮行（响应式）
  Widget _buildButtonRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 500;
        if (isNarrow) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                child: ElevatedButton.icon(
                  onPressed: _saveEditStudent,
                  icon: const Icon(Icons.save),
                  label: Text(_editingStudent != null ? '保存修改' : '保存'),
                  style: AppTheme.primaryButtonStyle,
                ),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: OutlinedButton.icon(
                  onPressed: _addStudent,
                  icon: const Icon(Icons.person_add),
                  label: const Text('添加学生'),
                  style: AppTheme.secondaryButtonStyle,
                ),
              ),
              if (_editingStudent != null)
                SizedBox(
                  width: constraints.maxWidth,
                  child: OutlinedButton.icon(
                    onPressed: _clearEditPanel,
                    icon: const Icon(Icons.clear),
                    label: const Text('取消编辑'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                      side: const BorderSide(color: AppTheme.borderMain),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _saveEditStudent,
                icon: const Icon(Icons.save),
                label: Text(_editingStudent != null ? '保存修改' : '保存'),
                style: AppTheme.primaryButtonStyle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _addStudent,
                icon: const Icon(Icons.person_add),
                label: const Text('添加学生'),
                style: AppTheme.secondaryButtonStyle,
              ),
            ),
            if (_editingStudent != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearEditPanel,
                  icon: const Icon(Icons.clear),
                  label: const Text('取消编辑'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textSecondary,
                    side: const BorderSide(color: AppTheme.borderMain),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  // 学生表格
  Widget _buildStudentTable() {
    if (_selectedClassId == null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child:
              Text('请先选择班级', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    if (_students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child:
              Text('该班级暂无学生', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowMinHeight: 48,
        dataRowMaxHeight: 56,
        columnSpacing: 24,
        horizontalMargin: 16,
        columns: const [
          DataColumn(
              label: Text('姓名',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          DataColumn(
              label: Text('密码',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          DataColumn(
              label: Text('电脑名称',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          DataColumn(
              label: Text('IP 地址',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          DataColumn(
              label: Text('积分',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          DataColumn(
              label: Text('班级',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
          DataColumn(
              label: Text('操作',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
        ],
        rows: _students.map((student) {
          final isEditing = _editingStudent != null &&
              _editingStudent!['id'] == student['id'];
          return DataRow(
              selected: isEditing,
              onSelectChanged: (_) => _startEditStudent(student),
              cells: [
                DataCell(Text(student['name'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(student['password'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(student['computer_name'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text(student['ip'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Text('${student['points'] ?? 0}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600))),
                DataCell(Text(student['class_id'] ?? '',
                    style: const TextStyle(fontSize: 13))),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _startEditStudent(student),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('修改',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.primaryBlue)),
                    ),
                    TextButton(
                      onPressed: () => _showDeleteConfirm(student),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('删除',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.dangerRed)),
                    ),
                  ],
                )),
              ]);
        }).toList(),
      ),
    );
  }

  // ==================== 学生操作方法 ====================

  void _startEditStudent(Map<String, dynamic> student) {
    setState(() {
      _editingStudent = student;
      _editNameController.text = student['name'] ?? '';
      _editPasswordController.text = student['password'] ?? '';
      _editComputerController.text = student['computer_name'] ?? '';
      _editIpController.text = student['ip'] ?? '';
      _editPointsController.text = '${student['points'] ?? 0}';
      _editSelectedClassId = student['class_id'] ?? _selectedClassId;
    });
  }

  void _clearEditPanel() {
    setState(() {
      _editingStudent = null;
      _editNameController.clear();
      _editPasswordController.clear();
      _editComputerController.clear();
      _editIpController.clear();
      _editPointsController.clear();
      _editSelectedClassId = _selectedClassId;
    });
  }

  Future<void> _saveEditStudent() async {
    if (_editingStudent == null) return;

    final name = _editNameController.text.trim();
    final password = _editPasswordController.text.trim();
    final computerName = _editComputerController.text.trim();
    final ip = _editIpController.text.trim();
    final points = int.tryParse(_editPointsController.text.trim()) ?? 0;
    final newClassId = _editSelectedClassId ?? _selectedClassId;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('姓名不能为空'), backgroundColor: Colors.red),
      );
      return;
    }

    if (newClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择班级'), backgroundColor: Colors.red),
      );
      return;
    }

    final oldClassId = _editingStudent!['class_id'] as String?;

    final updatedStudent = Map<String, dynamic>.from(_editingStudent!);
    updatedStudent['name'] = name;
    updatedStudent['password'] = password;
    updatedStudent['computer_name'] = computerName;
    updatedStudent['ip'] = ip;
    updatedStudent['points'] = points;
    updatedStudent['class_id'] = newClassId;

    if (oldClassId != null && oldClassId != newClassId) {
      final oldStudents = _httpService.loadClassStudents(oldClassId);
      oldStudents.removeWhere((s) => s['id'] == updatedStudent['id']);
      final oldData = {
        'class_id': oldClassId,
        'students': oldStudents,
        'updated_at': DateTime.now().toIso8601String(),
      };
      await _httpService.saveStudentToClass(oldClassId, oldData);
    }

    await _httpService.saveStudentToClass(newClassId, updatedStudent);

    setState(() {
      _clearEditPanel();
      _loadStudents();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('学生信息已更新'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _addStudent() async {
    final name = _editNameController.text.trim();
    final password = _editPasswordController.text.trim();
    final computerName = _editComputerController.text.trim();
    final ip = _editIpController.text.trim();
    final points = int.tryParse(_editPointsController.text.trim()) ?? 0;
    final classId = _editSelectedClassId ?? _selectedClassId;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('姓名不能为空'), backgroundColor: Colors.red),
      );
      return;
    }

    if (classId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择班级'), backgroundColor: Colors.red),
      );
      return;
    }

    final student = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'name': name,
      'password': password,
      'class_id': classId,
      'computer_name': computerName,
      'ip': ip,
      'points': points,
      'register_time': DateTime.now().toIso8601String(),
    };

    await _httpService.saveStudentToClass(classId, student);

    setState(() {
      _clearEditPanel();
      _loadStudents();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('学生 $name 已添加'), backgroundColor: Colors.green),
      );
    }
  }

  void _showDeleteConfirm(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定删除学生 [${student['name']}]？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteStudent(student);
            },
            style: AppTheme.dangerButtonStyle,
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteStudent(Map<String, dynamic> student) async {
    final classId = student['class_id'] as String? ?? _selectedClassId;
    if (classId == null) return;

    final students = _httpService.loadClassStudents(classId);
    students.removeWhere((s) => s['id'] == student['id']);

    final data = {
      'class_id': classId,
      'students': students,
      'updated_at': DateTime.now().toIso8601String(),
    };
    await _httpService.saveStudentToClass(classId, data);

    if (_editingStudent != null && _editingStudent!['id'] == student['id']) {
      _clearEditPanel();
    }

    setState(() {
      _loadStudents();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('已删除学生 ${student['name']}'),
            backgroundColor: Colors.green),
      );
    }
  }

  // ==================== 通用组件 ====================

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style:
                const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        isExpanded: true,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down, color: AppTheme.primaryBlue),
        menuMaxHeight: 250,
        items: items
            .map((item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(itemLabel(item),
                      style: const TextStyle(fontSize: 13)),
                ))
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  // ==================== Tab 3: 积分兑换 ====================

  void _loadPointsExchangeData() {
    final config = _httpService.pointsExchangeConfig;
    setState(() {
      _exchangeItems = List<Map<String, dynamic>>.from(
          (config['items'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
      _exchangeRecords = List<Map<String, dynamic>>.from(
          (config['exchange_records'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)));
    });
  }

  Widget _buildPointsExchangeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 商品管理
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.card_giftcard,
                        size: 20, color: Color(0xFF8B5CF6)),
                    const SizedBox(width: 8),
                    const Text('兑换商品',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showEditItemDialog(null),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加商品'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 时间筛选按钮
                    ElevatedButton.icon(
                      onPressed: _showFilterDatePicker,
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: Text(_filterDate != null
                          ? '${_filterDate!.year}/${_filterDate!.month}/${_filterDate!.day}'
                          : '筛选'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _filterDate != null
                            ? const Color(0xFF10B981)
                            : Colors.grey[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        await Future.delayed(const Duration(milliseconds: 300));
                        _loadPointsExchangeData();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('已刷新'),
                                backgroundColor: Colors.green),
                          );
                        }
                      },
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: '刷新',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_exchangeItems.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Center(
                        child: Text('暂无兑换商品，点击"添加商品"创建',
                            style: TextStyle(color: AppTheme.textSecondary))),
                  )
                else
                  Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _exchangeItems
                          .map((item) => SizedBox(
                                width: 140,
                                child: _buildExchangeItemCard(item),
                              ))
                          .toList()),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // 兑换记录
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.history,
                        size: 20, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    const Text('兑换记录',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                            color: AppTheme.textPrimary)),
                    const Spacer(),
                    // 显示筛选状态
                    if (_filterDate != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withAlpha(26),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                                '筛选: ${_filterDate!.year}/${_filterDate!.month}/${_filterDate!.day}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _clearFilter,
                              child: const Icon(Icons.close,
                                  size: 14, color: Color(0xFF10B981)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Text('共 ${_getFilteredRecords().length} 条',
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                if (_getFilteredRecords().isEmpty)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12)),
                    child: Center(
                        child: Text(
                            _filterDate != null ? '该日期暂无兑换记录' : '暂无兑换记录',
                            style: const TextStyle(
                                color: AppTheme.textSecondary))),
                  )
                else
                  ..._getFilteredRecords()
                      .reversed
                      .take(20)
                      .map((record) => ListTile(
                            dense: true,
                            leading: const Icon(Icons.redeem,
                                size: 18, color: Color(0xFF8B5CF6)),
                            title: Text(
                                '${record['student_name'] ?? ''} 兑换了 ${record['item_name'] ?? ''}'),
                            subtitle: Text(
                                '消耗 ${record['points_cost'] ?? 0} 积分 · ${_formatTime(record['exchange_time'] ?? '')}'),
                          )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime);
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  /// 显示日期选择器
  void _showFilterDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('zh', 'CN'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8B5CF6),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF1F2937),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _filterDate = picked;
      });
    }
  }

  /// 获取筛选后的兑换记录
  List<Map<String, dynamic>> _getFilteredRecords() {
    if (_filterDate == null) {
      return _exchangeRecords;
    }
    return _exchangeRecords.where((record) {
      final isoTime = record['exchange_time'] as String? ?? '';
      if (isoTime.isEmpty) return false;
      try {
        final dt = DateTime.parse(isoTime);
        return dt.year == _filterDate!.year &&
            dt.month == _filterDate!.month &&
            dt.day == _filterDate!.day;
      } catch (_) {
        return false;
      }
    }).toList();
  }

  /// 清除筛选
  void _clearFilter() {
    setState(() {
      _filterDate = null;
    });
  }

  Widget _buildExchangeItemCard(Map<String, dynamic> item) {
    final enabled = item['enabled'] as bool? ?? true;
    final stock = item['stock'] as int? ?? -1;
    final pointsCost = item['points_cost'] as int? ?? 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: enabled ? const Color(0xFFE2E8F0) : const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 名称
          Text(item['name'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          // 积分
          const SizedBox(height: 6),
          Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withAlpha(26),
                  borderRadius: BorderRadius.circular(8)),
              child: Text('$pointsCost 积分',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8B5CF6)))),
          // 库存
          const SizedBox(height: 4),
          if (stock != -1)
            Text('库存: $stock',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary))
          else
            const Text('库存: 不限',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          if (!enabled)
            Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(26),
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('已下架',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange))),
          // 操作按钮
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () => _showEditItemDialog(item),
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppTheme.primaryBlue),
                  tooltip: '编辑',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32)),
              IconButton(
                  onPressed: () => _toggleItemEnabled(item),
                  icon: Icon(
                      enabled
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: enabled ? Colors.orange : Colors.green),
                  tooltip: enabled ? '下架' : '上架',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32)),
              IconButton(
                  onPressed: () => _deleteExchangeItem(item),
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppTheme.dangerRed),
                  tooltip: '删除',
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditItemDialog(Map<String, dynamic>? item) {
    _itemNameController.text = item?['name'] ?? '';
    _itemPointsController.text = '${item?['points_cost'] ?? 10}';
    _itemStockController.text = '${item?['stock'] ?? -1}';
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(item != null ? '编辑商品' : '添加商品'),
              content: SizedBox(
                  width: 400,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(
                        controller: _itemNameController,
                        decoration: const InputDecoration(labelText: '商品名称 *')),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _itemPointsController,
                        decoration: const InputDecoration(labelText: '所需积分'),
                        keyboardType: TextInputType.number),
                    const SizedBox(height: 12),
                    TextField(
                        controller: _itemStockController,
                        decoration:
                            const InputDecoration(labelText: '库存 (-1为不限)'),
                        keyboardType: TextInputType.number),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _saveExchangeItem(item);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B5CF6),
                      foregroundColor: Colors.white),
                  child: const Text('保存'),
                ),
              ],
            ));
  }

  void _saveExchangeItem(Map<String, dynamic>? original) {
    final name = _itemNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('商品名称不能为空'), backgroundColor: Colors.red),
      );
      return;
    }
    final pointsCost = int.tryParse(_itemPointsController.text.trim()) ?? 10;
    final stock = int.tryParse(_itemStockController.text.trim()) ?? -1;
    final newItem = {
      'id': original?['id'] ?? DateTime.now().millisecondsSinceEpoch,
      'name': name,
      'points_cost': pointsCost,
      'stock': stock,
      'enabled': original?['enabled'] ?? true,
    };

    setState(() {
      if (original != null) {
        final idx = _exchangeItems.indexWhere((i) => i['id'] == original['id']);
        if (idx != -1) _exchangeItems[idx] = newItem;
      } else {
        _exchangeItems.add(newItem);
      }
    });
    _savePointsExchangeConfig();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(original != null ? '商品已更新' : '商品已添加'),
          backgroundColor: Colors.green),
    );
  }

  void _toggleItemEnabled(Map<String, dynamic> item) {
    setState(() {
      item['enabled'] = !(item['enabled'] as bool? ?? true);
    });
    _savePointsExchangeConfig();
  }

  void _deleteExchangeItem(Map<String, dynamic> item) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('确认删除'),
              content: Text('确定删除商品 [${item['name']}]？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _exchangeItems.removeWhere((i) => i['id'] == item['id']);
                    });
                    _savePointsExchangeConfig();
                  },
                  style: AppTheme.dangerButtonStyle,
                  child: const Text('删除'),
                ),
              ],
            ));
  }

  Future<void> _savePointsExchangeConfig() async {
    final config = {
      'items': _exchangeItems,
      'exchange_records': _exchangeRecords,
    };
    _httpService.pointsExchangeConfig = config;
    // 直接调用保存方法
    try {
      final file = File(_httpService.pointsExchangeConfigPath);
      final dir = file.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(config));
    } catch (e) {
      print('保存积分兑换配置失败: $e');
    }
    _loadPointsExchangeData();
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }
}
