import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'utils/app_path.dart';
import 'pages/dashboard_page.dart';
import 'pages/questions_page.dart';
import 'pages/statistics_page.dart';
import 'pages/tools_page.dart';
import 'pages/typing_control_page.dart';
import 'pages/student_management_page.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'providers/exam_provider.dart';
import 'providers/question_provider.dart';
import 'providers/statistics_provider.dart';
import 'providers/student_status_provider.dart';
import 'services/server_service.dart';
import 'services/http_server_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 启动 HTTP API 服务器（带超时保护）
  bool httpServerStarted = false;
  try {
    await HttpServerService.instance
        .startServer(20020)
        .timeout(const Duration(seconds: 10), onTimeout: () {
      print('警告: HTTP API 服务器启动超时（10秒），跳过');
    });
    httpServerStarted = true;
  } catch (e) {
    print('HTTP API 服务器启动失败: $e');
  }

  // 启动 Socket 服务（带超时保护）
  bool socketServerStarted = false;
  try {
    await ServerService.instance
        .startServer()
        .timeout(const Duration(seconds: 10), onTimeout: () {
      print('警告: Socket 服务器启动超时（10秒），跳过');
    });
    socketServerStarted = true;
  } catch (e) {
    print('Socket 服务器启动失败: $e');
  }

  // 如果服务器启动失败，显示警告（但不阻止应用运行）
  if (!httpServerStarted || !socketServerStarted) {
    print('警告: 部分服务器启动失败，部分功能可能不可用');
  }

  // 设置教师端激活标志
  try {
    HttpServerService.instance.setTeacherActive(true);
    ServerService.instance.setTeacherActive();
  } catch (e) {
    print('设置教师激活状态失败: $e');
  }

  // 初始化窗口管理器
  try {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1280, 720),
      center: true,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      minimumSize: const Size(1024, 600),
      title: '教师端',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  } catch (e) {
    print('窗口管理器初始化失败: $e');
  }

  runApp(const TeacherApp());
}

class TeacherApp extends StatelessWidget {
  const TeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 基于窗口尺寸计算字体缩放比例
    // 基准尺寸: 1280x7 20，缩放基准: 1.0
    final screenSize = MediaQuery.of(context).size;
    final baseWidth = 1280.0;
    final baseHeight = 720.0;

    // 取宽高缩放比例的平均值，确保字体缩放与窗口变化一致
    final scaleX = screenSize.width / baseWidth;
    final scaleY = screenSize.height / baseHeight;
    final scaleFactor = (scaleX + scaleY) / 2;

