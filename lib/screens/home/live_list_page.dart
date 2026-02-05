import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/real_live_page.dart';
import 'package:flutter_live/store/user_store.dart';
import '../../services/update_manager.dart';
import '../../tools/HttpUtil.dart';

// AnchorInfo 模型
class AnchorInfo {
  final String roomId;
  final String name;
  final String avatarUrl;
  final String title;
  final bool isLive;
  final int roomMode;
  final String? pkStartTime;
  final int pkDuration;
  final int punishmentDuration;
  final int myScore;
  final int opScore;
  final int bossIndex;
  final int bgIndex;

  AnchorInfo({
    required this.roomId,
    required this.name,
    required this.avatarUrl,
    required this.title,
    required this.isLive,
    this.roomMode = 0,
    this.pkStartTime,
    this.pkDuration = 90,
    this.punishmentDuration = 20,
    this.myScore = 0,
    this.opScore = 0,
    this.bossIndex = 0,
    this.bgIndex = 0,
  });

  factory AnchorInfo.fromJson(Map<String, dynamic> json) {
    return AnchorInfo(
      roomId: json['id'].toString(),
      name: json['title'] ?? "未知主播",
      avatarUrl: json['coverImg'] ?? "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/live_bg_1.jpg",
      title: json['aiPersona'] ?? "暂无介绍",
      isLive: (json['status'] == 1 || json['status'] == "1"),
      roomMode: int.tryParse(json['roomMode']?.toString() ?? "0") ?? 0,
    );
  }
}

class LiveListPage extends StatefulWidget {
  const LiveListPage({super.key});

  @override
  State<LiveListPage> createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> {
  List<AnchorInfo> _anchors = [];
  bool _isInitLoading = true;

  // 使用 GlobalKey 来控制 RefreshIndicator
  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    // 🔴 修改 1：移除了 WidgetsBinding 自动触发 _refreshKey.currentState?.show() 的逻辑
    // 改为直接调用数据请求方法，这样进页面会加载数据，但不会弹出下拉刷新圈
    _handleRefresh();
  }

  // 下拉刷新的具体逻辑
  Future<void> _handleRefresh() async {
    try {
      var responseData = await HttpUtil().get("/api/room/list");
      if (mounted) {
        setState(() {
          _anchors = (responseData as List).map((json) => AnchorInfo.fromJson(json)).toList();
          _isInitLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  // 开播逻辑
  void _onStartLive() async {
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
          Navigator.of(context)
              .push(
            MaterialPageRoute(
              builder: (context) => RealLivePage(
                userId: myUserId,
                userName: UserStore.to.nickname,
                avatarUrl: UserStore.to.avatar,
                level: 0,
                isHost: true,
                roomId: assignedRoomId,
              ),
            ),
          );
          // 🔴 修改 2：移除了 .then(...) 中的自动刷新逻辑
        }
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("开播失败: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        title: Text(
          "直播列表",
          style: TextStyle(color: theme.textTheme.titleLarge?.color, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: theme.textTheme.titleLarge?.color),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // 点击按钮，手动触发下拉刷新动画（保留这个按钮作为手动刷新的快捷方式）
              _refreshKey.currentState?.show();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onStartLive,
        backgroundColor: const Color(0xFFFF0050),
        elevation: 4,
        icon: const Icon(Icons.videocam, color: Colors.white),
        label: const Text(
          "我要开播",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      // 原生 RefreshIndicator
      body: RefreshIndicator(
        key: _refreshKey,
        color: const Color(0xFFFF0050),
        backgroundColor: Colors.white,
        onRefresh: _handleRefresh,
        child: ListView.separated(
          // 物理滚动效果配置
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.only(top: 5, bottom: 80),
          itemCount: _anchors.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, thickness: 0.5, indent: 100, endIndent: 16, color: dividerColor.withOpacity(0.1)),
          itemBuilder: (context, index) => _buildCustomListItem(_anchors[index], theme),
        ),
      ),
    );
  }

  Widget _buildCustomListItem(AnchorInfo anchor, ThemeData theme) {
    final bool isMyRoom = (UserStore.to.userAccountId == "2039" && anchor.roomId == "1001");
    String modeText = "直播中";
    IconData modeIcon = Icons.bar_chart_rounded;

    if (anchor.isLive) {
      if (anchor.roomMode == 1) {
        modeText = "PK排位";
        modeIcon = Icons.bolt;
      } else if (anchor.roomMode == 2) {
        modeText = "接受惩罚";
        modeIcon = Icons.sentiment_very_dissatisfied;
      } else if (anchor.roomMode == 3) {
        modeText = "连线互动";
        modeIcon = Icons.link;
      }
    }

    return InkWell(
      onTap: () => _enterRoom(anchor, isHost: isMyRoom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _RippleAvatar(avatarUrl: anchor.avatarUrl, isLive: anchor.isLive),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anchor.name,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textTheme.titleMedium?.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    anchor.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (anchor.isLive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFFF0050), Color(0xFFFF0080)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(modeIcon, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      modeText,
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                child: Text("离线", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }

  void _enterRoom(AnchorInfo anchor, {required bool isHost}) {
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (context) => RealLivePage(
          userId: UserStore.to.userId,
          userName: UserStore.to.nickname,
          avatarUrl: UserStore.to.avatar,
          level: 0,
          isHost: isHost,
          roomId: anchor.roomId,
        ),
      ),
    );
    // 🔴 修改 3：移除了 .then(...) 中的自动刷新逻辑，从直播间回来不再自动转圈
  }
}

// 简单的头像组件
class _RippleAvatar extends StatefulWidget {
  final String avatarUrl;
  final bool isLive;

  const _RippleAvatar({required this.avatarUrl, required this.isLive});

  @override
  State<_RippleAvatar> createState() => _RippleAvatarState();
}

class _RippleAvatarState extends State<_RippleAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    if (widget.isLive) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant _RippleAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLive != oldWidget.isLive) {
      if (widget.isLive) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isLive) {
      return Container(
        width: 62,
        height: 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey[300]!, width: 1),
        ),
        child: ClipOval(
          child: ColorFiltered(
            colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
            child: Image.network(widget.avatarUrl, fit: BoxFit.cover),
          ),
        ),
      );
    }
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ...List.generate(
            3,
                (index) => AnimatedBuilder(
              animation: _controller,
              builder: (ctx, child) {
                double t = Curves.easeOutQuad.transform((_controller.value + index * 0.33) % 1.0);
                return Transform.scale(
                  scale: 1.0 + t * 0.3,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFF0050).withOpacity((1.0 - t).clamp(0.0, 1.0) * 0.6),
                        width: 3.0 * (1.0 - t).clamp(0.5, 3.0),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFFF0050), width: 2.0),
              image: DecorationImage(image: NetworkImage(widget.avatarUrl), fit: BoxFit.cover),
            ),
          ),
        ],
      ),
    );
  }
}