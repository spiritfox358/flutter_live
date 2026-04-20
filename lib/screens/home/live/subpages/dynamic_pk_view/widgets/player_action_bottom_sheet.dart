import 'package:flutter/material.dart';

// 引入 LivePKPlayerModel 所在的路径
import 'package:flutter_live/screens/home/live/subpages/dynamic_pk_view/dynamic_pk_battle_view.dart';

import '../../../widgets/pk_score_bar_widgets.dart';
import '../../pk_rank/pk_contribution_ranking_bottom_sheet.dart';

class PlayerActionBottomSheet extends StatelessWidget {
  final LivePKPlayerModel targetPlayer;
  final bool isMe;
  final bool isHost;
  final PKStatus pkStatus;
  final VoidCallback onToggleMute;
  final VoidCallback onMuteAllExceptMe;
  final VoidCallback onSetFocus;
  final VoidCallback onViewProfile;
  final VoidCallback onEnterRoom;
  final VoidCallback? onViewRank;

  // 🟢 新增：摄像头状态和切换回调
  final bool isCameraOn;
  final VoidCallback onToggleCamera;

  final VoidCallback? onLeaveCoHost;

  const PlayerActionBottomSheet({
    super.key,
    required this.targetPlayer,
    required this.isMe,
    required this.isHost,
    required this.onToggleMute,
    required this.onMuteAllExceptMe,
    required this.onSetFocus,
    required this.onViewProfile,
    required this.onEnterRoom,
    required this.onToggleCamera, // 🟢 必传回调
    required this.pkStatus,
    this.isCameraOn = true, // 🟢 默认摄像头开启
    this.onViewRank,
    this.onLeaveCoHost,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 16, top: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A).withOpacity(0.95),
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
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onViewProfile();
                  },
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.pinkAccent.withOpacity(0.5), width: 1.5),
                      image: DecorationImage(image: NetworkImage(targetPlayer.avatarUrl), fit: BoxFit.cover),
                    ),
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

                if (!isMe)
                  _buildBigEnterButton(
                    onTap: () {
                      Navigator.pop(context);
                      onEnterRoom();
                    },
                  ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 13),

          // 3. 底部操作区 (左对齐)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                spacing: 0,
                runSpacing: 5,
                alignment: WrapAlignment.start,
                children: [
                  // 榜单
                  _buildActionButton(
                    icon: Icons.bar_chart_rounded,
                    iconColor: Colors.yellowAccent,
                    label: "榜单",
                    onTap: () {
                      Navigator.pop(context);
                      PkContributionBottomSheet.show(context, targetPlayer.roomId, targetPlayer.pkId);
                    },
                  ),

                  // 闭麦/禁麦
                  _buildActionButton(
                    icon: targetPlayer.isMuted ? Icons.mic : Icons.mic_off,
                    iconColor: targetPlayer.isMuted ? Colors.greenAccent : Colors.redAccent,
                    label: targetPlayer.isMuted ? "解除静音" : (isMe ? "闭麦" : "禁麦"),
                    onTap: () {
                      Navigator.pop(context);
                      onToggleMute();
                    },
                  ),

                  // 🟢 核心新增：开关摄像头 (仅对自己显示！)
                  if (isMe)
                    _buildActionButton(
                      icon: isCameraOn ? Icons.videocam : Icons.videocam_off,
                      iconColor: isCameraOn ? Colors.greenAccent : Colors.redAccent,
                      label: isCameraOn ? "关摄像头" : "开摄像头",
                      onTap: () {
                        Navigator.pop(context);
                        onToggleCamera(); // 触发回调
                      },
                    ),
                  if (isMe && onLeaveCoHost != null)
                    _buildActionButton(
                      icon: Icons.exit_to_app,
                      iconColor: Colors.redAccent,
                      label: "下麦",
                      onTap: () {
                        Navigator.pop(context);
                        onLeaveCoHost!(); // 触发下麦
                      },
                    ),
                  // 设为主咖
                  if ((isHost || isMe) && pkStatus != PKStatus.idle)
                    _buildActionButton(
                      icon: Icons.fullscreen,
                      iconColor: Colors.blueAccent,
                      label: "设为主咖",
                      onTap: () {
                        Navigator.pop(context);
                        onSetFocus();
                      },
                    ),

                  // 全员闭麦
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
          ),
          const SizedBox(height: 75),
        ],
      ),
    );
  }

  Widget _buildBigEnterButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFF2E56), Color(0xFFFF5252)]),
          borderRadius: BorderRadius.circular(5),
          boxShadow: [BoxShadow(color: Colors.pinkAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
        ),
        child: const Text(
          "进直播间",
          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
        ),
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
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white10, width: 1),
              ),
              child: Icon(icon, color: iconColor, size: 26),
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
