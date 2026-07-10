import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/student_status_provider.dart';

class StudentStatusWidget extends StatelessWidget {
  final String? classFilter;

  const StudentStatusWidget({super.key, this.classFilter});

  @override
  Widget build(BuildContext context) {
    return Consumer<StudentStatusProvider>(
      builder: (context, provider, child) {
        final students = classFilter != null
            ? provider.getStudentsByClass(classFilter!)
            : provider.students;

        return _buildStudentList(students);
      },
    );
  }

  Widget _buildStudentList(List<StudentStatusInfo> students) {
    if (students.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            '暂无学生信息',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: students.length,
      itemBuilder: (context, index) {
        final student = students[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildStudentCard(StudentStatusInfo student) {
    final statusColor = _getStatusColor(student.status);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withAlpha(77)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部：状态图标 + 姓名
          Row(
            children: [
              // 状态图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                ),
                child: Center(
                  child: Text(
                    student.statusIcon,
                    style: const TextStyle(fontSize: 20),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // 姓名和班级
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      student.classId,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 9,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          // 中间：电脑名称
          Row(
            children: [
              Icon(Icons.computer, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  student.computerName,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          // IP 地址
          Row(
            children: [
              Icon(Icons.language, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  student.ip,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 9,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // 底部：状态标签
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(26),
            ),
            child: Text(
              student.statusText,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
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
