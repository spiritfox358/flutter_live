import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/models/user_decorations_model.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/screens/home/live/widgets/profile/live_user_profile_popup.dart';

import '../../../../../tools/HttpUtil.dart';

class PkContributionBottomSheet extends StatefulWidget {
  final String targetRoomId; // 要查看的那个主播的房间 ID
  final String pkId; // 👈 1. 新增 pkId 字段

  const PkContributionBottomSheet({super.key, required this.targetRoomId, required this.pkId});

  // 暴露静态方法，方便一键呼出
  static void show(BuildContext context, String targetRoomId, String pkId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => PkContributionBottomSheet(targetRoomId: targetRoomId, pkId: pkId),
    );
  }

  @override
  State<PkContributionBottomSheet> createState() => _PkContributionBottomSheetState();
}

class _PkContributionBottomSheetState extends State<PkContributionBottomSheet> {
  bool _isLoading = true;
  List<dynamic> _contributors = [];

  @override
  void initState() {
    super.initState();
    _fetchPkContributors();
  }

  Future<void> _fetchPkContributors() async {
    try {
      // 🚀 这里换成你真实的获取单场 PK 贡献榜的接口
      final res = await HttpUtil().get('/api/giftLog/pk_ranking', params: {
        "pkId": widget.pkId,
        "roomId": widget.targetRoomId
      });
      // 模拟延迟和假数据
      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        setState(() {
          _contributors = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatScore(int score) {
    if (score == 0) return "0";
    if (score < 10000) return score.toString();
    return "${(score / 10000).toStringAsFixed(1)}万";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6, // PK 榜单不要太高，挡住视频
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.pinkAccent))
                : _contributors.isEmpty
                ? const Center(
                    child: Text("暂无人打赏，快来抢MVP吧~", style: TextStyle(color: Colors.grey)),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _contributors.length,
                    itemBuilder: (context, index) {
                      return _buildContributorItem(_contributors[index], index);
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom), // 底部安全距离
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.whatshot, color: Colors.redAccent, size: 20),
          SizedBox(width: 6),
          Text(
            "本局 PK 贡献榜",
            style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildContributorItem(Map<String, dynamic> user, int index) {
    final String name = user['senderName'] ?? "神秘人";
    final String avatar = user['senderAvatar'] ?? "";
    final int level = user['level'] ?? 1;
    final int score = user['score'] ?? 0;

    // 🚀 核心修复 2：因为后端把 avatarFrame 和 levelHonourBuff 直接放在了这层 Map 里，
    // 所以根本不需要找 user['decorations']，直接把整个 user 传给模型解析即可！
    final UserDecorationsModel decorations = UserDecorationsModel.fromMap(user);

    Color rankColor = Colors.grey[400]!;
    if (index == 0) rankColor = const Color(0xFFFF5252);
    if (index == 1) rankColor = const Color(0xFFFFAB40);
    if (index == 2) rankColor = const Color(0xFFFFD740);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // 1. 排名
          SizedBox(
            width: 30,
            child: Text(
              "${index + 1}",
              style: TextStyle(color: rankColor, fontSize: 18, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),

          // 2. 头像 & 头像框 (复用你的写法)
          GestureDetector(
            onTap: () => LiveUserProfilePopup.show(context, user),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                  backgroundColor: Colors.grey[200],
                  child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.grey) : null,
                ),
                if (decorations.hasAvatarFrame)
                  Positioned(
                    top: -5,
                    left: -5,
                    child: SizedBox(width: 50, height: 50, child: Image.network(decorations.avatarFrame!, fit: BoxFit.contain)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 3. 昵称 & 等级徽章 (带特效)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                LevelBadge(level: level, monthLevel: 0, levelHonourBuffUrl: decorations.levelHonourBuff),
              ],
            ),
          ),

          // 4. 贡献火力值
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _formatScore(score),
                style: const TextStyle(color: Colors.pinkAccent, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const Text("PK值", style: TextStyle(color: Colors.black38, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}
