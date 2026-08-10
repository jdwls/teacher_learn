import 'dart:io';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/image_service.dart';
import '../../../models/question_models.dart';

/// Mixin providing all choice question logic for the QuestionsPage
mixin ChoiceQuestionMixin on State {
  // ========== Choice Question State ==========
  // These fields must be declared in the host state class:
  //   List<Question> _questions;
  //   TextEditingController _questionController;
  //   TextEditingController _scoreController;
  //   TextEditingController _optionAController;
  //   TextEditingController _optionBController;
  //   TextEditingController _optionCController;
  //   TextEditingController _optionDController;
  //   String _selectedAnswer;
  //   int? _editingIndex;
  //   String? _tempQuestionImage;
  //   String? _tempOptionAImage;
  //   String? _tempOptionBImage;
  //   String? _tempOptionCImage;
  //   String? _tempOptionDImage;
  //   String? _savedQuestionImage;
  //   String? _savedOptionAImage;
  //   String? _savedOptionBImage;
  //   String? _savedOptionCImage;
  //   String? _savedOptionDImage;
  //   String? _selectedBank;

  // ========== Choice Question Methods ==========

  void clearForm() {
    // stub — host class provides the real implementation
  }

  void saveQuestionsToFile() {
    // This will be implemented in the host state class
  }

  Future<void> pickImage(String imageType) async {
    final pickedFile = await ImageService.pickImage();
    if (pickedFile == null) return;

    setState(() {
      switch (imageType) {
        case 'question':
          (this as dynamic)._tempQuestionImage = pickedFile.path;
          break;
        case 'A':
          (this as dynamic)._tempOptionAImage = pickedFile.path;
          break;
        case 'B':
          (this as dynamic)._tempOptionBImage = pickedFile.path;
          break;
        case 'C':
          (this as dynamic)._tempOptionCImage = pickedFile.path;
          break;
        case 'D':
          (this as dynamic)._tempOptionDImage = pickedFile.path;
          break;
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

  Future<void> previewImage(String? savedPath, String? tempPath) async {
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

  Future<void> deleteImage(String imageType) async {
    final label = imageType == 'question' ? '题干图片' : '选项${imageType}图片';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除这个$label吗？'),
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

    String? oldSavedPath;
    switch (imageType) {
      case 'question':
        oldSavedPath = self.savedQuestionImage as String?;
        break;
      case 'A':
        oldSavedPath = self.savedOptionAImage as String?;
        break;
      case 'B':
        oldSavedPath = self.savedOptionBImage as String?;
        break;
      case 'C':
        oldSavedPath = self.savedOptionCImage as String?;
        break;
      case 'D':
        oldSavedPath = self.savedOptionDImage as String?;
        break;
    }

    if (oldSavedPath != null && selectedBank != null) {
      await ImageService.deleteQuestionBankImage(selectedBank, oldSavedPath);
    }

    setState(() {
      switch (imageType) {
        case 'question':
          self.savedQuestionImage = null;
          self.tempQuestionImage = null;
          break;
        case 'A':
          self.savedOptionAImage = null;
          self.tempOptionAImage = null;
          break;
        case 'B':
          self.savedOptionBImage = null;
          self.tempOptionBImage = null;
          break;
        case 'C':
          self.savedOptionCImage = null;
          self.tempOptionCImage = null;
          break;
        case 'D':
          self.savedOptionDImage = null;
          self.tempOptionDImage = null;
          break;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$label 已删除'),
          backgroundColor: Colors.grey,
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> saveQuestion() async {
    final self = this as dynamic;
    final questionController = self.questionController as TextEditingController;
    final optionAController = self.optionAController as TextEditingController;
    final optionBController = self.optionBController as TextEditingController;
    final optionCController = self.optionCController as TextEditingController;
    final optionDController = self.optionDController as TextEditingController;
    final selectedAnswer = self.selectedAnswer as String;
    final selectedBank = self.selectedBank as String?;
    final scoreController = self.scoreController as TextEditingController;
    final editingIndex = self.editingIndex as int?;
    final questions = self.questions as List<Question>;

    if (questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入题干'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (optionAController.text.isEmpty ||
        optionBController.text.isEmpty ||
        optionCController.text.isEmpty ||
        optionDController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请填写所有选项'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedAnswer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请选择正确答案'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? questionImagePath = self.savedQuestionImage as String?;
    String? optionAImagePath = self.savedOptionAImage as String?;
    String? optionBImagePath = self.savedOptionBImage as String?;
    String? optionCImagePath = self.savedOptionCImage as String?;
    String? optionDImagePath = self.savedOptionDImage as String?;

    if (selectedBank != null) {
      final tempQuestionImage = self.tempQuestionImage as String?;
      final tempOptionAImage = self.tempOptionAImage as String?;
      final tempOptionBImage = self.tempOptionBImage as String?;
      final tempOptionCImage = self.tempOptionCImage as String?;
      final tempOptionDImage = self.tempOptionDImage as String?;

      if (tempQuestionImage != null) {
        if (self.savedQuestionImage != null) {
          await ImageService.deleteQuestionBankImage(
              selectedBank, self.savedQuestionImage as String);
        }
        final saved = await ImageService.copyFromCacheToQuestionBank(
          cachePath: tempQuestionImage,
          bankName: selectedBank,
          position: '题干',
          questionTitle: questionController.text,
        );
        if (saved != null) questionImagePath = saved;
      }

      if (tempOptionAImage != null) {
        if (self.savedOptionAImage != null) {
          await ImageService.deleteQuestionBankImage(
              selectedBank, self.savedOptionAImage as String);
        }
        final saved = await ImageService.copyFromCacheToQuestionBank(
          cachePath: tempOptionAImage,
          bankName: selectedBank,
          position: 'A',
          questionTitle: questionController.text,
        );
        if (saved != null) optionAImagePath = saved;
      }

      if (tempOptionBImage != null) {
        if (self.savedOptionBImage != null) {
          await ImageService.deleteQuestionBankImage(
              selectedBank, self.savedOptionBImage as String);
        }
        final saved = await ImageService.copyFromCacheToQuestionBank(
          cachePath: tempOptionBImage,
          bankName: selectedBank,
          position: 'B',
          questionTitle: questionController.text,
        );
        if (saved != null) optionBImagePath = saved;
      }

      if (tempOptionCImage != null) {
        if (self.savedOptionCImage != null) {
          await ImageService.deleteQuestionBankImage(
              selectedBank, self.savedOptionCImage as String);
        }
        final saved = await ImageService.copyFromCacheToQuestionBank(
          cachePath: tempOptionCImage,
          bankName: selectedBank,
          position: 'C',
          questionTitle: questionController.text,
        );
        if (saved != null) optionCImagePath = saved;
      }

      if (tempOptionDImage != null) {
        if (self.savedOptionDImage != null) {
          await ImageService.deleteQuestionBankImage(
              selectedBank, self.savedOptionDImage as String);
        }
        final saved = await ImageService.copyFromCacheToQuestionBank(
          cachePath: tempOptionDImage,
          bankName: selectedBank,
          position: 'D',
          questionTitle: questionController.text,
        );
        if (saved != null) optionDImagePath = saved;
      }

      await ImageService.clearCache();
    }

    if (editingIndex != null) {
      setState(() {
        questions[editingIndex] = Question(
          questionText: questionController.text,
          score: int.tryParse(scoreController.text) ?? 5,
          optionA: optionAController.text,
          optionB: optionBController.text,
          optionC: optionCController.text,
          optionD: optionDController.text,
          answer: selectedAnswer,
          questionImage: questionImagePath,
          optionAImage: optionAImagePath,
          optionBImage: optionBImagePath,
          optionCImage: optionCImagePath,
          optionDImage: optionDImagePath,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('题目 ${editingIndex + 1} 已更新'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    } else {
      final question = Question(
        questionText: questionController.text,
        score: int.tryParse(scoreController.text) ?? 5,
        optionA: optionAController.text,
        optionB: optionBController.text,
        optionC: optionCController.text,
        optionD: optionDController.text,
        answer: selectedAnswer,
        questionImage: questionImagePath,
        optionAImage: optionAImagePath,
        optionBImage: optionBImagePath,
        optionCImage: optionCImagePath,
        optionDImage: optionDImagePath,
      );
      setState(() {
        questions.add(question);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('题目已添加，当前共 ${questions.length} 题'),
            backgroundColor: AppTheme.successGreen,
          ),
        );
      }
    }

    if (selectedBank != null) {
      self.saveQuestionsToFile();
    }

    self.clearForm();
  }

  void loadQuestionToForm(int index) {
    final self = this as dynamic;
    final questions = self.questions as List<Question>;
    final q = questions[index];
    final questionController = self.questionController as TextEditingController;
    final scoreController = self.scoreController as TextEditingController;
    final optionAController = self.optionAController as TextEditingController;
    final optionBController = self.optionBController as TextEditingController;
    final optionCController = self.optionCController as TextEditingController;
    final optionDController = self.optionDController as TextEditingController;

    questionController.text = q.questionText;
    scoreController.text = q.score.toString();
    optionAController.text = q.optionA;
    optionBController.text = q.optionB;
    optionCController.text = q.optionC;
    optionDController.text = q.optionD;
    setState(() {
      self.selectedAnswer = q.answer;
      self.editingIndex = index;
      self.savedQuestionImage = q.questionImage;
      self.savedOptionAImage = q.optionAImage;
      self.savedOptionBImage = q.optionBImage;
      self.savedOptionCImage = q.optionCImage;
      self.savedOptionDImage = q.optionDImage;
      self.tempQuestionImage = null;
      self.tempOptionAImage = null;
      self.tempOptionBImage = null;
      self.tempOptionCImage = null;
      self.tempOptionDImage = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加载第 ${index + 1} 题到编辑区'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }

  // ========== Choice Question UI Components ==========

  Widget buildOptionInput(
      String label, TextEditingController controller, bool enabled) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: '$label 选项',
        hintText: enabled ? '请输入${label}选项内容...' : '请先选择题库',
        filled: true,
        fillColor: enabled ? const Color(0xFFF8FAFC) : Colors.grey[200],
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
          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
      ),
    );
  }

  Widget buildAnswerChip(String label, bool enabled) {
    final self = this as dynamic;
    final selectedAnswer = self.selectedAnswer as String;
    final isSelected = selectedAnswer == label;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: isSelected
              ? Colors.white
              : (enabled ? AppTheme.textPrimary : Colors.grey),
        ),
      ),
      selected: isSelected,
      selectedColor: AppTheme.successGreen,
      checkmarkColor: Colors.white,
      onSelected: enabled
          ? (selected) {
              setState(() {
                self.selectedAnswer = selected ? label : '';
              });
            }
          : null,
      backgroundColor: enabled ? const Color(0xFFF1F5F9) : Colors.grey[200],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget buildImageButton({
    required String label,
    required String imageType,
    required String? savedPath,
    required String? tempPath,
    required bool enabled,
    required Color color,
  }) {
    final hasImage = savedPath != null || tempPath != null;

    if (!enabled) {
      return SizedBox(
        width: 144,
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.image, size: 14, color: Colors.grey),
          label: Text(label,
              style: const TextStyle(color: Colors.grey, fontSize: 12)),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      );
    }

    if (hasImage) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => previewImage(savedPath, tempPath),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.visibility, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text('预览',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: () => deleteImage(imageType),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: 144,
      child: OutlinedButton.icon(
        onPressed: () => pickImage(imageType),
        icon: Icon(Icons.add_photo_alternate, size: 14, color: color),
        label: Text(label, style: TextStyle(color: color, fontSize: 11)),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }

  Widget buildQuestionForm() {
    final self = this as dynamic;
    final hasBank = (self.selectedBank as String?) != null;
    final questionController = self.questionController as TextEditingController;
    final optionAController = self.optionAController as TextEditingController;
    final optionBController = self.optionBController as TextEditingController;
    final optionCController = self.optionCController as TextEditingController;
    final optionDController = self.optionDController as TextEditingController;
    final editingIndex = self.editingIndex as int?;
    final savedQuestionImage = self.savedQuestionImage as String?;
    final tempQuestionImage = self.tempQuestionImage as String?;
    final savedOptionAImage = self.savedOptionAImage as String?;
    final tempOptionAImage = self.tempOptionAImage as String?;
    final savedOptionBImage = self.savedOptionBImage as String?;
    final tempOptionBImage = self.tempOptionBImage as String?;
    final savedOptionCImage = self.savedOptionCImage as String?;
    final tempOptionCImage = self.tempOptionCImage as String?;
    final savedOptionDImage = self.savedOptionDImage as String?;
    final tempOptionDImage = self.tempOptionDImage as String?;
    final scoreController = self.scoreController as TextEditingController;
    final questions = self.questions as List<Question>;

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
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hasBank ? '请输入题目内容...' : '请先选择题库',
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
          Row(
            children: [
              Expanded(
                  child: buildOptionInput('A', optionAController, hasBank)),
              const SizedBox(width: 12),
              Expanded(
                  child: buildOptionInput('B', optionBController, hasBank)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: buildOptionInput('C', optionCController, hasBank)),
              const SizedBox(width: 12),
              Expanded(
                  child: buildOptionInput('D', optionDController, hasBank)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Flexible(
                  child: buildImageButton(
                label: '题干图片',
                imageType: 'question',
                savedPath: savedQuestionImage,
                tempPath: tempQuestionImage,
                enabled: hasBank,
                color: AppTheme.primaryBlue,
              )),
              const SizedBox(width: 8),
              Flexible(
                  child: buildImageButton(
                label: '选项A图片',
                imageType: 'A',
                savedPath: savedOptionAImage,
                tempPath: tempOptionAImage,
                enabled: hasBank,
                color: Colors.grey[600]!,
              )),
              const SizedBox(width: 8),
              Flexible(
                  child: buildImageButton(
                label: '选项B图片',
                imageType: 'B',
                savedPath: savedOptionBImage,
                tempPath: tempOptionBImage,
                enabled: hasBank,
                color: Colors.grey[600]!,
              )),
              const SizedBox(width: 8),
              Flexible(
                  child: buildImageButton(
                label: '选项C图片',
                imageType: 'C',
                savedPath: savedOptionCImage,
                tempPath: tempOptionCImage,
                enabled: hasBank,
                color: Colors.grey[600]!,
              )),
              const SizedBox(width: 8),
              Flexible(
                  child: buildImageButton(
                label: '选项D图片',
                imageType: 'D',
                savedPath: savedOptionDImage,
                tempPath: tempOptionDImage,
                enabled: hasBank,
                color: Colors.grey[600]!,
              )),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '答案：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: hasBank ? AppTheme.textPrimary : Colors.grey,
                ),
              ),
              buildAnswerChip('A', hasBank),
              const SizedBox(width: 8),
              buildAnswerChip('B', hasBank),
              const SizedBox(width: 8),
              buildAnswerChip('C', hasBank),
              const SizedBox(width: 8),
              buildAnswerChip('D', hasBank),
              const SizedBox(width: 16),
              Text(
                '分值：',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: hasBank ? AppTheme.textPrimary : Colors.grey,
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
                    fillColor:
                        hasBank ? const Color(0xFFF8FAFC) : Colors.grey[200],
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
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: hasBank ? saveQuestion : null,
                icon: Icon(
                  editingIndex != null ? Icons.save : Icons.add,
                  size: 18,
                ),
                label: Text(
                  editingIndex != null ? '保存修改' : '添加选择题',
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
                onPressed: hasBank && editingIndex != null
                    ? () async {
                        final deletedIndex = editingIndex; // editingIndex is non-null here
                        questions.removeAt(deletedIndex);

                        self.saveQuestionsToFile();

                        self.clearForm();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('已删除第 ${deletedIndex + 1} 题'),
                            backgroundColor: Colors.grey,
                          ),
                        );
                      }
                    : null,
                icon: Icon(Icons.delete_outline, size: 18),
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
                  onPressed: () => self.clearForm(),
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

  Widget buildQuestionTable() {
    final self = this as dynamic;
    final questions = self.questions as List<Question>;

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
                '题目列表',
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
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          questions.isEmpty ? buildEmptyTable() : buildTable(),
        ],
      ),
    );
  }

  Widget buildEmptyTable() {
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
              '暂无题目，点击上方按钮添加',
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

  Widget buildTable() {
    final self = this as dynamic;
    final questions = self.questions as List<Question>;
    final editingIndex = self.editingIndex as int?;

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
                  Text('选项A', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('选项B', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('选项C', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('选项D', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('答案', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('分值', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: questions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final isEditing = editingIndex == index;
          return DataRow(
            color: MaterialStateProperty.all(
              isEditing ? AppTheme.primaryBlue.withAlpha(26) : null,
            ),
            onSelectChanged: (_) => loadQuestionToForm(index),
            cells: [
              DataCell(Text('选择题')),
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
                    q.optionA.length > 10
                        ? '${q.optionA.substring(0, 10)}...'
                        : q.optionA,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 100,
                  child: Text(
                    q.optionB.length > 10
                        ? '${q.optionB.substring(0, 10)}...'
                        : q.optionB,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 100,
                  child: Text(
                    q.optionC.length > 10
                        ? '${q.optionC.substring(0, 10)}...'
                        : q.optionC,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                SizedBox(
                  width: 100,
                  child: Text(
                    q.optionD.length > 10
                        ? '${q.optionD.substring(0, 10)}...'
                        : q.optionD,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withAlpha(26),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    q.answer,
                    style: TextStyle(
                      color: AppTheme.successGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              DataCell(Text('${q.score}分')),
            ],
          );
        }).toList(),
      ),
    );
  }
}