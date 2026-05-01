import 'package:flutter/material.dart';
import '../../../../tools/HttpUtil.dart';
import 'live/live_swipe_page.dart';

// 🟢 1. 数据模型：融合了用户信息和直播间信息
class FollowingRoomModel {
  final String userId;
  final String userName;
  final String userAvatar;
  final String signature;

  // 直播间相关
  final String roomId;
  final bool isLive;
  final String roomTitle;
  final String roomCover;
  final int roomType;
  final int roomMode; // 🚀 新增：为了同步 live_list_page 的 PK/连麦 状态

  // 原 JSON 数据 (为了透传给滑动页)
  final Map<String, dynamic> rawJson;

  FollowingRoomModel({
    required this.userId,
    required this.userName,
    required this.userAvatar,
    required this.signature,
    required this.roomId,
    required this.isLive,
    required this.roomTitle,
    required this.roomCover,
    required this.roomType,
    required this.roomMode,
    required this.rawJson,
  });

  factory FollowingRoomModel.fromJson(Map<String, dynamic> json) {
    return FollowingRoomModel(
      userId: json['userId']?.toString() ?? "",
      userName: json['userName'] ?? "神秘主播",
      userAvatar: json['userAvatar'] ?? "https://via.placeholder.com/150",
      signature: json['signature'] ?? "这个人很懒...",
      roomId: json['roomId']?.toString() ?? "",
      isLive: (json['isLive']?.toString() == "1"), // 后端查出来的是 1 代表开播
      roomTitle: json['roomTitle'] ?? "",
      roomCover: json['roomCover'] ?? "",
      roomType: int.tryParse(json['roomType']?.toString() ?? "0") ?? 0,
      roomMode: int.tryParse(json['roomMode']?.toString() ?? "0") ?? 0, // 🚀 解析 roomMode
      rawJson: json,
    );
  }
}

class HomeFollowingFeedPage extends StatefulWidget {
  const HomeFollowingFeedPage({super.key});

  @override
  State<HomeFollowingFeedPage> createState() => _HomeFollowingFeedPageState();
}

class _HomeFollowingFeedPageState extends State<HomeFollowingFeedPage> with AutomaticKeepAliveClientMixin {
  List<FollowingRoomModel> _list = [];
  bool _isInitLoading = true;

  // 提取出所有正在开播的原始 JSON 数据，专门喂给滑动切房组件
  List<dynamic> _onlyLiveRawList = [];

  final GlobalKey<RefreshIndicatorState> _refreshKey = GlobalKey<RefreshIndicatorState>();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _handleRefresh();
  }

  Future<void> _handleRefresh() async {
    try {
      var responseData = await HttpUtil().get("/api/relation/following_rooms");
      if (mounted) {
        setState(() {
          if (responseData is List) {
            _list = responseData.map((json) => FollowingRoomModel.fromJson(json)).toList();
            _onlyLiveRawList = responseData.where((json) => json['isLive']?.toString() == "1").toList();
          }
          _isInitLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isInitLoading = false);
    }
  }

  void _enterRoom(FollowingRoomModel model) {
    if (!model.isLive || model.roomId.isEmpty) {
      debugPrint("跳转到个人主页: ${model.userId}");
      // Navigator.push(context, MaterialPageRoute(builder: (context) => UserProfilePage(userInfo: model.rawJson)));
      return;
    }

    int activeIndex = _onlyLiveRawList.indexWhere((json) => json['roomId']?.toString() == model.roomId);
    if (activeIndex == -1) activeIndex = 0;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LiveSwipePage(
          initialRoomList: _onlyLiveRawList,
          initialIndex: activeIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final dividerColor = theme.dividerColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: RefreshIndicator(
        key: _refreshKey,
        color: const Color(0xFFFF0050),
        backgroundColor: Colors.white,
        onRefresh: _handleRefresh,
        child: _isInitLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)))
            : _list.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          children: [
            Container(
              height: MediaQuery.of(context).size.height * 0.7,
              alignment: Alignment.center,
              child: const Text("暂无关注的人", style: TextStyle(color: Colors.grey)),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
          padding: const EdgeInsets.only(top: 5, bottom: 80),
          itemCount: _list.length,
          separatorBuilder: (ctx, i) => Divider(height: 1, thickness: 0.5, indent: 90, endIndent: 16, color: dividerColor.withOpacity(0.1)),
          itemBuilder: (context, index) => _buildListItem(_list[index], theme),
        ),
      ),
    );
  }

  Widget _buildListItem(FollowingRoomModel model, ThemeData theme) {
    // 🚀 1. 完美复刻 live_list_page.dart 的状态文案和图标逻辑
    String modeText = "直播中";
    IconData modeIcon = Icons.bar_chart_rounded;

    if (model.isLive) {
      if (model.roomMode == 1) {
        modeText = "PK排位";
        modeIcon = Icons.bolt;
      } else if (model.roomMode == 2) {
        modeText = "接受惩罚";
        modeIcon = Icons.sentiment_very_dissatisfied;
      } else if (model.roomMode == 3) {
        modeText = "连线互动";
        modeIcon = Icons.link;
      }
    }

    return InkWell(
      onTap: () => _enterRoom(model),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            _RippleAvatar(avatarUrl: model.userAvatar, isLive: model.isLive),

            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.userName,
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: theme.textTheme.titleMedium?.color),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    model.isLive ? (model.roomTitle.isNotEmpty ? model.roomTitle : "正在直播中...") : model.signature,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // 🚀 2. 修复暗黑模式：统一使用 Colors.grey，避免黑底黑字看不见
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // 🚀 3. 完美复刻 live_list_page 的渐变状态角标
            if (model.isLive)
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
                decoration: BoxDecoration(color: Colors.grey.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                child: const Text("离线", style: TextStyle(color: Colors.grey, fontSize: 11)),
              ),
          ],
        ),
      ),
    );
  }
}

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
          // 暗色模式下如果边框太亮会突兀，可以随主题稍作调整，这里给个柔和的灰色
          border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
        ),
        child: ClipOval(
          // 🚀🚀🚀 修复：删掉了 ColorFiltered 遗像滤镜，恢复彩色头像！只保留灰色边框表示未开播
          child: Image.network(widget.avatarUrl, fit: BoxFit.cover, errorBuilder: (c,e,s) => const Icon(Icons.person, color: Colors.grey)),
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