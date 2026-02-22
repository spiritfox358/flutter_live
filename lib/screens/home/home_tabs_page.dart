import 'package:flutter/material.dart';
import 'live_list_page.dart';
import 'my_anchor_list_page.dart';

class HomeTabsPage extends StatefulWidget {
  const HomeTabsPage({super.key});

  @override
  State<HomeTabsPage> createState() => _HomeTabsPageState();
}

class _HomeTabsPageState extends State<HomeTabsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ["推荐", "我的主播"];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        // 关键点1：防止列表滚动时 AppBar 变色出现分割线效果
        scrolledUnderElevation: 0,
        // 关键点2：让 Title 区域靠左
        centerTitle: false,
        // 减少默认的左侧边距，让 Tab 更靠左
        titleSpacing: 0,
        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          // 关键点3：Tab 左对齐 (Flutter 3.13+)
          tabAlignment: TabAlignment.start,
          // 关键点4：去掉 TabBar 底部默认的灰色分割线
          dividerColor: Colors.transparent,

          labelColor: const Color(0xFFFF0050),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF0050),
          indicatorSize: TabBarIndicatorSize.label,
          // 调整一下 label 的 padding，避免左边太挤
          padding: const EdgeInsets.symmetric(horizontal: 10),
          labelStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16),
          tabs: _tabs.map((e) => Tab(text: e)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // ← 添加这行，禁止滑动
        children: const [
          // Tab 1: 推荐
          LiveListPage(),
          // Tab 2: 我的主播
          MyAnchorListPage(),
        ],
      ),
    );
  }
}
