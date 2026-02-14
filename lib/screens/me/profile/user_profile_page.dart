import 'package:flutter/material.dart';
import 'package:flutter_live/screens/me/me_screen.dart';
import '../../../store/user_store.dart';
import 'edit_profile_page.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _titleOpacityNotifier = ValueNotifier(0.0);

  final String _bgImage = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg";

  // 控制滚动的锁
  bool _isScrollLocked = false;

  // 模拟数据：index 0 有 4 个作品
  final List<int> _itemCounts = [14, 5, 3, 4];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _checkScrollLock();
      }
    });

    _scrollController.addListener(() {
      final offset = _scrollController.offset;
      double opacity = 0.0;
      if (offset <= 0) {
        opacity = 0.0;
      } else if (offset < 100) {
        opacity = 0.0;
      } else if (offset < 200) {
        opacity = (offset - 100) / 100;
      } else {
        opacity = 1.0;
      }
      if (_titleOpacityNotifier.value != opacity) {
        _titleOpacityNotifier.value = opacity;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollLock());
  }

  // 🟢 核心逻辑：计算高度
  void _checkScrollLock() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = MediaQuery.of(context).padding.top;
    final double navBarHeight = 44.0;

    // Header 总高度 = 350(图) + 46(Tab)
    double headerTotalHeight = 350.0 + 46.0;

    double contentHeight = 0;
    int count = _itemCounts[_tabController.index];

    if (count == 0) {
      contentHeight = 50;
    } else {
      double itemWidth = MediaQuery.of(context).size.width / 3;
      double itemHeight = itemWidth * (4 / 3);
      int rows = (count / 3).ceil();
      contentHeight = rows * itemHeight;
    }

    double totalScrollableHeight = headerTotalHeight + contentHeight + navBarHeight + topPadding;

    // 减去一些安全余量，确保计算准确
    bool shouldLock = totalScrollableHeight < (screenHeight + 10);

    if (_isScrollLocked != shouldLock) {
      setState(() {
        _isScrollLocked = shouldLock;
        if (_isScrollLocked && _scrollController.offset > 0) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _titleOpacityNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double navBarHeight = 44.0;
    const double tabBarHeight = 46.0;

    // 🟢 修复高度变矮问题：
    // 原始图片高度(350) + TabBar高度(46) = 396
    const double expandedHeight = 350.0 + tabBarHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NestedScrollView(
            controller: _scrollController,
            physics: ClampingLockScrollPhysics(isLocked: _isScrollLocked),
            headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
              return <Widget>[
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,

                  // 🟢 1. 恢复原有高度
                  // 设置为 396，减去底部的 Tab(46)，剩下的刚好是 350，和原来一模一样
                  expandedHeight: expandedHeight,
                  toolbarHeight: navBarHeight,
                  collapsedHeight: navBarHeight,

                  flexibleSpace: FlexibleSpaceBar(collapseMode: CollapseMode.pin, background: _buildHeaderContent()),

                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(tabBarHeight),
                    child: Container(
                      color: Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        indicatorColor: const Color(0xFFFFD700),
                        indicatorSize: TabBarIndicatorSize.label,
                        indicatorWeight: 3.0,
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        unselectedLabelStyle: const TextStyle(fontSize: 16),
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(vertical: 10),
                        dividerColor: Colors.transparent,
                        onTap: (_) {
                          setState(() {});
                          WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollLock());
                        },
                        tabs: const [Text("作品"), Text("推荐"), Text("收藏"), Text("喜欢")],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: Container(
              color: Colors.white,
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [_buildWorksGrid(), _buildEmptyPage("推荐为空"), _buildEmptyPage("暂时没有收藏"), _buildEmptyPage("喜欢的视频")],
              ),
            ),
          ),

          // 顶部导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _titleOpacityNotifier,
              builder: (context, opacity, child) {
                final iconColor = opacity > 0.5 ? Colors.black : Colors.white;
                return Container(
                  padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
                  height: topPadding + navBarHeight,
                  color: Colors.white.withOpacity(opacity),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: opacity,
                        child: const Text(
                          "个人中心",
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGlassCapsule(iconColor),
                          Row(
                            children: [
                              _buildGlassIcon(
                                Icons.search,
                                iconColor,
                                onTap: () {
                                  print("点击了搜索");
                                  // 这里可以执行跳转，例如：
                                  // Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchPage()));
                                },
                              ),
                              const SizedBox(width: 12),
                              _buildGlassIcon(
                                Icons.menu,
                                iconColor,
                                onTap: () {
                                  Map<String, dynamic> userProfile = UserStore.to.profile ?? {};
                                  Navigator.push(context, MaterialPageRoute(builder: (context) => MeScreen()));
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- 头部内容 ---
  Widget _buildHeaderContent() {
    return Stack(
      children: [
        // 背景图：撑满整个区域 (396高度)
        Positioned.fill(child: Image.network(_bgImage, fit: BoxFit.cover)),

        // 渐变遮罩
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 60,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.white.withOpacity(0.1), Colors.white],
              ),
            ),
          ),
        ),

        // 内容区域
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildAvatar(),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              UserStore.to.nickname,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black26)],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text("抖音号：${UserStore.to.userId}", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                const SizedBox(width: 4),
                                const Icon(Icons.content_copy, color: Colors.white70, size: 10),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildStat("185", "获赞"),
                      const SizedBox(width: 20),
                      _buildStat("27", "互关"),
                      const SizedBox(width: 20),
                      _buildStat("138", "关注"),
                      const SizedBox(width: 20),
                      _buildStat("32", "粉丝"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(UserStore.to.signature, style: const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    color: Colors.grey[100],
                    child: const Text("+ 添加性别等标签", style: TextStyle(color: Colors.grey, fontSize: 10)),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildToolItem(Icons.shopping_cart_outlined, "我的订单"),
                      _buildToolItem(Icons.history, "观看历史"),
                      _buildToolItem(Icons.account_balance_wallet_outlined, "我的钱包"),
                      _buildToolItem(Icons.person_search_outlined, "常访问的人"),
                      _buildToolItem(Icons.grid_view, "全部功能"),
                    ],
                  ),

                  // 🟢 2. 修复遮挡问题
                  // TabBar高度是 46，这里加 50px 的 padding，把图标顶上去
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- 辅助组件 ---
  Widget _buildWorksGrid() {
    return CustomScrollView(
      key: const PageStorageKey("works"),
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            return Container(
              color: Colors.grey[900],
              child: Image.network("https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_6.jpg", fit: BoxFit.cover),
            );
          }, childCount: _itemCounts[0]),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 1,
            crossAxisSpacing: 1,
            childAspectRatio: 3 / 4,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyPage(String text) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Container(
          color: Colors.white,
          alignment: Alignment.center,
          child: Text(text, style: const TextStyle(color: Colors.grey)),
        ),
      ),
    ],
  );

  Widget _buildAvatar() => SizedBox(
    width: 90,
    height: 90,
    child: Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            image: DecorationImage(image: NetworkImage(UserStore.to.avatar), fit: BoxFit.cover),
          ),
        ),
        Positioned(
          right: 0,
          bottom: 2,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 16),
          ),
        ),
      ],
    ),
  );

  // 🟢 图标颜色逻辑
  Widget _buildGlassCapsule(Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color == Colors.black ? Colors.grey[200] : Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Text(
          "添加朋友",
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  // 🟢 修改后的图标组件，支持点击
  Widget _buildGlassIcon(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap, // 绑定点击事件
      behavior: HitTestBehavior.opaque, // 确保点击区域友好
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color == Colors.black ? Colors.white : Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.black12),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  Widget _buildStat(String num, String text) => Row(
    children: [
      Text(
        num,
        style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ],
  );

  Widget _buildToolItem(IconData icon, String text) => Column(
    children: [
      Icon(icon, color: Colors.black87, size: 28),
      const SizedBox(height: 6),
      Text(text, style: const TextStyle(color: Colors.black87, fontSize: 11)),
    ],
  );
}

// 🟢 物理效果
class ClampingLockScrollPhysics extends ClampingScrollPhysics {
  final bool isLocked;

  const ClampingLockScrollPhysics({this.isLocked = false, super.parent});

  @override
  ClampingLockScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return ClampingLockScrollPhysics(isLocked: isLocked, parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (isLocked) {
      if (value > position.pixels && position.pixels >= 0) {
        return value - position.pixels;
      }
    }
    return super.applyBoundaryConditions(position, value);
  }
}
