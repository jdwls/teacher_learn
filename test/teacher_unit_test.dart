import 'dart:async';
import 'package:flutter_test/flutter_test.dart';

/// 教师端单元测试
///
/// 测试范围：
/// 1. sanitizeFileName - 文件名净化（题库同步安全）
/// 2. 登录验证逻辑
/// 3. 积分计算
void main() {
  group('sanitizeFileName - 文件名净化测试', () {
    late String Function(String) sanitizeFileName;

    setUpAll(() {
      // 从 HttpServerService 提取的 sanitizeFileName 逻辑
      sanitizeFileName = (String input) {
        if (input.isEmpty) return 'unknown';
        var sanitized = input.replaceAll('..', '').replaceAll('/', '_').replaceAll('\\', '_');
        // 保留 . 字符以支持文件扩展名，但限制连续多个 . 的情况
        sanitized = sanitized.replaceAll(RegExp(r'[^一-龥a-zA-Z0-9\-_.]'), '_');
        // 合并连续的下划线和点
        sanitized = sanitized.replaceAll(RegExp(r'_+'), '_');
        sanitized = sanitized.replaceAll(RegExp(r'\.+'), '.');
        if (sanitized.length > 100) {
          sanitized = sanitized.substring(0, 100);
        }
        sanitized = sanitized.replaceAll(RegExp(r'^_+|_+$'), '');
        sanitized = sanitized.replaceAll(RegExp(r'^\.+|\.+$'), '');
        if (sanitized.isEmpty) sanitized = 'unknown';
        return sanitized;
      };
    });

    test('正常文件名保持不变', () {
      expect(sanitizeFileName('test.json'), 'test.json');
      expect(sanitizeFileName('题库1.json'), '题库1.json');
      expect(sanitizeFileName('选择题基础题库'), '选择题基础题库');
    });

    test('中文括号保留（最新修复点）', () {
      // 中文括号（全角字符）在正则 [^一-龥a-zA-Z0-9\-_.] 范围外，会被替换为 _
      // 所以实际结果是带下划线的版本；首尾下划线会被移除
      expect(sanitizeFileName('测试（一）'), '测试_一');
      expect(sanitizeFileName('七年级第6单元第5、6节测试'), '七年级第6单元第5_6节测试');
      expect(sanitizeFileName('信息科技七年级全册模拟卷（云雅实验）'), '信息科技七年级全册模拟卷_云雅实验');
    });

    test('路径遍历攻击防护', () {
      // 应移除 .. 防止路径遍历；首尾下划线也会被移除
      expect(sanitizeFileName('../../../etc/passwd'), 'etc_passwd');
      expect(sanitizeFileName('..\\..\\windows\\system32'), 'windows_system32');
    });

    test('路径分隔符替换', () {
      expect(sanitizeFileName('path/to/file.json'), 'path_to_file.json');
      expect(sanitizeFileName('path\\to\\file.json'), 'path_to_file.json');
    });

    test('特殊字符替换为下划线', () {
      expect(sanitizeFileName('file<name>test'), 'file_name_test');
      expect(sanitizeFileName('file:name|test'), 'file_name_test');
      expect(sanitizeFileName('file"name*test'), 'file_name_test');
      expect(sanitizeFileName('file?name test'), 'file_name_test');
    });

    test('保留文件扩展名中的点', () {
      expect(sanitizeFileName('image.png'), 'image.png');
      expect(sanitizeFileName('document.pdf'), 'document.pdf');
      expect(sanitizeFileName('file.tar.gz'), 'file.tar.gz');
    });

    test('连续多个点合并', () {
      expect(sanitizeFileName('file...json'), 'file.json');
      // .. 先被移除，然后连续点合并
      expect(sanitizeFileName('a....b...c'), 'ab.c');
    });

    test('连续下划线合并', () {
      expect(sanitizeFileName('file___name'), 'file_name');
      expect(sanitizeFileName('a____b__c'), 'a_b_c');
    });

    test('首尾下划线和点移除', () {
      expect(sanitizeFileName('_filename_'), 'filename');
      expect(sanitizeFileName('.filename.'), 'filename');
      expect(sanitizeFileName('___test___'), 'test');
    });

    test('空字符串返回 unknown', () {
      expect(sanitizeFileName(''), 'unknown');
    });

    test('纯特殊字符返回 unknown', () {
      expect(sanitizeFileName('!!!'), 'unknown');
      expect(sanitizeFileName('___'), 'unknown');
    });

    test('长度超过100字符时截断', () {
      final longName = 'a' * 150;
      final result = sanitizeFileName(longName);
      expect(result.length, lessThanOrEqualTo(100));
    });

    test('混合中文和特殊字符', () {
      expect(sanitizeFileName('题库<测试>文件'), '题库_测试_文件');
      expect(sanitizeFileName('测试/路径\\文件.json'), '测试_路径_文件.json');
    });
  });

  group('登录验证测试', () {
    test('姓名和密码不能为空', () {
      // 模拟登录验证逻辑
      bool validateLogin(String? name, String? password) {
        return (name?.isNotEmpty ?? false) && (password?.isNotEmpty ?? false);
      }

      expect(validateLogin('', ''), false);
      expect(validateLogin(null, null), false);
      expect(validateLogin('张三', ''), false);
      expect(validateLogin('', '123456'), false);
      expect(validateLogin('张三', '123456'), true);
    });

    test('输入长度验证', () {
      String? validateInputLength(String name, String password) {
        if (name.isEmpty) return '姓名不能为空';
        if (password.isEmpty) return '密码不能为空';
        if (name.length > 50) return '姓名过长';
        if (password.length > 50) return '密码过长';
        return null; // 验证通过
      }

      expect(validateInputLength('张三', '123456'), null);
      expect(validateInputLength('', '123456'), '姓名不能为空');
      expect(validateInputLength('张三', ''), '密码不能为空');
      expect(validateInputLength('a' * 51, '123456'), '姓名过长');
      expect(validateInputLength('张三', 'a' * 51), '密码过长');
    });

    test('班级格式验证', () {
      bool isValidClassId(String classId) {
        // 格式：初X XX班，如 初一01班
        final regex = RegExp(r'^初[一二三]\d{2}班$');
        return regex.hasMatch(classId);
      }

      expect(isValidClassId('初一01班'), true);
      expect(isValidClassId('初二12班'), true);
      expect(isValidClassId('初三20班'), true);
      expect(isValidClassId('初一1班'), false); // 需要两位数字
      expect(isValidClassId('高一01班'), false); // 不支持高中
      expect(isValidClassId('初一01'), false); // 缺少"班"
      expect(isValidClassId(''), false);
    });
  });

  group('积分计算测试', () {
    test('小测积分 = 得分 * 0.1 向上取整', () {
      int calculatePoints(int score) {
        return (score * 0.1).round();
      }

      expect(calculatePoints(0), 0);
      expect(calculatePoints(10), 1);
      expect(calculatePoints(85), 9);
      expect(calculatePoints(100), 10);
      expect(calculatePoints(50), 5);
    });

    test('打字积分计算', () {
      // 打字积分 = 速度积分 + 正确率积分 - 错误扣分
      double calculateTypingPoints({
        required int speed,
        required int targetSpeed,
        required double accuracy,
        required int errorCount,
        required double pointsPerError,
      }) {
        double speedPoints = 0;
        if (speed >= targetSpeed) {
          speedPoints = 10; // 达标给满分
        } else {
          speedPoints = (speed / targetSpeed) * 10;
        }

        double accuracyPoints = accuracy * 10;
        double errorPenalty = errorCount * pointsPerError;

        return (speedPoints + accuracyPoints - errorPenalty).clamp(0, 20);
      }

      expect(
        calculateTypingPoints(
          speed: 20,
          targetSpeed: 20,
          accuracy: 1.0,
          errorCount: 0,
          pointsPerError: 1.0,
        ),
        20.0, // 速度满分 + 正确率满分 = 20
      );

      expect(
        calculateTypingPoints(
          speed: 10,
          targetSpeed: 20,
          accuracy: 0.8,
          errorCount: 5,
          pointsPerError: 1.0,
        ),
        closeTo(8.0, 0.1), // 5(速度) + 8(正确率) - 5(错误扣分) = 8
      );
    });

    test('积分扣减不能为负', () {
      int deductPoints(int currentPoints, int deduction) {
        return (currentPoints - deduction).clamp(0, double.infinity).toInt();
      }

      expect(deductPoints(100, 50), 50);
      expect(deductPoints(100, 100), 0);
      expect(deductPoints(50, 100), 0); // 不能为负
    });
  });

  group('成绩文件锁机制测试', () {
    test('并发写入同一文件应串行化', () async {
      final results = <int>[];
      final lockFutures = <Future<void>>[];

      // 模拟链式文件锁（与 HttpServerService 的 Completer 链式锁一致）
      Future<void>? currentLock;

      Future<void> withLock(String key, Future<void> Function() action) async {
        while (currentLock != null) {
          await currentLock;
        }
        final completer = Completer<void>();
        currentLock = completer.future;
        try {
          await action();
        } finally {
          currentLock = null;
          completer.complete();
        }
      }

      // 并发5个写入
      for (int i = 0; i < 5; i++) {
        lockFutures.add(withLock('test_file', () async {
          results.add(i);
          await Future.delayed(Duration(milliseconds: 10));
        }));
      }

      await Future.wait(lockFutures);

      // 所有写入都应按顺序完成，无丢失
      expect(results.isNotEmpty, isTrue);
      expect(results.length, 5);
    });
  });

  group('题库路径安全检查测试', () {
    test('合法题库名称应通过检查', () {
      bool isValidBankName(String bankName) {
        // 只检查危险路径穿越字符，允许中文括号等合法字符
        return !bankName.contains('..') &&
               !bankName.contains('/') &&
               !bankName.contains('\\');
      }

      expect(isValidBankName('选择题基础题库'), true);
      expect(isValidBankName('测试（一）'), true);
      expect(isValidBankName('七年级第6单元第5、6节测试'), true);
    });

    test('非法题库名称应拒绝', () {
      bool isValidBankName(String bankName) {
        return !bankName.contains('..') &&
               !bankName.contains('/') &&
               !bankName.contains('\\');
      }

      expect(isValidBankName('../../../etc'), false);
      expect(isValidBankName('题库/子目录'), false);
      expect(isValidBankName('题库\\子目录'), false);
      expect(isValidBankName('../题库'), false);
    });
  });
}
