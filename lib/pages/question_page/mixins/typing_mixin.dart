import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/question_models.dart';

/// Mixin providing all typing question logic for the QuestionsPage
mixin TypingQuestionMixin on State {
  // ========== Typing Question State ==========
  // These fields must be declared in the host state class:
  //   TextEditingController _typingReferenceTextController;
  //   TextEditingController _typingScoreController;
  //   TextEditingController _typingTimeLimitController;
  //   String _typingType;
  //   int? _editingTypingIndex;
  //   List<TypingQuestion> _typingQuestions;
  //   String? _selectedBank;

  // ========== Typing Question Methods ==========

  void saveQuestionsToFile() {
    // This will be implemented in the host state class
  }

  Future<void> saveTypingQuestion() async {
    final self = this as dynamic;
    if (self.typingReferenceTextController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入参考文本'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final typingQuestion = TypingQuestion(
      typingType: self.typingType,
      referenceText: self.typingReferenceTextController.text,
      timeLimit: int.tryParse(self.typingTimeLimitController.text) ?? 5,
      score: int.tryParse(self.typingScoreController.text) ?? 10,
    );

    setState(() {
      if (self.editingTypingIndex != null) {
        self.typingQuestions[self.editingTypingIndex!] = typingQuestion;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打字题 ${self.editingTypingIndex! + 1} 已更新'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        self.typingQuestions.add(typingQuestion);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('打字题已添加，当前共 ${self.typingQuestions.length} 题'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    });

    if (self.selectedBank != null) {
      saveQuestionsToFile();
    }

    clearTypingForm();
  }

  void clearTypingForm() {
    final self = this as dynamic;
    self.typingReferenceTextController.clear();
    self.typingScoreController.text = '10';
    self.typingTimeLimitController.text = '5';
    setState(() {
      self.editingTypingIndex = null;
      self.typingType = 'chinese';
    });
  }

  void loadTypingQuestionToForm(int index) {
    final self = this as dynamic;
    final q = self.typingQuestions[index] as TypingQuestion;
    self.typingReferenceTextController.text = q.referenceText;
    self.typingScoreController.text = q.score.toString();
    self.typingTimeLimitController.text = q.timeLimit.toString();

    setState(() {
      self.editingTypingIndex = index;
      self.typingType = q.typingType;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加载第 ${index + 1} 题到编辑区'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  void deleteTypingQuestion() {
    final self = this as dynamic;
    if (self.editingTypingIndex == null) return;

    final deletedIndex = self.editingTypingIndex!;
    self.typingQuestions.removeAt(deletedIndex);
    clearTypingForm();

    if (self.selectedBank != null) {
      saveQuestionsToFile();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除第 ${deletedIndex + 1} 题'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  // ========== Typing Question UI Builders ==========

  Widget buildTypingQuestionForm() {
    final self = this as dynamic;
    final bool hasBank = self.selectedBank != null;
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Text(
                '打字类型：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(
                  '中文打字',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: self.typingType == 'chinese'
                        ? Colors.white
                        : (hasBank ? AppTheme.textPrimary : Colors.grey),
                  ),
                ),
                selected: self.typingType == 'chinese',
                selectedColor: AppTheme.primaryBlue,
                checkmarkColor: Colors.white,
                onSelected: hasBank
                    ? (selected) {
                        if (selected) {
                          setState(() {
                            self.typingType = 'chinese';
                          });
                        }
                      }
                    : null,
                backgroundColor:
                    hasBank ? const Color(0xFFF1F5F9) : Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: Text(
                  '英文打字',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: self.typingType == 'english'
                        ? Colors.white
                        : (hasBank ? AppTheme.textPrimary : Colors.grey),
                  ),
                ),
                selected: self.typingType == 'english',
                selectedColor: AppTheme.primaryBlue,
                checkmarkColor: Colors.white,
                onSelected: hasBank
                    ? (selected) {
                        if (selected) {
                          setState(() {
                            self.typingType = 'english';
                          });
                        }
                      }
                    : null,
                backgroundColor:
                    hasBank ? const Color(0xFFF1F5F9) : Colors.grey[200],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: self.typingReferenceTextController,
            enabled: hasBank,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: hasBank ? '请输入学生需要打字的参考文本...' : '请先选择题库',
              labelText: '参考文本',
              filled: true,
              fillColor: hasBank ? const Color(0xFFF8FAFC) : Colors.grey[200],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderMain),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.borderMain),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppTheme.primaryBlue, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '时间限制：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: self.typingTimeLimitController,
                  enabled: hasBank,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderMain),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderMain),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 2),
                    ),
                  ),
                ),
              ),
              const Text('分钟',
                  style: TextStyle(fontSize: 13, color: AppTheme.textPrimary)),
              const SizedBox(width: 16),
              const Text(
                '分值：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: self.typingScoreController,
                  enabled: hasBank,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderMain),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppTheme.borderMain),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                          color: AppTheme.primaryBlue, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: hasBank ? saveTypingQuestion : null,
                icon: Icon(
                  self.editingTypingIndex != null ? Icons.save : Icons.add,
                  size: 18,
                ),
                label: Text(
                  self.editingTypingIndex != null ? '保存修改' : '添加打字题',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasBank
                      ? (self.editingTypingIndex != null
                          ? Colors.orange
                          : AppTheme.primaryBlue)
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: hasBank && self.editingTypingIndex != null
                    ? deleteTypingQuestion
                    : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除题目'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasBank && self.editingTypingIndex != null
                      ? Colors.red[400]
                      : Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (self.editingTypingIndex != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: clearTypingForm,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('取消'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget buildTypingQuestionTable() {
    final self = this as dynamic;
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
              const Icon(Icons.table_chart, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                '打字题列表',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withAlpha(26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '共 ${self.typingQuestions.length} 题',
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          (self.typingQuestions as List).isEmpty
              ? buildEmptyTypingTable()
              : buildTypingTable(),
        ],
      ),
    );
  }

  Widget buildEmptyTypingTable() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.keyboard_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '暂无打字题，点击上方按钮添加',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTypingTable() {
    final self = this as dynamic;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        showCheckboxColumn: false,
        headingRowColor: MaterialStateProperty.all(
          AppTheme.primaryBlue.withAlpha(26),
        ),
        border: TableBorder.all(
          color: AppTheme.borderMain,
          width: 1,
          borderRadius: BorderRadius.circular(8),
        ),
        columns: const [
          DataColumn(
              label: Text('题型', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('题号', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('打字类型', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('参考文本', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('时间限制', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('分值', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: (self.typingQuestions as List<TypingQuestion>).asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final isEditing = self.editingTypingIndex == index;

          final typeText = q.typingType == 'chinese' ? '中文打字' : '英文打字';
          final previewText = q.referenceText.length > 30
              ? '${q.referenceText.substring(0, 30)}...'
              : q.referenceText;

          return DataRow(
            color: MaterialStateProperty.all(
              isEditing ? AppTheme.primaryBlue.withAlpha(26) : null,
            ),
            onSelectChanged: (_) => loadTypingQuestionToForm(index),
            cells: [
              DataCell(Text('打字题')),
              DataCell(Text('${index + 1}')),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: q.typingType == 'chinese'
                        ? Colors.blue.withAlpha(26)
                        : Colors.green.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    typeText,
                    style: TextStyle(
                      color: q.typingType == 'chinese'
                          ? Colors.blue[700]
                          : Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 250,
                  child: Text(
                    previewText,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text('${q.timeLimit} 分钟')),
              DataCell(Text('${q.score} 分')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
