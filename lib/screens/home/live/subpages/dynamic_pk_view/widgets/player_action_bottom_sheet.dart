import 'dart:ui';
import 'package:flutter/material.dart';

// 记得引入你的 LivePKPlayerModel 所在的路径
import 'package:flutter_live/screens/home/live/widgets/view_mode/dynamic_pk_battle_view.dart';

class PlayerActionBottomSheet extends StatelessWidget {
  final LivePKPlayerModel targetPlayer;
  final bool isMe;
  final bool isHost;

  final VoidCallback onToggleMute;
  final VoidCallback onMuteAllExceptMe;
  final VoidCallback onSetFocus;
  final VoidCallback onViewProfile;

  // 🚀 新增：进入对方直播间的回调
  final VoidCallback onEnterRoom;

  const PlayerActionBottomSheet({
    super.key,
    required this.targetPlayer,
    required this.isMe,
    required this.isHost,
    required this.onToggleMute,
    required this.onMuteAllExceptMe,
    required this.onSetFocus,
    required this.onViewProfile,
    required this.onEnterRoom, // 🚀 别忘了加到构造函数里
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 16, top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 顶部小把手
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),

          // 2. 头部信息区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 1),
                    image: DecorationImage(image: NetworkImage(targetPlayer.avatarUrl), fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        targetPlayer.name,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text("ID: ${targetPlayer.userId}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onViewProfile();
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("主页", style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 20),

          // 3. 按钮操作区
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 24,
              runSpacing: 20,
              alignment: WrapAlignment.start,
              children: [
                // 🚀 新增按钮：进入TA的直播间！
                // 如果点的是我自己，就不需要显示这个按钮了
                if (!isMe)
                  _buildActionButton(
                    icon: Icons.login, // 或者用 Icons.meeting_room
                    iconColor: Colors.pinkAccent,
                    label: "进直播间",
                    onTap: () {
                      Navigator.pop(context);
                      onEnterRoom();
                    },
                  ),

                // 原来的其他按钮...
                _buildActionButton(
                  icon: targetPlayer.isMuted ? Icons.mic : Icons.mic_off,
                  iconColor: targetPlayer.isMuted ? Colors.greenAccent : Colors.redAccent,
                  label: targetPlayer.isMuted ? "解除静音" : (isMe ? "闭麦" : "禁麦"),
                  onTap: () {
                    Navigator.pop(context);
                    onToggleMute();
                  },
                ),

                if (isHost || isMe)
                  _buildActionButton(
                    icon: Icons.fullscreen,
                    iconColor: Colors.blueAccent,
                    label: "设为主咖",
                    onTap: () {
                      Navigator.pop(context);
                      onSetFocus();
                    },
                  ),

                if (isHost)
                  _buildActionButton(
                    icon: Icons.volume_off,
                    iconColor: Colors.orangeAccent,
                    label: "全员闭麦",
                    onTap: () {
                      Navigator.pop(context);
                      onMuteAllExceptMe();
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required Color iconColor, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 65,
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
