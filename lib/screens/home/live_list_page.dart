import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter_live/screens/home/live/index.dart';

class LiveListPage extends StatefulWidget {
  const LiveListPage({super.key});

  @override
  State<LiveListPage> createState() => _LiveListPageState();
}

class _LiveListPageState extends State<LiveListPage> {
  // 模拟直播列表数据
  final List<Map<String, dynamic>> _liveRooms = List.generate(10, (index) {
    return {
      "username": "主播 No.${index + 1}",
      "title": _getRandomTitle(index),
      "coverUrl": "https://picsum.photos/seed/${index + 200}/400/600", // 竖屏随机图
      "avatarUrl": "https://picsum.photos/seed/${index + 500}/100",
      "viewers": "${Random().nextInt(90) + 1}.${Random().nextInt(9)}k", // 例如 1.2k
      "tags": index % 2 == 0 ? ["颜值", "聊天"] : ["游戏", "大神"],
    };
  });

  static String _getRandomTitle(int index) {
    const titles = [
      "深夜电台，聊聊心事 🌙",
      "高端局排位，求带飞 🎮",
      "新歌首唱，快来听 🎵",
      "户外观景，带你看海 🌊",
      "沉浸式拆箱，惊喜不断 🎁",
      "猫咪日常，治愈系 🐱",
    ];
    return titles[index % titles.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0E), // 深色背景
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("直播广场", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.search, color: Colors.white), onPressed: () {}),
          IconButton(icon: const Icon(Icons.notifications_none, color: Colors.white), onPressed: () {}),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: GridView.builder(
          physics: const BouncingScrollPhysics(), // iOS回弹效果
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, // 一行两个
            childAspectRatio: 0.7, // 宽高比，0.7表示比较瘦长
            crossAxisSpacing: 8, // 横向间距
            mainAxisSpacing: 8, // 纵向间距
          ),
          itemCount: _liveRooms.length,
          itemBuilder: (context, index) {
            final room = _liveRooms[index];
            return _buildLiveCard(context, room);
          },
        ),
      ),
    );
  }

  // 构建单个直播卡片
  Widget _buildLiveCard(BuildContext context, Map<String, dynamic> room) {
    return GestureDetector(
      onTap: () {
        // ✨ 点击跳转到直播间页面
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const LiveStreamingPage()),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.grey[900], // 图片加载前的底色
          image: DecorationImage(
            image: NetworkImage(room['coverUrl']),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            // 1. 底部黑色渐变遮罩 (为了让文字看清)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 100,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // 2. 左上角：直播状态标签
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 模拟跳动的直播图标
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${room['viewers']}人",
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),

            // 3. 右上角：标签 (如 "颜值")
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.pinkAccent.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (room['tags'] as List).first,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // 4. 底部信息：标题和主播名
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题
                  Text(
                    room['title'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // 主播信息
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 9,
                        backgroundImage: NetworkImage(room['avatarUrl']),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room['username'],
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // 喜欢按钮
                      Icon(Icons.favorite_border, size: 14, color: Colors.white.withOpacity(0.7)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}