import 'dart:io';
import 'package:path/path.dart' as path;

/// 应用路径工具类
/// 解决打包后 Directory.current.path 返回工作目录而非exe目录的问题
class AppPath {
  static String? _projectRoot;

  /// 获取项目根目录（打包后为exe所在目录，开发时为项目源码目录）
  static String get projectRoot {
    if (_projectRoot != null) return _projectRoot!;

    // 判断是否为打包后的exe运行
    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;

    // 开发模式：优先使用工作目录（flutter run 时为项目根目录）
    var candidate = Directory.current.path;
    if (File(path.join(candidate, 'pubspec.yaml')).existsSync()) {
      _projectRoot = candidate;
    } else {
      // 从exe目录向上查找（build/windows/x64/runner/Debug -> 项目根目录）
      var dir = Directory(exeDir);
      while (dir.path != dir.parent.path) {
        final parentPath = dir.parent.path;
        if (File(path.join(parentPath, 'pubspec.yaml')).existsSync() &&
            Directory(path.join(parentPath, 'lib')).existsSync()) {
          _projectRoot = parentPath;
          break;
        }
        dir = dir.parent;
      }
      // 打包后部署：exe目录下有information目录且没有pubspec.yaml
      if (_projectRoot == null &&
          Directory(path.join(exeDir, 'information')).existsSync()) {
        _projectRoot = exeDir;
      }
      // 如果还是找不到，使用工作目录
      _projectRoot ??= Directory.current.path;
    }

    print('应用根目录: $_projectRoot');
    print('  exe路径: $exePath');
    print('  工作目录: ${Directory.current.path}');

    return _projectRoot!;
  }

  /// 【P21修复】information目录路径 - 使用 path.join 避免跨平台路径问题
  static String get informationDir => path.join(projectRoot, 'information');

  /// 【P21修复】题库目录路径 - 使用 path.join 避免跨平台路径问题
  static String get questionBankDir => path.join(projectRoot, '题库');

  /// 学生端在线升级文件目录
  ///
  /// 解析顺序（找到即用，都没有则用第一候选自动创建）：
  ///   1. 应用根目录下的 student_online_update     —— 生产部署（与 Teacher.exe 同级）
  ///   2. 应用根目录上一层的同名目录              —— 开发模式（仓库根，与 student/ teacher/ 平行）
  static String? _studentOnlineUpdateDir;

  static String get studentOnlineUpdateDir {
    if (_studentOnlineUpdateDir != null) return _studentOnlineUpdateDir!;
    final primary = path.join(projectRoot, 'student_online_update');
    final secondary = path.join(Directory(projectRoot).parent.path, 'student_online_update');
    for (final dir in [primary, secondary]) {
      if (Directory(dir).existsSync()) {
        _studentOnlineUpdateDir = dir;
        print('学生端升级包目录: $_studentOnlineUpdateDir');
        return dir;
      }
    }
    // 两处都不存在（如首次部署）：用主候选并自动创建
    Directory(primary).createSync(recursive: true);
    _studentOnlineUpdateDir = primary;
    print('学生端升级包目录不存在，已自动创建: $primary');
    return primary;
  }
}
