import 'dart:ui';
import 'package:flutter/material.dart';
import '../../trtc_manager.dart';

class CoHostUserModel {
  final String userId;
  final String roomId;
  final String avatarUrl;
  final String name;
  final bool isMuted;
  final bool isCameraOn; // 🟢 1. 新增：记录该用户的摄像头状态

  CoHostUserModel({
    required this.userId,
    required this.roomId,
    required this.avatarUrl,
    required this.name,
    this.isMuted = false,
    this.isCameraOn = true, // 默认 true
  });
}

class CoHostVideoListView extends StatelessWidget {
  final List<CoHostUserModel> coHosts;
  final String currentUserId;
  final bool isHost;
  final Function(String userId)? onKickCoHost;
  final Function(CoHostUserModel)? onTapCell;

  // 🟢 2. 新增：接收底层正在推流的用户列表
  final Set<String> activeVideoUsers;

  const CoHostVideoListView({
    super.key,
    required this.coHosts,
    required this.currentUserId,
    this.isHost = false,
    this.onKickCoHost,
    this.onTapCell,
    this.activeVideoUsers = const {}, // 默认空
  });

  @override
  Widget build(BuildContext context) {
    if (coHosts.isEmpty) return const SizedBox.shrink();
    final double cellSize = MediaQuery.of(context).size.width / 3.8;

    return Container(
      width: cellSize,
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
      child: ListView.builder(
        padding: EdgeInsets.zero,
        reverse: true,
        shrinkWrap: true,
        itemCount: coHosts.length,
        itemBuilder: (context, index) {
          return _buildCell(context, coHosts[index], cellSize);
        },
      ),
    );
  }

  Widget _buildCell(BuildContext context, CoHostUserModel user, double size) {
    bool isMe = user.userId == currentUserId;
    bool isFakeData = user.userId.startsWith("fake_");

    // 判定：有没有视频流？
    bool hasVideoStream = isMe ? user.isCameraOn : activeVideoUsers.contains(user.userId);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.only(top: 8.0), // 加上一点边距，防止格子挤在一起误触
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1B),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ==========================================
          // 1. 最底层画面（视频 或 毛玻璃头像）
          // ==========================================
          if (isFakeData || !hasVideoStream)
            Stack(
              fit: StackFit.expand,
              children: [
                Image.network(user.avatarUrl, fit: BoxFit.cover, errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900])),
                BackdropFilter(filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0), child: Container(color: Colors.black.withOpacity(0.4))),
                Center(
                  child: SizedBox(
                    width: size * 0.55, height: size * 0.55,
                    child: CircleAvatar(backgroundImage: NetworkImage(user.avatarUrl)),
                  ),
                )
              ],
            )
          else if (isMe)
            TRTCManager().getLocalVideoWidget()
          else
            TRTCManager().getRemoteVideoWidget(user.userId),

          // ==========================================
          // 🚀 2. 终极修复：绝对防御的透明玻璃罩！
          // 放在视频的上一层，强制吸收所有手指点击，绝不让底层视频吞噬手势！
          // ==========================================
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (onTapCell != null) {
                  debugPrint("✅ 玻璃罩成功拦截到点击，呼叫主页面！被点的人: ${user.name}");
                  onTapCell!(user);
                }
              },
              child: Container(color: Colors.transparent),
            ),
          ),

          // ==========================================
          // 3. 底部黑条名字和闭麦图标
          // 🚀 加上 IgnorePointer，防止这块黑色区域挡住上面玻璃罩的点击
          // ==========================================
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.isMuted) const Icon(Icons.mic_off, color: Colors.redAccent, size: 12),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showActionMenu(BuildContext context, CoHostUserModel targetUser) {
    // ... 原有的踢人弹窗逻辑保持不变 ...
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.redAccent),
                title: Text("将 ${targetUser.name} 抱下麦", style: const TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(ctx);
                  if (onKickCoHost != null) onKickCoHost!(targetUser.userId);
                },
              ),
              Container(height: 8, color: Colors.grey[200]),
              ListTile(title: const Center(child: Text("取消", style: TextStyle(color: Colors.black87))), onTap: () => Navigator.pop(ctx)),
            ],
          ),
        );
      },
    );
  }
}