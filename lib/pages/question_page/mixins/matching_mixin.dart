import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/image_service.dart';
import '../../../models/question_models.dart';
import '../controllers.dart';

/// Mixin providing all matching question logic for the QuestionsPage
mixin MatchingQuestionMixin on State {
  // ========== Matching Question State ==========
  // These fields must be declared in the host state class:
  //   List<MatchingQuestion> _matchingQuestions;
  //   TextEditingController _matchingQuestionController;
  //   TextEditingController _matchingScoreController;
  //   String? _savedMatchingQuestionImage;
  //   String? _tempMatchingQuestionImage;
  //   int? _editingMatchingIndex;
  //   List<MatchingItemControllers> _matchingItemControllers;
  //   int _matchingItemCount;
  //   String? _selectedBank;

  // ========== Matching Question Methods ==========

  void saveQuestionsToFile() {
    // This will be implemented in the host state class
  }

  void initializeMatchingItemControllers() {
    final self = this as dynamic;
    final controllers = self.matchingItemControllers as List<MatchingItemControllers>;
    controllers.clear();
    // 初始化时仅创建初始需求的数量，后续动态扩展
    final initialCount = (self.matchingItemCount as int?) ?? 2;
    for (int i = 0; i < initialCount; i++) {
      controllers.add(MatchingItemControllers());
    }
  }

  /// 确保有足够的匹配项控制器（动态扩展）
  void _ensureMatchingControllers(int requiredCount) {
    final self = this as dynamic;
    final controllers = self.matchingItemControllers as List<MatchingItemControllers>;
    while (controllers.length < requiredCount) {
      controllers.add(MatchingItemControllers());
    }
  }

  void addMatchingItem() {
    final self = this as dynamic;
    _ensureMatchingControllers((self.matchingItemCount as int) + 1);
    setState(() {
      self.matchingItemCount++;
    });
  }

  Future<void> saveMatchingQuestion() async {
    final self = this as dynamic;
    final questionController =
        self.matchingQuestionController as TextEditingController;
    final scoreController =
        self.matchingScoreController as TextEditingController;
    final selectedBank = self.selectedBank as String?;
    final editingIndex = self.editingMatchingIndex as int?;
    final questions =
        self.matchingQuestions as List<MatchingQuestion>;
    final itemControllers =
        self.matchingItemControllers as List<MatchingItemControllers>;
    final itemCount = self.matchingItemCount as int;

    if (questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入题干'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? savedQuestionImage = self.savedMatchingQuestionImage as String?;
    final tempQuestionImage = self.tempMatchingQuestionImage as String?;
    if (tempQuestionImage != null && selectedBank != null) {
      final oldSaved = self.savedMatchingQuestionImage as String?;
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
    // 每个 item 均分总分，确保累加 = questionScore
    final itemScore = itemCount > 0
        ? (questionScore ~/ itemCount)
        : 5;
    final scoreRemainder = itemCount > 0 ? questionScore % itemCount : 0;

    final items = <MatchingItem>[];
    for (int i = 0; i < itemCount; i++) {
      final ctrl = itemControllers[i];
      if (ctrl.leftController.text.isNotEmpty &&
          ctrl.rightController.text.isNotEmpty) {
        String? savedLeftImage = ctrl.leftImagePath;
        String? savedRightImage = ctrl.rightImagePath;

        if (ctrl.leftImagePath != null && selectedBank != null) {
          final saved = await ImageService.copyFromCacheToQuestionBank(
            cachePath: ctrl.leftImagePath!,
            bankName: selectedBank,
            position: '左侧${i + 1}',
            questionTitle: questionController.text,
          );
          if (saved != null) savedLeftImage = saved;
        }

        if (ctrl.rightImagePath != null && selectedBank != null) {
          final saved = await ImageService.copyFromCacheToQuestionBank(
            cachePath: ctrl.rightImagePath!,
            bankName: selectedBank,
            position: '右侧${i + 1}',
            questionTitle: questionController.text,
          );
          if (saved != null) savedRightImage = saved;
        }

        items.add(MatchingItem(
          leftText: ctrl.leftController.text,
          rightText: ctrl.rightController.text,
          leftImage: savedLeftImage,
          rightImage: savedRightImage,
          score: itemScore + (i < scoreRemainder ? 1 : 0),
        ));
      }
    }

    if (items.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('请至少填写一对匹配项'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final matchingQuestion = MatchingQuestion(
      questionText: questionController.text,
      score: int.tryParse(scoreController.text) ?? 5,
      items: items,
      questionImage: savedQuestionImage,
    );

    setState(() {
      if (editingIndex != null) {
        questions[editingIndex] = matchingQuestion;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连线题 ${editingIndex + 1} 已更新'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      } else {
        questions.add(matchingQuestion);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('连线题已添加，当前共 ${questions.length} 题'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    });

    if (selectedBank != null) {
      self.saveQuestionsToFile();
    }

    await ImageService.clearCache();

    clearMatchingForm();
  }

  void clearMatchingForm() {
    final self = this as dynamic;
    final questionController =
        self.matchingQuestionController as TextEditingController;
    final scoreController =
        self.matchingScoreController as TextEditingController;
    final itemControllers =
        self.matchingItemControllers as List<MatchingItemControllers>;

    questionController.clear();
    scoreController.text = '5';
    setState(() {
      self.editingMatchingIndex = null;
      self.savedMatchingQuestionImage = null;
      self.tempMatchingQuestionImage = null;
      self.matchingItemCount = 2;
    });

    for (final ctrl in itemControllers) {
      ctrl.leftController.clear();
      ctrl.rightController.clear();
      ctrl.leftImagePath = null;
      ctrl.rightImagePath = null;
    }
  }

  void loadMatchingQuestionToForm(int index) {
    final self = this as dynamic;
    final questions =
        self.matchingQuestions as List<MatchingQuestion>;
    final questionController =
        self.matchingQuestionController as TextEditingController;
    final scoreController =
        self.matchingScoreController as TextEditingController;
    final itemControllers =
        self.matchingItemControllers as List<MatchingItemControllers>;

    final q = questions[index];
    questionController.text = q.questionText;
    scoreController.text =
        q.items.isNotEmpty ? q.items[0].score.toString() : '5';
    self.savedMatchingQuestionImage = q.questionImage;

    _ensureMatchingControllers(q.items.length);

    setState(() {
      self.editingMatchingIndex = index;
      self.matchingItemCount = q.items.length;
    });

    _ensureMatchingControllers(q.items.length);
    for (int i = 0; i < q.items.length; i++) {
      final item = q.items[i];
      itemControllers[i].leftController.text = item.leftText;
      itemControllers[i].rightController.text = item.rightText;
      itemControllers[i].leftImagePath = item.leftImage;
      itemControllers[i].rightImagePath = item.rightImage;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加载第 ${index + 1} 题到编辑区'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  void deleteMatchingQuestion() {
    final self = this as dynamic;
    final editingIndex = self.editingMatchingIndex as int?;
    final questions =
        self.matchingQuestions as List<MatchingQuestion>;

    if (editingIndex == null) return;

    final deletedIndex = editingIndex;
    questions.removeAt(deletedIndex);
    clearMatchingForm();

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

  Future<void> pickMatchingQuestionImage() async {
    final pickedFile = await ImageService.pickImage();
    if (pickedFile == null) return;

    setState(() {
      (this as dynamic)._tempMatchingQuestionImage = pickedFile.path;
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

  Future<void> previewMatchingQuestionImage(
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

  Future<void> deleteMatchingQuestionImage() async {
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
    final savedImage = self.savedMatchingQuestionImage as String?;

    if (savedImage != null && selectedBank != null) {
      await ImageService.deleteQuestionBankImage(selectedBank, savedImage);
    }

    setState(() {
      self.savedMatchingQuestionImage = null;
      self.tempMatchingQuestionImage = null;
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

  Future<void> pickMatchingImage(int index, String side) async {
    final self = this as dynamic;
    final itemControllers =
        self.matchingItemControllers as List<MatchingItemControllers>;

    final pickedFile = await ImageService.pickImage();
    if (pickedFile == null) return;

    setState(() {
      if (side == 'left') {
        itemControllers[index].leftImagePath = pickedFile.path;
      } else {
        itemControllers[index].rightImagePath = pickedFile.path;
      }
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

  Future<void> previewMatchingImage(int index, String side) async {
    final self = this as dynamic;
    final itemControllers =
        self.matchingItemControllers as List<MatchingItemControllers>;

    String? path = side == 'left'
        ? itemControllers[index].leftImagePath
        : itemControllers[index].rightImagePath;

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

  // ========== Matching Question UI Components ==========

  Widget buildMatchingQuestionForm() {
    final self = this as dynamic;
    final hasBank = (self.selectedBank as String?) != null;
    final questionController =
        self.matchingQuestionController as TextEditingController;
    final scoreController =
        self.matchingScoreController as TextEditingController;
    final savedQuestionImage =
        self.savedMatchingQuestionImage as String?;
    final tempQuestionImage =
        self.tempMatchingQuestionImage as String?;
    final editingIndex = self.editingMatchingIndex as int?;
    final itemCount = self.matchingItemCount as int;

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
              hintText: hasBank ? '请输入连线题题干...' : '请先选择题库',
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
          SizedBox(
            height: 200,
            child: SingleChildScrollView(
              child: Column(
                children: List.generate(itemCount, (index) {
                  return buildMatchingItemRow(index, hasBank);
                }),
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
              buildMatchingImageButton(
                label: '题干图片',
                imageType: 'matchingQuestion',
                savedPath: savedQuestionImage,
                tempPath: tempQuestionImage,
                enabled: hasBank,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: hasBank ? saveMatchingQuestion : null,
                icon: Icon(
                  editingIndex != null ? Icons.save : Icons.add,
                  size: 18,
                ),
                label: Text(
                  editingIndex != null ? '保存修改' : '添加连线题',
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
                onPressed: hasBank ? addMatchingItem : null,
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
                    ? deleteMatchingQuestion
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
                  onPressed: clearMatchingForm,
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

  Widget buildMatchingItemRow(int index, bool enabled) {
    final self = this as dynamic;
    final itemControllers =
        self.matchingItemControllers as List<MatchingItemControllers>;
    final itemCount = self.matchingItemCount as int;
    final ctrl = itemControllers[index];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 760,
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
            flex: 2,
            child: TextField(
              controller: ctrl.leftController,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: '左侧${index + 1}',
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
            onPressed: enabled ? () => pickMatchingImage(index, 'left') : null,
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
            onPressed: enabled && ctrl.leftImagePath != null
                ? () => previewMatchingImage(index, 'left')
                : null,
            icon: Icon(
              Icons.visibility,
              color: ctrl.leftImagePath != null
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
                ? () {
                    setState(() {
                      // 按 index 移除指定项，不再固定删除最后一项
                      for (int j = index; j < itemCount - 1; j++) {
                        itemControllers[j].leftController.text =
                            itemControllers[j + 1].leftController.text;
                        itemControllers[j].rightController.text =
                            itemControllers[j + 1].rightController.text;
                        itemControllers[j].leftImagePath =
                            itemControllers[j + 1].leftImagePath;
                        itemControllers[j].rightImagePath =
                            itemControllers[j + 1].rightImagePath;
                      }
                      // 清除最后一项
                      final lastIdx = itemCount - 1;
                      itemControllers[lastIdx].leftController.clear();
                      itemControllers[lastIdx].rightController.clear();
                      itemControllers[lastIdx].leftImagePath = null;
                      itemControllers[lastIdx].rightImagePath = null;
                      self.matchingItemCount = itemCount - 1;
                    });
                  }
                : null,
            icon: Icon(
              Icons.close,
              color:
                  enabled && itemCount > 2 ? Colors.red : Colors.grey,
              size: 18,
            ),
            tooltip: '删除此项目',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed:
                enabled ? () => pickMatchingImage(index, 'right') : null,
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
            onPressed: enabled && ctrl.rightImagePath != null
                ? () => previewMatchingImage(index, 'right')
                : null,
            icon: Icon(
              Icons.visibility,
              color: ctrl.rightImagePath != null
                  ? AppTheme.successGreen
                  : Colors.grey,
              size: 18,
            ),
            tooltip: '预览图片',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: ctrl.rightController,
              enabled: enabled,
              decoration: InputDecoration(
                hintText: '右侧${index + 1}',
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
        ],
      ),
        ),
      ),
    );
  }

  Widget buildMatchingImageButton({
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
            onPressed: () => previewMatchingQuestionImage(savedPath, tempPath),
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
            onPressed: () => deleteMatchingQuestionImage(),
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
      onPressed: () => pickMatchingQuestionImage(),
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

  Widget buildMatchingQuestionTable() {
    final self = this as dynamic;
    final questions =
        self.matchingQuestions as List<MatchingQuestion>;

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
                '连线题列表',
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
              ? buildEmptyMatchingTable()
              : buildMatchingTable(),
        ],
      ),
    );
  }

  Widget buildEmptyMatchingTable() {
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
              '暂无连线题，点击上方按钮添加',
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

  Widget buildMatchingTable() {
    final self = this as dynamic;
    final questions =
        self.matchingQuestions as List<MatchingQuestion>;
    final editingIndex = self.editingMatchingIndex as int?;

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
                  Text('左侧项目', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('右侧项目', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('题干图片', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final isEditing = editingIndex == index;

          final leftItems = q.items.map((e) => e.leftText).take(3).join('、');
          final rightItems = q.items.map((e) => e.rightText).take(3).join('、');

          return DataRow(
            color: MaterialStateProperty.all(
              isEditing ? AppTheme.primaryBlue.withAlpha(26) : null,
            ),
            onSelectChanged: (_) => loadMatchingQuestionToForm(index),
            cells: [
              DataCell(Text('连线题')),
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
                SizedBox(
                  width: 100,
                  child: Text(
                    leftItems.length > 15
                        ? '${leftItems.substring(0, 15)}...'
                        : leftItems,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 100,
                  child: Text(
                    rightItems.length > 15
                        ? '${rightItems.substring(0, 15)}...'
                        : rightItems,
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
            ],
          );
        }).toList(),
      ),
    );
  }
}
