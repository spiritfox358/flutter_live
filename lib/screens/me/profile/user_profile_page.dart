import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/me/me_screen.dart';
import 'package:palette_generator/palette_generator.dart';
import '../../../store/user_store.dart';

class UserProfilePage extends StatefulWidget {
  final Map<String, dynamic>? userInfo;

  const UserProfilePage({super.key, this.userInfo});

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _titleOpacityNotifier = ValueNotifier(0.0);

  final String _defaultBgImage = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_13.jpg";

  // 控制滚动的锁
  bool _isScrollLocked = false;

  // 下拉刷新状态
  bool _isRefreshing = false;
  final int _visitorCount = 100;

  // 🌟 性能优化1：采用局部刷新，下拉时拒绝整个页面疯狂 setState 重绘
  final ValueNotifier<double> _pullNotifier = ValueNotifier(0.0);
  double _dragStartY = 0.0;

  Color _dynamicBgColor = const Color(0xFCFCFCFF);

  bool get isMe {
    if (widget.userInfo == null) return true;
    return widget.userInfo!['userId']?.toString() == UserStore.to.userId?.toString();
  }

  String get _displayAvatar => isMe ? UserStore.to.avatar : (widget.userInfo?['avatar'] ?? '');

  String get _displayNickname => isMe ? UserStore.to.nickname : (widget.userInfo?['nickname'] ?? '--');

  String get _displayUserId => isMe ? UserStore.to.userId : (widget.userInfo?['id']?.toString() ?? '--');

  String get _displaySignature => isMe ? UserStore.to.signature : (widget.userInfo?['signature'] ?? '...');

  String get _displayBgImage => isMe ? UserStore.to.profileBg : (widget.userInfo?['profileBg'] ?? _defaultBgImage);

