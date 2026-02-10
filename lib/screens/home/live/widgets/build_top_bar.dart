import 'package:flutter/material.dart';

import '../profile_pill.dart';
import 'viewer_list.dart';

class BuildTopBar extends StatelessWidget {
  final String title;
  final String name;
  final String roomId;
  final int onlineCount;
  final String avatar;
// 🟢 1. 新增：接收 ViewerList 的 Key
  final GlobalKey<ViewerListState>? viewerListKey;
  // 🟢 1. 新增：定义点击回调
  final VoidCallback? onClose;

  const BuildTopBar({
    super.key,
    required this.title,
    required this.name,
    required this.roomId,
    required this.onlineCount,
    required this.avatar,
    this.onClose, // 🟢 2. 加入构造函数
    this.viewerListKey, // 🟢 2. 加入构造函数
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            ProfilePill(name: name, avatar: avatar),
            const Spacer(),
            ViewerList(key: viewerListKey,roomId: roomId, onlineCount: onlineCount),
            const SizedBox(width: 8),
            // 🟢 3. 包裹 GestureDetector 添加点击事件
            GestureDetector(
              onTap: onClose, // 绑定回调
              behavior: HitTestBehavior.opaque, // 扩大点击区域有效性
              child: Padding(
                padding: const EdgeInsets.all(4.0), // 增加一点点击热区
                child: Icon(Icons.close, color: Colors.white.withAlpha(230), size: 25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