    // 限制缩放范围在 0.8 ~ 1.5 之间，避免字体过小或过大
    final clampedScale = scaleFactor.clamp(0.8, 1.5);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => ExamProvider()),
        ChangeNotifierProvider(create: (_) => QuestionProvider()),
        ChangeNotifierProvider(create: (_) => StatisticsProvider()),
        ChangeNotifierProvider(
          create: (_) {
            final provider = StudentStatusProvider();
            provider.startRefresh();
            return provider;
          },
        ),
      ],
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(clampedScale),
        ),
        child: MaterialApp(
          title: '教师端',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('zh', 'CN'),
            Locale('en', 'US'),
          ],
          locale: const Locale('zh', 'CN'),
          home: const MainNavigationPage(),
        ),
      ),
    );
  }
}

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 设置教师端激活标志
    _setTeacherActive();
    // 根据课表自动选择班级
    _autoSelectClassFromSchedule();
  }

  /// 根据课表自动选择班级
  Future<void> _autoSelectClassFromSchedule() async {
    try {
      // 读取课表文件
      final scheduleFile =
          File('${AppPath.projectRoot}/information/manage/schedule.json');
      if (!scheduleFile.existsSync()) {
        _setDefaultClass();
        return;
      }

      final content = await scheduleFile.readAsString();
      final data = json.decode(content) as Map<String, dynamic>;
      final periods = data['periods'] as List<dynamic>?;
      final days = data['days'] as Map<String, dynamic>?;

      if (periods == null || days == null) {
        _setDefaultClass();
        return;
      }

      // 获取当前星期几
      final now = DateTime.now();
      final weekdayMap = {1: '周一', 2: '周二', 3: '周三', 4: '周四', 5: '周五'};
      final todayLabel = weekdayMap[now.weekday];

      if (todayLabel == null) {
        // 周末，使用默认班级
        _setDefaultClass();
        return;
      }

      // 获取今天的课表
      final todaySchedule = days[todayLabel] as List<dynamic>?;
      if (todaySchedule == null || todaySchedule.isEmpty) {
        _setDefaultClass();
        return;
      }

      // 根据当前时间匹配节课
      final currentTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      for (int i = 0; i < periods.length && i < todaySchedule.length; i++) {
        final timeStr = periods[i]['time'] as String? ?? '';
        if (timeStr.isEmpty) continue;
        final parts = timeStr.split('-');
        if (parts.length != 2) continue;
        final startTime = parts[0].trim();
        final endTime = parts[1].trim();

        if (currentTime.compareTo(startTime) >= 0 &&
            currentTime.compareTo(endTime) < 0) {
          final className = todaySchedule[i]?.toString() ?? '';
          if (className.isNotEmpty) {
            print('课表自动选择班级: $className ($todayLabel $timeStr)');
            await _applyClass(className);
            return;
          }
        }
      }

      // 当前时间不在任何节课内，使用默认班级
      _setDefaultClass();
    } catch (e) {
      print('课表自动选择班级失败: $e');
      _setDefaultClass();
    }
  }

  /// 设置默认班级
  Future<void> _setDefaultClass() async {
    await _applyClass('初一01班');
  }

  /// 应用班级选择
  Future<void> _applyClass(String classLabel) async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.setSelectedClass(classLabel);

    try {
      // 直接调用 HttpServerService 内部方法，避免 HTTP 回环
      HttpServerService.instance.setActiveClass(classLabel);
      print('已设置活跃班级: $classLabel');
    } catch (e) {
      print('设置活跃班级失败: $e');
    }
  }

  Future<void> _setTeacherActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('teacher_active', true);

    // 直接调用 HttpServerService 内部方法，避免 HTTP 回环
    try {
      HttpServerService.instance.setTeacherActive(true);
      print('已通知后端：教师端已激活');
    } catch (e) {
      print('通知后端失败: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _clearTeacherActiveSync();
    }
  }

  /// 同步版本的清除（使用 then 链式调用，确保在进程退出前尽可能完成）
  void _clearTeacherActiveSync() {
    try {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('teacher_active', false);
      });
    } catch (e) {
      print('清除教师激活状态失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clearTeacherActive();
    super.dispose();
  }

  Future<void> _clearTeacherActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('teacher_active', false);
  }

  int _selectedIndex = 0;

  final List<NavigationItem> _navigationItems = [
    NavigationItem('首页', Icons.dashboard_outlined),
    NavigationItem('出题', Icons.edit_note_outlined),
    NavigationItem('统计', Icons.analytics_outlined),
    NavigationItem('学生端控制', Icons.keyboard_outlined),
    NavigationItem('学生管理', Icons.people_outline),
    NavigationItem('关于', Icons.info_outline),
  ];

  final List<Widget> _pages = [
    const DashboardPage(),
    const QuestionsPage(),
    const StatisticsPage(),
    const TypingControlPage(),
    const StudentManagementPage(),
    const ToolsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 侧边导航
          _buildSidebar(),
          // 主内容区
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 200,
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(245),
        border: Border.all(color: const Color(0xFFE5EEFB)),
      ),
      child: Column(
        children: [
          // 标题
          Container(
            padding: const EdgeInsets.all(20),
            child: const Text(
              '教师端',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          // 导航项
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _navigationItems.length,
              itemBuilder: (context, index) {
                final item = _navigationItems[index];
                final isSelected = _selectedIndex == index;
                return _buildNavItem(item, index, isSelected);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(NavigationItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 20,
              color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
            ),
            const SizedBox(width: 10),
            Text(
              item.label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: isSelected ? Colors.white : const Color(0xFF1E3A8A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NavigationItem {
  final String label;
  final IconData icon;

  NavigationItem(this.label, this.icon);
}
