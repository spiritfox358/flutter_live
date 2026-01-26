import 'package:flutter/material.dart';

import '../../../../tools/HttpUtil.dart';

class ViewerPanel extends StatefulWidget {
  final String roomId;
  final int realTimeOnlineCount; // 从 WebSocket 传进来的实时数字

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

  @override
  void initState() {
    super.initState();
    _fetchOnlineUsers();
  }

  // 请求接口获取列表
  void _fetchOnlineUsers() async {
    try {
      // 调用后端: /api/pk/online_users?roomId=xxx (注意核对你控制器的实际路径)
      final res = await HttpUtil().get(
        "/api/room/online_users",
        params: {"roomId": widget.roomId},
      );

      if (mounted) {
        setState(() {
          // 假设 res 是 List<dynamic>
          _viewers = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("加载观众列表失败: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF171717),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 1. 顶部栏 (显示 WebSocket 传进来的实时总数)
          _buildHeader(context),

          // 2. 列表内容
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _viewers.isEmpty
                ? const Center(
                child: Text("暂时无人在线",
                    style: TextStyle(color: Colors.white54)))
                : ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: _viewers.length,
              itemBuilder: (context, index) {
                return _buildViewerItem(_viewers[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text(
                "在线观众",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              // 🟢 这里展示 WebSocket 传进来的实时数字，而不是列表的长度
              // 因为列表可能只加载了前 50 人，但在线可能有 1万人
              Text(
                "${widget.realTimeOnlineCount}",
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, color: Colors.white70, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildViewerItem(Map<String, dynamic> user, int index) {
    // 🟢 自动处理前三名逻辑：只要后端排好序，index 0/1/2 就是大哥
    Color rankColor = Colors.grey;
    String rankText = "${index + 1}";
    if (index == 0) rankColor = const Color(0xFFFFD700); // 金
    if (index == 1) rankColor = const Color(0xFFC0C0C0); // 银
    if (index == 2) rankColor = const Color(0xFFCD7F32); // 铜

    // 解析字段，防止空值报错
    final String name = user['nickname'] ?? "神秘用户";
    final String avatar = user['avatar'] ?? "";
    final int level = user['level'] ?? 1;
    final bool isVip = user['isVip'] ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              rankText,
              style: TextStyle(
                color: index < 3 ? rankColor : Colors.white38,
                fontWeight: index < 3 ? FontWeight.bold : FontWeight.normal,
                fontStyle: FontStyle.italic,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border:
              index < 3 ? Border.all(color: rankColor, width: 1.5) : null,
            ),
            child: CircleAvatar(
              radius: 20,
              // 处理图片加载错误的情况
              backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
              backgroundColor: Colors.grey[800],
              child: avatar.isEmpty ? const Icon(Icons.person, color: Colors.white) : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.lightBlueAccent],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bar_chart,
                              color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            "$level",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isVip) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.2),
                          border: Border.all(
                              color: Colors.purpleAccent, width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "VIP",
                          style: TextStyle(
                            color: Colors.purpleAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}