  final List<int> _itemCounts = [14, 5, 3, 4];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: isMe ? 4 : 2, vsync: this);

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollLock();

      // 🌟 终极防卡顿优化：错峰执行！
      // 延迟 400 毫秒，避开 Navigator.push 的页面转场动画。
      // 等页面极其丝滑地进入并停稳后，再在背后偷偷提取颜色。
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) {
          _extractDominantColor();
        }
      });
    });
  }

  void _checkScrollLock() {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = MediaQuery.of(context).padding.top;
    const double navBarHeight = 44.0;

    double baseHeaderHeight = isMe ? 350.0 : 250.0;
    double headerTotalHeight = baseHeaderHeight + 46.0;

    double contentHeight = 0;
    int count = 0;
    if (_tabController.index < _itemCounts.length) {
      count = _itemCounts[_tabController.index];
    }

    if (count == 0) {
      contentHeight = 50;
    } else {
      double itemWidth = MediaQuery.of(context).size.width / 3;
      double itemHeight = itemWidth * (4 / 3);
      int rows = (count / 3).ceil();
      contentHeight = rows * itemHeight;
    }

    double totalScrollableHeight = headerTotalHeight + contentHeight + navBarHeight + topPadding;
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

  Future<void> _extractDominantColor() async {
    if (_displayBgImage.isEmpty) return;

    try {
      final PaletteGenerator generator = await PaletteGenerator.fromImageProvider(
        NetworkImage(_displayBgImage),
        // 🌟 性能优化2：将待分析的图像强行缩小为 60x60，提取瞬间完成，彻底告别卡顿！
        size: const Size(60, 60),
        maximumColorCount: 20,
      );

      if (mounted) {
        setState(() {
          _dynamicBgColor = generator.dominantColor?.color ?? generator.darkMutedColor?.color ?? const Color(0xFFD4C4FB);
        });
      }
    } catch (e) {
      debugPrint("提取图片颜色失败: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _titleOpacityNotifier.dispose();
    _pullNotifier.dispose(); // 别忘了释放
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double navBarHeight = 44.0;
    const double tabBarHeight = 46.0;

    final double baseHeaderHeight = isMe ? 350.0 : 285.0;
    final double expandedHeight = baseHeaderHeight + tabBarHeight;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 底层：监听物理拖拽
          Listener(
            onPointerDown: (event) {
              if (!isMe) return; // 🟢 需求2：如果是看别人的主页，直接掐断下拉动作
              if (_isRefreshing) return;
              _dragStartY = event.position.dy;
            },
            onPointerMove: (event) {
              if (!isMe) return; // 🟢 需求2：如果是看别人的主页，直接掐断下拉动作
              if (_isRefreshing) return;
              if (_scrollController.hasClients && _scrollController.offset <= 0) {
                double delta = event.position.dy - _dragStartY;
                if (delta > 0) {
                  // 🌟 只更新 Notifier 内部的值，不再调用 setState 导致页面崩溃式重绘
                  double ratio = delta / 120.0;
                  if (ratio > 1.5) ratio = 1.5;
                  _pullNotifier.value = ratio;
                } else {
                  _dragStartY = event.position.dy;
                }
              } else {
                _dragStartY = event.position.dy;
              }
            },
            onPointerUp: (event) async {
              if (!isMe) return; // 🟢 需求2：如果是看别人的主页，直接掐断下拉动作
              if (_isRefreshing) return;

              if (_pullNotifier.value >= 1.0) {
                setState(() {
                  _isRefreshing = true;
                });
                _pullNotifier.value = 1.0;

                await Future.delayed(const Duration(seconds: 1));

                if (mounted) {
                  setState(() {
                    _isRefreshing = false;
                  });
                  _pullNotifier.value = 0.0;
                }
              } else {
                _pullNotifier.value = 0.0;
              }
            },
            child: NestedScrollView(
              controller: _scrollController,
              physics: ClampingLockScrollPhysics(isLocked: _isScrollLocked),
              headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                return <Widget>[
                  SliverAppBar(
                    automaticallyImplyLeading: false,
                    pinned: true,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    backgroundColor: Colors.transparent,
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
                          tabs: isMe ? const [Text("作品"), Text("推荐"), Text("收藏"), Text("喜欢")] : const [Text("作品"), Text("推荐")],
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
                  children: isMe
                      ? [_buildWorksGrid(), _buildEmptyPage("推荐为空"), _buildEmptyPage("暂时没有收藏"), _buildEmptyPage("喜欢的视频")]
                      : [_buildWorksGrid(), _buildEmptyPage("推荐为空")],
                ),
              ),
            ),
          ),

          // 2. 中层：下拉刷新悬浮圈
          // 🌟 包裹 ValueListenableBuilder，滑动时只有这个小圈圈在独立重绘，性能爆表！
          ValueListenableBuilder<double>(
            valueListenable: _pullNotifier,
            builder: (context, pullRatio, child) {
              return AnimatedPositioned(
                duration: _isRefreshing ? const Duration(milliseconds: 300) : Duration.zero,
                curve: Curves.easeOutBack,
                top: topPadding + navBarHeight + (pullRatio * 25.0),
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: (pullRatio * 2.0).clamp(0.0, 1.0),
                  child: Center(
                    child: Transform.scale(
                      scale: _isRefreshing ? 1.0 : (pullRatio * 0.5 + 0.5).clamp(0.5, 1.0),
                      child: Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
                        ),
                        child: _isRefreshing
                            ? const CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)))
                            : Transform.rotate(
                                angle: pullRatio * 6.28,
                                child: const Icon(Icons.refresh, color: Color(0xFFFFD700), size: 24),
                              ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // 3. 顶层：导航栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<double>(
              valueListenable: _titleOpacityNotifier,
              builder: (context, opacity, child) {
                final iconColor = opacity > 0.5 ? Colors.black : Colors.white;

                // 🌟 核心微调：错频消失算法
                // 乘以 2.5 倍速！当 opacity 达到 0.4 的时候，按钮透明度就已经掉到 0 彻底消失了
                // 这样完美给中间即将显现的“个人中心”腾出空间，绝对不重叠！
                final double buttonOpacity = (1.0 - opacity * 2.5).clamp(0.0, 1.0);

                return Container(
                  padding: EdgeInsets.only(top: topPadding, left: 16, right: 16),
                  height: topPadding + navBarHeight,
                  color: Colors.white.withOpacity(opacity),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: opacity,
                        child: Text(
                          isMe ? "个人中心" : _displayNickname,
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe || Navigator.canPop(context)) ...[
                              _buildGlassIcon(Icons.arrow_back_ios_new, iconColor, onTap: () => Navigator.pop(context)),
                              const SizedBox(width: 12),
                            ],
                            // 🟢 左侧：应用加速消失透明度
                            if (buttonOpacity > 0.0)
                              IgnorePointer(
                                ignoring: buttonOpacity == 0.0,
                                child: Opacity(opacity: buttonOpacity, child: _buildGlassCapsule(isMe ? "添加朋友" : "求更新", iconColor)),
                              ),
                          ],
                        ),
                      ),

                      Positioned(
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 🟢 右侧访客图标：应用加速消失透明度
                            if (buttonOpacity > 0.0)
                              IgnorePointer(
                                ignoring: buttonOpacity == 0.0,
                                child: Opacity(
                                  opacity: buttonOpacity,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 12.0),
                                    child: _visitorCount > 0
                                        ? _buildVisitorCapsule(iconColor, _visitorCount)
                                        : _buildGlassIcon(
                                            Icons.people_outline,
                                            iconColor,
                                            onTap: () {
                                              print("点击了访客");
                                            },
                                          ),
                                  ),
                                ),
                              ),

                            _buildGlassIcon(Icons.search, iconColor, onTap: () {}),
                            if (isMe) ...[
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
                          ],
                        ),
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

  // --- 新增：带文字的访客胶囊按钮 ---
  Widget _buildVisitorCapsule(Color color, int count) {
    return GestureDetector(
      onTap: () {
        print("点击了访客记录");
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32, // 保持和旁边搜索框、菜单圆圈一样的高度
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          // 保持和圆圈图标一样的玻璃态底色方案
          color: color == Colors.black ? Colors.white : Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              "新访客$count",
              style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // --- 头部内容 ---
  Widget _buildHeaderContent() {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedContainer(duration: const Duration(milliseconds: 500), color: _dynamicBgColor),
        ),

        Positioned.fill(
          child: _displayBgImage.isNotEmpty
              ? ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.transparent, Colors.transparent],
                      stops: [0.1, 0.5, 1],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.network(_displayBgImage, fit: BoxFit.fitWidth, alignment: Alignment.topCenter),
                )
              : const SizedBox(),
        ),

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
                colors: [Colors.transparent, Colors.white.withOpacity(0.5), Colors.white],
              ),
            ),
          ),
        ),

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
                              _displayNickname,
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
                                Text("抖音号：$_displayUserId", style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                  Text(_displaySignature, style: const TextStyle(color: Colors.black54, fontSize: 13)),

                  if (isMe) ...[
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
                  ] else ...[
                    const SizedBox(height: 16),
                  ],

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
            image: _displayAvatar.isNotEmpty ? DecorationImage(image: NetworkImage(_displayAvatar), fit: BoxFit.cover) : null,
          ),
          child: _displayAvatar.isEmpty ? const CircularProgressIndicator(strokeWidth: 2) : null,
        ),
        if (isMe)
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

  Widget _buildGlassCapsule(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: color == Colors.black ? Colors.grey[200] : Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Text(
          text,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );

  Widget _buildGlassIcon(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
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
