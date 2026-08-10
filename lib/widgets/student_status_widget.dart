import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/student_status_provider.dart';

class StudentStatusWidget extends StatefulWidget {
  final String? classFilter;

  const StudentStatusWidget({super.key, this.classFilter});

  @override
  State<StudentStatusWidget> createState() => _StudentStatusWidgetState();
}

class _StudentStatusWidgetState extends State<StudentStatusWidget> {
  // 排序配置
  String _sortColumn = 'name';
  bool _sortAscending = true;

  void _toggleSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  // 表头配置：key, 显示名, 列宽比
  static const _columns = [
    ('name', '学生姓名', 1.2),
    ('classId', '班级', 1.0),
    ('computerName', '电脑名称', 1.6),
    ('ip', 'IP地址', 1.4),
    ('status', '在线状态', 1.0),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentStatusProvider>(
      builder: (context, provider, child) {
        final students = widget.classFilter != null
            ? provider.getStudentsByClass(widget.classFilter!)
            : provider.students;

        // 排序
        final sorted = List<StudentStatusInfo>.from(students);
        sorted.sort((a, b) {
          int cmp;
          switch (_sortColumn) {
            case 'name':
              cmp = a.name.compareTo(b.name);
              break;
            case 'classId':
              cmp = a.classId.compareTo(b.classId);
              break;
            case 'computerName':
              cmp = a.computerName.compareTo(b.computerName);
              break;
            case 'ip':
              cmp = a.ip.compareTo(b.ip);
              break;
            case 'status':
              cmp = a.statusText.compareTo(b.statusText);
              break;
            default:
              cmp = 0;
          }
          return _sortAscending ? cmp : -cmp;
        });

        return Column(
          children: [
            // 学生表格
            Expanded(
              child: sorted.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline, size: 48,
                              color: Colors.grey[300]),
                          const SizedBox(height: 8),
                          const Text('暂无学生信息',
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Table(
                        border: TableBorder(
                          left: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                          right: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                          bottom: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                          top: BorderSide.none,
                          horizontalInside: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                          verticalInside: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
                        ),
                        columnWidths: {
                          for (int i = 0; i < _columns.length; i++)
                            i: FlexColumnWidth(_columns[i].$3),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: [
                          // 表头行（可点击排序）
                          TableRow(
                            decoration: const BoxDecoration(
                                color: Color(0xFFF1F5F9)),
                            children: List.generate(_columns.length, (i) {
                              final (key, label, _) = _columns[i];
                              final isSorted = _sortColumn == key;
                              return _buildHeaderCell(
                                label,
                                isSorted: isSorted,
                                ascending: _sortAscending,
                                onTap: () => _toggleSort(key),
                              );
                            }),
                          ),
                          // 数据行
                          for (int i = 0; i < sorted.length; i++)
                            TableRow(
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? Colors.white
                                    : const Color(0xFFF8FAFC),
                              ),
                              children: [
                                _buildCell(sorted[i].name, bold: true),
                                _buildCell(sorted[i].classId),
                                _buildCell(sorted[i].computerName),
                                _buildCell(sorted[i].ip),
                                _buildStatusCell(sorted[i]),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeaderCell(String label,
      {bool isSorted = false, bool ascending = true, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: isSorted ? const Color(0xFF2563EB) : const Color(0xFF334155),
              ),
            ),
            if (isSorted)
              Icon(
                ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 12,
                color: const Color(0xFF2563EB),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(String text, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: const Color(0xFF334155),
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildStatusCell(StudentStatusInfo student) {
    final statusColor = _getStatusColor(student.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: statusColor.withAlpha(26),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: statusColor.withAlpha(77)),
          ),
          child: Text(
            student.statusText,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.online:
        return Colors.green;
      case StudentStatus.typing:
        return Colors.blue;
      case StudentStatus.exam:
        return Colors.orange;
      case StudentStatus.offline:
        return Colors.grey;
    }
  }
}