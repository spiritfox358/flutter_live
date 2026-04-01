import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/viewer_panel.dart';
import '../../../../../tools/HttpUtil.dart';
import '../../models/user_decorations_model.dart';

// 数据模型
class ViewerModel {
  final String id;
  final String avatarUrl;
  final UserDecorationsModel decorations;

  const ViewerModel({required this.id, required this.avatarUrl, required this.decorations});

  factory ViewerModel.fromJson(Map<String, dynamic> json) {
    UserDecorationsModel decorationsMap = UserDecorationsModel.fromMap(json['decorations'] ?? {});
    return ViewerModel(id: json['userId'].toString(), avatarUrl: json['avatar'] ?? "", decorations: decorationsMap);
  }
}

class ViewerList extends StatefulWidget {
  final String roomId;
  final int onlineCount;

  const ViewerList({super.key, required this.roomId, required this.onlineCount});

  @override
  State<ViewerList> createState() => ViewerListState();
}

class ViewerListState extends State<ViewerList> {
  List<ViewerModel> _topViewers = [];
// 🟢 1. 新增一个内部变量来维护在线人数
  late int _currentOnlineCount;

  @override
  void initState() {
    super.initState();
    // 🟢 2. 初始化时使用外层传入的值
    _currentOnlineCount = widget.onlineCount;
    _fetchTopViewers();
  }

  @override
  void didUpdateWidget(ViewerList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onlineCount != widget.onlineCount) {
      _fetchTopViewers();
    }
  }

  // 🟢 3. 新增此方法：专门供外部 websocket 调用的局部刷新！
  void updateOnlineCount(int newCount) {
    if (!mounted) return;
    setState(() {
      _currentOnlineCount = newCount;
    });
    // 人数变了，顺便刷新一下头像榜单
    _fetchTopViewers();
  }

  void _fetchTopViewers() async {
    if (widget.roomId.isEmpty) return;
    try {
      final res = await HttpUtil().get("/api/room/online_users", params: {"roomId": widget.roomId});
      if (res is List) {
        if (!mounted) return;

        // 核心修复：先过滤出在线用户，再取前 3 名
        final list = res
            .where((e) => e['isOnline'] == true) // 1. 只要在线的
            .take(3) // 2. 取前三个
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
      builder: (context) => ViewerPanel(roomId: widget.roomId, realTimeOnlineCount: widget.onlineCount),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 👉 定义基础尺寸
    const double avatarSize = 28.0; // 头像本身的大小
    const double overlapOffset = 18.0; // 头像重叠的间距

    final int avatarCount = _topViewers.length;

    // 格式化人数显示
    String countStr = "$_currentOnlineCount";
    if (widget.onlineCount > 10000) {
      countStr = "${(widget.onlineCount / 10000).toStringAsFixed(1)}万";
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
              // 👉 控制整个头像组离右边文字的距离
              margin: const EdgeInsets.only(right: 4),
              // 👉 计算容器总宽度：(N-1)*间距 + 最后一个头像的宽度
              width: (avatarCount - 1) * overlapOffset + avatarSize,
              height: 32,
              child: Stack(
                // 渲染顺序：[No.3, No.2, No.1] -> 这样 No.1 (最后渲染) 会盖在最上面
                // clipBehavior: Clip.none, // 如果头像框特别大被切掉，可以在这里加这个属性
                children: List.generate(avatarCount, (index) {
                  // 数据源逻辑：_topViewers[0] 是大哥
                  // 我们希望大哥在最左边 (left: 0)，且层级最高 (Stack最后画)
                  final int dataIndex = avatarCount - 1 - index;
                  final viewer = _topViewers[dataIndex];
                  final double leftPos = dataIndex * overlapOffset;

                  return Positioned(
                    left: leftPos,
                    // 👉 垂直居中：容器高32，头像高28，(32-28)/2 = 2
                    top: 2,

                    // 🟢 2. 这里加了一层 Stack，用来把头像框叠在头像上
                    child: Stack(
                      alignment: Alignment.center, // 居中对齐
                      clipBehavior: Clip.none, // 👉 关键：允许头像框超出 28x28 的限制，否则框会被切掉
                      children: [
                        // A. 头像本体
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1),
                          ),
                          child: CircleAvatar(radius: 14, backgroundColor: Colors.grey[800], backgroundImage: NetworkImage(viewer.avatarUrl)),
                        ),

                        // B. 头像框图片
                        if (viewer.decorations.hasAvatarFrame)
                          Positioned(
                            // 👉 因为头像很小(28)，框需要比头像大一圈
                            // 这里设置偏移量，让框中心对准头像中心
                            top: -3,
                            left: -3,
                            child: SizedBox(
                              // 👉 框的大小：28 * 1.4 ≈ 39，根据素材实际情况微调
                              width: 33,
                              height: 33,
                              child: Image.network(viewer.decorations.avatarFrame!, fit: BoxFit.contain),
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),

          // 2. 人数胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(16)),
            child: Text(
              countStr,
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
