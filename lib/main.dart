import 'package:flutter/material.dart';
import 'package:flutter_live/screens/dashboard_tabs.dart';
import 'package:flutter_live/screens/home/live_list_page.dart';
import 'package:flutter_live/screens/home/live_list_page1.dart';
import 'package:flutter_live/screens/home/live/index.dart';
import 'package:flutter_live/screens/login/login_page.dart';
import 'screens/course_screen.dart';
import 'screens/doc_screen.dart';
import 'screens/me_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      // 1. 设置跟随系统 (System)
      themeMode: ThemeMode.system,

      // 2. 定义亮色主题 (Light Mode)
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF8F9FB), // 浅灰背景
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
        scaffoldBackgroundColor: const Color(0xFF1B2339), // 深蓝背景
        cardColor: const Color(0xFF232D45), // 卡片深色
        dividerColor: Colors.white10,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF232D45),
          foregroundColor: Colors.white, // 标题文字白色
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.blue,
          onSurface: Colors.white,
          onSurfaceVariant: Colors.white70,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF232D45),
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),

      home: const LoginPage(),
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
    const LiveListPage(userId: '123123', userName: '123123',avatarUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/6e738b58d65d8b3685efffc4cdb9c2cd.png",level: "73",),
    // const CourseScreen(),
    // const DocScreen(),
    // const ExamListScreen(),
    const MeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '首页'),
          // BottomNavigationBarItem(icon: Icon(Icons.school), label: '训练'),
          // BottomNavigationBarItem(icon: Icon(Icons.school), label: '课程'),
          // BottomNavigationBarItem(icon: Icon(Icons.description), label: '文档'),
          // BottomNavigationBarItem(icon: Icon(Icons.message), label: '消息'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: '我'),
        ],
      ),
    );
  }
}