import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/viewer_panel.dart';

import '../../../../tools/HttpUtil.dart';

// 数据模型
class ViewerModel {
  final String id;
  final String avatarUrl;

  const ViewerModel({required this.id, required this.avatarUrl});

  factory ViewerModel.fromJson(Map<String, dynamic> json) {
    return ViewerModel(
      id: json['userId'].toString(),
      avatarUrl: json['avatar'] ?? "",
    );
  }
}

class ViewerList extends StatefulWidget {
  final String roomId;
  final int onlineCount; // 🟢 从父组件传下来的实时 WebSocket 人数

  const ViewerList({
    super.key,
    required this.roomId,
    required this.onlineCount,
  });

  @override
  State<ViewerList> createState() => _ViewerListState();
}

class _ViewerListState extends State<ViewerList> {
  List<ViewerModel> _topViewers = [];

  @override
  void initState() {
    super.initState();
    _fetchTopViewers();
  }

  // 🟢 拉取前几名大哥的头像用于展示
  // 注意：这个不需要通过 Socket 实时推，进房拉一次即可，或者每隔1分钟拉一次
  void _fetchTopViewers() async {
    if (widget.roomId.isEmpty) return;
    try {
      final res = await HttpUtil().get(
        "/api/room/online_users",
        params: {"roomId": widget.roomId},
      );
      if (res is List) {
        // 只取前 3 个
        final list = res.take(3).map((e) => ViewerModel.fromJson(e)).toList();
        if (mounted) {
          setState(() {
            _topViewers = list;
          });
        }
      }
    } catch (e) {
      print("获取头部观众失败: $e");
    }
  }

  void _showViewerPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ViewerPanel(
        roomId: widget.roomId,
        // 🟢 把最新的实时人数传给弹窗
        realTimeOnlineCount: widget.onlineCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 28.0;
    const double overlapOffset = 18.0;

    final int avatarCount = _topViewers.length;

    // 格式化人数显示 (例如 12000 -> 1.2w)
    String countStr = "${widget.onlineCount}";
    if (widget.onlineCount > 10000) {
      countStr = "${(widget.onlineCount / 10000).toStringAsFixed(1)}w";
    }

    return GestureDetector(
      onTap: () => _showViewerPanel(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 头像重叠区 (如果有数据)
          if (avatarCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              width: (avatarCount - 1) * overlapOffset + avatarSize,
              height: 32,
              child: Stack(
                children: List.generate(avatarCount, (index) {
                  // 倒序渲染：第0个(大哥)要在最上面，所以最后渲染
                  // 但 Stack 默认是后面覆盖前面。
                  // 这里的算法是：index 0 是列表里的人，位置最右，层级最低？
                  // 不，通常习惯是：大哥在最左边，层级最高。

                  // 修正逻辑：
                  // 我们希望：A(No.1) 在最左，B(No.2) 在 A 后面，C(No.3) 在 B 后面
                  // Stack 绘制顺序：先画 C，再画 B，再画 A。

                  // 真实的 viewer 数据 (倒序取，先取 C)
                  final viewer = _topViewers[avatarCount - 1 - index];

                  // 位置计算：
                  // 假设总共3人。
                  // Loop 0: 取 C。C 应该是被压在最底下的，位置在最右边?
                  // 实际上，这种重叠头像通常是最左边的在最上面。
                  // 所以：
                  // A (index 0): left 0, z-index high
                  // B (index 1): left 15, z-index mid
                  // C (index 2): left 30, z-index low

                  // 为了实现 A 盖住 B，Stack 代码里必须 B 在前，A 在后。
                  // 所以我们代码里的 List.generate 顺序应该是 [C, B, A]

                  final double leftPos = (avatarCount - 1 - index) * overlapOffset;

                  return Positioned(
                    left: leftPos,
                    top: 2,
                    child: Container(
                      width: avatarSize,
                      height: avatarSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                      ),
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey[800],
                        backgroundImage: NetworkImage(viewer.avatarUrl),
                      ),
                    ),
                  );
                }),
              ),
            ),

          // 2. 人数胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              countStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}