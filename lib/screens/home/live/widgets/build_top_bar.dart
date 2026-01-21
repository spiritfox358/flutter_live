import 'package:flutter/material.dart';

import '../profile_pill.dart';
import '../viewer_list.dart';

class BuildTopBar extends StatelessWidget {
  // 如果需要从外部传递数据，可以定义构造函数
  final String title;

  const BuildTopBar({super.key, required this.title});

  // 可选：添加 key 或其他参数
  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            const ProfilePill(),
            const Spacer(),
            const ViewerList(),
            const SizedBox(width: 8),
            const Icon(Icons.close, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}
