import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/message/chat_detail_page.dart';
import 'package:flutter_live/screens/message/services/dm_service.dart';
import 'package:flutter_live/screens/message/services/dm_socket_service.dart';
import 'package:flutter_live/screens/message/services/dm_unread_notifier.dart';
import 'package:flutter_live/screens/login/login_page.dart';
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

class _UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  static const double _meHeaderHeight = 278.0;
  static const double _otherHeaderHeight = 318.0;
  static const double _profileTagSlotHeight = 28.0;

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _titleOpacityNotifier = ValueNotifier(0.0);
  final String _defaultBgImage =
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/common_profile_bg.jpg";

  // 🟢 核心滚动锁状态
  bool _isScrollLocked = false;

  // 下拉刷新状态
  bool _isRefreshing = false;
  late int _visitorCount = 0;

  final ValueNotifier<double> _pullNotifier = ValueNotifier(0.0);
  double _dragStartY = 0.0;

  List<dynamic> _worksList = [];
  bool _isLoadingWorks = true;
  bool _isSwitchingAccount = false;
  bool _isAnchorLive = false;
  int _relationStatus = 0; // 0-未关注, 1-已关注, 2-互相关注, -1-自己
  String _relationText = "关注";
  bool _isRelationLoading = false;

  Map<String, dynamic>? _remoteUserInfo;

  Map<String, dynamic>? get _effectiveUserInfo {
    if (isMe) return UserStore.to.profile;
    return _remoteUserInfo ?? widget.userInfo;
  }

  String? _readUserId(Map<String, dynamic>? info) {
    final userId = info?['userId']?.toString();
    if (userId != null && userId.isNotEmpty) return userId;
    final id = info?['id']?.toString();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  String _readString(String key, {String fallback = ''}) {
    final value = _effectiveUserInfo?[key]?.toString();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  bool get isMe {
    if (widget.userInfo == null) return true;
    return _readUserId(widget.userInfo) == UserStore.to.userId;
  }

  String get _fetchId {
    if (isMe) return UserStore.to.userId.toString();
    return _readUserId(_effectiveUserInfo) ?? "";
  }

  String get _displayAvatar =>
      isMe ? UserStore.to.avatar : _readString('avatar');

  String get _displayNickname =>
      isMe ? UserStore.to.nickname : _readString('nickname', fallback: '--');

  String get _displayUserId =>
      isMe ? UserStore.to.userId : (_readUserId(_effectiveUserInfo) ?? '--');

  String get _displaySignature =>
      isMe ? UserStore.to.signature : _readString('signature', fallback: '...');

  List<String> get _profileTags {
    final source = _effectiveUserInfo;
    if (source == null) return [];

    final tags = <String>[];
    final city = source['city']?.toString().trim();
    final ipLocation = source['ipLocation']?.toString().trim();
    final gender = _genderText(source['gender']);

    if (ipLocation != null && ipLocation.isNotEmpty) {
      tags.add('IP: $ipLocation');
    } else if (city != null && city.isNotEmpty) {
      tags.add(city);
    }
    if (gender != null) tags.add(gender);
    return tags;
  }

  String? _genderText(dynamic value) {
    final raw = value?.toString();
    if (raw == '1') return '男';
    if (raw == '2') return '女';
    return null;
  }

  String get _displayBgImage {
    if (isMe) return UserStore.to.profileBg;
    final profileBg = _readString('profileBg');
    return profileBg.isEmpty ? _defaultBgImage : profileBg;
  }

  Color get _dynamicBgColor {
    String? hexString = isMe
        ? UserStore.to.profileBgColor
        : _readString('profileBgColor');
    return _parseHexColor(hexString);
  }

  Color _parseHexColor(
    String? hexColor, {
    Color fallback = const Color(0xFF3BB5D3),
  }) {
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
    _tabController = TabController(length: 2, vsync: this);

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

    unawaited(_fetchRemoteUserInfo());

    if (!isMe) {
      // add visitor record
      unawaited(
        HttpUtil()
            .post("/api/user/visitor/record", data: {"targetUserId": _fetchId})
            .catchError((e) => debugPrint("记录访客失败: $e")), // 防止未捕获的异常报错
      );
      unawaited(_fetchRelationStatus());
    }
    _fetchUserWorks();
  }

  Future<void> _fetchRemoteUserInfo() async {
    final uid = _fetchId;
    if (uid.isEmpty) return;

    try {
      final data = await HttpUtil().get(
        "/api/user/info",
        params: {"userId": uid},
      );
      if (!mounted || data is! Map) return;

      final merged = <String, dynamic>{...?widget.userInfo};
      for (final entry in data.entries) {
        if (entry.value != null) {
          merged[entry.key.toString()] = entry.value;
        }
      }
      merged['userId'] = _readUserId(Map<String, dynamic>.from(merged)) ?? uid;
      merged['id'] = merged['id'] ?? merged['userId'];
      final isLive = merged['isLive']?.toString() == '1';

      if (isMe) {
        await UserStore.to.saveProfile(merged);
      }

      setState(() {
        _remoteUserInfo = merged;
        _isAnchorLive = isLive;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkScrollLock());
    } catch (e) {
      debugPrint("获取用户主页资料失败: $e");
    }
  }

  Future<void> _fetchUserWorks() async {
    final uid = _fetchId;
    if (uid.isEmpty) {
      if (mounted) setState(() => _isLoadingWorks = false);
      return;
    }

    try {
      var res = await HttpUtil().get(
        "/api/work/user_works",
        params: {"userId": uid},
      );

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

  Future<void> _showSwitchAccountSheet() async {
    if (_isSwitchingAccount) return;

    final currentProfile = UserStore.to.profile;
    if (UserStore.to.token.isNotEmpty && currentProfile != null) {
      await UserStore.to.saveLoginSession(
        token: UserStore.to.token,
        profile: currentProfile,
      );
    }
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        int? switchingUserId;
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> handleSwitch(Map<String, dynamic> account) async {
              final userId = int.tryParse(account['id']?.toString() ?? '');
              if (userId == null ||
                  userId <= 0 ||
                  account['isCurrent'] == true) {
                return;
              }

              setModalState(() => switchingUserId = userId);
              await _switchAccount(userId.toString(), sheetContext);
              if (sheetContext.mounted) {
                setModalState(() => switchingUserId = null);
              }
            }

            Future<void> handleAddAccount() async {
              Navigator.of(sheetContext).pop();
              final loggedIn = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => const LoginPage(returnAfterLogin: true),
                ),
              );
              if (loggedIn == true && mounted) {
                _refreshAfterAccountChanged();
              }
            }

            final accounts = UserStore.to.loggedInAccounts.map((item) {
              final profile = Map<String, dynamic>.from(item['profile'] as Map);
              final profileUserId =
                  profile['id']?.toString() ??
                  profile['userId']?.toString() ??
                  "";
              profile['isCurrent'] = profileUserId == UserStore.to.userId;
              return profile;
            }).toList();

            return Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.68,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1E1E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "切换账号",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        18 + MediaQuery.of(context).padding.bottom,
                      ),
                      itemBuilder: (context, index) {
                        if (index == accounts.length) {
                          return _buildAddAccountItem(handleAddAccount);
                        }
                        final account = accounts[index];
                        final userId = int.tryParse(
                          account['id']?.toString() ?? '',
                        );
                        final isCurrent = account['isCurrent'] == true;
                        final isSwitching =
                            userId != null && switchingUserId == userId;
                        return _buildSwitchAccountItem(
                          account: account,
                          isCurrent: isCurrent,
                          isSwitching: isSwitching,
                          onTap: () => handleSwitch(account),
                        );
                      },
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemCount: accounts.length + 1,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _switchAccount(String userId, BuildContext sheetContext) async {
    if (_isSwitchingAccount) return;

    setState(() => _isSwitchingAccount = true);
    try {
      final switched = await UserStore.to.switchToCachedAccount(userId);
      if (!switched) throw Exception("本地没有这个账号的登录缓存");

      if (!mounted) return;
      _refreshAfterAccountChanged();

      if (sheetContext.mounted) Navigator.of(sheetContext).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("已切换到 ${UserStore.to.nickname}")));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("切换账号失败: $e")));
    } finally {
      if (mounted) setState(() => _isSwitchingAccount = false);
    }
  }

  void _refreshAfterAccountChanged() {
    DmSocketService.instance.disconnect();
    UserStore.to.forceUpdateAvatar();
    DmSocketService.instance.connect();
    globalDmUnreadRefreshNotifier.value++;

    setState(() {
      _visitorCount = 0;
      _worksList = [];
      _isLoadingWorks = true;
    });
    unawaited(UserService.syncUserInfo());
    unawaited(fetchUnreadVisitorCount());
    unawaited(_fetchUserWorks());
  }

  Future<void> _openPrivateChat() async {
    final targetId = int.tryParse(_fetchId);
    if (targetId == null || targetId <= 0 || isMe) return;

    try {
      final conversation = await DmService.getOrCreateConversation(
        targetId: targetId,
        targetName: _displayNickname,
        targetAvatar: _displayAvatar,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatDetailPage(conversation: conversation),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("打开私信失败: $e")));
    }
  }

  Future<void> _fetchRelationStatus() async {
    final targetId = _fetchId;
    if (targetId.isEmpty || isMe) return;

    try {
      final data = await HttpUtil().get(
        "/api/relation/status",
        params: {"targetId": targetId},
      );
      if (!mounted || data == null) return;
      setState(() {
        _relationStatus = data["status"] ?? 0;
        _relationText = data["text"] ?? "关注";
        _isRelationLoading = false;
      });
    } catch (e) {
      debugPrint("获取关系状态失败: $e");
      if (mounted) {
        setState(() => _isRelationLoading = false);
      }
    }
  }

  Future<void> _toggleFollowFromProfile() async {
    final targetId = _fetchId;
    if (_isRelationLoading || targetId.isEmpty || isMe) return;

    setState(() => _isRelationLoading = true);
    try {
      if (_relationStatus == 0) {
        await HttpUtil().post(
          "/api/relation/follow",
          data: {"targetId": targetId},
        );
      } else {
        await HttpUtil().post(
          "/api/relation/unfollow",
          data: {"targetId": targetId},
        );
      }
      await _fetchRelationStatus();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRelationLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("操作失败: $e")));
    }
  }

  // 🌟 终极版：极其精准的高度计算与防误锁逻辑
  void _checkScrollLock() {
    if (!mounted) return;

    final double screenHeight = MediaQuery.of(context).size.height;
    final double topPadding = MediaQuery.of(context).padding.top;

    // 🟢 核心修复1：使用 viewPadding 获取最真实的底部安全区高度！
    // 穿透父级 Scaffold 的吞噬，在苹果手机上稳稳拿到 34.0
    final double bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    // 🟢 完全对齐你 main.dart 里的物理底部高度
    final double customBottomBarHeight = 50.0 + bottomPadding;

    // 真正可以显示内容的可视区高度
    final double realVisibleHeight = screenHeight - customBottomBarHeight;

    // 头部总高度 (背景区 + TabBar + 刘海屏)
    final double baseHeaderHeight = isMe ? _meHeaderHeight : _otherHeaderHeight;
    final double tabBarHeight = 46.0;
    final double headerExpandedHeight =
        baseHeaderHeight + tabBarHeight + topPadding;

    double contentHeight = 0;

    // 1. 动态判断每个 Tab 的真实高度
    if (_tabController.index == 0) {
      if (_isLoadingWorks || _worksList.isEmpty) {
        contentHeight = 0;
      } else {
        int count = _worksList.length;
        // 🟢 核心修复2：扣除掉网格间隙(2像素)，算出极其精准的单行高度
        double itemWidth = (MediaQuery.of(context).size.width - 2) / 3;
        double itemHeight = itemWidth * (4 / 3);
        int rows = (count / 3).ceil();
        contentHeight = (rows * itemHeight) + ((rows - 1) * 1.0);
      }
    } else {
      contentHeight = 0;
    }

    double totalHeight = headerExpandedHeight + contentHeight;

    // 🌟 终极修复3：引入 40 像素的“安全防误锁区”
    // 只要总高度距离可视区底部不到 40 像素 (比如第二行露了一半)，立刻强制解锁允许滑动！
    bool shouldLock = totalHeight <= (realVisibleHeight - 40);

    debugPrint(
      "====== 高度精准计算: 头部 $headerExpandedHeight + 内容 $contentHeight = 总计 $totalHeight. 可视高度: $realVisibleHeight => 锁定状态: $shouldLock ======",
    );

    if (_isScrollLocked != shouldLock) {
      setState(() {
        _isScrollLocked = shouldLock;
      });
      if (shouldLock &&
          _scrollController.hasClients &&
          _scrollController.offset > 0) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
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

    final double baseHeaderHeight = isMe ? _meHeaderHeight : _otherHeaderHeight;
    final double expandedHeight = baseHeaderHeight + tabBarHeight;

    // 🚀 终极杀招：直接使用系统的 NeverScrollableScrollPhysics (绝对禁止滚动)
    final ScrollPhysics scrollPhysics = _isScrollLocked
        ? const NeverScrollableScrollPhysics()
        : const ClampingScrollPhysics();

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
              if (_scrollController.hasClients &&
                  _scrollController.offset <= 0) {
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
                await Future.wait([
                  UserService.syncUserInfo(),
                  _fetchUserWorks(),
                ]);

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
              headerSliverBuilder:
                  (BuildContext context, bool innerBoxIsScrolled) {
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
                        flexibleSpace: FlexibleSpaceBar(
                          collapseMode: CollapseMode.pin,
                          background: _buildHeaderContent(),
                        ),
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
                              labelStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              unselectedLabelStyle: const TextStyle(
                                fontSize: 16,
                              ),
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(
                                vertical: 10,
                              ),
                              dividerColor: Colors.transparent,
                              onTap: (_) {
                                setState(() {});
                                WidgetsBinding.instance.addPostFrameCallback(
                                  (_) => _checkScrollLock(),
                                );
                              },
                              tabs: isMe
                                  ? const [Text("作品"), Text("喜欢")]
                                  : const [Text("作品"), Text("推荐")],
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
                          _buildEmptyPage("喜欢的视频", scrollPhysics),
                        ]
                      : [
                          _buildWorksGrid(scrollPhysics),
                          _buildEmptyPage("推荐为空", scrollPhysics),
                        ],
                ),
              ),
            ),
          ),

          // 2. 中层：下拉刷新悬浮圈
          ValueListenableBuilder<double>(
            valueListenable: _pullNotifier,
            builder: (context, pullRatio, child) {
              return AnimatedPositioned(
                duration: _isRefreshing
                    ? const Duration(milliseconds: 300)
                    : Duration.zero,
                curve: Curves.easeOutBack,
                top: topPadding + navBarHeight + (pullRatio * 25.0),
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: (pullRatio * 2.0).clamp(0.0, 1.0),
                  child: Center(
                    child: Transform.scale(
                      scale: _isRefreshing
                          ? 1.0
                          : (pullRatio * 0.5 + 0.5).clamp(0.5, 1.0),
                      child: Container(
                        width: 40,
                        height: 40,
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: _isRefreshing
                            ? const CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFFFD700),
                                ),
                              )
                            : Transform.rotate(
                                angle: pullRatio * 6.28,
                                child: const Icon(
                                  Icons.refresh,
                                  color: Color(0xFFFFD700),
                                  size: 24,
                                ),
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
                final double buttonOpacity = (1.0 - opacity * 2.5).clamp(
                  0.0,
                  1.0,
                );

                return Container(
                  padding: EdgeInsets.only(
                    top: topPadding,
                    left: 16,
                    right: 16,
                  ),
                  height: topPadding + navBarHeight,
                  color: Colors.white.withValues(alpha: opacity),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Opacity(
                        opacity: opacity,
                        child: Text(
                          isMe ? "个人中心" : _displayNickname,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                      ),

                      Positioned(
                        left: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isMe || Navigator.canPop(context)) ...[
                              _buildGlassIcon(
                                Icons.arrow_back_ios_new,
                                iconColor,
                                onTap: () => Navigator.pop(context),
                              ),
                              const SizedBox(width: 12),
                            ],
                            if (buttonOpacity > 0.0 && isMe)
                              IgnorePointer(
                                ignoring: buttonOpacity == 0.0,
                                child: Opacity(
                                  opacity: buttonOpacity,
                                  child: _buildGlassCapsule(
                                    "切换账号",
                                    iconColor,
                                    onTap: _showSwitchAccountSheet,
                                  ),
                                ),
                              ),
                            if (buttonOpacity > 0.0 && !isMe)
                              IgnorePointer(
                                ignoring: buttonOpacity == 0.0,
                                child: Opacity(
                                  opacity: buttonOpacity,
                                  child: _buildGlassCapsule("求更新", iconColor),
                                ),
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
                                        ? _buildVisitorCapsule(
                                            iconColor,
                                            _visitorCount,
                                          )
                                        : _buildGlassIcon(
                                            Icons.people_outline,
                                            iconColor,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const ProfileVisitorsPage(),
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                              ),

                            if (!isMe)
                              _buildGlassIcon(
                                Icons.search,
                                iconColor,
                                onTap: () {},
                              ),
                            if (isMe) ...[
                              const SizedBox(width: 12),
                              _buildGlassIcon(
                                Icons.menu,
                                iconColor,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MeScreen(),
                                    ),
                                  );
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
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
              ),
            ),
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
                  MaterialPageRoute(
                    builder: (context) => ShortVideoPage(workId: work['id']),
                  ),
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
                      const Center(
                        child: Icon(
                          Icons.video_library,
                          color: Colors.white38,
                          size: 30,
                        ),
                      ),

                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.favorite_border,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            likeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black38,
                                ),
                              ],
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
  Widget _buildEmptyPage(String text, ScrollPhysics physics) =>
      CustomScrollView(
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
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 86,
          height: 86,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isAnchorLive ? const Color(0xFFFF2E55) : Colors.white,
                width: _isAnchorLive ? 3 : 2,
              ),
              image: _displayAvatar.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(_displayAvatar),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _displayAvatar.isEmpty
                ? const CircularProgressIndicator(strokeWidth: 2)
                : null,
          ),
        ),
        if (_isAnchorLive)
          Positioned(
            left: 18,
            right: 18,
            bottom: 2,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2E55),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: const Text(
                  "直播中",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        if (isMe && !_isAnchorLive)
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
        final shouldRefresh = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileVisitorsPage()),
        );
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
          color: color == Colors.black
              ? Colors.white
              : Colors.black.withValues(alpha: 0.3),
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
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassCapsule(String text, Color color, {VoidCallback? onTap}) {
    final child = Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: color == Colors.black
            ? Colors.white
            : Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );

    if (onTap == null) return child;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }

  Widget _buildSwitchAccountItem({
    required Map<String, dynamic> account,
    required bool isCurrent,
    required bool isSwitching,
    required VoidCallback onTap,
  }) {
    final avatar = account['avatar']?.toString() ?? '';
    final nickname = account['nickname']?.toString() ?? '未命名账号';
    final accountId =
        account['accountId']?.toString() ?? account['id'].toString();
    final signature = account['signature']?.toString() ?? '';

    return Material(
      color: isCurrent ? const Color(0xFFFFF1F4) : const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isCurrent || isSwitching ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: const Color(0xFFEDEDED),
                backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
                child: avatar.isEmpty
                    ? const Icon(Icons.person, color: Colors.black38)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF2E55),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "当前",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      signature.isEmpty ? "抖音号：$accountId" : signature,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isSwitching)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  isCurrent ? Icons.check_circle : Icons.chevron_right,
                  color: isCurrent ? const Color(0xFFFF2E55) : Colors.black26,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddAccountItem(VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF7F7F7),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFECECEC),
                child: Icon(Icons.add, color: Color(0xFFFF2E55), size: 28),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  "添加账号",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassIcon(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color == Colors.black
              ? Colors.white
              : Colors.black.withValues(alpha: 0.3),
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
        style: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                      colors: const [
                        Colors.white,
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: isMe ? const [0, 0.46, 1] : const [0, 0.56, 1],
                    ).createShader(bounds);
                  },
                  blendMode: BlendMode.dstIn,
                  child: SizedBox.expand(
                    child: Image.network(
                      _displayBgImage,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                    ),
                  ),
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
                colors: [
                  Colors.transparent,
                  Colors.white.withValues(alpha: 0.5),
                  Colors.white,
                ],
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
                                shadows: [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  "抖音号：$_displayUserId",
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.content_copy,
                                  color: Colors.white70,
                                  size: 10,
                                ),
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
                  Text(
                    _displaySignature,
                    style: const TextStyle(color: Colors.black54, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  _buildProfileTags(),

                  if (!isMe) ...[
                    const SizedBox(height: 18),
                    _buildProfileActionRow(),
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

  Widget _buildProfileTags() {
    final tags = _profileTags;

    return SizedBox(
      height: _profileTagSlotHeight,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: tags.isEmpty
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(
                  children: tags.map((tag) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F3F3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF666666),
                          fontSize: 11,
                          height: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
    );
  }

  Widget _buildProfileActionRow() {
    final bool isFollowing = _relationStatus == 1 || _relationStatus == 2;
    final Color followBg = isFollowing
        ? const Color(0xFFF2F2F2)
        : const Color(0xFFFF2E55);
    final Color followFg = isFollowing ? Colors.black87 : Colors.white;

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isRelationLoading ? null : _toggleFollowFromProfile,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                disabledBackgroundColor: followBg,
                disabledForegroundColor: followFg,
                backgroundColor: followBg,
                foregroundColor: followFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: _isRelationLoading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(followFg),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isFollowing) ...[
                          const Icon(Icons.add, size: 22),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _relationText,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: const Color(0xFFF2F2F2),
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: _openPrivateChat,
            borderRadius: BorderRadius.circular(6),
            child: const SizedBox(
              width: 48,
              height: 44,
              child: Icon(
                Icons.near_me_rounded,
                color: Color(0xFF1F2430),
                size: 26,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
