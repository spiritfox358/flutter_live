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
  final int onlineCount;

  const ViewerList({
    super.key,
    required this.roomId,
    required this.onlineCount,
  });

  @override
  State<ViewerList> createState() => ViewerListState();
}

class ViewerListState extends State<ViewerList> {
  List<ViewerModel> _topViewers = [];

  @override
  void initState() {
    super.initState();
    _fetchTopViewers();
  }

  @override
  void didUpdateWidget(ViewerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onlineCount != widget.onlineCount) {
      _fetchTopViewers();
    }
  }
  void refresh() {
    print("🔄 ViewerList 收到刷新指令，正在更新榜单...");
    _fetchTopViewers();
  }
  void _fetchTopViewers() async {
    if (widget.roomId.isEmpty) return;
    try {
      final res = await HttpUtil().get(
        "/api/room/online_users",
        params: {"roomId": widget.roomId},
      );
      if (res is List) {
        if (!mounted) return;

        // 🟢 核心修复：先过滤出在线用户，再取前 3 名
        final list = res
            .where((e) => e['isOnline'] == true) // 1. 只要在线的
            .take(3)                             // 2. 取前三个
            .map((e) => ViewerModel.fromJson(e)) // 3. 转模型
            .toList();

        setState(() {
          _topViewers = list;
        });
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
        realTimeOnlineCount: widget.onlineCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const double avatarSize = 28.0;
    const double overlapOffset = 18.0;

    final int avatarCount = _topViewers.length;

    // 格式化人数显示
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
          // 1. 头像重叠区
          if (avatarCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 4),
              width: (avatarCount - 1) * overlapOffset + avatarSize,
              height: 32,
              child: Stack(
                // 渲染顺序：[No.3, No.2, No.1] -> 这样 No.1 (最后渲染) 会盖在最上面
                children: List.generate(avatarCount, (index) {
                  // 数据源逻辑：_topViewers[0] 是大哥
                  // 我们希望大哥在最左边 (left: 0)，且层级最高 (Stack最后画)

                  // 倒序循环：
                  // 假设 size=3.
                  // Loop 0: index=0. dataIndex = 3-1-0 = 2 (老三). left = (2)*18 = 36.
                  // Loop 1: index=1. dataIndex = 3-1-1 = 1 (老二). left = (1)*18 = 18.
                  // Loop 2: index=2. dataIndex = 3-1-2 = 0 (大哥). left = 0. -> 最后画，盖住别人

                  final int dataIndex = avatarCount - 1 - index;
                  final viewer = _topViewers[dataIndex];
                  final double leftPos = dataIndex * overlapOffset;

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