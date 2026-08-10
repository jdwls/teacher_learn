import 'package:flutter/material.dart';

/// 连线题匹配项的控制器
class MatchingItemControllers {
  final TextEditingController leftController = TextEditingController();
  final TextEditingController rightController = TextEditingController();
  String? leftImagePath;
  String? rightImagePath;

  void dispose() {
    leftController.dispose();
    rightController.dispose();
  }
}

/// 顺序题项目控制器
class SequentialItemControllers {
  final TextEditingController controller = TextEditingController();
  String? imagePath;

  void dispose() {
    controller.dispose();
  }
}

/// 操作题初始文件控制器
class OperationFileController {
  final TextEditingController fileNameController = TextEditingController();
  final TextEditingController contentController = TextEditingController();
  String? sourceFilePath; // 源文件路径（选择文件后存储）
  String? cachePath; // 缓存路径（用于后续复制到题库）

  void dispose() {
    fileNameController.dispose();
    contentController.dispose();
  }

  void clear() {
    fileNameController.clear();
    contentController.clear();
    sourceFilePath = null;
    cachePath = null;
  }
}

/// 操作题行检查项控制器
class OperationLineCheckController {
  final TextEditingController lineNumberController = TextEditingController();
  final TextEditingController expectedContentController =
      TextEditingController();
  final TextEditingController scoreController =
      TextEditingController(text: '5');
  final TextEditingController filePathController = TextEditingController();

  void dispose() {
    lineNumberController.dispose();
    expectedContentController.dispose();
    scoreController.dispose();
    filePathController.dispose();
  }
}

/// 操作题答案检查项控制器
class OperationAnswerController {
  final TextEditingController targetPathController = TextEditingController();
  final TextEditingController keywordsController = TextEditingController();
  final TextEditingController scoreController =
      TextEditingController(text: '5');
  // 行检查项列表
  final List<OperationLineCheckController> lineCheckControllers = [];
  int lineCheckCount = 0;

  void clear() {
    targetPathController.clear();
    keywordsController.clear();
    scoreController.text = '5';
    for (final ctrl in lineCheckControllers) {
      ctrl.dispose();
    }
    lineCheckControllers.clear();
  }

  void dispose() {
    targetPathController.dispose();
    keywordsController.dispose();
    scoreController.dispose();
    for (final ctrl in lineCheckControllers) {
      ctrl.dispose();
    }
  }
}