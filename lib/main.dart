import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_live/screens/dashboard/ranking/user_ranking_page.dart';
import 'package:flutter_live/screens/home/home_tabs_page.dart';
import 'package:flutter_live/screens/login/login_page.dart';
import 'package:flutter_live/screens/message/services/dm_service.dart';
import 'package:flutter_live/screens/message/services/dm_socket_service.dart';
import 'package:flutter_live/screens/message/services/dm_unread_notifier.dart';
import 'package:flutter_live/screens/me/profile/user_profile_page.dart';
import 'package:flutter_live/screens/message/message_page.dart';
import 'package:flutter_live/screens/home/live/real_live_page.dart';
import 'package:flutter_live/screens/works/publish_work_page.dart';
import 'package:flutter_live/store/user_store.dart';
import 'package:flutter_live/tools/HttpUtil.dart';
import 'package:flutter_live/widgets/in_app_notification.dart';
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
  int _dmUnreadCount = 0;
  int _lastDmUnreadDeltaEvent = 0;
  StreamSubscription<DmSocketEvent>? _dmSocketSub;

  final List<Widget> _screens = [
    const HomeTabsPage(),
    const UserRankingPage(),
    const SizedBox.shrink(),
    const MessagePage(),
    const UserProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    globalMainTabNotifier.addListener(_onGlobalTabChanged);
    globalDmUnreadRefreshNotifier.addListener(_onDmUnreadRefreshRequested);
    globalDmUnreadDeltaNotifier.addListener(_onDmUnreadDeltaChanged);
    DmSocketService.instance.connect();
    _dmSocketSub = DmSocketService.instance.events.listen(_handleDmSocketEvent);
    unawaited(_loadDmUnreadCount());
  }

  void _onGlobalTabChanged() {
    if (mounted && _currentIndex != globalMainTabNotifier.value) {
      setState(() => _currentIndex = globalMainTabNotifier.value);
      if (globalMainTabNotifier.value == 3) {
        unawaited(_loadDmUnreadCount());
      }
    }
  }

  Future<void> _loadDmUnreadCount() async {
    try {
      final count = await DmService.getUnreadCount();
      if (mounted) {
        setState(() => _dmUnreadCount = count);
      }
    } catch (e) {
      debugPrint('获取私信未读数失败: $e');
    }
  }

  void _onDmUnreadRefreshRequested() {
    unawaited(_loadDmUnreadCount());
  }

  void _onDmUnreadDeltaChanged() {
    final next = globalDmUnreadDeltaNotifier.value;
    final delta = next - _lastDmUnreadDeltaEvent;
    _lastDmUnreadDeltaEvent = next;
    if (delta == 0 || !mounted) return;
    setState(() {
      _dmUnreadCount = (_dmUnreadCount + delta).clamp(0, 999);
    });
  }

  void _handleDmSocketEvent(DmSocketEvent event) {
    if (event.type == 'DM_RECEIVED') {
      unawaited(DmService.getConversations());
      if (_currentIndex != 3) {
        _showDmNotification(event);
      }
      if (mounted) {
        setState(() {
          _dmUnreadCount = event.unreadCount ?? (_dmUnreadCount + 1);
        });
      }
    } else if (event.type == 'DM_READ' || event.type == 'DM_READ_ACK') {
      unawaited(_loadDmUnreadCount());
    }
  }

  void _showDmNotification(DmSocketEvent event) {
    final message = event.message;
    if (message == null) return;

    final extra = _parseExtraData(message.extraData);
    final title = (extra['followerName'] ?? extra['senderName'] ?? '新私信')
        .toString();
    final avatar = (extra['followerAvatar'] ?? extra['senderAvatar'] ?? '')
        .toString();

    InAppNotification.showMessage(
      title: title,
      content: message.displayContent,
      avatar: avatar,
      onTap: () {
        globalMainTabNotifier.value = 3;
        if (mounted) {
          setState(() => _currentIndex = 3);
        }
      },
    );
  }

  Map<String, dynamic> _parseExtraData(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}
    return {};
  }

  @override
  void dispose() {
    globalMainTabNotifier.removeListener(_onGlobalTabChanged);
    globalDmUnreadRefreshNotifier.removeListener(_onDmUnreadRefreshRequested);
    globalDmUnreadDeltaNotifier.removeListener(_onDmUnreadDeltaChanged);
    _dmSocketSub?.cancel();
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
    final Color unselectedColor = forceBlackBg
        ? Colors.white54
        : (isDark ? Colors.white70 : Colors.black54);

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
          boxShadow: forceBlackBg
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
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
              _buildTextTab(
                3,
                '消息',
                selectedColor,
                unselectedColor,
                badgeCount: _dmUnreadCount,
              ),
              _buildTextTab(4, '我', selectedColor, unselectedColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextTab(
    int index,
    String label,
    Color selectedColor,
    Color unselectedColor, {
    int badgeCount = 0,
  }) {
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? selectedColor : unselectedColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -8,
                    right: -18,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Color(0xFFFF2E55),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: navBadgeBorderColor(index)),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color navBadgeBorderColor(int index) {
    if (_currentIndex == 0) return Colors.black87;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF232D45) : Colors.white;
  }

  Widget _buildIconTab(int index, Color selectedColor, Color unselectedColor) {
    return Expanded(
      child: InkWell(
        onTap: _showCreateSheet,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 9.0), // 这里设置上间距，例如 10.0
            child: Icon(
              Icons.add_box_outlined,
              color: unselectedColor,
              size: 30, // 图标大小可调
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF161616) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white60 : Colors.black54;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                _buildCreateAction(
                  icon: Icons.play_circle_fill_rounded,
                  title: '发布视频',
                  subtitle: '上传视频作品',
                  iconColor: const Color(0xFFFF2E55),
                  textColor: textColor,
                  subTextColor: subTextColor,
                  onTap: _openVideoPublisher,
                ),
                // TODO: 安全相关功能未完成，先隐藏开播按钮
                // const SizedBox(height: 8),
                // _buildCreateAction(
                //   icon: Icons.videocam_rounded,
                //   title: '我要开播',
                //   subtitle: '开始一场直播',
                //   iconColor: const Color(0xFFFF0050),
                //   textColor: textColor,
                //   subTextColor: subTextColor,
                //   onTap: _startLive,
                // ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color textColor,
    required Color subTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: subTextColor, size: 22),
          ],
        ),
      ),
    );
  }

  void _startLive() async {
    Navigator.of(context).pop();

    final String myUserId = UserStore.to.userId;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050))),
    );

    try {
      final res = await HttpUtil().post(
        "/api/room/start_live",
        data: {"anchorId": int.tryParse(myUserId) ?? 0, "title": UserStore.to.nickname, "coverImg": UserStore.to.avatar},
      );
      if (mounted) {
        Navigator.pop(context); // 关loading
        if (res != null) {
          final String assignedRoomId = res['roomId'].toString();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => RealLivePage(
                userId: myUserId,
                userName: UserStore.to.nickname,
                avatarUrl: UserStore.to.avatar,
                level: 0,
                isHost: true,
                roomId: assignedRoomId,
                roomType: LiveRoomType.normal,
                monthLevel: 0,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("开播失败: $e")));
    }
  }

  void _openVideoPublisher() {
    Navigator.of(context).pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const PublishWorkPage()));
  }
}
