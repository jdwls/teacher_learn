import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;

/// 题库导入验证错误
class ImportError {
  final int row; // 行号
  final String field; // 字段名
  final String message; // 错误信息

  ImportError({
    required this.row,
    required this.field,
    required this.message,
  });

  @override
  String toString() => '第${row + 1}行 [$field]: $message';
}

/// 题库导入结果
class ImportResult {
  final bool success;
  final String? errorMessage;
  final List<ImportError> errors;
  final int importedCount;

  ImportResult({
    required this.success,
    this.errorMessage,
    this.errors = const [],
    this.importedCount = 0,
  });
}

/// 题库导入服务类
class QuestionImportService {
  /// 导入题库（JSON 格式）
  static Future<ImportResult> importQuestionBank({
    required String filePath,
    required String targetBankName,
  }) async {
    try {
      // 只支持 JSON 格式
      final extension = filePath.split('.').last.toLowerCase();
      if (extension != 'json') {
        return ImportResult(
          success: false,
          errorMessage: '不支持的文件格式，仅支持 .json 格式',
        );
      }

      // 解析 JSON 文件
      final questions = await _parseJsonFile(filePath);

      if (questions.isEmpty) {
        return ImportResult(
          success: false,
          errorMessage: '文件中没有找到任何选择题题目',
        );
      }

      // 预校验
      final errors = validateQuestions(questions, filePath);
      if (errors.isNotEmpty) {
        return ImportResult(
          success: false,
          errors: errors,
          errorMessage: '校验失败，发现 ${errors.length} 个错误',
        );
      }

      // 检查题库是否已存在（使用绝对路径）
      final rootDir = Directory.current.path;
      final bankDir = Directory(path.join(rootDir, '题库', targetBankName));
      if (await bankDir.exists()) {
        return ImportResult(
          success: false,
          errorMessage: '题库 "$targetBankName" 已存在，请使用其他名称或先删除现有题库',
        );
      }

      // 创建题库文件夹
      await bankDir.create(recursive: true);

      // 创建图片文件夹
      final imgDir = Directory(path.join(bankDir.path, '图片'));
      await imgDir.create();

      // 处理图片文件夹
      final sourceDir = File(filePath).parent;
      final targetImgDir = Directory('${bankDir.path}/图片');

      bool hasImageFolder = false;
      Directory? imageSourceDir;

      await for (final entity in sourceDir.list()) {
        if (entity is Directory) {
          final dirName =
              entity.path.split(RegExp(r'[/\\]')).last.toLowerCase();
          if (dirName == '图片' || dirName == 'images' || dirName == 'img') {
            hasImageFolder = true;
            imageSourceDir = entity;
            break;
          }
        }
      }

      if (hasImageFolder && imageSourceDir != null) {
        if (await targetImgDir.exists()) {
          await targetImgDir.delete(recursive: true);
        }
        await _copyDirectory(imageSourceDir, targetImgDir);
      }

      // 收集更新后的题目（保留原有图片路径引用）
      final updatedQuestions =
          questions.map((q) => Map<String, dynamic>.from(q)).toList();

      // 保存到 JSON 文件
      final success = await _saveQuestionsToJsonBank(
        targetBankName,
        updatedQuestions,
      );

      if (!success) {
        return ImportResult(
          success: false,
          errorMessage: '保存题库失败',
        );
      }

      return ImportResult(
        success: true,
        importedCount: updatedQuestions.length,
      );
    } catch (e) {
      return ImportResult(
        success: false,
        errorMessage: '导入失败: $e',
      );
    }
  }

