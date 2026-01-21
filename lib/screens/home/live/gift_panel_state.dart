import 'package:flutter/material.dart';
import './index.dart';
import 'gift_panel.dart';

class GiftPanelState extends State<GiftPanel>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = -1;
  late TabController _tabController;

  // 资源常量
  static const String ranger_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%83%BD%E5%B8%82%E6%B8%B8%E4%BE%A0.mp4';
  static const String ranger_2 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E5%AF%BB%E9%BE%99%E6%B8%B8%E4%BE%A0.mp4';
  static const String ranger_3 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0.mp4';
  static const String dragon_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E6%BD%9C%E9%BE%99%E5%9C%A8%E6%B8%8A.mp4';
  static const String dragon_2 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%BE%99%E8%85%BE%E4%B9%9D%E5%A4%A9.mp4';
  static const String radiant_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%92%80%E7%92%A8%E5%85%89%E7%BF%BC.mp4';
  static const String rose_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%8E%AB%E7%91%B0%E4%B9%8B%E7%BA%A6.mp4';
  static const String diamond_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E6%B0%B8%E6%81%92%E4%B9%8B%E9%92%BB.mp4';
  static const String seaStar_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E6%B5%B7%E6%B4%8B%E4%B9%8B%E6%98%9F.mp4';
  static const String lion_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%8B%82%E7%8B%AE%E6%80%92%E5%90%BC.mp4';
  static const String reallyLoveYou_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E7%9C%9F%E7%9A%84%E7%88%B1%E4%BD%A0.mp4';
  static const String diamondCar_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%92%BB%E7%9F%B3%E8%B7%91%E8%BD%A6.mp4';
  static const String blackGoldCarnival_1 =
      'https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/effect_video/%E9%BB%91%E9%87%91%E5%98%89%E5%B9%B4%E5%8D%8E.mp4';

  final List<GiftItemData> _gifts = const [
    GiftItemData(
      name: "真的爱你",
      price: 520,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%9C%9F%E7%9A%84%E7%88%B1%E4%BD%A0.png",
      effectAsset: reallyLoveYou_1,
    ),
    GiftItemData(
      name: "钻石跑车",
      price: 1500,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E9%92%BB%E7%9F%B3%E8%B7%91%E8%BD%A6.png",
      effectAsset: diamondCar_1,
    ),
    GiftItemData(
      name: "黑金嘉年华",
      price: 36000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E9%92%BB%E7%9F%B3%E5%98%89%E5%B9%B4%E5%8D%8E.png",
      effectAsset: blackGoldCarnival_1,
      tag: "万象",
    ),
    GiftItemData(
      name: "都市游侠",
      price: 10000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E9%83%BD%E5%B8%82%E6%B8%B8%E4%BE%A0.png",
      effectAsset: ranger_1,
    ),
    GiftItemData(
      name: "寻龙游侠",
      price: 20000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/xlyx.png",
      effectAsset: ranger_2,
    ),
    GiftItemData(
      name: "御龙游侠",
      price: 30000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ylyx.png",
      effectAsset: ranger_3,
      tag: "神秘",
      expireTime: "08/07 22:59",
    ),
    GiftItemData(
      name: "潜龙在渊",
      price: 16888,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/qlzy.png",
      effectAsset: dragon_1,
    ),
    GiftItemData(
      name: "龙腾九天",
      price: 30000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ltjt.png",
      effectAsset: dragon_2,
      tag: "神秘",
      expireTime: "08/07 22:41",
    ),
    GiftItemData(
      name: "璀璨光翼",
      price: 30000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/ltjt.png",
      effectAsset: radiant_1,
    ),
    GiftItemData(
      name: "玫瑰之约",
      price: 6000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%8E%AB%E7%91%B0%E4%B9%8B%E7%BA%A6.png",
      effectAsset: rose_1,
    ),
    GiftItemData(
      name: "永恒之钻",
      price: 30000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%B0%B8%E6%81%92%E4%B9%8B%E9%92%BB.png",
      effectAsset: diamond_1,
      tag: "万象",
    ),
    GiftItemData(
      name: "海洋之星",
      price: 30000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E6%B5%B7%E6%B4%8B%E4%B9%8B%E5%BF%83.png",
      effectAsset: seaStar_1,
    ),
    GiftItemData(
      name: "狂狮怒吼",
      price: 30000,
      iconUrl:
          "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/icon/%E7%8B%82%E7%8B%AE%E6%80%92%E5%90%BC.png",
      effectAsset: lion_1,
    ),
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
      height: 400,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF161823).withOpacity(0.95),
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
              data: ThemeData(
                highlightColor: Colors.transparent,
                splashColor: Colors.transparent,
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.only(right: 20),
                labelColor: Colors.white,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelColor: Colors.white60,
                indicatorColor: const Color(0xFFFF0050),
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "推荐"),
                  Tab(text: "神秘商店"),
                  Tab(text: "常用"),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                Icon(Icons.diamond, color: Colors.cyanAccent, size: 14),
                SizedBox(width: 4),
                Text(
                  "53",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                SizedBox(width: 4),
                Text(
                  "3002300 >",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftGrid(List<GiftItemData> gifts) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: gifts.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.72,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
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
            debugPrint("GiftPanel: 点击发送 ${gift.name}");
            widget.onSend(gift);
          },
        );
      },
    );
  }
}

