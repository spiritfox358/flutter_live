// lib/web/my_alpha_player_web_stub.dart

import 'package:flutter/material.dart';

// 🟢 关键修改：必须继承 StatelessWidget，否则主文件 build 方法会报错类型不匹配
class MyAlphaPlayerWeb extends StatelessWidget {
  final int viewId;
  final Function(dynamic controller) onCreated;
  final VoidCallback? onFinish; // 🟢 补上这个参数

  const MyAlphaPlayerWeb({super.key, required this.viewId, required this.onCreated, this.onFinish});

  @override
  Widget build(BuildContext context) {
    // Android/iOS 端永远不会运行到这里，返回个空占位即可
    return const SizedBox();
  }
}

class MyAlphaPlayerWebController {
  void play(String url, {double? hue}) {}

  void stop() {}
}
