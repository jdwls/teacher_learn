import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/image_service.dart';
import '../../../models/question_models.dart';
import '../controllers.dart';

/// Mixin providing all sequential question logic for the QuestionsPage
mixin SequentialQuestionMixin on State {
  // ========== Sequential Question State ==========
  // These fields must be declared in the host state class:
  //   TextEditingController _sequentialQuestionController;
  //   TextEditingController _sequentialScoreController;
  //   String? _savedSequentialQuestionImage;
  //   String? _tempSequentialQuestionImage;
  //   int? _editingSequentialIndex;
  //   List<SequentialItemControllers> _sequentialItemControllers;
  //   int _sequentialItemCount;
  //   List<SequentialQuestion> _sequentialQuestions;
  //   String? _selectedBank;

  // ========== Sequential Question Methods ==========

  void saveQuestionsToFile() {
    // This will be implemented in the host state class
  }

  void initializeSequentialItemControllers() {
    final self = this as dynamic;
    final controllers = self.sequentialItemControllers as List<SequentialItemControllers>;
    controllers.clear();
    // 初始化时仅创建初始需求的数量，后续动态扩展
    final initialCount = (self.sequentialItemCount as int?) ?? 3;
    for (int i = 0; i < initialCount; i++) {
      controllers.add(SequentialItemControllers());
    }
  }

  /// 确保有足够的顺序项控制器（动态扩展）
  void _ensureSequentialControllers(int requiredCount) {
    final self = this as dynamic;
    final controllers = self.sequentialItemControllers as List<SequentialItemControllers>;
    while (controllers.length < requiredCount) {
      controllers.add(SequentialItemControllers());
    }
  }

  void addSequentialItem() {
    final self = this as dynamic;
    _ensureSequentialControllers((self.sequentialItemCount as int) + 1);
    setState(() {
      self.sequentialItemCount++;
    });
  }

  void removeSequentialItem(int index) {
    final self = this as dynamic;
    final itemCount = self.sequentialItemCount as int;
    if (itemCount > 2) {
      setState(() {
        final controllers = self.sequentialItemControllers as List<SequentialItemControllers>;
        // 将后面的元素前移覆盖被删除项
        for (int j = index; j < itemCount - 1; j++) {
          controllers[j].controller.text = controllers[j + 1].controller.text;
          controllers[j].imagePath = controllers[j + 1].imagePath;
        }
        // 清除最后一项
        controllers[itemCount - 1].controller.clear();
        controllers[itemCount - 1].imagePath = null;
        self.sequentialItemCount = itemCount - 1;
      });
    }
  }

  Future<void> saveSequentialQuestion() async {
    final self = this as dynamic;
    final questionController =
        self.sequentialQuestionController as TextEditingController;
    final scoreController =
        self.sequentialScoreController as TextEditingController;
    final selectedBank = self.selectedBank as String?;
    final editingIndex = self.editingSequentialIndex as int?;
    final questions =
        self.sequentialQuestions as List<SequentialQuestion>;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;
    final itemCount = self.sequentialItemCount as int;

    if (questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入题干'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? savedQuestionImage = self.savedSequentialQuestionImage as String?;
    final tempQuestionImage = self.tempSequentialQuestionImage as String?;
    if (tempQuestionImage != null && selectedBank != null) {
      final oldSaved = self.savedSequentialQuestionImage as String?;
      if (oldSaved != null) {
        await ImageService.deleteQuestionBankImage(selectedBank, oldSaved);
      }
      final saved = await ImageService.copyFromCacheToQuestionBank(
        cachePath: tempQuestionImage,
        bankName: selectedBank,
        position: '题干',
        questionTitle: questionController.text,
      );
      if (saved != null) savedQuestionImage = saved;
    }

    final questionScore = int.tryParse(scoreController.text) ?? 5;
    // 方案B：题目总分由 items 分值累加得出
    final itemScore = itemCount > 0 ? (questionScore ~/ itemCount) : 5;
    final scoreRemainder = itemCount > 0 ? questionScore % itemCount : 0;

    final items = <SequentialItem>[];
    for (int i = 0; i < itemCount; i++) {
      final ctrl = itemControllers[i];
      if (ctrl.controller.text.isNotEmpty) {
        String? savedItemImage = ctrl.imagePath;

        if (ctrl.imagePath != null && selectedBank != null) {
          final saved = await ImageService.copyFromCacheToQuestionBank(
            cachePath: ctrl.imagePath!,
            bankName: selectedBank,
            position: '项${i + 1}',
            questionTitle: questionController.text,
          );
          if (saved != null) savedItemImage = saved;
        }

        items.add(SequentialItem(
          text: ctrl.controller.text,
          image: savedItemImage,
          score: itemScore + (i < scoreRemainder ? 1 : 0),
        ));
      }
    }

    if (items.length < 2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请至少填写两项待排序内容'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final sequentialQuestion = SequentialQuestion(
      questionText: questionController.text,
      score: int.tryParse(scoreController.text) ?? 5,
      items: items,
      questionImage: savedQuestionImage,
    );

    setState(() {
      if (editingIndex != null) {
        questions[editingIndex] = sequentialQuestion;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('顺序题 ${editingIndex + 1} 已更新'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        questions.add(sequentialQuestion);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('顺序题已添加，当前共 ${questions.length} 题'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    });

    if (selectedBank != null) {
      self.saveQuestionsToFile();
    }

    await ImageService.clearCache();

    clearSequentialForm();
  }

  void clearSequentialForm() {
    final self = this as dynamic;
    final questionController =
        self.sequentialQuestionController as TextEditingController;
    final scoreController =
        self.sequentialScoreController as TextEditingController;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;

    questionController.clear();
    scoreController.text = '5';
    setState(() {
      self.editingSequentialIndex = null;
      self.savedSequentialQuestionImage = null;
      self.tempSequentialQuestionImage = null;
      self.sequentialItemCount = 3;
    });

    for (final ctrl in itemControllers) {
      ctrl.controller.clear();
      ctrl.imagePath = null;
    }
  }

  void loadSequentialQuestionToForm(int index) {
    final self = this as dynamic;
    final questions =
        self.sequentialQuestions as List<SequentialQuestion>;
    final questionController =
        self.sequentialQuestionController as TextEditingController;
    final scoreController =
        self.sequentialScoreController as TextEditingController;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;

    final q = questions[index];
    questionController.text = q.questionText;
    scoreController.text = q.score.toString();
    self.savedSequentialQuestionImage = q.questionImage;

    _ensureSequentialControllers(q.items.length);

    setState(() {
      self.editingSequentialIndex = index;
      self.sequentialItemCount = q.items.length;
    });

    for (int i = 0; i < q.items.length; i++) {
      final item = q.items[i];
      itemControllers[i].controller.text = item.text;
      itemControllers[i].imagePath = item.image;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加载第 ${index + 1} 题到编辑区'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  void deleteSequentialQuestion() {
    final self = this as dynamic;
    final editingIndex = self.editingSequentialIndex as int?;
    final questions =
        self.sequentialQuestions as List<SequentialQuestion>;

    if (editingIndex == null) return;

    final deletedIndex = editingIndex;
    questions.removeAt(deletedIndex);
    clearSequentialForm();

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

  // ========== Image Picking Methods ==========

  Future<void> pickSequentialQuestionImage() async {
    final pickedFile = await ImageService.pickImage();
    if (pickedFile == null) return;

    setState(() {
      (this as dynamic)._tempSequentialQuestionImage = pickedFile.path;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选择图片: ${pickedFile.name}'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> previewSequentialQuestionImage(
      String? savedPath, String? tempPath) async {
    String? fullPath;

    if (tempPath != null) {
      fullPath = tempPath;
    } else if (savedPath != null) {
      fullPath = ImageService.getImageFullPath(savedPath);
    }

    if (fullPath == null) return;

    final file = File(fullPath);
    final exists = await file.exists();

    if (!exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片文件不存在，可能已被删除'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final success = await ImageService.previewImage(fullPath);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开图片'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> deleteSequentialQuestionImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个题干图片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final self = this as dynamic;
    final selectedBank = self.selectedBank as String?;
    final savedImage = self.savedSequentialQuestionImage as String?;

    if (savedImage != null && selectedBank != null) {
      await ImageService.deleteQuestionBankImage(selectedBank, savedImage);
    }

    setState(() {
      self.savedSequentialQuestionImage = null;
      self.tempSequentialQuestionImage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('题干图片已删除'),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> pickSequentialItemImage(int index) async {
    final self = this as dynamic;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;

    final pickedFile = await ImageService.pickImage();
    if (pickedFile == null) return;

    setState(() {
      itemControllers[index].imagePath = pickedFile.path;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已选择图片: ${pickedFile.name}'),
          backgroundColor: AppTheme.successGreen,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> previewSequentialItemImage(int index) async {
    final self = this as dynamic;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;

    final path = itemControllers[index].imagePath;

    if (path == null) return;

    String fullPath = path;
    if (!p.isAbsolute(path)) {
      fullPath = ImageService.getImageFullPath(path);
    }

    final file = File(fullPath);
    final exists = await file.exists();

    if (!exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('图片文件不存在，可能已被删除'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final success = await ImageService.previewImage(fullPath);
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('无法打开图片'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ========== Sequential Question UI Components ==========

  Widget buildSequentialQuestionForm() {
    final self = this as dynamic;
    final hasBank = (self.selectedBank as String?) != null;
    final questionController =
        self.sequentialQuestionController as TextEditingController;
    final scoreController =
        self.sequentialScoreController as TextEditingController;
    final savedQuestionImage =
        self.savedSequentialQuestionImage as String?;
    final tempQuestionImage =
        self.tempSequentialQuestionImage as String?;
    final editingIndex = self.editingSequentialIndex as int?;
    final itemCount = self.sequentialItemCount as int;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;

    if (itemControllers.isEmpty) {
      initializeSequentialItemControllers();
    }

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
          TextField(
            controller: questionController,
            enabled: hasBank,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: hasBank ? '请输入顺序题题干...' : '请先选择题库',
              labelText: '题干',
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderMain),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_list_numbered,
                        size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      '待排序项目（输入内容即设置正确顺序）',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 160,
                  child: SingleChildScrollView(
                    child: Column(
                      children: List.generate(itemCount, (index) {
                        return buildSequentialItemRow(index, hasBank);
                      }),
                    ),
                  ),
                ),
              ],
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
                '分值：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 60,
                child: TextField(
                  controller: scoreController,
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
              const SizedBox(width: 8),
              buildSequentialImageButton(
                label: '题干图片',
                imageType: 'sequentialQuestion',
                savedPath: savedQuestionImage,
                tempPath: tempQuestionImage,
                enabled: hasBank,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: hasBank ? saveSequentialQuestion : null,
                icon: Icon(
                  editingIndex != null ? Icons.save : Icons.add,
                  size: 18,
                ),
                label: Text(
                  editingIndex != null ? '保存修改' : '添加顺序题',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasBank
                      ? (editingIndex != null
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
                onPressed: hasBank ? addSequentialItem : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  '添加项目（$itemCount）',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasBank ? Colors.blue[400] : Colors.grey[300],
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
                onPressed: hasBank && editingIndex != null
                    ? deleteSequentialQuestion
                    : null,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('删除题目'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasBank && editingIndex != null
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
              if (editingIndex != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: clearSequentialForm,
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

  Widget buildSequentialItemRow(int index, bool enabled) {
    final self = this as dynamic;
    final itemControllers =
        self.sequentialItemControllers as List<SequentialItemControllers>;
    final itemCount = self.sequentialItemCount as int;
    final ctrl = itemControllers[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 520,
          child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl.controller,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: '第 ${index + 1} 项',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderMain),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                      const BorderSide(color: AppTheme.primaryBlue, width: 2),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: enabled ? () => pickSequentialItemImage(index) : null,
            icon: Icon(
              Icons.add_photo_alternate,
              color: enabled ? AppTheme.primaryBlue : Colors.grey,
              size: 18,
            ),
            tooltip: '插入图片',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            onPressed: enabled && ctrl.imagePath != null
                ? () => previewSequentialItemImage(index)
                : null,
            icon: Icon(
              Icons.visibility,
              color: ctrl.imagePath != null
                  ? AppTheme.successGreen
                  : Colors.grey,
              size: 18,
            ),
            tooltip: '预览图片',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: enabled && itemCount > 2
                ? () => removeSequentialItem(index)
                : null,
            icon: Icon(
              Icons.close,
              color:
                  enabled && itemCount > 2 ? Colors.red : Colors.grey,
              size: 18,
            ),
            tooltip: '删除此项',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
        ),
      ),
    );
  }

  Widget buildSequentialImageButton({
    required String label,
    required String imageType,
    required String? savedPath,
    required String? tempPath,
    required bool enabled,
  }) {
    final hasImage = savedPath != null || tempPath != null;

    if (!enabled) {
      return OutlinedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.image, size: 16, color: Colors.grey),
        label: Text(label, style: const TextStyle(color: Colors.grey)),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.grey,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    if (hasImage) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () => previewSequentialQuestionImage(savedPath, tempPath),
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('预览'),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => deleteSequentialQuestionImage(),
            icon: const Icon(Icons.close, size: 16),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(8),
              minimumSize: const Size(32, 32),
            ),
            tooltip: '删除图片',
          ),
        ],
      );
    }

    return OutlinedButton.icon(
      onPressed: () => pickSequentialQuestionImage(),
      icon: Icon(Icons.add_photo_alternate,
          size: 16, color: AppTheme.primaryBlue),
      label: Text(label, style: TextStyle(color: AppTheme.primaryBlue)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget buildSequentialQuestionTable() {
    final self = this as dynamic;
    final questions =
        self.sequentialQuestions as List<SequentialQuestion>;

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
                '顺序题列表',
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
                  '共 ${questions.length} 题',
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
          questions.isEmpty
              ? buildEmptySequentialTable()
              : buildSequentialTable(),
        ],
      ),
    );
  }

  Widget buildEmptySequentialTable() {
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
              Icons.assignment_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '暂无顺序题，点击上方按钮添加',
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

  Widget buildSequentialTable() {
    final self = this as dynamic;
    final questions =
        self.sequentialQuestions as List<SequentialQuestion>;
    final editingIndex = self.editingSequentialIndex as int?;

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
              label: Text('题干', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('题干图片', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('待排序项', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('项图', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final isEditing = editingIndex == index;

          final itemTexts = q.items.map((e) => e.text).take(4).join('、');

          return DataRow(
            color: MaterialStateProperty.all(
              isEditing ? AppTheme.primaryBlue.withAlpha(26) : null,
            ),
            onSelectChanged: (_) => loadSequentialQuestionToForm(index),
            cells: [
              DataCell(Text('顺序题')),
              DataCell(Text('${index + 1}')),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(
                    q.questionText.length > 20
                        ? '${q.questionText.substring(0, 20)}...'
                        : q.questionText,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Icon(
                  q.questionImage != null
                      ? Icons.image
                      : Icons.image_not_supported,
                  color: q.questionImage != null
                      ? AppTheme.successGreen
                      : Colors.grey,
                  size: 20,
                ),
              ),
              DataCell(
                SizedBox(
                  width: 150,
                  child: Text(
                    itemTexts.length > 20
                        ? '${itemTexts.substring(0, 20)}...'
                        : itemTexts,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Icon(
                  q.items.any((e) => e.image != null)
                      ? Icons.image
                      : Icons.image_not_supported,
                  color: q.items.any((e) => e.image != null)
                      ? AppTheme.successGreen
                      : Colors.grey,
                  size: 20,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}