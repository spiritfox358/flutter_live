import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/store/user_store.dart'; // 🟢 引入 UserStore 用于比对ID
import '../../../../tools/HttpUtil.dart';

class ViewerPanel extends StatefulWidget {
  final String roomId;
  final int realTimeOnlineCount;

  const ViewerPanel({
    super.key,
    required this.roomId,
    required this.realTimeOnlineCount,
  });

  @override
  State<ViewerPanel> createState() => _ViewerPanelState();
}

class _ViewerPanelState extends State<ViewerPanel> {
  List<dynamic> _viewers = [];
  bool _isLoading = true;
  int _currentTab = 0; // 0:贡献榜

  // 🟢 新增：用于底部栏显示的“我的信息”
  int _myRank = 0; // 0 表示未上榜
  int _myScore = 0;

  @override
  void initState() {
    super.initState();
    _fetchOnlineUsers();
  }

  void _fetchOnlineUsers() async {
    try {
      final res = await HttpUtil().get(
        "/api/room/online_users",
        params: {"roomId": widget.roomId},
      );

      if (mounted) {
        List<dynamic> list = res ?? [];

        // 🟢 1. 核心逻辑：遍历列表，找到“我自己”
        int myRankFound = 0;
        int myScoreFound = 0;
        final String myUserId = UserStore.to.userId; // 获取当前登录用户ID

        for (int i = 0; i < list.length; i++) {
          // 后端返回的可能是 number 或 string，统一转 string 比对
          final String uid = list[i]['userId']?.toString() ?? "";

          if (uid == myUserId) {
            myRankFound = i + 1; // 排名从 1 开始
            myScoreFound = list[i]['score'] ?? 0; // 获取分数
            break; // 找到了就退出循环
          }
        }

        setState(() {
          _viewers = list;
          _isLoading = false;
          // 更新我的信息
          _myRank = myRankFound;
          _myScore = myScoreFound;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 辅助方法：格式化分数 (例如 12500 -> 1.2w)
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
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
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
          // 4. 底部固定的“我”的信息栏
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
        style: TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
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
    final bool isAdmin = user['role'] == 'admin' || index == 0; // 注意：index==0这个逻辑可能要根据新排序调整，建议只看role
    final bool isVip = user['isVip'] ?? false;
    final int score = user['score'] ?? 0;

    // 🟢 1. 获取在线状态 (默认 true 防崩)
    final bool isOnline = user['isOnline'] ?? true;

    // 🟢 2. 定义离线样式：整体透明度降低
    final double opacity = isOnline ? 1.0 : 0.6;

    Color rankColor = Colors.grey;
    if (index == 0) rankColor = const Color(0xFFFF5252);
    if (index == 1) rankColor = const Color(0xFFFFAB40);
    if (index == 2) rankColor = const Color(0xFFFFD740);

    // 如果离线，前三名的颜色也可以变灰，看你需要不需要
    // if (!isOnline) rankColor = Colors.grey[400]!;

    return Opacity(
      opacity: opacity, // 🟢 整体置灰
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 30,
              child: Text(
                "${index + 1}",
                style: TextStyle(
                  color: index < 3 ? rankColor : Colors.grey[400],
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: 8),

            // 头像
            CircleAvatar(
              radius: 20,
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              backgroundColor: Colors.grey[200],
              // 🟢 离线头像可以加个黑白滤镜，或者仅仅靠 Opacity 就够了
              child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
            ),

            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      // 🟢 如果离线，名字后面加个备注，或者不加只靠颜色区分
                      isOnline ? name : "$name (离线)",
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isAdmin) ...[
                    _buildAdminBadge(),
                    const SizedBox(width: 4),
                  ],
                  LevelBadge(level: level),
                  const SizedBox(width: 4),
                  if (isVip) ...[
                    _buildVipBadge(),
                    const SizedBox(width: 4),
                  ],
                  // ... 其他勋章
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 30.0), // 设置左边的内边距为16.0逻辑像素
              child: Text(
                _formatScore(score),
                style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            )
          ],
        ),
      ),
    );
  }

  // 4. 底部“我”的信息栏
  Widget _buildMyInfoBar(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    // 从 UserStore 获取我的基本信息
    final myName = UserStore.to.userName;
    final myLevel = UserStore.to.userLevel;
    final myAvatar = UserStore.to.avatar;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // 🟢 显示我的排名 (0 或 -1 表示未上榜)
          SizedBox(
            width: 30,
            child: Text(
              _myRank > 0 ? "$_myRank" : "-",
              style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.grey,
            backgroundImage: myAvatar.isNotEmpty ? NetworkImage(myAvatar) : null,
            child: myAvatar.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 20) : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                myName,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(height: 2),
              LevelBadge(level: myLevel),
            ],
          ),
          const Spacer(),
          // 🟢 显示我的总贡献分
          Text(
              "本场贡献 ${_formatScore(_myScore)}",
              style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)
          ),
        ],
      ),
    );
  }

  // --- 小组件封装 ---

  Widget _buildAdminBadge() {
    return Container(
      width: 16,
      height: 16,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFFF4081),
        shape: BoxShape.circle,
      ),
      child: const Text(
        "管",
        style: TextStyle(color: Colors.white, fontSize: 10, height: 1.0),
      ),
    );
  }

  Widget _buildVipBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFFD6A66D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        "V年",
        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFanBadge(String name, int level) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFAB40),
        borderRadius: BorderRadius.circular(4),
      ),
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