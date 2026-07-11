import 'dart:io';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/file_picker_service.dart';
import '../../../models/question_models.dart';
import '../controllers.dart';

/// Mixin providing all operation question logic for the QuestionsPage
mixin OperationQuestionMixin on State {
  // ========== Operation Question State ==========
  // These fields must be declared in the host state class:
  //   List<OperationQuestion> _operationQuestions;
  //   TextEditingController _operationQuestionController;
  //   TextEditingController _operationScoreController;
  //   int? _editingOperationIndex;
  //   List<OperationFileController> _operationFileControllers;
  //   List<OperationAnswerController> _operationAnswerControllers;
  //   int _operationFileCount;
  //   int _operationAnswerCount;
  //   String? _selectedOperationFileName;
  //   String? _selectedBank;

  // ========== Stub Methods ==========

  void saveQuestionsToFile() {
    // This will be implemented in the host state class
  }

  // ========== File Helper Methods ==========

  /// 截断文件名显示（超过7个字显示省略号）
  String truncateFileName(String fileName) {
    if (fileName.length > 7) {
      return '${fileName.substring(0, 7)}...';
    }
    return fileName;
  }

  /// 生成挖空后的初始文件内容
  String generateHollowedContent(
      String originalContent, List<int> linesToHollow) {
    final lines = originalContent.split('\n');
    final sortedLines = linesToHollow.toList()..sort((a, b) => b.compareTo(a));
    for (final lineNum in sortedLines) {
      final index = lineNum - 1;
      if (index >= 0 && index < lines.length) {
        lines[index] = '';
      }
    }
    return lines.join('\n');
  }

  /// 获取可用的初始文件名列表
  List<String> getAvailableFileNames() {
    final self = this as dynamic;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    final fileCount = self.operationFileCount as int;

    final fileNames = <String>[];
    for (int i = 0; i < fileCount; i++) {
      if (i < controllers.length) {
        final fileName = controllers[i].fileNameController.text;
        if (fileName.isNotEmpty) {
          fileNames.add(fileName);
        }
      }
    }
    return fileNames;
  }

  // ========== File Picking Methods ==========

  Future<void> pickOperationFile(int index) async {
    try {
      final result = await FilePickerService.pickSingleFile();
      if (result == null) return;

      final self = this as dynamic;
      final controllers =
          self.operationFileControllers as List<OperationFileController>;

      while (controllers.length <= index) {
        controllers.add(OperationFileController());
      }
      final ctrl = controllers[index];

      setState(() {
        ctrl.sourceFilePath = result.filePath;
        ctrl.fileNameController.text = result.fileName;
        ctrl.contentController.text = result.content;
        self.selectedOperationFileName = result.fileName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选择文件: ${result.fileName}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void clearOperationFile(int index) {
    final self = this as dynamic;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    if (index < controllers.length) {
      final ctrl = controllers[index];
      setState(() {
        ctrl.sourceFilePath = null;
        ctrl.fileNameController.clear();
        ctrl.contentController.clear();
      });
    }
  }

  Future<void> pickBottomOperationFile() async {
    try {
      final result = await FilePickerService.pickAndCacheFile();
      if (result == null) return;

      final self = this as dynamic;
      final controllers =
          self.operationFileControllers as List<OperationFileController>;

      while (controllers.length < 1) {
        controllers.add(OperationFileController());
      }

      controllers[0].sourceFilePath = result.filePath;
      controllers[0].cachePath = result.cachePath;
      controllers[0].fileNameController.text = result.fileName;
      controllers[0].contentController.text = result.content;

      setState(() {
        self.operationFileCount = 1;
        self.selectedOperationFileName = result.fileName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选择文件: ${truncateFileName(result.fileName)}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> pickAnswerFile(int answerIndex) async {
    try {
      final result = await FilePickerService.pickSingleFile();
      if (result == null) return;

      final self = this as dynamic;
      final controllers =
          self.operationFileControllers as List<OperationFileController>;
      final fileCount = self.operationFileCount as int;

      while (controllers.length <= fileCount) {
        controllers.add(OperationFileController());
      }

      final newIndex = fileCount;
      controllers[newIndex].sourceFilePath = result.filePath;
      controllers[newIndex].fileNameController.text = result.fileName;
      controllers[newIndex].contentController.text = result.content;

      setState(() {
        self.operationFileCount = newIndex + 1;
        final answerControllers =
            self.operationAnswerControllers as List<OperationAnswerController>;
        answerControllers[answerIndex].targetPathController.text =
            result.fileName;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已选择文件: ${truncateFileName(result.fileName)}'),
            backgroundColor: AppTheme.successGreen,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void readLineFromInitialFile(int answerIndex, int lineCheckIndex) {
    final self = this as dynamic;
    final answerControllers =
        self.operationAnswerControllers as List<OperationAnswerController>;

    // 越界检查
    if (answerIndex >= answerControllers.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('答案索引超出范围'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final answerCtrl = answerControllers[answerIndex];

    if (lineCheckIndex >= answerCtrl.lineCheckControllers.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('检查行索引超出范围'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final lineCheckCtrl = answerCtrl.lineCheckControllers[lineCheckIndex];
    final lineNumber = int.tryParse(lineCheckCtrl.lineNumberController.text);
    final selectedFileName = self.selectedOperationFileName as String?;

    if (selectedFileName == null || selectedFileName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先点击底部"选择文件"按钮选择文件'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (lineNumber == null || lineNumber < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入有效的行号'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    String? fileContent;
    String? matchedFilePath;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    final fileCount = self.operationFileCount as int;

    for (int i = 0; i < fileCount; i++) {
      if (i < controllers.length) {
        final ctrl = controllers[i];
        if (ctrl.fileNameController.text == selectedFileName) {
          fileContent = ctrl.contentController.text;
          final editingIndex = self.editingOperationIndex as int?;
          final selectedBank = self.selectedBank as String?;
          final questionId = editingIndex != null
              ? '题目${editingIndex + 1}'
              : '题目${(self.operationQuestions as List).length + 1}';
          matchedFilePath =
              '题库/$selectedBank/操作题/$questionId/${ctrl.fileNameController.text}';
          break;
        }
      }
    }

    if (fileContent == null || fileContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '未找到文件内容: ${truncateFileName(selectedFileName)}'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final lines = fileContent.split('\n');
    if (lineNumber > lines.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('行号超出范围，文件共 ${lines.length} 行'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final lineContent = lines[lineNumber - 1].trim();
    lineCheckCtrl.expectedContentController.text = lineContent;
    if (matchedFilePath != null) {
      lineCheckCtrl.filePathController.text = matchedFilePath;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已读取第 $lineNumber 行内容'),
        backgroundColor: AppTheme.successGreen,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  // ========== List Management Methods ==========

  void addOperationFile() {
    final self = this as dynamic;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    setState(() {
      self.operationFileCount++;
      final newIndex = (self.operationFileCount as int) - 1;
      while (controllers.length <= newIndex) {
        controllers.add(OperationFileController());
      }
    });
  }

  void removeOperationFile(int index) {
    final self = this as dynamic;
    final fileCount = self.operationFileCount as int;
    if (fileCount > 1) {
      setState(() {
        self.operationFileCount--;
        final controllers =
            self.operationFileControllers as List<OperationFileController>;
        if (index < controllers.length) {
          controllers[index].dispose();
          controllers.removeAt(index);
        }
      });
    }
  }

  void addOperationAnswer() {
    final self = this as dynamic;
    setState(() {
      self.operationAnswerCount++;
      final index = (self.operationAnswerCount as int) - 1;
      final answerControllers =
          self.operationAnswerControllers as List<OperationAnswerController>;
      while (answerControllers.length <= index) {
        answerControllers.add(OperationAnswerController());
      }
      if (answerControllers[index].lineCheckControllers.isEmpty) {
        answerControllers[index]
            .lineCheckControllers
            .add(OperationLineCheckController());
      }
    });
  }

  void removeOperationAnswer(int index) {
    final self = this as dynamic;
    final answerCount = self.operationAnswerCount as int;
    if (answerCount > 1) {
      setState(() {
        self.operationAnswerCount--;
        final answerControllers =
            self.operationAnswerControllers as List<OperationAnswerController>;
        if (index < answerControllers.length) {
          answerControllers[index].dispose();
          answerControllers.removeAt(index);
        }
      });
    }
  }

  // ========== Save/Load/Delete Methods ==========

  Future<void> saveOperationQuestion() async {
    final self = this as dynamic;
    final questionController =
        self.operationQuestionController as TextEditingController;
    final selectedBank = self.selectedBank as String?;
    final editingIndex = self.editingOperationIndex as int?;
    final operationQuestions =
        self.operationQuestions as List<OperationQuestion>;
    final answerCount = self.operationAnswerCount as int;
    final answerControllers =
        self.operationAnswerControllers as List<OperationAnswerController>;

    if (questionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请输入题目描述'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请先选择题库'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 构建初始文件：按文件路径分组，同文件的多行检查合并到检查行列表
    final initialFiles = <OperationFile>[];
    final controllers =
        self.operationFileControllers as List<OperationFileController>;

    // 先从 fileControllers 获取完整文件内容（按文件名索引）
    final fileContentByFileName = <String, String>{};
    final fileCount = self.operationFileCount as int;
    for (int i = 0; i < fileCount; i++) {
      final fileName = i < controllers.length
          ? controllers[i].fileNameController.text.trim()
          : '';
      if (fileName.isNotEmpty) {
        fileContentByFileName[fileName] =
            i < controllers.length ? controllers[i].contentController.text : '';
      }
    }

    // 按文件路径分组：key=文件路径, value=检查行列表
    final fileCheckLines = <String, List<Map<String, dynamic>>>{};
    final filePaths = <String, String>{}; // 文件路径 -> 文件名

    for (int i = 0; i < answerCount; i++) {
      if (i < answerControllers.length) {
        final ctrl = answerControllers[i];
        // 从 lineCheckControllers 中获取文件路径和检查行信息
        for (int j = 0; j < ctrl.lineCheckControllers.length; j++) {
          final lineCtrl = ctrl.lineCheckControllers[j];
          final filePath = lineCtrl.filePathController.text.trim();
          final lineNumber = int.tryParse(lineCtrl.lineNumberController.text);
          final expectedContent = lineCtrl.expectedContentController.text.trim();
          final lineScore = int.tryParse(lineCtrl.scoreController.text) ?? 5;

          if (filePath.isEmpty || lineNumber == null || lineNumber < 1) continue;

          if (!fileCheckLines.containsKey(filePath)) {
            fileCheckLines[filePath] = [];
            filePaths[filePath] = filePath.split('/').last;
          }
          fileCheckLines[filePath]!.add({
            '行号': lineNumber,
            '内容': expectedContent,
            '分值': lineScore,
          });
        }
      }
    }

    // 从 filePaths 构建 OperationFile 对象
    for (final entry in fileCheckLines.entries) {
      final filePath = entry.key;
      final checkLines = entry.value;
      final fileName = filePaths[filePath]!;
      final totalFileScore = checkLines.fold<int>(0, (sum, cl) => sum + (cl['分值'] as int));

      initialFiles.add(OperationFile(
        fileName: fileName,
        filePath: filePath,
        checkLines: checkLines,
        score: totalFileScore,
        content: fileContentByFileName[fileName] ?? '',
      ));
    }

    if (initialFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('请至少添加一个有效的检查项（文件路径、行号和期望内容）'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // 计算总分（所有检查项分值之和）
    final totalScore = initialFiles.fold<int>(0, (sum, f) => sum + f.score);

    final operationQuestion = OperationQuestion(
      questionText: questionController.text,
      score: totalScore > 0 ? totalScore : 10,
      initialFiles: initialFiles,
    );

    setState(() {
      if (editingIndex != null) {
        operationQuestions[editingIndex] = operationQuestion;
      } else {
        operationQuestions.add(operationQuestion);
      }
    });

    // 复制文件到题库目录
    final questionId = editingIndex != null
        ? '题目${editingIndex + 1}'
        : '题目${operationQuestions.length}';
    for (final file in initialFiles) {
      if (file.fileName.isNotEmpty) {
        try {
          final fileName = file.fileName;
          final targetDir = Directory('${Directory.current.path}/题库/$selectedBank/操作题/$questionId');
          if (!targetDir.existsSync()) {
            targetDir.createSync(recursive: true);
          }
          final targetFile = File('${targetDir.path}/$fileName');
          // 从 fileControllers 中查找对应的源文件内容
          final sourceContent = fileContentByFileName[fileName];
          if (sourceContent != null && sourceContent.isNotEmpty) {
            targetFile.writeAsStringSync(sourceContent);
          }
          // 更新 filePath 为实际文件系统路径
          file.filePath = '题库/$selectedBank/操作题/$questionId/$fileName';
        } catch (e) {
          // 文件复制失败不影响主流程
        }
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editingIndex != null
              ? '操作题 ${editingIndex + 1} 已更新'
              : '操作题已添加，当前共 ${operationQuestions.length} 题'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    }

    if (selectedBank != null) {
      saveQuestionsToFile();
    }

    clearOperationForm();
  }

  void locClearOperationForm() {
    final self = this as dynamic;
    final questionController =
        self.operationQuestionController as TextEditingController;
    final scoreController =
        self.operationScoreController as TextEditingController;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    final answerControllers =
        self.operationAnswerControllers as List<OperationAnswerController>;

    questionController.clear();
    scoreController.text = '10';
    setState(() {
      self.editingOperationIndex = null;
      self.operationFileCount = 1;
      self.operationAnswerCount = 1;
      self.selectedOperationFileName = null;
    });
    // 清除所有文件控制器并保留第一个以备复用
    for (int i = 1; i < controllers.length; i++) {
      controllers[i].dispose();
    }
    if (controllers.isNotEmpty) {
      controllers[0].clear();
      controllers.removeRange(1, controllers.length);
    } else {
      controllers.add(OperationFileController());
    }
    // 清除所有答案控制器并保留第一个以备复用
    for (int i = 1; i < answerControllers.length; i++) {
      answerControllers[i].dispose();
    }
    if (answerControllers.isNotEmpty) {
      answerControllers[0].clear();
      answerControllers.removeRange(1, answerControllers.length);
      answerControllers[0].lineCheckControllers.clear();
    } else {
      answerControllers.add(OperationAnswerController());
    }
    // 确保至少有一个 lineCheckController
    if (answerControllers.isNotEmpty &&
        answerControllers[0].lineCheckControllers.isEmpty) {
      answerControllers[0].lineCheckControllers.add(
          OperationLineCheckController());
    }
  }

  /// 统一清除操作题表单
  void clearOperationForm() {
    locClearOperationForm();
  }

  void loadOperationQuestionToForm(int index) {
    final self = this as dynamic;
    final operationQuestions =
        self.operationQuestions as List<OperationQuestion>;
    final questionController =
        self.operationQuestionController as TextEditingController;
    final scoreController =
        self.operationScoreController as TextEditingController;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    final answerControllers =
        self.operationAnswerControllers as List<OperationAnswerController>;

    final q = operationQuestions[index];

    // 先清空旧表单
    locClearOperationForm();

    questionController.text = q.questionText;
    scoreController.text = q.score.toString();

    // 计算展开后的检查行总数
    int totalCheckLines = 0;
    for (final file in q.initialFiles) {
      if (file.checkLines != null && file.checkLines!.isNotEmpty) {
        totalCheckLines += file.checkLines!.length;
      } else {
        totalCheckLines += 1;
      }
    }

    final fileCount = q.initialFiles.length.clamp(1, 100);
    setState(() {
      self.editingOperationIndex = index;
      self.operationFileCount = fileCount;
      self.operationAnswerCount = totalCheckLines.clamp(1, 100);
    });

    // 填充文件控制器
    while (controllers.length < q.initialFiles.length) {
      controllers.add(OperationFileController());
    }
    for (int i = 0; i < q.initialFiles.length; i++) {
      final file = q.initialFiles[i];
      controllers[i].fileNameController.text = file.fileName;
      controllers[i].contentController.text = file.content ?? '';
    }

    // 设置选中的文件名
    if (q.initialFiles.isNotEmpty) {
      self.selectedOperationFileName = q.initialFiles[0].fileName;
    }

    // 展开检查行：每个 checkLine 对应一个答案控制器
    while (answerControllers.length < totalCheckLines) {
      answerControllers.add(OperationAnswerController());
    }
    int answerIdx = 0;
    for (final item in q.initialFiles) {
      final filePath = item.filePath ?? item.fileName;
      if (item.checkLines != null && item.checkLines!.isNotEmpty) {
        for (final cl in item.checkLines!) {
          final lineNum = cl['行号'] ?? cl['lineNumber'] ?? 1;
          final content = cl['内容'] ?? cl['content'] ?? '';
          final lineScore = cl['分值'] ?? cl['score'] ?? 5;

          final answerCtrl = answerControllers[answerIdx];
          answerCtrl.targetPathController.text = filePath;
          answerCtrl.keywordsController.text = '';
          answerCtrl.scoreController.text = lineScore.toString();

          if (answerCtrl.lineCheckControllers.isEmpty) {
            answerCtrl.lineCheckControllers.add(OperationLineCheckController());
          }
          final lineCtrl = answerCtrl.lineCheckControllers[0];
          lineCtrl.lineNumberController.text = lineNum.toString();
          lineCtrl.expectedContentController.text = content.toString();
          lineCtrl.scoreController.text = lineScore.toString();
          lineCtrl.filePathController.text = filePath;

          answerIdx++;
        }
      } else {
        // 兼容旧格式：没有 checkLines，使用单行号/内容
        final answerCtrl = answerControllers[answerIdx];
        answerCtrl.targetPathController.text = filePath;
        answerCtrl.keywordsController.text = '';
        answerCtrl.scoreController.text = item.score.toString();

        if (answerCtrl.lineCheckControllers.isEmpty) {
          answerCtrl.lineCheckControllers.add(OperationLineCheckController());
        }
        final lineCtrl = answerCtrl.lineCheckControllers[0];
        lineCtrl.lineNumberController.text = item.lineNumber.toString();
        lineCtrl.expectedContentController.text = item.expectedContent;
        lineCtrl.scoreController.text = item.score.toString();
        lineCtrl.filePathController.text = filePath;

        answerIdx++;
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已加载第 ${index + 1} 题到编辑区'),
        backgroundColor: AppTheme.primaryBlue,
      ),
    );
  }
  Future<void> deleteOperationQuestion() async {
    final self = this as dynamic;
    final editingIndex = self.editingOperationIndex as int?;
    final selectedBank = self.selectedBank as String?;
    final operationQuestions =
        self.operationQuestions as List<OperationQuestion>;

    if (editingIndex == null) return;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除第 ${editingIndex + 1} 题操作题吗？\n此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    final deletedIndex = editingIndex;
    final questionId = '题目${deletedIndex + 1}';

    if (selectedBank != null) {
      try {
        final targetDir =
            '${Directory.current.path}/题库/$selectedBank/操作题/$questionId';
        final dir = Directory(targetDir);
        if (await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        // ignore
      }
    }

    operationQuestions.removeAt(deletedIndex);
    clearOperationForm();

    if (selectedBank != null) {
      saveQuestionsToFile();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除第 ${deletedIndex + 1} 题'),
        backgroundColor: Colors.grey,
      ),
    );
  }

  // ========== Operation Question UI ==========

  Widget buildOperationQuestionForm() {
    final self = this as dynamic;
    final hasBank = (self.selectedBank as String?) != null;
    final questionController =
        self.operationQuestionController as TextEditingController;
    final editingIndex = self.editingOperationIndex as int?;
    final answerCount = self.operationAnswerCount as int;
    final selectedFileName = self.selectedOperationFileName as String?;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: questionController,
            enabled: hasBank,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: hasBank ? '请输入操作题题目描述...' : '请先选择题库',
              labelText: '题目描述',
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
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green[200]!),
            ),
            child: SizedBox(
              height: 250,
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(answerCount, (index) {
                    return buildOperationAnswerRow(index, hasBank);
                  }),
                ),
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
              if (editingIndex == null)
                ElevatedButton.icon(
                  onPressed: hasBank ? saveOperationQuestion : null,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加操作题'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        hasBank ? AppTheme.primaryBlue : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (editingIndex != null)
                ElevatedButton.icon(
                  onPressed: hasBank ? saveOperationQuestion : null,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('保存'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasBank ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              if (editingIndex != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: hasBank ? deleteOperationQuestion : null,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('删除题目'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasBank
                        ? Colors.red[400]
                        : Colors.grey[300],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
              ElevatedButton.icon(
                onPressed: hasBank ? pickBottomOperationFile : null,
                icon: Icon(
                  selectedFileName != null
                      ? Icons.file_present
                      : Icons.folder_open,
                  size: 18,
                ),
                label: Text(
                  selectedFileName != null
                      ? '选择文件: ${truncateFileName(selectedFileName)}'
                      : '选择文件',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasBank
                      ? (selectedFileName != null
                          ? Colors.green[600]
                          : Colors.blue[400])
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: hasBank ? addOperationAnswer : null,
                icon: const Icon(Icons.add, size: 18),
                label: Text('添加检查项 ($answerCount)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      hasBank ? Colors.green[600] : Colors.grey[300],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (editingIndex != null) ...[
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => self.clearOperationForm(),
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

  Widget buildOperationFileRow(int index, bool enabled) {
    final self = this as dynamic;
    final controllers =
        self.operationFileControllers as List<OperationFileController>;
    while (controllers.length <= index) {
      controllers.add(OperationFileController());
    }
    final ctrl = controllers[index];
    final hasFile = ctrl.sourceFilePath != null;
    final fileCount = self.operationFileCount as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          ElevatedButton.icon(
            onPressed: enabled ? () => pickOperationFile(index) : null,
            icon: Icon(
              hasFile ? Icons.file_present : Icons.folder_open,
              size: 16,
            ),
            label: Text(
              hasFile ? '已选择' : '选择文件',
              style: const TextStyle(fontSize: 12),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: hasFile ? Colors.green[600] : Colors.blue[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: ctrl.fileNameController,
              enabled: false,
              decoration: InputDecoration(
                hintText: '文件名（自动填充）',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
            onPressed:
                enabled && hasFile ? () => clearOperationFile(index) : null,
            icon: Icon(
              Icons.clear,
              color: hasFile ? Colors.orange : Colors.grey,
              size: 18,
            ),
            tooltip: '清除文件',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: enabled && fileCount > 1
                ? () => removeOperationFile(index)
                : null,
            icon: Icon(
              Icons.close,
              color:
                  enabled && fileCount > 1 ? Colors.red : Colors.grey,
              size: 18,
            ),
            tooltip: '删除此文件',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget buildOperationAnswerRow(int index, bool enabled) {
    final self = this as dynamic;
    final answerControllers =
        self.operationAnswerControllers as List<OperationAnswerController>;
    while (answerControllers.length <= index) {
      answerControllers.add(OperationAnswerController());
    }
    final ctrl = answerControllers[index];
    if (ctrl.lineCheckControllers.isEmpty) {
      ctrl.lineCheckControllers.add(OperationLineCheckController());
    }
    final answerCount = self.operationAnswerCount as int;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            height: 36
,
            child: TextField(
              controller: ctrl.lineCheckControllers.first.lineNumberController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '行号',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.borderMain),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ElevatedButton.icon(
            onPressed: enabled && ctrl.lineCheckControllers.isNotEmpty
                ? () => readLineFromInitialFile(index, 0)
                : null,
            icon: const Icon(Icons.download, size: 14),
            label: const Text('读取', style: TextStyle(fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[400],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              minimumSize: const Size(60, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: ctrl.lineCheckControllers.first.expectedContentController,
                enabled: enabled,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: '期望内容',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppTheme.borderMain),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 50,
            height: 36,
            child: TextField(
              controller: ctrl.lineCheckControllers.first.scoreController,
              enabled: enabled,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: '分',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: enabled && answerCount > 1
                ? () => removeOperationAnswer(index)
                : null,
            icon: Icon(
              Icons.close,
              color: enabled && answerCount > 1
                  ? Colors.red
                  : Colors.grey,
              size: 20,
            ),
            tooltip: '删除此检查项',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  Widget buildOperationQuestionTable() {
    final self = this as dynamic;
    final operationQuestions =
        self.operationQuestions as List<OperationQuestion>;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.table_chart, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                '操作题列表',
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
                  '共 ${operationQuestions.length} 题',
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
          operationQuestions.isEmpty
              ? buildEmptyOperationTable()
              : buildOperationTable(),
        ],
      ),
    );
  }

  Widget buildEmptyOperationTable() {
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
              Icons.computer_outlined,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              '暂无操作题，点击上方按钮添加',
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

  Widget buildOperationTable() {
    final self = this as dynamic;
    final operationQuestions =
        self.operationQuestions as List<OperationQuestion>;
    final editingIndex = self.editingOperationIndex as int?;

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
                  Text('题目描述', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('初始文件', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('检查项', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label: Text('分值', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: operationQuestions.asMap().entries.map((entry) {
          final index = entry.key;
          final q = entry.value;
          final isEditing = editingIndex == index;
          final previewText = q.questionText.length > 30
              ? '${q.questionText.substring(0, 30)}...'
              : q.questionText;
          final fileCount = q.initialFiles.length;
          int answerCount = 0;
          int totalScore = 0;
          for (final f in q.initialFiles) {
            if (f.checkLines != null && f.checkLines!.isNotEmpty) {
              answerCount += f.checkLines!.length;
              for (final cl in f.checkLines!) {
                totalScore += (cl['分值'] ?? cl['score'] ?? 5) as int;
              }
            } else {
              answerCount += 1;
              totalScore += f.score;
            }
          }
          return DataRow(
            color: MaterialStateProperty.all(
                isEditing ? AppTheme.primaryBlue.withAlpha(26) : null),
            onSelectChanged: (_) => loadOperationQuestionToForm(index),
            cells: [
              DataCell(Text('操作题')),
              DataCell(Text('${index + 1}')),
              DataCell(SizedBox(
                width: 200,
                child: Text(previewText, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$fileCount 个文件',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )),
              DataCell(Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '$answerCount 项',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              )),
              DataCell(Text('$totalScore 分')),
            ],
          );
        }).toList(),
      ),
    );
  }
}
