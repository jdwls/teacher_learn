import 'dart:convert';
import 'dart:io';
import '../utils/app_path.dart';

class QuestionBankService {
  static String get _rootDir => AppPath.projectRoot;

  /// 获取所有题库列表
  static Future<List<String>> getQuestionBanks() async {
    final bankRootPath = '$_rootDir/题库';
    final bankRootDir = Directory(bankRootPath);

    if (!await bankRootDir.exists()) {
      return [];
    }

    final banks = <String>[];
    await for (final entity in bankRootDir.list()) {
      if (entity is Directory) {
        final name = entity.path.split('/').last.split('\\').last;
        banks.add(name);
      }
    }
    return banks;
  }

  /// 删除题库
  static Future<bool> deleteQuestionBank(String bankName) async {
    try {
      final bankPath = '$_rootDir/题库/$bankName';
      final bankDir = Directory(bankPath);
      if (await bankDir.exists()) {
        await bankDir.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// 从题库读取选择题数据
  static Future<List<Map<String, dynamic>>> loadQuestionsFromBank(
      String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return [];
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final choiceQuestions = (data['choiceQuestions'] as List<dynamic>?)
              ?.map((q) => _convertChoiceQuestion(q))
              .toList() ??
          [];

      return choiceQuestions;
    } catch (e) {
      return [];
    }
  }

  /// 转换选择题数据格式（从 JSON 存储格式转为应用内部格式，兼容新旧格式）
  static Map<String, dynamic> _convertChoiceQuestion(Map<String, dynamic> q) {
    // 检查是否为嵌套格式（有items数组）
    final items = q['items'] as List<dynamic>?;

    if (items != null && items.isNotEmpty) {
      // 嵌套格式：从items中读取选项和答案
      final firstItem = items[0] as Map<String, dynamic>;
      return {
        'type': q['题型'] ?? '选择题',
        'number': q['题号']?.toString() ?? '',
        'questionText': q['题干'] ?? '',
        'optionA': firstItem['选项A'] ?? '',
        'optionB': firstItem['选项B'] ?? '',
        'optionC': firstItem['选项C'] ?? '',
        'optionD': firstItem['选项D'] ?? '',
        'questionImage': q['题干图片'] ?? '',
        'imageA': firstItem['图片A'] ?? '',
        'imageB': firstItem['图片B'] ?? '',
        'imageC': firstItem['图片C'] ?? '',
        'imageD': firstItem['图片D'] ?? '',
        'answer': firstItem['答案'] ?? '',
        'score': firstItem['分值'] ?? '5',
      };
    } else {
      // 旧格式（扁平结构）
      return {
        'type': q['题型'] ?? '选择题',
        'number': q['题号']?.toString() ?? '',
        'questionText': q['题干'] ?? '',
        'optionA': q['选项A'] ?? '',
        'optionB': q['选项B'] ?? '',
        'optionC': q['选项C'] ?? '',
        'optionD': q['选项D'] ?? '',
        'questionImage': q['题干图片'] ?? '',
        'imageA': q['图片A'] ?? '',
        'imageB': q['图片B'] ?? '',
        'imageC': q['图片C'] ?? '',
        'imageD': q['图片D'] ?? '',
        'answer': q['答案'] ?? '',
        'score': q['分值'] ?? '5',
      };
    }
  }

  /// 保存题目到题库（JSON 格式）
  static Future<bool> saveQuestionToBank(
    String bankName,
    List<Map<String, dynamic>> questions, {
    List<Map<String, dynamic>>? matchingQuestions,
    List<Map<String, dynamic>>? sequentialQuestions,
    List<Map<String, dynamic>>? typingQuestions,
    List<Map<String, dynamic>>? operationQuestions,
    int? examTimeLimit,
    int? earlySubmitMinutes,
  }) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      // 如果文件不存在，先创建空的题库结构
      if (!await jsonFile.exists()) {
        final bankPath = '$_rootDir/题库/$bankName';
        final bankDir = Directory(bankPath);
        await bankDir.create(recursive: true);

        final emptyBank = {
          'version': '1.0',
          'name': bankName,
          'createdAt': DateTime.now().toIso8601String(),
          'examTimeLimit': 30,
          'earlySubmitMinutes': 25,
          'choiceQuestions': <Map<String, dynamic>>[],
          'matchingQuestions': <Map<String, dynamic>>[],
          'sequentialQuestions': <Map<String, dynamic>>[],
          'typingQuestions': <Map<String, dynamic>>[],
          'operationQuestions': <Map<String, dynamic>>[],
        };
        await jsonFile.writeAsString(jsonEncode(emptyBank), flush: true);
      }

      // 转换选择题数据为存储格式（嵌套items数组格式）
      final choiceQuestionsData = questions.asMap().entries.map((entry) {
        final q = entry.value;
        return {
          '题型': q['type'] ?? '选择题',
          '题号': '${entry.key + 1}',
          '题干': q['questionText'] ?? '',
          '题干图片': q['questionImage'] ?? '',
          'items': [
            {
              '选项A': q['optionA'] ?? '',
              '选项B': q['optionB'] ?? '',
              '选项C': q['optionC'] ?? '',
              '选项D': q['optionD'] ?? '',
              '图片A': q['imageA'] ?? '',
              '图片B': q['imageB'] ?? '',
              '图片C': q['imageC'] ?? '',
              '图片D': q['imageD'] ?? '',
              '答案': q['answer'] ?? '',
              '分值': q['score'] ?? '5',
            }
          ],
        };
      }).toList();

      // 转换连线题数据为存储格式（嵌套items数组格式）
      final matchingQuestionsData = <Map<String, dynamic>>[];
      if (matchingQuestions != null) {
        for (int qIndex = 0; qIndex < matchingQuestions.length; qIndex++) {
          final mq = matchingQuestions[qIndex];
          // 兼容中文和英文键名
          final items = mq['items'] as List<dynamic>? ?? [];

          // 构建items数组
          final itemsList = <Map<String, dynamic>>[];
          for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
            final item = items[itemIndex] as Map<String, dynamic>;
            // 兼容中文和英文键名
            final leftText = item['左侧内容'] ?? item['leftText'] ?? '';
            final rightText = item['右侧内容'] ?? item['rightText'] ?? '';
            final leftImage = item['左侧图片'] ?? item['leftImage'] ?? '';
            final rightImage = item['右侧图片'] ?? item['rightImage'] ?? '';
            // 保持原始类型：如果是int就保存为int，否则转为字符串
            final itemScore = item['分值'] is int
                ? item['分值']
                : int.tryParse(item['分值']?.toString() ?? '5') ?? 5;

            itemsList.add({
              '序号': '${itemIndex + 1}',
              '左侧内容': leftText,
              '左侧图片': leftImage,
              '右侧内容': rightText,
              '右侧图片': rightImage,
              '分值': itemScore,
            });
          }

          // 保存题目总分，学生端优先使用该字段评分。
          final questionScore = mq['score'] is num
              ? (mq['score'] as num).toInt()
              : int.tryParse(mq['score']?.toString() ?? '') ??
                  itemsList.fold<int>(0, (sum, item) => sum + (item['分值'] as int));
          matchingQuestionsData.add({
            '题型': '连线题',
            '题号': '${qIndex + 1}',
            '题干': mq['题干'] ?? mq['questionText'] ?? '',
            '题干图片': mq['题干图片'] ?? mq['questionImage'] ?? '',
            'score': questionScore,
            'items': itemsList,
          });
        }
      }

      // 转换顺序题数据为存储格式（嵌套items数组格式）
      final sequentialQuestionsData = <Map<String, dynamic>>[];
      if (sequentialQuestions != null) {
        for (int qIndex = 0; qIndex < sequentialQuestions.length; qIndex++) {
          final sq = sequentialQuestions[qIndex];
          // 兼容中文和英文键名
          final items = sq['items'] as List<dynamic>? ?? [];

          // 构建items数组
          final itemsList = <Map<String, dynamic>>[];
          for (int itemIndex = 0; itemIndex < items.length; itemIndex++) {
            final item = items[itemIndex] as Map<String, dynamic>;
            // 兼容中文和英文键名
            final itemText = item['待排序项目'] ?? item['text'] ?? '';
            final itemImage = item['项图片'] ?? item['image'] ?? '';
            // 保持原始类型：如果是int就保存为int，否则转为字符串
            final itemScore = item['分值'] is int
                ? item['分值']
                : int.tryParse(item['分值']?.toString() ?? '5') ?? 5;

            itemsList.add({
              '序号': '${itemIndex + 1}',
              '待排序项目': itemText,
              '项图片': itemImage,
              '分值': itemScore,
            });
          }

          final questionScore = sq['score'] is num
              ? (sq['score'] as num).toInt()
              : int.tryParse(sq['score']?.toString() ?? '') ??
                  itemsList.fold<int>(0, (sum, item) => sum + (item['分值'] as int));
          sequentialQuestionsData.add({
            '题型': '顺序题',
            '题号': '${qIndex + 1}',
            '题干': sq['题干'] ?? sq['questionText'] ?? '',
            '题干图片': sq['题干图片'] ?? sq['questionImage'] ?? '',
            'score': questionScore,
            'items': itemsList,
          });
        }
      }

      // 转换打字题数据为存储格式
      final typingQuestionsData = <Map<String, dynamic>>[];
      if (typingQuestions != null) {
        for (int qIndex = 0; qIndex < typingQuestions.length; qIndex++) {
          final tq = typingQuestions[qIndex];
          typingQuestionsData.add({
            '题型': '打字题',
            '题号': '${qIndex + 1}',
            '打字类型': tq['打字类型'] ?? 'chinese',
            '参考文本': tq['参考文本'] ?? '',
            '时间限制': tq['时间限制'] ?? 5,
            '分值': tq['分值'] ?? 10,
          });
        }
      }

      // 读取现有题库数据以保留 examTimeLimit 和 earlySubmitMinutes（如果未提供）
      int finalExamTimeLimit = examTimeLimit ?? 30;
      int finalEarlySubmitMinutes = earlySubmitMinutes ?? 25;
      if (examTimeLimit == null && await jsonFile.exists()) {
        try {
          final existingContent = await jsonFile.readAsString();
          final existingData =
              jsonDecode(existingContent) as Map<String, dynamic>;
          finalExamTimeLimit = existingData['examTimeLimit'] as int? ?? 30;
          finalEarlySubmitMinutes =
              existingData['earlySubmitMinutes'] as int? ?? 25;
        } catch (e) {
          // 忽略读取错误，使用默认值
        }
      }

      // 转换操作题数据为存储格式
      final operationQuestionsData = <Map<String, dynamic>>[];
      if (operationQuestions != null) {
        for (int qIndex = 0; qIndex < operationQuestions.length; qIndex++) {
          final oq = operationQuestions[qIndex];
          // 转换初始文件（保留所有字段：文件名、文件路径、行号、期望内容、分值、内容、检查行）
          final initialFilesList = (oq['初始文件'] as List<dynamic>?)
                  ?.map((f) {
                    final fileData = <String, dynamic>{
                      '文件名': f['文件名']?.toString() ?? '',
                      '文件路径': f['文件路径']?.toString() ?? '',
                    };
                    // 保留行号
                    if (f['行号'] != null) {
                      fileData['行号'] = f['行号'];
                    }
                    // 保留期望内容
                    if (f['期望内容']?.toString().isNotEmpty == true) {
                      fileData['期望内容'] = f['期望内容'].toString();
                    }
                    // 保留分值
                    if (f['分值'] != null) {
                      fileData['分值'] = f['分值'];
                    }
                    // 检查行和内容都保存
                    if (f['检查行'] != null) {
                      fileData['检查行'] = f['检查行'];
                    }
                    if (f['内容']?.toString().isNotEmpty == true) {
                      fileData['内容'] = f['内容'].toString();
                    }
                    return fileData;
                  })
                  .toList() ??
              [];

          final questionData = <String, dynamic>{
            '题型': '操作题',
            '题号': '${qIndex + 1}',
            '题干': oq['题干'] ?? oq['questionText'] ?? '',
            '初始文件': initialFilesList,
          };
          // 不再添加总分到题目级别，分值已在检查行中

          operationQuestionsData.add(questionData);
        }
      }

      // 构建题库数据
      final bankData = {
        'version': '1.0',
        'name': bankName,
        'createdAt': DateTime.now().toIso8601String(),
        'examTimeLimit': finalExamTimeLimit,
        'earlySubmitMinutes': finalEarlySubmitMinutes,
        'choiceQuestions': choiceQuestionsData,
        'matchingQuestions': matchingQuestionsData,
        'sequentialQuestions': sequentialQuestionsData,
        'typingQuestions': typingQuestionsData,
        'operationQuestions': operationQuestionsData,
      };

      final jsonString = const JsonEncoder.withIndent('  ').convert(bankData);

      // 安全写入：临时文件 → flush → JSON 校验 → 原子 rename
      final tempFile = File('${jsonFile.path}.tmp');
      try {
        await tempFile.writeAsString(jsonString, flush: true);
        json.decode(await tempFile.readAsString());
        if (await jsonFile.exists()) {
          await jsonFile.delete();
        }
        await tempFile.rename(jsonFile.path);
      } catch (e) {
        print('保存题库JSON失败: $e');
        try {
          if (await tempFile.exists()) await tempFile.delete();
        } catch (_) {}
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 从题库读取连线题数据
  static Future<List<Map<String, dynamic>>> loadMatchingQuestionsFromBank(
      String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return [];
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final matchingQuestionsList =
          (data['matchingQuestions'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

      // 转换为应用内部格式
      final questions = <Map<String, dynamic>>[];

      for (int i = 0; i < matchingQuestionsList.length; i++) {
        final mq = matchingQuestionsList[i];

        // 检查是否为嵌套格式（有items数组）
        final nestedItems = mq['items'] as List<dynamic>?;

        if (nestedItems != null) {
          // 嵌套格式：直接读取items数组
          final items = <Map<String, dynamic>>[];
          for (final item in nestedItems) {
            final itemMap = item as Map<String, dynamic>;
            items.add({
              'leftText': itemMap['左侧内容'] ?? itemMap['leftText'] ?? '',
              'rightText': itemMap['右侧内容'] ?? itemMap['rightText'] ?? '',
              'leftImage': itemMap['左侧图片']?.toString().isNotEmpty == true
                  ? itemMap['左侧图片']
                  : null,
              'rightImage': itemMap['右侧图片']?.toString().isNotEmpty == true
                  ? itemMap['右侧图片']
                  : null,
              'score': itemMap['分值'] ?? '5',
            });
          }

          questions.add({
            'type': '连线题',
            'number': mq['题号']?.toString() ?? '${i + 1}',
            'questionText': mq['题干'] ?? '',
            'questionImage':
                mq['题干图片']?.toString().isNotEmpty == true ? mq['题干图片'] : null,
            'items': items,
            'score': mq['分值']?.toString() ?? '5',
          });
        } else {
          // 旧格式：每行一个item，需要按题号分组
          final questionGroups = <String, List<Map<String, dynamic>>>{};
          for (final row in matchingQuestionsList) {
            final questionNumber = row['题号']?.toString() ?? '1';
            questionGroups.putIfAbsent(questionNumber, () => []);
            questionGroups[questionNumber]!.add(row);
          }

          for (final entry in questionGroups.entries) {
            final rows = entry.value;
            if (rows.isEmpty) continue;

            final firstRow = rows[0];
            final items = <Map<String, dynamic>>[];
            String questionImage = '';
            String score = '5';

            for (int j = 0; j < rows.length; j++) {
              final row = rows[j];
              // 兼容中文和英文键名
              items.add({
                'leftText': row['左侧内容'] ?? row['左侧文本'] ?? '',
                'rightText': row['右侧内容'] ?? row['右侧文本'] ?? '',
                'leftImage': row['左侧图片']?.toString().isNotEmpty == true
                    ? row['左侧图片']
                    : null,
                'rightImage': row['右侧图片']?.toString().isNotEmpty == true
                    ? row['右侧图片']
                    : null,
              });

              if (j == 0) {
                questionImage = row['题干图片']?.toString() ?? '';
                score = row['分值']?.toString() ?? '5';
              }
            }

            questions.add({
              'type': '连线题',
              'number': entry.key,
              'questionText': firstRow['题干'] ?? '',
              'questionImage':
                  questionImage.isNotEmpty == true ? questionImage : null,
              'items': items,
              'score': score,
            });
          }
          break; // 旧格式已处理完
        }
      }

      return questions;
    } catch (e) {
      return [];
    }
  }

  /// 从题库读取顺序题数据
  static Future<List<Map<String, dynamic>>> loadSequentialQuestionsFromBank(
      String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return [];
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final sequentialQuestionsList =
          (data['sequentialQuestions'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

      // 转换为应用内部格式
      final questions = <Map<String, dynamic>>[];
      for (int i = 0; i < sequentialQuestionsList.length; i++) {
        final sq = sequentialQuestionsList[i];

        // 检查是否为嵌套格式（有items数组）
        final nestedItems = sq['items'] as List<dynamic>?;

        if (nestedItems != null) {
          // 嵌套格式：直接读取items数组
          final items = <Map<String, dynamic>>[];
          for (final item in nestedItems) {
            final itemMap = item as Map<String, dynamic>;
            items.add({
              'text': itemMap['待排序项目'] ?? '',
              'image': itemMap['项图片']?.toString().isNotEmpty == true
                  ? itemMap['项图片']
                  : null,
              'score': itemMap['分值'] ?? '5',
            });
          }

          questions.add({
            'type': '顺序题',
            'number': sq['题号']?.toString() ?? '${i + 1}',
            'questionText': sq['题干'] ?? '',
            'questionImage':
                sq['题干图片']?.toString().isNotEmpty == true ? sq['题干图片'] : null,
            'items': items,
            'score': sq['分值']?.toString() ?? '5',
          });
        } else {
          // 旧格式：每行一个item，需要按题号分组
          final questionGroups = <String, List<Map<String, dynamic>>>{};
          for (final row in sequentialQuestionsList) {
            final questionNumber = row['题号']?.toString() ?? '1';
            questionGroups.putIfAbsent(questionNumber, () => []);
            questionGroups[questionNumber]!.add(row);
          }

          for (final entry in questionGroups.entries) {
            final rows = entry.value;
            if (rows.isEmpty) continue;

            final firstRow = rows[0];
            final items = <Map<String, dynamic>>[];
            String questionImage = '';
            String score = '5';

            for (int j = 0; j < rows.length; j++) {
              final row = rows[j];
              items.add({
                'text': row['待排序项目'] ?? '',
                'image': row['项图片']?.toString().isNotEmpty == true
                    ? row['项图片']
                    : null,
              });

              if (j == 0) {
                questionImage = row['题干图片']?.toString() ?? '';
                score = row['分值']?.toString() ?? '5';
              }
            }

            questions.add({
              'type': '顺序题',
              'number': entry.key,
              'questionText': firstRow['题干'] ?? '',
              'questionImage':
                  questionImage.isNotEmpty == true ? questionImage : null,
              'items': items,
              'score': score,
            });
          }
          break; // 旧格式已处理完
        }
      }

      return questions;
    } catch (e) {
      return [];
    }
  }

  /// 从题库读取打字题数据
  static Future<List<Map<String, dynamic>>> loadTypingQuestionsFromBank(
      String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return [];
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final typingQuestionsList = (data['typingQuestions'] as List<dynamic>?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // 转换为应用内部格式
      final questions = <Map<String, dynamic>>[];
      for (int i = 0; i < typingQuestionsList.length; i++) {
        final tq = typingQuestionsList[i];
        questions.add({
          'type': '打字题',
          'number': tq['题号']?.toString() ?? '${i + 1}',
          'typingType': tq['打字类型'] ?? 'chinese',
          'referenceText': tq['参考文本'] ?? '',
          'timeLimit': tq['时间限制'] ?? 5,
          'score': tq['分值'] ?? 10,
        });
      }

      return questions;
    } catch (e) {
      return [];
    }
  }

  /// 从题库读取操作题数据
  static Future<List<Map<String, dynamic>>> loadOperationQuestionsFromBank(
      String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return [];
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      final operationQuestionsList =
          (data['operationQuestions'] as List<dynamic>?)
                  ?.cast<Map<String, dynamic>>() ??
              [];

      // 转换为应用内部格式
      final questions = <Map<String, dynamic>>[];
      for (int i = 0; i < operationQuestionsList.length; i++) {
        final oq = operationQuestionsList[i];

        // 转换初始文件（保留所有字段：文件名、文件路径、行号、期望内容、分值、内容、检查行）
        final initialFiles = (oq['初始文件'] as List<dynamic>?)
                ?.map((f) {
                  final file = <String, dynamic>{
                    '文件名': f['文件名']?.toString() ?? '',
                    '文件路径': f['文件路径']?.toString() ?? '',
                  };
                  // 读取行号
                  if (f['行号'] != null) {
                    file['行号'] = f['行号'];
                  }
                  // 读取期望内容
                  if (f['期望内容']?.toString().isNotEmpty == true) {
                    file['期望内容'] = f['期望内容'].toString();
                  }
                  // 读取分值
                  if (f['分值'] != null) {
                    file['分值'] = f['分值'];
                  }
                  // 检查行（原样保留，OperationFile.fromMap 能解析）
                  if (f['检查行'] is List) {
                    file['检查行'] = f['检查行'];
                  }
                  // 内容
                  if (f['内容']?.toString().isNotEmpty == true) {
                    file['内容'] = f['内容'].toString();
                  }
                  return file;
                })
                .toList() ??
            [];
        // 从检查行提取 answers（保留用于其他用途）
        final answers = <Map<String, dynamic>>[];
        for (final file in initialFiles) {
          final checkLines = file['检查行'] as List?;
          if (checkLines != null && checkLines.isNotEmpty) {
            for (final cl in checkLines) {
              final clMap = cl as Map<String, dynamic>;
              answers.add({
                'targetPath': file['文件路径']?.toString() ?? '',
                'lineNumber': clMap['行号'] is int
                    ? clMap['行号'] as int
                    : int.tryParse(clMap['行号']?.toString() ?? '1') ?? 1,
                'expectedContent': clMap['期望内容']?.toString() ?? '',
                'score': 5,
              });
            }
          }
        }

        questions.add({
          'type': '操作题',
          'number': oq['题号']?.toString() ?? '${i + 1}',
          'questionText': oq['题干'] ?? '',
          'score': oq['分值'] ?? 10,
          'initialFiles': initialFiles,
          'answers': answers,
        });
      }

      return questions;
    } catch (e) {
      print('加载操作题失败: $e');
      return [];
    }
  }

  /// 导出题库为 JSON 文件
  static Future<String?> exportQuestionBankToJson(
    String bankName,
    String exportPath,
  ) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return null;
      }

      await jsonFile.copy(exportPath);

      return exportPath;
    } catch (e) {
      return null;
    }
  }