  /// 从文件夹选择器获取题库文件夹并解析
  static Future<Map<String, dynamic>?> pickAndParseFile() async {
    try {
      // 选择文件（只选择 JSON 文件）
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null; // 用户取消选择
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        return {'error': '无法获取文件路径'};
      }

      // 获取文件名作为题库名称
      final fileName = filePath.split('/').last.split('\\').last;
      final bankName = fileName.replaceAll('.json', '');

      // 解析 JSON 文件
      final questions = await _parseJsonFile(filePath);

      return {
        'filePath': filePath,
        'questions': questions,
        'bankName': bankName,
        'originalBankName': bankName,
        'questionCount': questions.length,
      };
    } catch (e) {
      return {'error': '读取文件夹失败: $e'};
    }
  }

  /// 解析 JSON 文件
  static Future<List<Map<String, dynamic>>> _parseJsonFile(
      String filePath) async {
    try {
      final file = File(filePath);
      final jsonString = await file.readAsString();
      final jsonData = jsonDecode(jsonString);

      final questions = <Map<String, dynamic>>[];

      // 支持两种格式：
      // 1. 直接是数组格式 [{...}, {...}]
      // 2. 包含 choiceQuestions 字段的对象格式
      List<dynamic> questionList;

      if (jsonData is List) {
        questionList = jsonData;
      } else if (jsonData is Map<String, dynamic>) {
        if (jsonData.containsKey('choiceQuestions')) {
          questionList = jsonData['choiceQuestions'] as List<dynamic>? ?? [];
        } else if (jsonData.containsKey('questions')) {
          questionList = jsonData['questions'] as List<dynamic>? ?? [];
        } else {
          final firstListField = jsonData.entries
              .where((e) => e.value is List)
              .map((e) => e.value as List<dynamic>)
              .firstOrNull;
          questionList = firstListField ?? [];
        }
      } else {
        return [];
      }

      // 字段映射：支持中文列名和英文字段名
      for (int i = 0; i < questionList.length; i++) {
        final q = questionList[i] as Map<String, dynamic>;

        // 获取题目文本（支持多种字段名）
        final questionText = _getJsonValue(q, ['questionText', '题干', '题目']);
        if (questionText?.toString().isEmpty ?? true) continue;

        // 获取选项（支持中文和英文）
        final optionA = _getJsonValue(q, ['optionA', '选项A', 'A']);
        final optionB = _getJsonValue(q, ['选项B', '选项B', 'B']);
        final optionC = _getJsonValue(q, ['optionC', '选项C', 'C']);
        final optionD = _getJsonValue(q, ['optionD', '选项D', 'D']);

        // 获取图片（支持多种命名）
        final questionImage = _getJsonValue(q, ['questionImage', '题干图片', '题图']);
        final imageA = _getJsonValue(q, ['imageA', '图片A', 'optionAImage']);
        final imageB = _getJsonValue(q, ['imageB', '图片B', 'optionBImage']);
        final imageC = _getJsonValue(q, ['imageC', '图片C', 'optionCImage']);
        final imageD = _getJsonValue(q, ['imageD', '图片D', 'optionDImage']);

        // 获取答案和分值
        final answer =
            _getJsonValue(q, ['answer', '答案'])?.toString().toUpperCase() ?? '';
        final score = _getJsonValue(q, ['score', '分值'])?.toString() ?? '5';

        // 转换为标准格式
        questions.add({
          'type': '选择题',
          'number': '${i + 1}',
          'questionText': questionText,
          'optionA': optionA ?? '',
          'optionB': optionB ?? '',
          'optionC': optionC ?? '',
          'optionD': optionD ?? '',
          'questionImage': questionImage ?? '',
          'imageA': imageA ?? '',
          'imageB': imageB ?? '',
          'imageC': imageC ?? '',
          'imageD': imageD ?? '',
          'answer': answer,
          'score': score,
        });
      }

      return questions;
    } catch (e) {
      return [];
    }
  }

  /// 从 JSON 对象中获取值（支持多个可能的字段名）
  static String? _getJsonValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      if (data.containsKey(key) && data[key] != null) {
        final value = data[key];
        if (value is String && value.isNotEmpty) {
          return value;
        } else if (value != null) {
          return value.toString();
        }
      }
    }
    return null;
  }

  /// 校验题目数据
  static List<ImportError> validateQuestions(
    List<Map<String, dynamic>> questions,
    String filePath,
  ) {
    final errors = <ImportError>[];

    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];

      // 检查必填字段
      if (q['questionText']?.toString().isEmpty ?? true) {
        errors.add(ImportError(
          row: i,
          field: 'questionText',
          message: '题干不能为空',
        ));
      }

      // 检查选项
      final options = ['A', 'B', 'C', 'D'];
      for (final opt in options) {
        final key = 'option$opt';
        if (q[key]?.toString().isEmpty ?? true) {
          errors.add(ImportError(
            row: i,
            field: key,
            message: '选项$opt内容不能为空',
          ));
        }
      }

      // 检查答案
      final answer = q['answer']?.toString().toUpperCase() ?? '';
      if (!options.contains(answer)) {
        errors.add(ImportError(
          row: i,
          field: 'answer',
          message: '答案必须是 A、B、C、D 之一',
        ));
      }

      // 检查分值
      final score = int.tryParse(q['score']?.toString() ?? '');
      if (score == null || score <= 0) {
        errors.add(ImportError(
          row: i,
          field: 'score',
          message: '分值必须是正整数',
        ));
      }
    }

    return errors;
  }

  /// 复制整个目录
  static Future<void> _copyDirectory(
      Directory source, Directory destination) async {
    await destination.create(recursive: true);

    await for (final entity in source.list()) {
      if (entity is File) {
        final newPath =
            '${destination.path}/${entity.path.split(RegExp(r'[/\\]')).last}';
        await entity.copy(newPath);
      } else if (entity is Directory) {
        final newDir = Directory(
            '${destination.path}/${entity.path.split(RegExp(r'[/\\]')).last}');
        await _copyDirectory(entity, newDir);
      }
    }
  }

  /// 保存题目到 JSON 格式题库（使用绝对路径）
  static Future<bool> _saveQuestionsToJsonBank(
    String bankName,
    List<Map<String, dynamic>> questions,
  ) async {
    try {
      final rootDir = Directory.current.path;
      final jsonFilePath = path.join(rootDir, '题库', bankName, '题库.json');
      final jsonFile = File(jsonFilePath);

      // 构建题库结构（字段与 Excel 表格列名对应）
      final bankData = {
        'version': '1.0',
        'name': bankName,
        'createdAt': DateTime.now().toIso8601String(),
        'choiceQuestions': questions
            .map((q) => {
                  '题型': q['type'] ?? '选择题',
                  '题号': q['number'] ?? '',
                  '题干': q['questionText'] ?? '',
                  '选项A': q['optionA'] ?? '',
                  '选项B': q['optionB'] ?? '',
                  '选项C': q['optionC'] ?? '',
                  '选项D': q['optionD'] ?? '',
                  '题干图片': q['questionImage'] ?? '',
                  '图片A': q['imageA'] ?? '',
                  '图片B': q['imageB'] ?? '',
                  '图片C': q['imageC'] ?? '',
                  '图片D': q['imageD'] ?? '',
                  '答案': q['answer'] ?? '',
                  '分值': q['score'] ?? '5',
                })
            .toList(),
        'matchingQuestions': <Map<String, dynamic>>[],
        'sequentialQuestions': <Map<String, dynamic>>[],
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(bankData);
      await jsonFile.writeAsString(jsonString, flush: true);

      return true;
    } catch (e) {
      return false;
    }
  }
}
