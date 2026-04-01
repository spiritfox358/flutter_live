import 'package:flutter/material.dart';
import 'package:flutter_live/screens/dashboard/ranking/user_ranking_page.dart';
import 'package:flutter_live/screens/home/home_tabs_page.dart';
import 'package:flutter_live/screens/login/login_page.dart';
import 'package:flutter_live/screens/me/profile/user_profile_page.dart';
import 'package:flutter_live/screens/message/message_page.dart';
import 'package:flutter_live/screens/works/publish_work_page.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:media_kit/media_kit.dart';

// 🟢 1. 定义全局的 navigatorKey
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final ValueNotifier<int> globalRefreshRecommendNotifier = ValueNotifier(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await UserStore.to.init();

  // 🟢 极其重要：初始化 media_kit 底层引擎！
  MediaKit.ensureInitialized();
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

    // 🟢 核心逻辑：判断当前是否是前两个 Tab (索引为 0 或 1)
    // final bool forceBlackBg = _currentIndex == 0 || _currentIndex == 1;
    final bool forceBlackBg = _currentIndex == 0;

    // 1. 动态计算背景色
    final Color navBgColor = forceBlackBg
        ? Colors
              .black87 // 前两个 Tab 永远纯黑
        : (isDark ? const Color(0xFF232D45) : Colors.white); // 其他 Tab 跟随系统主题

    // 2. 动态计算【未选中】的文字/图标颜色
    // 如果背景被强制变黑了，未选中的字必须变成半透明白色，否则亮色模式下会黑底黑字看不见
    final Color unselectedColor = forceBlackBg ? Colors.white54 : (isDark ? Colors.white70 : Colors.black54);

    // 3. 动态计算【选中】的文字/图标颜色
    // 沉浸式黑底时选中的字是纯白；普通白底时选中的字恢复成蓝色
    final Color selectedColor = forceBlackBg ? Colors.white : Colors.blue;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        height: 50 + MediaQuery.of(context).padding.bottom,
        decoration: BoxDecoration(
          color: navBgColor, // 👈 动态应用的背景色
          // 纯黑背景不需要顶部阴影，白/灰背景时才需要一点阴影区分界限
          boxShadow: forceBlackBg ? [] : [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -2))],
        ),
        child: SafeArea(
          // 因为我们已经在外层高度加了 padding.bottom，所以 SafeArea 这里底部不用重复增加安全区
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 注意：这里的 '榜单' 是基于你上传代码里的命名，可以随时改成 '朋友'
              _buildTextTab(0, '首页', selectedColor, unselectedColor),
              _buildTextTab(1, '榜单', selectedColor, unselectedColor),
              _buildIconTab(2, selectedColor, unselectedColor), // 中间加号
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
          // 👇 加入这段双击刷新的核心逻辑 👇
          if (index == 0 && _currentIndex == 0) {
            // 如果用户本来就在首页，再次点击首页 -> 发送刷新信号！
            globalRefreshRecommendNotifier.value++;
          }

          globalMainTabNotifier.value = index;
          setState(() => _currentIndex = index);
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 13.0), // 这里设置上间距，例如 10.0
            child: Text(
              label,
              style: TextStyle(color: isSelected ? selectedColor : unselectedColor, fontSize: 16, fontWeight: FontWeight.bold),
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
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 9.0), // 这里设置上间距，例如 10.0
            child: Icon(
              Icons.add_box_outlined,
              color: isSelected ? selectedColor : unselectedColor,
              size: 30, // 图标大小可调
            ),
          ),
        ),
      ),
    );
  }
}
