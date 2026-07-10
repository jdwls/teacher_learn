import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

/// 图片管理服务类
class ImageService {
  /// 获取题库根目录（当前工作目录下的题库文件夹）
  static String getQuestionBankRootDir() {
    return '${Directory.current.path}/题库';
  }

  /// 获取题库图片存储目录（当前工作目录下）
  static Future<String> getQuestionBankImageDir(String bankName) async {
    final imageDir = Directory('${getQuestionBankRootDir()}/$bankName/图片');
    if (!await imageDir.exists()) {
      await imageDir.create(recursive: true);
    }
    return imageDir.path;
  }

  /// 获取缓存目录
  static Future<String> getCacheDir() async {
    final cacheDir = await getTemporaryDirectory();
    final imageCacheDir = Directory('${cacheDir.path}/image_cache');
    if (!await imageCacheDir.exists()) {
      await imageCacheDir.create(recursive: true);
    }
    return imageCacheDir.path;
  }

  /// 从本地选择图片
  static Future<PlatformFile?> pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      return result?.files.firstOrNull;
    } catch (e) {
      print('ImageService: 选择图片失败: $e');
      return null;
    }
  }

  /// 生成唯一文件名
  /// 格式：{位置}_{时间戳}.{扩展名} 或 {位置}_{标题}.{扩展名}
  static String generateUniqueFileName({
    required String position, // 如 "题干", "A", "B", "C", "D"
    String? title,
    required String extension,
  }) {
    // 过滤非法字符
    String cleanTitle = '';
    if (title != null && title.isNotEmpty) {
      cleanTitle = title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      if (cleanTitle.length > 20) {
        cleanTitle = cleanTitle.substring(0, 20);
      }
    }

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    if (cleanTitle.isNotEmpty) {
      return '${position}_${cleanTitle}_$timestamp.$extension';
    } else {
      return '${position}_$timestamp.$extension';
    }
  }

  /// 保存图片到题库目录
  /// 返回相对路径
  static Future<String?> saveImageToQuestionBank({
    required PlatformFile pickedFile,
    required String bankName,
    required String position,
    String? questionTitle,
  }) async {
    try {
      final imageDir = await getQuestionBankImageDir(bankName);
      final extension = pickedFile.extension ?? 'png';
      final fileName = generateUniqueFileName(
        position: position,
        title: questionTitle,
        extension: extension,
      );
      final targetPath = '$imageDir/$fileName';

      // 复制文件到目标目录
      final sourceFile = File(pickedFile.path!);
      await sourceFile.copy(targetPath);

      // 返回相对路径
      return '$bankName/图片/$fileName';
    } catch (e) {
      print('ImageService: 保存图片到题库失败: $e');
      return null;
    }
  }

  /// 获取图片的完整路径（基于当前工作目录）
  static String getImageFullPath(String relativePath) {
    return '${getQuestionBankRootDir()}/$relativePath';
  }

  /// 预览图片（用默认图片查看器打开）
  static Future<bool> previewImage(String fullPath) async {
    print('ImageService.previewImage: 完整路径 = $fullPath');
    print('ImageService.previewImage: 当前工作目录 = ${Directory.current.path}');

    try {
      final file = File(fullPath);

      // 先检查文件是否存在
      if (!await file.exists()) {
        print('ImageService.previewImage: 文件不存在');
        return false; // 文件不存在
      }

      print('ImageService.previewImage: 文件存在，准备打开');

      // Windows上使用cmd打开图片
      // 使用start命令打开图片
      final result = await Process.run(
        'cmd',
        ['/c', 'start', '""', fullPath],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      print('ImageService: 预览图片失败 (path: $fullPath): $e');
      return false;
    }
  }

  /// 删除图片文件
  static Future<bool> deleteImage(String fullPath) async {
    try {
      final file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('ImageService: 删除图片文件失败 (path: $fullPath): $e');
      return false;
    }
  }

  /// 删除题库中记录的图片
  static Future<bool> deleteQuestionBankImage(
      String bankName, String relativePath) async {
    try {
      final fullPath = getImageFullPath(relativePath);
      return await deleteImage(fullPath);
    } catch (e) {
      print(
          'ImageService: 删除题库图片失败 (bank: $bankName, path: $relativePath): $e');
      return false;
    }
  }

  /// 清理缓存
  static Future<void> clearCache() async {
    try {
      final cacheDir = await getCacheDir();
      final directory = Directory(cacheDir);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        await directory.create();
      }
    } catch (e) {
      print('ImageService: 清理缓存失败: $e');
    }
  }

  /// 将缓存图片复制到题库目录
  static Future<String?> copyFromCacheToQuestionBank({
    required String cachePath,
    required String bankName,
    required String position,
    String? questionTitle,
  }) async {
    print(
        'ImageService: 开始复制图片 - cachePath: $cachePath, bankName: $bankName, position: $position');

    try {
      // 检查源文件是否存在
      final sourceFile = File(cachePath);
      if (!await sourceFile.exists()) {
        print('ImageService: 源文件不存在 - $cachePath');
        return null;
      }

      // 获取目标目录
      final imageDir = await getQuestionBankImageDir(bankName);
      print('ImageService: 目标目录 - $imageDir');

      // 生成文件名
      final extension = cachePath.split('.').last;
      final fileName = generateUniqueFileName(
        position: position,
        title: questionTitle,
        extension: extension,
      );
      final targetPath = '$imageDir/$fileName';
      print('ImageService: 目标文件 - $targetPath');

      // 复制文件
      await sourceFile.copy(targetPath);

      // 验证文件是否复制成功
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        print('ImageService: 文件复制成功 - $targetPath');
        return '$bankName/图片/$fileName';
      } else {
        print('ImageService: 文件复制失败');
        return null;
      }
    } catch (e) {
      print('ImageService: 复制图片时出错 - $e');
      return null;
    }
  }

  /// 检查图片是否存在
  static Future<bool> imageExists(String relativePath) async {
    try {
      final fullPath = getImageFullPath(relativePath);
      return await File(fullPath).exists();
    } catch (e) {
      print('ImageService: 检查图片是否存在失败 (path: $relativePath): $e');
      return false;
    }
  }
}
