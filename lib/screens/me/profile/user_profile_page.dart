import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/me/profile/me_screen.dart';
import 'package:flutter_live/services/user_service.dart';

import '../../../store/user_store.dart';
import '../../../tools/HttpUtil.dart';
import '../../works/short_video_page.dart';
import '../visitors/profile_visitors_page.dart';

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
  final String _defaultBgImage = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/common_profile_bg.jpg";

  // 🟢 核心滚动锁状态
  bool _isScrollLocked = false;

  // 下拉刷新状态
  bool _isRefreshing = false;
  late int _visitorCount = 0;

  final ValueNotifier<double> _pullNotifier = ValueNotifier(0.0);
  double _dragStartY = 0.0;

  List<dynamic> _worksList = [];
  bool _isLoadingWorks = true;

  bool get isMe {
    if (widget.userInfo == null) return true;
    return widget.userInfo!['userId']?.toString() == UserStore.to.userId?.toString();
  }

  String get _fetchId {
    if (isMe) return UserStore.to.userId.toString() ?? "";
    return widget.userInfo?['userId']?.toString() ?? widget.userInfo?['id']?.toString() ?? "";
  }

  String get _displayAvatar => isMe ? UserStore.to.avatar : (widget.userInfo?['avatar'] ?? '');

  String get _displayNickname => isMe ? UserStore.to.nickname : (widget.userInfo?['nickname'] ?? '--');

  String get _displayUserId => isMe ? UserStore.to.userId : (widget.userInfo?['id']?.toString() ?? '--');

  String get _displaySignature => isMe ? UserStore.to.signature : (widget.userInfo?['signature'] ?? '...');

  String get _displayBgImage => isMe ? UserStore.to.profileBg : (widget.userInfo?['profileBg'] ?? _defaultBgImage);

  Color get _dynamicBgColor {
    String? hexString = isMe ? UserStore.to.profileBgColor : widget.userInfo?['profileBgColor'];
    return _parseHexColor(hexString);
  }

  Color _parseHexColor(String? hexColor, {Color fallback = const Color(0xFF3BB5D3)}) {
    if (hexColor == null || hexColor.isEmpty) return fallback;
    try {
      final buffer = StringBuffer();
      if (hexColor.length == 6 || hexColor.length == 7) buffer.write('ff');
      buffer.write(hexColor.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (e) {
      return fallback;
    }
  }

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
    });

    if (!isMe) {
      // add visitor record
      unawaited(
        HttpUtil().post("/api/user/visitor/record", data: {"targetUserId": _fetchId}).catchError((e) => debugPrint("记录访客失败: $e")), // 防止未捕获的异常报错
      );
    }
    _fetchUserWorks();
  }

  Future<void> _fetchUserWorks() async {
    final uid = _fetchId;
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoadingWorks = false);
      return;
    }

    try {
      var res = await HttpUtil().get("/api/work/user_works", params: {"userId": uid});

      if (mounted) {
        setState(() {
          _worksList = (res as List<dynamic>?) ?? [];
          _isLoadingWorks = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollLock());
      }
    } catch (e) {
      debugPrint("获取作品列表失败: $e");
      if (mounted) {
        setState(() => _isLoadingWorks = false);
      }
    }
  }

  Future<void> fetchUnreadVisitorCount() async {
    final uid = _fetchId;
    if (uid.isEmpty) {
      return;
    }
    try {
      var unreadCount = await HttpUtil().get("/api/user/visitor/unread_count");
      if (mounted) {
        setState(() {
          _visitorCount = int.tryParse(unreadCount.toString())!;
        });
      }
    } catch (e) {
      debugPrint("clear fail: $e");
    }
  }

  // 🌟 终极版：极其精准的高度计算与锁定逻辑
  void _checkScrollLock() {
    if (!mounted) return;

    final double screenHeight = MediaQuery.of(context).size.height;
    // 🟢 修复1：获取底部安全区（如 iPhone 底部横条占用高度）
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    // 🟢 修复2：获取 Flutter 标准底部导航栏的高度 (一般是 56.0)
    final double bottomNavBarHeight = kBottomNavigationBarHeight;

    // 🟢 核心修复：算出扣除底部栏后，上方内容真正可以显示的高度区域
    final double realVisibleHeight = screenHeight - bottomNavBarHeight - bottomPadding;

    // 头部总高度 (背景区 + TabBar)
    final double headerExpandedHeight = (isMe ? 355.0 : 270.0) + 46.0;

    double contentHeight = 0;

    // 1. 动态判断每个 Tab 的真实高度
    if (_tabController.index == 0) {
      if (_isLoadingWorks || _worksList.isEmpty) {
        contentHeight = 0; // 加载中或空状态 -> 内部高度视为 0
      } else {
        // 精准计算出当前网格到底有多高
        int count = _worksList.length;
        double itemWidth = MediaQuery.of(context).size.width / 3;
        double itemHeight = itemWidth * (4 / 3);
        int rows = (count / 3).ceil();
        contentHeight = (rows * itemHeight) + ((rows - 1) * 1.0);
      }
    } else {
      // 推荐、收藏、喜欢 目前都是空白页 -> 内部高度视为 0
      contentHeight = 0;
    }

    // 总高度 = 头部 + 下方内容列表
    double totalHeight = headerExpandedHeight + contentHeight;

    // 🌟 核心判断修复：总高度是否小于等于【真实的可用可视高度】
    // (加了 5 像素的容错缓冲，防止浮点数精度导致差一丁点被卡住)
    bool shouldLock = totalHeight <= (realVisibleHeight + 5);

    debugPrint("====== 高度计算: 头部 $headerExpandedHeight + 内容 $contentHeight = 总计 $totalHeight. 真实可视高度: $realVisibleHeight => 是否锁定: $shouldLock ======");

    if (_isScrollLocked != shouldLock) {
      setState(() {
        _isScrollLocked = shouldLock;
      });
      // 如果当前已经被推上去了，但因为切换到了空白页触发了锁定，自动回滚下来
      if (shouldLock && _scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _titleOpacityNotifier.dispose();
    _pullNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.of(context).padding.top;
    const double navBarHeight = 44.0;
    const double tabBarHeight = 46.0;

    final double baseHeaderHeight = isMe ? 355.0 : 270.0;
    final double expandedHeight = baseHeaderHeight + tabBarHeight;

    // 🚀 终极杀招：直接使用系统的 NeverScrollableScrollPhysics (绝对禁止滚动)
    final ScrollPhysics scrollPhysics = _isScrollLocked ? const NeverScrollableScrollPhysics() : const ClampingScrollPhysics();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. 底层：监听物理拖拽
          Listener(
            onPointerDown: (event) {
              if (!isMe) return;
              if (_isRefreshing) return;
              _dragStartY = event.position.dy;
            },
            onPointerMove: (event) {
              if (!isMe) return;
              if (_isRefreshing) return;
              if (_scrollController.hasClients && _scrollController.offset <= 0) {
                double delta = event.position.dy - _dragStartY;
                if (delta > 0) {
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
              if (!isMe) return;
              if (_isRefreshing) return;

              if (_pullNotifier.value >= 1.0) {
                setState(() {
                  _isRefreshing = true;
                });
                _pullNotifier.value = 1.0;

                fetchUnreadVisitorCount();
                await Future.wait([UserService.syncUserInfo(), _fetchUserWorks()]);

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
              // 🌟 把它赋给外层协调器
              physics: scrollPhysics,
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
                      ? [
                          _buildWorksGrid(scrollPhysics),
                          _buildEmptyPage("推荐为空", scrollPhysics),
                          _buildEmptyPage("暂时没有收藏", scrollPhysics),
                          _buildEmptyPage("喜欢的视频", scrollPhysics),
                        ]
                      : [_buildWorksGrid(scrollPhysics), _buildEmptyPage("推荐为空", scrollPhysics)],
                ),
              ),
            ),
          ),

          // 2. 中层：下拉刷新悬浮圈
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
                            if (buttonOpacity > 0.0 && isMe)
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
                                              Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileVisitorsPage()));
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

  // --- 🌟 把它同步赋给内部的所有列表和空白页 ---
  Widget _buildWorksGrid(ScrollPhysics physics) {
    if (_isLoadingWorks) {
      return CustomScrollView(
        physics: physics,
        slivers: [
          SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400))),
          ),
        ],
      );
    }

    if (_worksList.isEmpty) {
      return _buildEmptyPage(isMe ? "你还没有发布作品" : "该用户还没有发布作品", physics);
    }

    return CustomScrollView(
      key: const PageStorageKey("works"),
      physics: physics,
      slivers: [
        SliverGrid(
          delegate: SliverChildBuilderDelegate((context, index) {
            final work = _worksList[index];
            final coverUrl = work['coverUrl'] ?? work['cover_url'] ?? '';
            final likeCount = work['likeCount'] ?? work['like_count'] ?? 0;

            return GestureDetector(
              onTap: () async {
                // 等待页面返回结果
                final bool? shouldRefresh = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ShortVideoPage(workId: work['id'])),
                );

                // 如果接收到 true，说明发生了删除或上下架，触发列表刷新
                if (shouldRefresh == true) {
                  _fetchUserWorks(); // 替换为你实际的列表刷新方法
                }
              },
              child: Container(
                color: Colors.grey[900],
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (coverUrl.isNotEmpty)
                      Image.network(coverUrl, fit: BoxFit.cover)
                    else
                      const Center(child: Icon(Icons.video_library, color: Colors.white38, size: 30)),

                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.favorite_border, color: Colors.white, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            likeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [Shadow(offset: Offset(0, 1), blurRadius: 2, color: Colors.black38)],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }, childCount: _worksList.length),
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

  // --- 🌟 把它同步赋给内部的所有列表和空白页 ---
  Widget _buildEmptyPage(String text, ScrollPhysics physics) => CustomScrollView(
    physics: physics,
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

  Widget _buildVisitorCapsule(Color color, int count) {
    return GestureDetector(
      onTap: () async {
        // 🟢 加上 async
        // 🟢 等待访客页返回的结果
        final shouldRefresh = await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileVisitorsPage()));
        Future.delayed(const Duration(milliseconds: 500), () {
          if (shouldRefresh == true && mounted) {
            fetchUnreadVisitorCount();
          }
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
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

  Widget _buildHeaderContent() {
    return Stack(
      children: [
        Positioned.fill(child: Container(color: _dynamicBgColor)),

        Positioned.fill(
          child: _displayBgImage.isNotEmpty
              ? ShaderMask(
                  shaderCallback: (Rect bounds) {
                    return LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [Colors.white, Colors.transparent, Colors.transparent],
                      stops: isMe ? const [0, 0.46, 1] : const [0, 0.56, 1],
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
                      _buildStat("0", "获赞"),
                      const SizedBox(width: 20),
                      _buildStat("0", "互关"),
                      const SizedBox(width: 20),
                      _buildStat("0", "关注"),
                      const SizedBox(width: 20),
                      _buildStat("0", "粉丝"),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(_displaySignature, style: const TextStyle(color: Colors.black54, fontSize: 14)),

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
}