  /// 从题库读取考试时间限制（分钟）
  static Future<int> loadExamTimeLimit(String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return 30; // 默认30分钟
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return data['examTimeLimit'] as int? ?? 30;
    } catch (e) {
      return 30; // 默认30分钟
    }
  }

  /// 从题库读取提前交卷时间（分钟）
  static Future<int> loadEarlySubmitMinutes(String bankName) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return 25; // 默认25分钟
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      return data['earlySubmitMinutes'] as int? ?? 25;
    } catch (e) {
      return 25; // 默认25分钟
    }
  }

  /// 保存提前交卷时间到题库
  static Future<bool> saveEarlySubmitMinutes(
      String bankName, int earlySubmitMinutes) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return false;
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      data['earlySubmitMinutes'] = earlySubmitMinutes;

      final newJsonString = const JsonEncoder.withIndent('  ').convert(data);
      await jsonFile.writeAsString(newJsonString, flush: true);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// 保存考试时间限制到题库
  static Future<bool> saveExamTimeLimit(
      String bankName, int examTimeLimit) async {
    try {
      final jsonFilePath = '$_rootDir/题库/$bankName/题库.json';
      final jsonFile = File(jsonFilePath);

      if (!await jsonFile.exists()) {
        return false;
      }

      final jsonString = await jsonFile.readAsString();
      final data = jsonDecode(jsonString) as Map<String, dynamic>;

      data['examTimeLimit'] = examTimeLimit;

      final newJsonString = const JsonEncoder.withIndent('  ').convert(data);
      await jsonFile.writeAsString(newJsonString, flush: true);

      return true;
    } catch (e) {
      return false;
    }
  }
}