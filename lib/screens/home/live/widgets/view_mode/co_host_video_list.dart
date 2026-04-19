import 'package:flutter/material.dart';

// 引入你的 TRTC 管理器
import '../../trtc_manager.dart';

class CoHostUserModel {
  final String userId;
  final String roomId;
  final String avatarUrl;
  final String name;
  final bool isMuted;

  CoHostUserModel({
    required this.userId,
    required this.roomId,
    required this.avatarUrl,
    required this.name,
    this.isMuted = false,
  });
}

class CoHostVideoListView extends StatelessWidget {
  final List<CoHostUserModel> coHosts;
  final String currentUserId;

  // 🟢 新增：主播权限标识和踢人回调
  final bool isHost;
  final Function(String userId)? onKickCoHost;

  // 原有的普通点击回调（备用）
  final Function(CoHostUserModel)? onTapCell;

  const CoHostVideoListView({
    super.key,
    required this.coHosts,
    required this.currentUserId,
    this.isHost = false, // 默认不是主播
    this.onKickCoHost,
    this.onTapCell,
  });

  @override
  Widget build(BuildContext context) {
    if (coHosts.isEmpty) return const SizedBox.shrink();

    final double cellSize = MediaQuery.of(context).size.width / 3.8;

    return Container(
      width: cellSize,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        reverse: true,
        shrinkWrap: true,
        itemCount: coHosts.length,
        itemBuilder: (context, index) {
          // 🟢 传入 context，为了弹窗能用
          return _buildCell(context, coHosts[index], cellSize);
        },
      ),
    );
  }

  Widget _buildCell(BuildContext context, CoHostUserModel user, double size) {
    bool isMe = user.userId == currentUserId;
    bool isFakeData = user.userId.startsWith("fake_");

    return GestureDetector(
      onTap: () {
        // 🟢 核心交互逻辑：
        // 如果我是主播，且点的不是我自己，就弹出踢人菜单
        if (isHost && !isMe) {
          _showActionMenu(context, user);
        } else {
          // 否则走普通的点击回调
          onTapCell?.call(user);
        }
      },
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFF1B1B1B),
          borderRadius: BorderRadius.zero,
          border: Border.all(color: Colors.white24, width: 0.5),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (isFakeData)
              Image.network(
                user.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
              )
            else if (isMe)
              TRTCManager().getLocalVideoWidget()
            else
              TRTCManager().getRemoteVideoWidget(user.userId),

            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),

            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isMuted)
                      const Icon(Icons.mic_off, color: Colors.redAccent, size: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🟢 封装的底部弹窗 UI (彻底给主页面减负)
  void _showActionMenu(BuildContext context, CoHostUserModel targetUser) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.redAccent),
                title: Text("将 ${targetUser.name} 抱下麦", style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx); // 先关弹窗
                  // 触发外部传进来的踢人动作
                  if (onKickCoHost != null) {
                    onKickCoHost!(targetUser.userId);
                  }
                },
              ),
              Container(height: 8, color: Colors.grey[200]),
              ListTile(
                title: const Center(child: Text("取消", style: TextStyle(color: Colors.black87))),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        );
      },
    );
  }
}