import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/models/user_decorations_model.dart';
import 'package:flutter_live/screens/home/live/widgets/common/admin_badge_widget.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/screens/home/live/widgets/profile/live_user_profile_popup.dart';
import 'package:flutter_live/store/user_store.dart';
import '../../../../tools/HttpUtil.dart';

class ViewerPanel extends StatefulWidget {
  final String roomId;
  final int realTimeOnlineCount;

  const ViewerPanel({super.key, required this.roomId, required this.realTimeOnlineCount});

  @override
  State<ViewerPanel> createState() => _ViewerPanelState();
}

class _ViewerPanelState extends State<ViewerPanel> {
  List<dynamic> _viewers = [];
  bool _isLoading = true;
  int _currentTab = 0; // 0:贡献榜

  // 用于底部栏显示的“我的信息”
  int _myRank = 0; // 0 表示未上榜
  int _myScore = 0;

  @override
  void initState() {
    super.initState();
    _fetchOnlineUsers();
  }

  void _fetchOnlineUsers() async {
    try {
      final res = await HttpUtil().get("/api/room/online_users", params: {"roomId": widget.roomId});

      if (mounted) {
        List<dynamic> list = res ?? [];

        // 核心逻辑：遍历列表，找到“我自己”
        int myRankFound = 0;
        int myScoreFound = 0;
        final String myUserId = UserStore.to.userId; // 获取当前登录用户ID

        for (int i = 0; i < list.length; i++) {
          final String uid = list[i]['userId']?.toString() ?? "";

          if (uid == myUserId) {
            myRankFound = i + 1; // 排名从 1 开始
            myScoreFound = list[i]['score'] ?? 0;
            break;
          }
        }

        setState(() {
          _viewers = list;
          _isLoading = false;
          _myRank = myRankFound;
          _myScore = myScoreFound;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 辅助方法：格式化分数
  String _formatScore(int score) {
    if (score == 0) return "0";
    if (score < 10000) return score.toString();
    return "${(score / 10000).toStringAsFixed(1)}w";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _viewers.isEmpty
                ? _buildEmptyView()
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _viewers.length,
                    itemBuilder: (context, index) {
                      return _buildViewerItem(_viewers[index], index);
                    },
                  ),
          ),
          // 底部固定的“我”的信息栏
          _buildMyInfoBar(context),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text("暂无观众", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: const Text(
        "在线观众",
        style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = ["贡献榜 (${widget.realTimeOnlineCount})", "高等级", "千钻贡献", "星守护"];
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (c, i) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final isSelected = _currentTab == index;
          return GestureDetector(
            onTap: () => setState(() => _currentTab = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF3E5F5) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tabs[index],
                style: TextStyle(
                  color: isSelected ? const Color(0xFF9C27B0) : Colors.grey[600],
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildViewerItem(Map<String, dynamic> user, int index) {
    final String name = user['nickname'] ?? "神秘人";
    final String avatar = user['avatar'] ?? "";
    final int level = user['level'] ?? 1;
    final Map<String, dynamic>? rawDecorations = user['decorations'] as Map<String, dynamic>?;
    final UserDecorationsModel decorations = UserDecorationsModel.fromMap(rawDecorations ?? {});
    final int monthLevel = user['monthLevel'] ?? 0;
    final bool isAdmin = user['role'] == 'admin' || index == 0;
    final bool isVip = user['isVip'] ?? false;
    final int score = user['score'] ?? 0;

    // 获取在线状态 (默认 true 防崩)
    final bool isOnline = user['isOnline'] ?? true;

    // 定义离线样式：整体透明度降低
    final double opacity = isOnline ? 1.0 : 0.6;

    Color rankColor = Colors.grey;
    if (index == 0) rankColor = const Color(0xFFFF5252);
    if (index == 1) rankColor = const Color(0xFFFFAB40);
    if (index == 2) rankColor = const Color(0xFFFFD740);

    return Opacity(
      opacity: opacity, // 整体置灰
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                "${index + 1}",
                style: TextStyle(color: index < 3 ? rankColor : Colors.grey[400], fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // 🟢 修改处：使用 Stack 叠加头像框
            GestureDetector(
              onTap: () {
                // final currentUser = widget.userStatusNotifier.value;
                // Navigator.pop(context);
                LiveUserProfilePopup.show(context, user);
              },
              child: Stack(
                alignment: Alignment.center, // 确保居中对齐
                clipBehavior: Clip.none, // 允许头像框略微超出边界
                children: [
                  // 1. 底层头像 (半径20)
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                    backgroundColor: Colors.grey[200],
                    child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                  ),
                  // 2. 上层头像框
                  // 这里的 55x55 是相对于头像直径40调整的，可根据实际视觉效果微调
                  if (decorations.hasAvatarFrame)
                    Positioned(
                      top: -5, // 👈 向下偏移
                      left: -5, // 👈 向右偏移
                      child: SizedBox(width: 50, height: 50, child: Image.network(decorations.avatarFrame!, fit: BoxFit.contain)),
                    ),
                ],
              ),
            ),

            // 🟢 修改结束
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      isOnline ? name : "$name (离线)",
                      style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isAdmin) ...[AdminBadgeWidget(), const SizedBox(width: 4)],
                  LevelBadge(level: level, monthLevel: monthLevel, showConsumption: true),
                  const SizedBox(width: 4),
                  if (isVip) ...[_buildVipBadge(), const SizedBox(width: 4)],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30.0),
              child: Text(
                _formatScore(score),
                style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 底部“我”的信息栏
  Widget _buildMyInfoBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 从 UserStore 获取我的基本信息
    final myName = UserStore.to.nickname;
    final myLevel = UserStore.to.userLevel;
    final monthLevel = UserStore.to.monthLevel;
    final myAvatar = UserStore.to.avatar;
    UserDecorationsModel decorationsMap = UserDecorationsModel.fromMap(UserStore.to.decorations);
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -2), blurRadius: 5)],
      ),
      child: Row(
        children: [
          // 显示我的排名 (0 或 -1 表示未上榜)
          SizedBox(
            width: 30,
            child: Text(
              _myRank > 0 ? "$_myRank" : "-",
              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          GestureDetector(
            onTap: () {
              Map<String, dynamic>? userMap = UserStore.to.profile;
              userMap?["userId"] = UserStore.to.userId;
              LiveUserProfilePopup.show(context, userMap);
            },
            // 🟢 修改处：底部栏头像也加框
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // 1. 底层头像 (半径18)
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey,
                  backgroundImage: myAvatar.isNotEmpty ? NetworkImage(myAvatar) : null,
                  child: myAvatar.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
                ),
                // 2. 上层头像框 (尺寸稍微调小适配半径18)
                if (decorationsMap.hasAvatarFrame)
                  Positioned(
                    top: -5, // 👈 向下偏移
                    left: -5, // 👈 向右偏移
                    child: SizedBox(width: 45, height: 45, child: Image.network(decorationsMap.avatarFrame!, fit: BoxFit.contain)),
                  ),
              ],
            ),
          ),

          // 🟢 修改结束
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                myName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 2),
              LevelBadge(level: myLevel, monthLevel: monthLevel, showConsumption: true),
            ],
          ),
          const Spacer(),
          // 显示我的总贡献分
          Text(
            "本场贡献 ${_formatScore(_myScore)}",
            style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildVipBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(color: const Color(0xFFD6A66D), borderRadius: BorderRadius.circular(4)),
      child: const Text(
        "V年",
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFanBadge(String name, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(color: const Color(0xFFFFAB40), borderRadius: BorderRadius.circular(4)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite, size: 8, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
