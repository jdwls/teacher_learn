import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

/// 文件选择结果
class FilePickResult {
  final String filePath;
  final String fileName;
  final String content;
  final int lineCount;
  final int fileSize;
  final String? cachePath; // 缓存路径（新增）

  FilePickResult({
    required this.filePath,
    required this.fileName,
    required this.content,
    required this.lineCount,
    required this.fileSize,
    this.cachePath,
  });
}

/// 文件信息
class FileInfo {
  final String fileName;
  final int lineCount;
  final int fileSize;
  final List<String> lines;

  FileInfo({
    required this.fileName,
    required this.lineCount,
    required this.fileSize,
    required this.lines,
  });
}

/// 文件选择服务
class FilePickerService {
  /// 允许的文件扩展名
  static const List<String> allowedExtensions = ['html', 'css', 'js', 'txt'];

  /// 选择单个文件
  static Future<FilePickResult?> pickSingleFile({
    List<String> allowedExtensions = allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      if (file.path == null) {
        return null;
      }

      // 读取文件内容
      final content = await readFileContent(file.path!);
      if (content == null) {
        return null;
      }

      // 获取文件信息
      final lineCount = content.split('\n').length;
      final fileSize = file.size;

      return FilePickResult(
        filePath: file.path!,
        fileName: file.name,
        content: content,
        lineCount: lineCount,
        fileSize: fileSize,
      );
    } catch (e) {
      print('选择文件失败: $e');
      return null;
    }
  }

  /// 选择多个文件
  static Future<List<FilePickResult>> pickMultipleFiles({
    List<String> allowedExtensions = allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: true,
      );

      if (result == null || result.files.isEmpty) {
        return [];
      }

      final results = <FilePickResult>[];
      for (final file in result.files) {
        if (file.path == null) continue;

        final content = await readFileContent(file.path!);
        if (content == null) continue;

        final lineCount = content.split('\n').length;
        final fileSize = file.size;

        results.add(FilePickResult(
          filePath: file.path!,
          fileName: file.name,
          content: content,
          lineCount: lineCount,
          fileSize: fileSize,
        ));
      }

      return results;
    } catch (e) {
      print('选择文件失败: $e');
      return [];
    }
  }

  /// 读取文件内容
  static Future<String?> readFileContent(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      print('读取文件失败: $e');
      return null;
    }
  }

  /// 获取文件信息（行数、大小、行列表）
  static Future<FileInfo?> getFileInfo(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final lines = content.split('\n');
      final lineCount = lines.length;
      final fileSize = await file.length();
      final fileName = filePath.split('\\').last.split('/').last;

      return FileInfo(
        fileName: fileName,
        lineCount: lineCount,
        fileSize: fileSize,
        lines: lines,
      );
    } catch (e) {
      print('获取文件信息失败: $e');
      return null;
    }
  }

  /// 操作题文件缓存目录
  static String? _operationCacheDir;
  static final _uuid = Uuid();

  /// 获取操作题缓存目录
  static String getOperationCacheDir() {
    if (_operationCacheDir == null) {
      _operationCacheDir = '${Directory.systemTemp.path}/operation_file_cache';
    }
    return _operationCacheDir!;
  }

  /// 选择文件并缓存（用于操作题）
  /// 返回包含缓存路径的文件选择结果
  static Future<FilePickResult?> pickAndCacheFile({
    List<String> allowedExtensions = allowedExtensions,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final file = result.files.first;
      if (file.path == null) {
        return null;
      }

      // 生成唯一的缓存目录
      final cacheId = _uuid.v4();
      final cacheDir = '${getOperationCacheDir()}/$cacheId';
      final cacheDirEntity = Directory(cacheDir);
      if (!await cacheDirEntity.exists()) {
        await cacheDirEntity.create(recursive: true);
      }

      // 复制文件到缓存目录
      final sourceFile = File(file.path!);
      final cachePath = '$cacheDir/${file.name}';
      await sourceFile.copy(cachePath);

      // 读取文件内容（用于行检查等）
      final content = await readFileContent(cachePath);
      if (content == null) {
        return null;
      }

      final lineCount = content.split('\n').length;
      final fileSize = file.size;

      print('文件已缓存到: $cachePath');

      return FilePickResult(
        filePath: file.path!,
        fileName: file.name,
        content: content,
        lineCount: lineCount,
        fileSize: fileSize,
        cachePath: cachePath,
      );
    } catch (e) {
      print('选择并缓存文件失败: $e');
      return null;
    }
  }

  /// 从缓存路径读取文件内容
  static Future<String?> readFromCache(String cachePath) async {
    try {
      final file = File(cachePath);
      if (!await file.exists()) {
        print('缓存文件不存在: $cachePath');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      print('读取缓存文件失败: $e');
      return null;
    }
  }

  /// 清理操作题缓存目录
  static Future<void> clearOperationCache() async {
    try {
      final cacheDir = Directory(getOperationCacheDir());
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        print('操作题缓存已清理');
      }
      _operationCacheDir = null;
    } catch (e) {
      print('清理缓存失败: $e');
    }
  }

  /// 删除单个缓存目录
  static Future<void> deleteCacheDir(String cachePath) async {
    try {
      if (cachePath.isEmpty) return;

      // 获取缓存目录路径（文件所在目录）
      final file = File(cachePath);
      final cacheDir = file.parent;

      if (await cacheDir.exists()) {
        // 只删除这个特定题目的缓存目录
        await cacheDir.delete(recursive: true);
        print('缓存目录已删除: ${cacheDir.path}');
      }
    } catch (e) {
      print('删除缓存目录失败: $e');
    }
  }

  /// 读取文件指定行及其上下文
  static Future<List<String>> readLineWithContext(
    String filePath,
    int lineNumber, {
    int contextLines = 1,
  }) async {
    try {
      final info = await getFileInfo(filePath);
      if (info == null) {
        return [];
      }

      final lines = info.lines;
      final result = <String>[];

      // 行号从1开始，转换为索引从0开始
      final targetIndex = lineNumber - 1;

      // 添加前面行
      for (int i = targetIndex - contextLines; i < targetIndex; i++) {
        if (i >= 0 && i < lines.length) {
          result.add(lines[i]);
        } else {
          result.add('');
        }
      }

      // 添加目标行
      if (targetIndex >= 0 && targetIndex < lines.length) {
        result.add(lines[targetIndex]);
      } else {
        result.add('');
      }

      // 添加后面行
      for (int i = targetIndex + 1; i <= targetIndex + contextLines; i++) {
        if (i >= 0 && i < lines.length) {
          result.add(lines[i]);
        } else {
          result.add('');
        }
      }

      return result;
    } catch (e) {
      print('读取行上下文失败: $e');
      return [];
    }
  }
}
