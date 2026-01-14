import 'package:flutter/material.dart';
import 'package:flutter_live/screens/dashboard/active_user_screen.dart';
import 'package:flutter_live/screens/dashboard/active_user_top_screen.dart';
import 'package:flutter_live/screens/dashboard/school_board_screen.dart';
import 'package:flutter_live/screens/dashboard/school_management_screen.dart';
import 'package:flutter_live/screens/dashboard/stats_screen.dart';
import 'package:flutter_live/screens/dashboard/student_leaderboard_screen.dart';
import 'package:flutter_live/screens/dashboard/student_personal_dashboard_screen.dart';
import 'package:flutter_live/screens/dashboard/teacher_stats_screen.dart';
import 'package:flutter_live/screens/dashboard/grade_report_screen.dart';
import 'package:flutter_live/screens/home/live_list_page.dart';

class DashboardTabPage extends StatelessWidget {
  const DashboardTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 获取当前是否是深色模式，用于调整未选中文字的颜色
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          // 使用 title 放 TabBar
          title: SizedBox(
            height: 40,
            child: TabBar(
              // 【核心修改 1】开启滚动
              isScrollable: true,
              // 【核心修改 2】设置对齐方式 (Flutter 3.13+ 推荐)
              // 如果想居中显示用 TabAlignment.center，想靠左滑动用 TabAlignment.start
              tabAlignment: TabAlignment.center,

              indicatorSize: TabBarIndicatorSize.label,
              indicatorColor: Colors.blue,
              labelColor: Colors.blue,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey,

              // 开启滚动后，padding 很重要，防止标签挤在一起
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),

              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '直播列表'),
                Tab(text: '学生看板'),
                Tab(text: '用户活跃度看板'),
                Tab(text: '用户活跃Top榜'),
                // Tab(text: '个人看板'),
                // Tab(text: '经营看板'),
                // Tab(text: '成绩看板'),
                // Tab(text: '老师看板'),
                // Tab(text: '安宁校区'),
              ],
            ),
          ),
          centerTitle: true,
        ),
        body: const TabBarView(
          physics: NeverScrollableScrollPhysics(),
          children: [
            LiveListPage(),
            StatsScreen(),
            ActiveUserScreen(),
            ActiveUserTopScreen()
            // StudentPersonalDashboardScreen(),
            // SchoolManagementScreen(),
            // GradeReportScreen(),
            // StudentLeaderboardPage(),
            // TeacherStatsScreen(),
          ],
        ),
      ),
    );
  }
}