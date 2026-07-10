import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as path;
import '../utils/app_path.dart';

/// 打字文章服务 - 从JSON文件加载文章
class TypingArticleService {
  static final String _rootDir = AppPath.projectRoot;
  static final String _assetsDir =
      path.join(_rootDir, 'information', 'type_articles');
  static final Random _random = Random();

  // 缓存文章列表
  static List<Map<String, dynamic>>? _chineseArticles;
  static List<Map<String, dynamic>>? _englishArticles;

  /// 加载中文文章列表
  static List<Map<String, dynamic>> _loadChineseArticles() {
    if (_chineseArticles != null) return _chineseArticles!;
    try {
      final file = File(path.join(_assetsDir, 'chinese_typing_articles.json'));
      if (!file.existsSync()) {
        print('中文打字文章JSON文件不存在: ${file.path}');
        return [];
      }
      final content = file.readAsStringSync();
      final decoded = json.decode(content);
      if (decoded is List) {
        _chineseArticles = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        _chineseArticles =
            (decoded['articles'] as List<dynamic>).cast<Map<String, dynamic>>();
      } else {
        _chineseArticles = [];
      }
      return _chineseArticles!;
    } catch (e) {
      print('加载中文打字文章失败: $e');
      return [];
    }
  }

  /// 加载英文文章列表
  static List<Map<String, dynamic>> _loadEnglishArticles() {
    if (_englishArticles != null) return _englishArticles!;
    try {
      final file = File(path.join(_assetsDir, 'english_typing_articles.json'));
      if (!file.existsSync()) {
        print('英文打字文章JSON文件不存在: ${file.path}');
        return [];
      }
      final content = file.readAsStringSync();
      final decoded = json.decode(content);
      if (decoded is List) {
        _englishArticles = decoded.cast<Map<String, dynamic>>();
      } else if (decoded is Map<String, dynamic>) {
        _englishArticles =
            (decoded['articles'] as List<dynamic>).cast<Map<String, dynamic>>();
      } else {
        _englishArticles = [];
      }
      return _englishArticles!;
    } catch (e) {
      print('加载英文打字文章失败: $e');
      return [];
    }
  }

  /// 根据类型获取文章列表
  static List<Map<String, dynamic>> _getArticles(String type) {
    if (type == 'chinese') {
      return _loadChineseArticles();
    } else {
      return _loadEnglishArticles();
    }
  }

  /// 刷新缓存（当文章库更新后调用）
  static void refreshCache() {
    _chineseArticles = null;
    _englishArticles = null;
  }

  /// 获取文章数量
  static Future<int> getArticleCount(String type) async {
    return _getArticles(type).length;
  }

  /// 获取随机一篇文章
  static Future<String?> getRandomArticle(String type) async {
    final articles = _getArticles(type);
    if (articles.isEmpty) return null;
    final article = articles[_random.nextInt(articles.length)];
    return article['content'] as String?;
  }

  /// 获取指定文章
  static Future<String?> getArticle(String type, int index) async {
    final articles = _getArticles(type);
    if (index < 0 || index >= articles.length) return null;
    return articles[index]['content'] as String?;
  }

  /// 获取所有文章列表（供API使用）
  static List<Map<String, dynamic>> getAllArticles(String type) {
    return _getArticles(type);
  }

  /// 保存文章列表到JSON文件
  static Future<bool> saveArticles(
      String type, List<Map<String, dynamic>> articles) async {
    try {
      final fileName = type == 'chinese'
          ? 'chinese_typing_articles.json'
          : 'english_typing_articles.json';
      final file = File(path.join(_assetsDir, fileName));
      final data = {
        'articles': articles,
      };
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(data));
      // 刷新缓存
      refreshCache();
      return true;
    } catch (e) {
      print('保存${type == 'chinese' ? '中文' : '英文'}打字文章失败: $e');
      return false;
    }
  }
}