class _GiftItemWidget extends StatefulWidget {
  final GiftItemData gift;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onSend;

  const _GiftItemWidget({
    required this.gift,
    required this.isSelected,
    required this.onTap,
    required this.onSend,
  });

  @override
  State<_GiftItemWidget> createState() => _GiftItemWidgetState();
}

class _GiftItemWidgetState extends State<_GiftItemWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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
    const double buttonHeight = 28.0;
    const double cardRadius = 8.0;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          // 🔴 1. 新增：开启抗锯齿裁剪，强制所有子元素（包括按钮）都在圆角内部
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(cardRadius),
            border: Border.all(
              color: widget.isSelected
                  ? const Color(0xFFFFFFFF)
                  : Colors.transparent,
              width: 0.2,
            ),
            color: widget.isSelected
                ? Colors.white.withOpacity(0.05)
                : Colors.transparent,
          ),
          child: Stack(
            children: [
              // 1. 礼物内容区域
              Positioned.fill(
                // 🔴 2. 新增：给底部留出按钮的高度的 padding，
                // 防止内容（比如价格）被底部的按钮挡住
                child: Padding(
                  padding: EdgeInsets.only(bottom: widget.isSelected ? buttonHeight : 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onTap,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 图片 + 过期时间叠加区域
                          SizedBox(
                            height: 60,
                            child: Stack(
                              alignment: Alignment.bottomCenter,
                              children: [
                                Container(
                                  height: 60,
                                  alignment: Alignment.center,
                                  child: Image.network(
                                    widget.gift.iconUrl,
                                    width: 54,
                                    height: 54,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                if (widget.gift.expireTime != null)
                                  Transform.translate(
                                    offset: const Offset(0, 3),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 0),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withOpacity(0.7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        "${widget.gift.expireTime}过期",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (widget.isSelected)
                            Text(
                              "${widget.gift.price} 钻",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          else ...[
                            Text(
                              widget.gift.name,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                            ),
                            Text(
                              "${widget.gift.price} 钻",
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 10,
                              ),
                            ),
                          ],
                          // 🔴 3. 删除：这里原本的 SizedBox(height: buttonHeight) 可以去掉了，
                          // 因为我们在上面用了 Positioned.fill + Padding 处理了避让
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 2. 左上角分类标签 (保持不变)
              if (widget.gift.tag != null)
                Positioned(
                  left: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: widget.gift.tag == "神秘"
                          ? const Color(0xFFD96F31)
                          : const Color(0xFFE5D1B5),
                      // 🔴 4. 优化：左上角圆角直接为 0，因为父容器已经裁剪了，这样最贴合
                      borderRadius: const BorderRadius.only(
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                    child: Text(
                      widget.gift.tag!,
                      style: TextStyle(
                        color: widget.gift.tag == "神秘"
                            ? Colors.white
                            : const Color(0xFF5A4331),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),

              // 3. 选中后的发送按钮
              if (widget.isSelected)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: widget.onSend,
                    child: Container(
                      height: buttonHeight,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration( // 🔴 5. 修改：去掉 const，圆角逻辑简化
                        gradient: LinearGradient(
                          colors: [Color(0xFFFF0050), Color(0xFFFE2C55)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          bottom: Radius.circular(8.0), // 👈 只底部有圆角
                        ),
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
            ],
          ),
        );
      },
    );
  }
}
