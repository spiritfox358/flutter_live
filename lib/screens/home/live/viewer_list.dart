import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/viewer_panel.dart';

class ViewerList extends StatelessWidget {
  const ViewerList({super.key});

  // 弹出面板逻辑
  void _showViewerPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent, // 透明背景，让圆角生效
      isScrollControlled: true, // 允许半屏高度
      builder: (context) => const ViewerPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 基础配置
    const double avatarSize = 28.0;
    const double overlapOffset = 18.0;
    const int avatarCount = 3;

    // 计算容器宽度
    const double stackWidth = (avatarCount - 1) * overlapOffset + avatarSize;

    // 🟢 包裹 GestureDetector 添加点击事件
    return GestureDetector(
      onTap: () => _showViewerPanel(context),
      behavior: HitTestBehavior.opaque, // 确保点击空白处也能触发
      child: Row(
        mainAxisSize: MainAxisSize.min, // 紧凑布局
        children: [
          // 1. 头像重叠区
          SizedBox(
            width: stackWidth,
            height: 32, // 给定明确高度
            child: Stack(
              children: List.generate(avatarCount, (index) {
                // 倒序逻辑：让最左边(第一个)显示在最上面
                // index 0 -> renderIndex 2 (最底层, 最右边)
                // index 2 -> renderIndex 0 (最顶层, 最左边)
                final renderIndex = avatarCount - 1 - index;

                return Positioned(
                  left: renderIndex * overlapOffset,
                  top: 2, // 稍微垂直居中一点
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      // 黑色描边，产生切割效果
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[800], // 兜底背景色
                      // 🟢 换个稳定点的图源，防止不出图
                      backgroundImage: const NetworkImage(
                        'https://cdn-icons-png.flaticon.com/512/4525/4525672.png',
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(width: 4),

          // 2. 人数胶囊
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "1.2w",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold
              ),
            ),
          ),
        ],
      ),
    );
  }
}