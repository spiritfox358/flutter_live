import 'package:flutter/material.dart';

class ViewerPanel extends StatelessWidget {
  const ViewerPanel({super.key});

  @override
  Widget build(BuildContext context) {
    // 模拟数据：生成 20 个观众
    final List<Map<String, dynamic>> viewers = List.generate(20, (index) {
      return {
        "name": "观众_${888 + index}",
        "avatar": "https://picsum.photos/seed/${index + 100}/200",
        "level": 50 - index, // 等级递减
        "isVip": index < 5, // 前5个是贵宾
      };
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // 占据屏幕 70% 高度
      decoration: const BoxDecoration(
        color: Color(0xFF171717), // 深色背景
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          // 1. 顶部拖拽条 & 标题
          _buildHeader(context),

          // 2. 列表内容
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 0),
              itemCount: viewers.length,
              itemBuilder: (context, index) {
                return _buildViewerItem(viewers[index], index);
              },
            ),
          ),
        ],
      ),
    );
  }

  // 构建顶部栏
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
      ),
      child: Column(
        children: [
          // 灰色小横条 (视觉提示可拖拽)
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // 标题栏
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
              const SizedBox(width: 4),
              Text(
                "1.2w",
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

  // 构建单行观众信息
  Widget _buildViewerItem(Map<String, dynamic> user, int index) {
    // 前三名给特殊排名图标/颜色
    Color rankColor = Colors.grey;
    String rankText = "${index + 1}";
    if (index == 0) rankColor = const Color(0xFFFFD700); // 金
    if (index == 1) rankColor = const Color(0xFFC0C0C0); // 银
    if (index == 2) rankColor = const Color(0xFFCD7F32); // 铜

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.transparent, // 点击时的涟漪效果基底
      child: Row(
        children: [
          // 排名
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

          // 头像
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: index < 3 ? Border.all(color: rankColor, width: 1.5) : null,
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(user['avatar']),
            ),
          ),
          const SizedBox(width: 12),

          // 信息 (昵称 + 等级)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // 等级标签
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Colors.blueAccent, Colors.lightBlueAccent],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bar_chart, color: Colors.white, size: 10),
                          const SizedBox(width: 2),
                          Text(
                            "${user['level']}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (user['isVip']) ...[
                      const SizedBox(width: 6),
                      // 贵宾标签
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: Colors.purpleAccent.withOpacity(0.2),
                          border: Border.all(color: Colors.purpleAccent, width: 0.5),
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

          // 右侧按钮 (例如：关注 或 主页)
          GestureDetector(
            onTap: () {
              // TODO: 点击关注逻辑
            },
            child: index % 3 == 0 // 模拟部分已关注，部分未关注
                ? const Icon(Icons.check, color: Colors.white30, size: 20)
                : const Icon(Icons.add_circle_outline, color: Colors.pinkAccent, size: 20),
          ),
        ],
      ),
    );
  }
}