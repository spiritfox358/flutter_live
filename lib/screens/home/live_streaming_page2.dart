import 'package:flutter/material.dart';
import 'dart:ui'; // For image filter if needed

// --- 假数据模型 ---
class ChatMessage {
  final String name;
  final String content;
  final int level;
  final Color levelColor;
  final bool isSystem; // 比如 "来了" 或者 "点赞"

  ChatMessage({
    required this.name,
    required this.content,
    this.level = 0,
    this.levelColor = Colors.blue,
    this.isSystem = false,
  });
}

class LiveStreamingPage2 extends StatefulWidget {
  const LiveStreamingPage2({super.key});

  @override
  State<LiveStreamingPage2> createState() => _LiveStreamingPageState();
}

class _LiveStreamingPageState extends State<LiveStreamingPage2> {
  // 模拟聊天数据
  final List<ChatMessage> _messages = [
    ChatMessage(name: "Luna", content: "没脸宝", level: 23, levelColor: Colors.purple),
    ChatMessage(name: "右岸", content: "看着你紧张，", level: 16, levelColor: Colors.blueAccent),
    ChatMessage(name: "从此安静", content: "👍", level: 42, levelColor: Colors.deepPurple),
    ChatMessage(name: "从此安静", content: "相思病", level: 42, levelColor: Colors.deepPurple),
    ChatMessage(name: "从此安静", content: "👏👏👏👍👍👍", level: 42, levelColor: Colors.deepPurple),
    ChatMessage(name: "_梦醒时分ღζ🍻", content: "来了", level: 25, levelColor: Colors.indigo, isSystem: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 防止键盘顶起背景
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. 背景层 (模拟直播画面)
          Positioned.fill(
            child: Image.network(
              // 这里用一张网络图片模拟主播画面，实际开发中替换为 VideoPlayer
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?q=80&w=2459&auto=format&fit=crop',
              fit: BoxFit.cover,
            ),
          ),

          // 2. 遮罩层 (为了让文字更清晰，给底部加一点黑色渐变)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.transparent,
                    Colors.black.withOpacity(0.4),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // 3. 安全区域 UI
          SafeArea(
            child: Column(
              children: [
                // --- 顶部区域 ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: Row(
                    children: [
                      // 左上角：主播信息胶囊
                      const _ProfilePill(),
                      const Spacer(),
                      // 右上角：观众列表
                      const _ViewerList(),
                      const SizedBox(width: 8),
                      // 关闭按钮
                      const Icon(Icons.close, color: Colors.white, size: 28),
                    ],
                  ),
                ),

                // 顶部下方的榜单 (模拟)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _RankTag(text: "小时榜", color: Colors.grey.withOpacity(0.5)),
                      const Spacer(),
                    ],
                  ),
                ),

                // 顶部右侧的活动入口 (模拟)
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 5),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _ActivityBanner(text: "我的收集进度 0/6", icon: Icons.ac_unit),
                  ),
                ),

                const Spacer(), // 撑开中间区域

                // --- 底部左侧：聊天列表 ---
                Container(
                  height: 250, // 限制聊天区域高度
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: ShaderMask(
                    // 顶部淡出效果
                    shaderCallback: (Rect bounds) {
                      return LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.white],
                        stops: const [0.0, 0.2],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      reverse: true, // 消息从底部开始
                      itemCount: _messages.reversed.length,
                      itemBuilder: (context, index) {
                        final msg = _messages.reversed.toList()[index];
                        return _buildChatItem(msg);
                      },
                    ),
                  ),
                ),

                // --- 底部：输入框和操作按钮 ---
                const _BottomActionBar(),
              ],
            ),
          ),

          // 4. 悬浮元素：点歌按钮 (右侧中部)
          Positioned(
            right: 10,
            top: 300,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.purpleAccent, width: 1),
              ),
              alignment: Alignment.center,
              child: const Text(
                "点歌",
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建单条聊天消息
  Widget _buildChatItem(ChatMessage msg) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisSize: MainAxisSize.min, // 让 Row 宽度自适应内容，而不是撑满
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3), // 消息背景泡
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // 等级徽章
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [msg.levelColor.withOpacity(0.8), msg.levelColor],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.pentagon, size: 10, color: Colors.white), // 模拟图标
                      const SizedBox(width: 2),
                      Text(
                        "${msg.level}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // 名字
                Text(
                  "${msg.name}: ",
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                // 内容
                Text(
                  msg.content,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 组件：顶部主播信息胶囊 ---
class _ProfilePill extends StatelessWidget {
  const _ProfilePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=5'), // 假头像
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                "糖🍬宝...",
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                "0本场点赞",
                style: TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.amber, // 关注按钮颜色
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add, size: 14, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// --- 组件：右上角观众列表 ---
class _ViewerList extends StatelessWidget {
  const _ViewerList();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          height: 32,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: CircleAvatar(
                  radius: 14,
                  backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=${10 + index}'),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            "4",
            style: TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

// --- 组件：榜单/活动标签 ---
class _RankTag extends StatelessWidget {
  final String text;
  final Color color;

  const _RankTag({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
    );
  }
}

class _ActivityBanner extends StatelessWidget {
  final String text;
  final IconData icon;

  const _ActivityBanner({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: TextStyle(color: Colors.white, fontSize: 10))),
          Icon(icon, color: Colors.blueAccent, size: 16),
        ],
      ),
    );
  }
}


// --- 组件：底部操作栏 ---
class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          // 输入框
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(18),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.centerLeft,
              child: Text(
                "说点什么...",
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 表情
          const Icon(Icons.emoji_emotions_outlined, color: Colors.white, size: 30),
          const SizedBox(width: 10),
          // 连线/PK (Infinity loop icon approx)
          const Icon(Icons.all_inclusive, color: Colors.blueAccent, size: 30),
          const SizedBox(width: 10),
          // 爱心礼物
          const Icon(Icons.favorite_border, color: Colors.pinkAccent, size: 30),
          const SizedBox(width: 10),
          // 礼物盒
          const Icon(Icons.card_giftcard, color: Colors.pinkAccent, size: 30),
          const SizedBox(width: 10),
          // 转发
          const Icon(Icons.reply, color: Colors.white, size: 30),
        ],
      ),
    );
  }
}