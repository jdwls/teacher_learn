import 'dart:io';

/// 操作题文件管理服务
class OperationFileManager {
  static final String _rootDir = Directory.current.path;

  /// 复制文件到题库操作题目录
  /// [sourceFilePath] 源文件路径
  /// [bankName] 题库名称
  /// [questionId] 题目ID（如 "题目1" 或 "1"）
  /// [fileType] 文件类型：'initial'（初始文件）或 'answer'（答案文件）
  /// 返回目标文件路径，失败返回 null
  static Future<String?> copyFileToQuestionBank(
    String sourceFilePath,
    String bankName,
    String questionId,
    String fileType,
  ) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        print('源文件不存在: $sourceFilePath');
        return null;
      }

      // 提取文件名
      final fileName = sourceFilePath.split('\\').last.split('/').last;

      // 构建目标目录路径
      // 格式：题库/{题库名}/操作题/{题目ID}/{fileType}/{文件名}
      final targetDir = '$_rootDir/题库/$bankName/操作题/$questionId/$fileType';
      final targetDirEntity = Directory(targetDir);
      if (!await targetDirEntity.exists()) {
        await targetDirEntity.create(recursive: true);
      }

      // 构建目标文件路径
      final targetPath = '$targetDir/$fileName';

      // 复制文件
      await sourceFile.copy(targetPath);

      print('文件已复制到: $targetPath');
      return targetPath;
    } catch (e) {
      print('复制文件失败: $e');
      return null;
    }
  }

  /// 获取题库中操作题文件路径
  static String getOperationFilePath(
    String bankName,
    String questionId,
    String fileType,
    String fileName,
  ) {
    return '$_rootDir/题库/$bankName/操作题/$questionId/$fileType/$fileName';
  }

  /// 获取操作题相对路径（用于JSON存储）
  static String getRelativePath(
    String questionId,
    String fileType,
    String fileName,
  ) {
    return '操作题/$questionId/$fileType/$fileName';
  }

  /// 删除操作题文件
  static Future<bool> deleteOperationFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        print('文件已删除: $filePath');
      }
      return true;
    } catch (e) {
      print('删除文件失败: $e');
      return false;
    }
  }

  /// 删除整个题目目录
  static Future<bool> deleteQuestionDirectory(
    String bankName,
    String questionId,
  ) async {
    try {
      final dirPath = '$_rootDir/题库/$bankName/操作题/$questionId';
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        print('题目目录已删除: $dirPath');
      }
      return true;
    } catch (e) {
      print('删除题目目录失败: $e');
      return false;
    }
  }

  /// 从相对路径读取文件内容
  static Future<String?> readFileContent(
    String bankName,
    String relativePath,
  ) async {
    try {
      final fullPath = '$_rootDir/题库/$bankName/$relativePath';
      final file = File(fullPath);
      if (!await file.exists()) {
        print('文件不存在: $fullPath');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      print('读取文件失败: $e');
      return null;
    }
  }

  /// 检查文件是否存在
  static Future<bool> fileExists(String bankName, String relativePath) async {
    try {
      final fullPath = '$_rootDir/题库/$bankName/$relativePath';
      final file = File(fullPath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }

  /// 获取题库操作题目录下的所有文件
  static Future<List<String>> listOperationFiles(
    String bankName,
    String questionId,
    String fileType,
  ) async {
    try {
      final dirPath = '$_rootDir/题库/$bankName/操作题/$questionId/$fileType';
      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        return [];
      }

      final files = <String>[];
      await for (final entity in dir.list()) {
        if (entity is File) {
          files.add(entity.path.split('\\').last.split('/').last);
        }
      }
      return files;
    } catch (e) {
      print('列出文件失败: $e');
      return [];
    }
  }

  /// 创建不完整的初始文件（删除指定行）
  /// [sourceFilePath] 源文件路径
  /// [targetFilePath] 目标文件路径
  /// [linesToRemove] 要删除的行号列表（从1开始）
  static Future<bool> createIncompleteFile(
    String sourceFilePath,
    String targetFilePath,
    List<int> linesToRemove,
  ) async {
    try {
      final sourceFile = File(sourceFilePath);
      if (!await sourceFile.exists()) {
        return false;
      }

      final content = await sourceFile.readAsString();
      final lines = content.split('\n');

      // 按行号降序排序，从后往前删除避免索引变化
      final sortedLines = linesToRemove.toList()
        ..sort((a, b) => b.compareTo(a));

      for (final lineNum in sortedLines) {
        final index = lineNum - 1; // 转换为0-based索引
        if (index >= 0 && index < lines.length) {
          lines[index] = ''; // 用空行替代，保持行号对应
        }
      }

      // 确保目标目录存在
      final targetFile = File(targetFilePath);
      final targetDir = targetFile.parent;
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      await targetFile.writeAsString(lines.join('\n'));
      return true;
    } catch (e) {
      print('创建不完整文件失败: $e');
      return false;
    }
  }
}
