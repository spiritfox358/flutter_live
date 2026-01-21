import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/viewer_panel.dart';

// 🟢 1. 定义数据模型 (通常单独放在 models/viewer_model.dart 文件中)
class ViewerModel {
  final String id;
  final String avatarUrl;
  final String name; // 预留字段，以后可能要用

  const ViewerModel({
    required this.id,
    required this.avatarUrl,
    this.name = '',
  });
}

class ViewerList extends StatelessWidget {
  const ViewerList({super.key});

  // 🟢 2. 模拟 API 返回的数据列表
  // 以后这里的数据会通过网络请求获取，然后通过 Provider/Bloc 传进来
  static const List<ViewerModel> _mockViewers = [
    ViewerModel(
      id: '1',
      avatarUrl: 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/fus_1.jpg',
      name: 'User A',
    ),
    ViewerModel(
      id: '2',
      avatarUrl: 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/mysterious_personal.png',
      name: 'User B',
    ),
    ViewerModel(
      id: '3',
      avatarUrl: 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/fus_1.jpg',
      name: 'User C',
    ),
    // 假设 API 返回了更多人，但我们只显示前3个
    ViewerModel(id: '4', avatarUrl: '...', name: 'User D'),
  ];

  void _showViewerPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ViewerPanel(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 基础配置
    const double avatarSize = 28.0;
    const double overlapOffset = 18.0;

    // 🟢 3. 数据处理逻辑
    // 即使 API 返回 100 个人，我们只取前 3 个进行头像堆叠展示
    final displayList = _mockViewers.take(3).toList();
    final int avatarCount = displayList.length;

    // 如果没有人，直接返回空或者占位 (防止报错)
    if (avatarCount == 0) return const SizedBox();

    // 计算容器宽度
    final double stackWidth = (avatarCount - 1) * overlapOffset + avatarSize;

    return GestureDetector(
      onTap: () => _showViewerPanel(context),
      behavior: HitTestBehavior.opaque,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. 头像重叠区
          SizedBox(
            width: stackWidth,
            height: 32,
            child: Stack(
              // 🟢 4. 核心渲染逻辑
              // Stack 的绘制顺序是：列表里的第一个组件在最底下，最后一个组件在最顶层。
              // 我们想要的效果：列表里第0个人(最新的) 在最顶层、最左边。
              // 所以我们需要把 displayList "倒序" 生成 Widget，让第0个人最后被绘制。
              children: List.generate(avatarCount, (index) {
                // 逻辑反转：
                // 如果 index 是 0 (数据源的最后一个人)，他是最底层的，放在最右边
                // 如果 index 是 last (数据源的第一个人)，他是最顶层的，放在最左边

                // 我们直接遍历 displayList 的反向索引
                // 比如 displayList 是 [A, B, C]
                // 我们生成的 Widget 顺序应该是 [Widget(C), Widget(B), Widget(A)]
                // 这样 A 才会盖在 B 上面，B 盖在 C 上面。

                // 当前要渲染的数据模型 (倒序取，先渲染最底下的)
                final viewer = displayList[avatarCount - 1 - index];

                // 计算位置：第0个人(A) 位置是0，第1个人(B) 位置是 1*offset...
                // 这里的 index 是 List.generate 的索引 (0, 1, 2)
                // 对应的数据是 (C, B, A)
                // C 的位置应该是最右边 -> left: 2 * offset
                // A 的位置应该是最左边 -> left: 0 * offset

                // 修正位置计算：
                final double leftPosition = (avatarCount - 1 - index) * overlapOffset;

                return Positioned(
                  left: leftPosition,
                  top: 2,
                  child: Container(
                    width: avatarSize,
                    height: avatarSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 0.1),
                    ),
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.grey[800],
                      // 🟢 从对象中获取 URL
                      backgroundImage: NetworkImage(viewer.avatarUrl),
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(width: 4),

          // 2. 人数胶囊 (真实场景下，这个数字也是 API 返回的，比如 totalCount)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              "1.2w", // 以后这里用 _mockTotalCount 之类的变量
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}