import 'package:flutter/material.dart';
import './index.dart'; // 引入数据模型
import 'gift_panel.dart'; // 引入 Widget 定义

class GiftPanelState extends State<GiftPanel> with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  late TabController _tabController;

  static const String ranger_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%83%BD%E5%B8%82%E6%B8%B8%E4%BE%A0.mp4';
  static const String ranger_2 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E5%AF%BB%E9%BE%99%E6%B8%B8%E4%BE%A0.mp4';
  static const String ranger_3 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0.mp4';
  static const String dragon_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E6%BD%9C%E9%BE%99%E5%9C%A8%E6%B8%8A.mp4';
  static const String dragon_2 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%BE%99%E8%85%BE%E4%B9%9D%E5%A4%A9.mp4';
  static const String radiant_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%92%80%E7%92%A8%E5%85%89%E7%BF%BC.mp4';
  static const String rose_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%8E%AB%E7%91%B0%E4%B9%8B%E7%BA%A6.mp4';
  static const String diamond_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E6%B0%B8%E6%81%92%E4%B9%8B%E9%92%BB.mp4';
  static const String seaStar_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E6%B5%B7%E6%B4%8B%E4%B9%8B%E6%98%9F.mp4';
  static const String lion_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%8B%82%E7%8B%AE%E6%80%92%E5%90%BC.mp4';
  static const String reallyLoveYou_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%9C%9F%E7%9A%84%E7%88%B1%E4%BD%A0.mp4';
  static const String diamondCar_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%92%BB%E7%9F%B3%E8%B7%91%E8%BD%A6.mp4';
  static const String blackGoldCarnival_1 = 'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%BB%91%E9%87%91%E5%98%89%E5%B9%B4%E5%8D%8E.mp4';

  final List<GiftItemData> _gifts = const [
    GiftItemData(name: "真的爱你", price: 520, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%9C%9F%E7%9A%84%E7%88%B1%E4%BD%A0.png", effectAsset: reallyLoveYou_1),
    GiftItemData(name: "钻石跑车", price: 1500, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E9%92%BB%E7%9F%B3%E8%B7%91%E8%BD%A6.png", effectAsset: diamondCar_1),
    GiftItemData(name: "黑金嘉年华", price: 36000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E9%92%BB%E7%9F%B3%E5%98%89%E5%B9%B4%E5%8D%8E.png", effectAsset: blackGoldCarnival_1),
    GiftItemData(name: "都市游侠", price: 10000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E9%83%BD%E5%B8%82%E6%B8%B8%E4%BE%A0.png", effectAsset: ranger_1),
    GiftItemData(name: "寻龙游侠", price: 20000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/xlyx.png", effectAsset: ranger_2),
    GiftItemData(name: "御龙游侠", price: 30000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ylyx.png", effectAsset: ranger_3),
    GiftItemData(name: "潜龙在渊", price: 16888, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/qlzy.png", effectAsset: dragon_1),
    GiftItemData(name: "龙腾九天", price: 30000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ltjt.png", effectAsset: dragon_2),
    GiftItemData(name: "璀璨光翼", price: 30000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ltjt.png", effectAsset: radiant_1),
    GiftItemData(name: "玫瑰之约", price: 6000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%8E%AB%E7%91%B0%E4%B9%8B%E7%BA%A6.png", effectAsset: rose_1),
    GiftItemData(name: "永恒之钻", price: 30000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%B0%B8%E6%81%92%E4%B9%8B%E9%92%BB.png", effectAsset: diamond_1),
    GiftItemData(name: "海洋之星", price: 30000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%B5%B7%E6%B4%8B%E4%B9%8B%E5%BF%83.png", effectAsset: seaStar_1),
    GiftItemData(name: "狂狮怒吼", price: 30000, iconUrl: "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%8B%82%E7%8B%AE%E6%80%92%E5%90%BC.png", effectAsset: lion_1),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 380,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.black.withValues(red: 0, green: 0, blue: 0, alpha: 0.93),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          _buildTopBar(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGiftGrid(_gifts),
                _buildGiftGrid(_gifts.reversed.toList()),
                _buildGiftGrid(_gifts.sublist(0, 4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      child: Row(
        children: [
          Expanded(
            child: Theme(
              data: ThemeData(highlightColor: Colors.transparent, splashColor: Colors.transparent),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.only(right: 20),
                labelColor: Colors.white,
                labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                unselectedLabelColor: Colors.white60,
                indicatorColor: const Color(0xFFFF0050),
                dividerColor: Colors.transparent,
                tabs: const [Tab(text: "推荐"), Tab(text: "神秘商店"), Tab(text: "常用")],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.diamond, color: Colors.cyanAccent, size: 14),
                SizedBox(width: 4),
                Text("23", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                SizedBox(width: 8),
                Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                SizedBox(width: 4),
                Text("58 >", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(List<GiftItemData> gifts) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: gifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.72, // 稍微增加一点高度以容纳所有内容
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final gift = gifts[index];
        final isSelected = _selectedIndex == _gifts.indexOf(gift);

        return _GiftItemWidget(
          gift: gift,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedIndex = _gifts.indexOf(gift);
            });
          },
          onSend: () {
            // 只要这里打印了，说明点击逻辑通了，父组件的 MP4 逻辑就会执行
            debugPrint("GiftPanel: 点击发送 ${gift.name}");
            widget.onSend(gift);
          },
        );
      },
    );
  }
}

// ✨ 核心修复组件 ✨
class _GiftItemWidget extends StatefulWidget {
  final GiftItemData gift;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSend;

  const _GiftItemWidget({
    Key? key,
    required this.gift,
    required this.isSelected,
    required this.onTap,
    required this.onSend,
  }) : super(key: key);

  @override
  State<_GiftItemWidget> createState() => _GiftItemWidgetState();
}

class _GiftItemWidgetState extends State<_GiftItemWidget> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    // 闪光动画：亮 -> 暗
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.5), weight: 70),
    ]).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _GiftItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelected && !oldWidget.isSelected) {
      _animController.forward(from: 0.0);
    } else if (!widget.isSelected) {
      _animController.reset();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 按钮的高度常量
    const double buttonHeight = 26.0;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final double glowOpacity = widget.isSelected ? _glowAnimation.value : 0.0;

        return Container(
          // 裁切圆角：保证内部直角按钮不溢出
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            // 选中时的背景渐变
            gradient: widget.isSelected
                ? LinearGradient(
              colors: [Colors.white.withOpacity(0.15), Colors.white.withOpacity(0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            )
                : null,
          ),
          child: Stack(
            children: [
              // --------------------------------------------------------
              // 1. 内容层 (点击触发选中)
              // --------------------------------------------------------
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent, // 确保点击空白处也能触发
                  onTap: widget.onTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 动态 Spacer：选中时把内容往上挤
                      // 这种方式比 Padding 更平滑，能自动分配剩余空间
                      if (widget.isSelected) const SizedBox(height: 4),

                      // 图片
                      // 选中时稍微缩小一点点，腾出空间
                      Image.network(
                          widget.gift.iconUrl,
                          width: widget.isSelected ? 43 : 48,
                          height: widget.isSelected ? 43 : 48
                      ),

                      const SizedBox(height: 4),

                      // 礼物名称 (始终显示)
                      Text(
                        widget.gift.name,
                        style: TextStyle(
                          color: widget.isSelected ? Colors.white : Colors.white70,
                          fontSize: 12,
                          fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // 钻石价格 (始终显示)
                      // 选中时文字变亮，且字体可能需要微调
                      Text(
                        "${widget.gift.price} 钻",
                        style: TextStyle(
                          color: widget.isSelected ? Colors.white : Colors.white.withOpacity(0.5),
                          fontSize: 10,
                        ),
                      ),

                      // 🟢 关键：选中时，底部留出按钮的高度，防止遮挡
                      if (widget.isSelected)
                        const SizedBox(height: buttonHeight + 2),
                    ],
                  ),
                ),
              ),

              // --------------------------------------------------------
              // 2. 底部按钮层 (点击触发发送)
              // --------------------------------------------------------
              if (widget.isSelected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    // 必须设置为 opaque，确保它拦截所有点击，不传给底层的选中层
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      // 这里触发发送
                      widget.onSend();
                    },
                    child: Container(
                      height: buttonHeight,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF0050), Color(0xFFFF0080)],
                        ),
                        // 直角，无圆角
                      ),
                      child: const Text(
                        "赠送",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // --------------------------------------------------------
              // 3. 边框特效层 (不拦截点击)
              // --------------------------------------------------------
              Positioned.fill(
                child: IgnorePointer( // 🟢 关键：让点击穿透边框
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(widget.isSelected ? 0.9 : 0),
                        width: 1.5,
                      ),
                      boxShadow: widget.isSelected
                          ? [
                        BoxShadow(
                          color: Colors.cyanAccent.withOpacity(0.5 * glowOpacity),
                          blurRadius: 8 + (5 * glowOpacity),
                          spreadRadius: 1 * glowOpacity,
                        )
                      ]
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}