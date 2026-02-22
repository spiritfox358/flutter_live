import 'package:flutter/material.dart';
import 'package:flutter_live/screens/dashboard/ranking/user_ranking_page.dart';
import 'package:flutter_live/screens/home/home_tabs_page.dart';
import 'package:flutter_live/screens/login/login_page.dart';
import 'package:flutter_live/screens/me/profile/user_profile_page.dart';
import 'package:flutter_live/screens/message/message_page.dart';
import 'package:flutter_live/screens/works/publish_work_page.dart';
import 'package:flutter_live/store/user_store.dart';

// 🟢 1. 定义全局的 navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserStore.to.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // 🟢 2. 绑定 navigatorKey
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,

      // 1. 设置跟随系统 (System)
      themeMode: ThemeMode.system,
      // 1. 在这里设置全局滚动行为
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        physics: const ClampingScrollPhysics(), // 去掉弹跳
      ),
      // 2. 定义亮色主题 (Light Mode)
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        // 浅灰背景
        cardColor: Colors.white,
        dividerColor: Colors.grey[300],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black, // 标题文字黑色
          elevation: 1,
        ),
        colorScheme: const ColorScheme.light(
          primary: Colors.blue,
          onSurface: Colors.black87, // 主要文字
          onSurfaceVariant: Colors.black54, // 次要文字
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),

      // 3. 定义暗色主题 (Dark Mode)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B2339),
        // 深蓝背景
        cardColor: const Color(0xFF232D45),
        // 卡片深色
        dividerColor: Colors.white10,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF232D45),
          foregroundColor: Colors.white, // 标题文字白色
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(primary: Colors.blue, onSurface: Colors.white, onSurfaceVariant: Colors.white70),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF232D45),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),

      home: UserStore.to.isLogin ? const MainContainer() : const LoginPage(),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeTabsPage(),
    const UserRankingPage(),
    const PublishWorkPage(),
    const MessagePage(),
    const UserProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    globalMainTabNotifier.addListener(_onGlobalTabChanged);
  }

  void _onGlobalTabChanged() {
    if (mounted && _currentIndex != globalMainTabNotifier.value) {
      setState(() => _currentIndex = globalMainTabNotifier.value);
    }
  }

  @override
  void dispose() {
    globalMainTabNotifier.removeListener(_onGlobalTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedColor = Colors.blue;
    final unselectedColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 50 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF232D45) : Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTextTab(0, '首页', selectedColor, unselectedColor),
              _buildTextTab(1, '榜单', selectedColor, unselectedColor),
              _buildIconTab(2, selectedColor, unselectedColor),
              _buildTextTab(3, '消息', selectedColor, unselectedColor),
              _buildTextTab(4, '我', selectedColor, unselectedColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextTab(int index, String label, Color selectedColor, Color unselectedColor) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          globalMainTabNotifier.value = index;
          setState(() => _currentIndex = index);
        },
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? selectedColor : unselectedColor,
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconTab(int index, Color selectedColor, Color unselectedColor) {
    final isSelected = _currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          globalMainTabNotifier.value = index;
          setState(() => _currentIndex = index);
        },
        child: Center(
          child: Icon(
            Icons.add_box_outlined,
            color: isSelected ? selectedColor : unselectedColor,
            size: 30, // 图标大小可调
          ),
        ),
      ),
    );
  }
}
