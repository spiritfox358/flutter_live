import 'package:flutter/material.dart';

class MusicRoomContentView extends StatelessWidget {
  final String currentBgImage;
  final String roomTitle;
  final String anchorName;

  const MusicRoomContentView({
    super.key,
    required this.currentBgImage,
    required this.roomTitle,
    required this.anchorName,
  });

  @override
  Widget build(BuildContext context) {
    // 这里是你听歌房的自定义 UI
    return Stack(
      children: [
        // 1. 背景图 (复用逻辑)
        Positioned.fill(
          child: Image.network(
            currentBgImage,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(color: Colors.black),
          ),
        ),

        // 2. 听歌房特有的中间内容
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 比如放一个旋转的唱片
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                  image: const DecorationImage(
                    image: NetworkImage("https://your-disk-cover.png"),
                  ),
                  border: Border.all(color: Colors.white24, width: 8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.music_note, color: Colors.white, size: 50),
              ),
              const SizedBox(height: 20),
              Text(
                "正在播放: 七里香 - 周杰伦",
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              // 模拟歌词
              Text(
                "窗外的麻雀 在电线杆多嘴~",
                style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}