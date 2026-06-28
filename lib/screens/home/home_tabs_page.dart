import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_live/screens/home/feed/article_feed_page.dart';
import 'package:flutter_live/screens/home/home_following_feed_page.dart';
import 'live_list_page.dart';

class HomeTabsPage extends StatefulWidget {
  const HomeTabsPage({super.key});

  @override
  State<HomeTabsPage> createState() => _HomeTabsPageState();
}

class _HomeTabsPageState extends State<HomeTabsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // final List<String> _tabs = ["推荐", "直播", "我的主播","多人PK房间"];
  final List<String> _tabs = ["推荐", "直播", "关注"];
  // final List<String> _tabs = ["推荐", "直播", "我的主播"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);

    // 🟢 核心步骤 1：监听 Tab 切换，一滑动就触发重绘
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // 触发 build 方法重新计算 UI 状态
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkTheme = theme.brightness == Brightness.dark;

    // 🟢 推荐页已改为图文列表（浅色），不再需要黑底沉浸式
    const bool isImmersive = false;

    // 🟢 核心步骤 3：根据是否沉浸式，动态决定所有颜色和阴影
    // 如果是沉浸式：黑底、透明AppBar、白字、加阴影
    // 如果是其他页：跟随系统主题色（白/黑底）、去阴影
    final Color bgColor = isImmersive
        ? Colors.black
        : theme.scaffoldBackgroundColor;
    final Color appBarBgColor = isImmersive
        ? Colors.transparent
        : theme.scaffoldBackgroundColor;

    // 图标和选中的文字颜色（其他页如果是亮色模式就是黑色，暗黑模式就是白色）
    final Color iconAndTextColor = isImmersive
        ? Colors.white
        : (isDarkTheme ? Colors.white : Colors.black87);
    // 未选中的文字颜色
    final Color unselectedTextColor = isImmersive
        ? Colors.white70
        : Colors.grey;

    // 只有沉浸模式才需要文字和图标的阴影
    final List<Shadow>? shadows = isImmersive
        ? const [
            Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1)),
          ]
        : null;

    // 动态调整手机顶部的系统状态栏（时间、电量）颜色
    SystemChrome.setSystemUIOverlayStyle(
      isImmersive || isDarkTheme
          ? SystemUiOverlayStyle
                .light // 白色状态栏
          : SystemUiOverlayStyle.dark, // 黑色状态栏
    );

    return Scaffold(
      // 🟢 动态控制：只有在推荐页，视频才顶到刘海屏里面
      extendBodyBehindAppBar: isImmersive,
      backgroundColor: bgColor,

      appBar: AppBar(
        backgroundColor: appBarBgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,

        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          onTap: (index) {
            // 如果当前就在推荐页(0)，并且再次点击了推荐，触发刷新
            // if (index == 0 && _tabController.index == 0) {
            //   globalRefreshRecommendNotifier.value++; // 发送刷新信号
            // }
          },
          // 动态应用颜色
          labelColor: iconAndTextColor,
          unselectedLabelColor: unselectedTextColor,
          indicatorColor: iconAndTextColor,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3.0,
          padding: const EdgeInsets.symmetric(horizontal: 0),

          indicatorPadding: const EdgeInsets.only(
            top: 8, // ✅ 上边距
            bottom: 8, // ✅ 下边距
            left: 3, // 左边距
            right: 3, // 右边距
          ),
          // 动态应用阴影
          labelStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            shadows: shadows,
          ),
          unselectedLabelStyle: TextStyle(fontSize: 16, shadows: shadows),
          tabs: _tabs.map((e) => Tab(text: e)).toList(),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        // 这里如果你未来想要左右滑动切换 Tab，可以把 NeverScrollableScrollPhysics 删掉
        physics: const NeverScrollableScrollPhysics(),
        children: const [
          ArticleFeedPage(),
          LiveListPage(),
          HomeFollowingFeedPage(),
          // MyAnchorListPage(),
          // PKRealLayoutDemoPage(),
          // PKTestPage(),
        ],
      ),
    );
  }
}
