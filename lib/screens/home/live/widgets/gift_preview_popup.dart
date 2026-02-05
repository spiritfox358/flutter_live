import 'package:flutter/material.dart';

/// 神秘商店 - 礼物预览弹窗
class GiftPreviewPopup extends StatelessWidget {
  const GiftPreviewPopup({super.key});

  @override
  Widget build(BuildContext context) {
    // 定义深色主题色
    const Color bgColor = Color(0xFF1E2235);
    const Color cardColor = Color(0xFF2C304B);
    const Color goldColor = Color(0xFFD4AF37);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7, // 占屏幕 70%
      decoration: const BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 1. 顶部标题栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: goldColor, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      "神秘商店 - 新品预览",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        border: Border.all(color: goldColor, width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        "马年限定",
                        style: TextStyle(color: goldColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),

          // 2. 中间内容区 (网格列表)
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 一行 3 个
                childAspectRatio: 0.75, // 高宽比
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: 6, // 模拟 6 个新品
              itemBuilder: (context, index) {
                return _buildMysteryGiftItem(index, cardColor, goldColor);
              },
            ),
          ),

          // 3. 底部按钮
          Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, MediaQuery.of(context).padding.bottom + 10),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFDE09E), Color(0xFFE2B76D)], // 金色渐变
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: const Center(
                child: Text(
                  "前往神秘商店",
                  style: TextStyle(
                    color: Color(0xFF4E342E),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMysteryGiftItem(int index, Color cardColor, Color goldColor) {
    // 模拟数据
    final List<String> names = ["马到成功", "飞黄腾达", "一马当先", "汗血宝马", "龙马精神", "天马行空"];
    final List<int> prices = [520, 1314, 6666, 8888, 9999, 18888];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图片占位
          Expanded(
            child: Center(
              child: Icon(Icons.card_giftcard, size: 40, color: Colors.white.withOpacity(0.5)),
            ),
          ),
          // 名称
          Text(
            names[index % names.length],
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          // 价格
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/dou_coin_icon.png",
                width: 12, height: 12,
              ),
              const SizedBox(width: 4),
              Text(
                "${prices[index % prices.length]}",
                style: TextStyle(color: goldColor, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}