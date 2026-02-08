import 'package:flutter/material.dart';
import 'package:flutter_live/models/user_models.dart';
import 'package:flutter_live/screens/home/live/widgets/gift_preview/gift_unlock_details.dart';
import 'package:flutter_live/screens/home/live/widgets/level_badge_widget.dart';
import 'package:flutter_live/screens/home/live/widgets/live_profile_popup.dart';
import '../../../services/gift_api.dart'; // ⚠️ 请确认路径
import 'gift_panel.dart';
import 'models/live_models.dart';

class GiftPanelState extends State<GiftPanel> with TickerProviderStateMixin {
  int _selectedIndex = -1;
  int myBalance = 0;

  // 动态数据源
  TabController? _tabController;
  List<GiftTab> _tabs = [];
  List<GiftItemData> _allGifts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() async {
    // 🟢 优先使用外部传入的数据，避免重复请求
    if (widget.initialGiftList != null && widget.initialGiftList!.isNotEmpty) {
      _allGifts = widget.initialGiftList!;
      // 只要礼物数据，Tab 还是需要去查一下
      try {
        final tabs = await GiftApi.getTabs();
        if (mounted) {
          setState(() {
            _tabs = tabs.isEmpty ? [GiftTab(id: "0", name: "全部", code: "all")] : tabs;
            _tabController = TabController(length: _tabs.length, vsync: this);
            _isLoading = false;
          });
        }
      } catch (e) {
        _handleError(e);
      }
    }

    // 如果外部没传数据，则走原来的逻辑
    try {
      final results = await Future.wait([GiftApi.getTabs(), GiftApi.getGiftList()]);

      if (mounted) {
        setState(() {
          final fetchedTabs = results[0] as List<GiftTab>;
          _tabs = fetchedTabs.isEmpty ? [GiftTab(id: "0", name: "全部", code: "all")] : fetchedTabs;

          _allGifts = results[1] as List<GiftItemData>;
          _tabController = TabController(length: _tabs.length, vsync: this);
          _isLoading = false;
        });
      }
    } catch (e) {
      _handleError(e);
    }
  }

  void _handleError(dynamic e) {
    debugPrint("初始化数据失败: $e");
    if (mounted) {
      setState(() {
        _isLoading = false;
        _tabs = [GiftTab(id: "0", name: "默认", code: "default")];
        _tabController = TabController(length: 1, vsync: this);
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 440,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: const Color(0xFF161823).withOpacity(0.98),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
      ),
      child: Column(
        children: [
          _buildLevelHeader(),
          _buildTopBar(),
          const Divider(height: 1, color: Colors.white10),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF0050)))
                : _tabController == null
                ? const SizedBox()
                : TabBarView(
                    controller: _tabController,
                    children: _tabs.map((tab) {
                      // 简单的筛选逻辑：如果 tabCode 是 'all' 或者 'default'，显示所有，否则按 tabId 筛选
                      final isAll = tab.code == 'all' || tab.code == 'default';
                      final tabGifts = isAll ? _allGifts : _allGifts.where((g) => g.tabId == tab.id).toList();

                      if (tabGifts.isEmpty) {
                        return const Center(
                          child: Text("该分类暂无礼物", style: TextStyle(color: Colors.white24, fontSize: 12)),
                        );
                      }
                      return _buildGiftGrid(tabGifts);
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 11.5, 8),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.centerRight,
            children: [
              ValueListenableBuilder<UserModel>(
                valueListenable: widget.userStatusNotifier,
                builder: (context, value, child) {
                  return LevelBadge(level: value.level);
                },
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: ValueListenableBuilder<UserModel>(
                    valueListenable: widget.userStatusNotifier,
                    builder: (context, value, child) {
                      return LinearProgressIndicator(
                        value:
                            (value.coinsNextLevelThreshold - value.coinsToNextLevel - value.coinsCurrentLevelThreshold) /
                            (value.coinsNextLevelThreshold - value.coinsCurrentLevelThreshold),
                        minHeight: 6,
                        backgroundColor: Colors.white.withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation(Color(0xFFEC407A)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 6),
                ValueListenableBuilder<UserModel>(
                  valueListenable: widget.userStatusNotifier,
                  builder: (context, value, child) {
                    int nextLevel = value.level + 1;
                    return Text("距离$nextLevel级 还差${value.coinsToNextLevelText}钻", style: const TextStyle(color: Colors.white54, fontSize: 10));
                  },
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () {
              final currentUser = widget.userStatusNotifier.value;
              // Navigator.pop(context);
              showLiveProfilePopup(context, currentUser);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(3)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text("个人中心", style: TextStyle(color: Colors.white70, fontSize: 11)),
                  SizedBox(width: 2),
                  Icon(Icons.keyboard_arrow_right, color: Colors.white54, size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    if (_isLoading || _tabController == null) {
      return const SizedBox(height: 40);
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 0, bottom: 0),
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
                labelColor: const Color(0xFFFFD700),
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                unselectedLabelColor: Colors.white60,
                indicatorColor: const Color(0xFFFFD700),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3.0,
                dividerColor: Colors.transparent,
                indicatorPadding: const EdgeInsets.only(bottom: 0),
                tabs: _tabs.map((tab) => Tab(height: 35, text: tab.name)).toList(),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.3), borderRadius: BorderRadius.circular(3)),
            child: Row(
              children: [
                Image.network(
                  "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/avatar/dou_coin_icon.png",
                  width: 15,
                  height: 15,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 6),
                ValueListenableBuilder<UserModel>(
                  valueListenable: widget.userStatusNotifier,
                  builder: (context, value, child) {
                    return Text(
                      value.coin.toString(),
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
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
        final isSelected = _selectedIndex != -1 && _allGifts.indexOf(gift) == _selectedIndex;

        return _GiftItemWidget(
          gift: gift,
          isSelected: isSelected,
          onTap: () {
            setState(() {
              _selectedIndex = _allGifts.indexOf(gift);
            });
          },
          onSend: () {
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
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
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

  /// 🟢 辅助方法：格式化时间为 "08/08 23:34过期"
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return "";
    try {
      final DateTime dt = DateTime.parse(dateStr);
      final String month = dt.month.toString().padLeft(2, '0');
      final String day = dt.day.toString().padLeft(2, '0');
      final String hour = dt.hour.toString().padLeft(2, '0');
      final String minute = dt.minute.toString().padLeft(2, '0');
      return "$month/$day $hour:$minute过期";
    } catch (e) {
      return "即将过期"; // 解析失败的兜底
    }
  }

  @override
  Widget build(BuildContext context) {
    const double buttonHeight = 28.0;
    const double cardRadius = 8.0;
    final bool isLocked = widget.gift.isLocked ?? true;
    final double opacity = isLocked ? 0.6 : 1.0;

    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Opacity(
          opacity: opacity,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cardRadius),
              border: Border.all(color: widget.isSelected ? const Color(0xFFFFFFFF) : Colors.transparent, width: 0.2),
              color: widget.isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
            ),
            child: Stack(
              children: [
                // 1. 内容区域
                Positioned.fill(
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
                            // --- 图标区域 (包含绝对定位的时间标签) ---
                            SizedBox(
                              height: 60,
                              width: 60,
                              child: Stack(
                                alignment: Alignment.center,
                                clipBehavior: Clip.none,
                                children: [
                                  // 图片
                                  Positioned.fill(
                                    child: Image.network(
                                      widget.gift.iconUrl,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24),
                                    ),
                                  ),

                                  // 🟢 过期时间：绝对定位 + 白色半透明背景 + 黑色文字
                                  if (widget.gift.expireTime != null)
                                    Positioned(
                                      bottom: 0,
                                      left: -10, // 稍微给点负边距，防止文字太长被切
                                      right: -10,
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.white70.withOpacity(0.3), // 白色半透明
                                            borderRadius: BorderRadius.circular(8), // 圆角
                                          ),
                                          child: Text(
                                            _formatDate(widget.gift.expireTime),
                                            style: const TextStyle(
                                                color: Colors.white, // 黑色文字
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold
                                            ),
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 2),

                            // --- 名字区域 (选中时不显示) ---
                            if (!widget.isSelected)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isLocked)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 2),
                                        child: Icon(Icons.lock, color: Colors.white70, size: 10),
                                      ),
                                    Text(
                                      widget.gift.name,
                                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                            // --- 价格区域 ---
                            Text(
                              "${widget.gift.price} 钻",
                              style: TextStyle(
                                color: widget.isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                                fontSize: 10,
                                fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // --- 左上角标签 ---
                if (widget.gift.tag != null && widget.gift.tag!.isNotEmpty)
                  Positioned(
                    left: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: widget.gift.tag == "神秘" ? const Color(0xFFD96F31) : const Color(0xFFE5D1B5),
                        borderRadius: const BorderRadius.only(bottomRight: Radius.circular(8)),
                      ),
                      child: Text(
                        widget.gift.tag!,
                        style: TextStyle(
                          color: widget.gift.tag == "神秘" ? Colors.white : const Color(0xFF5A4331),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                // --- 底部按钮 ---
                if (widget.isSelected)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: isLocked ? () => GiftUnlockDetails.show(context, widget.gift) : widget.onSend,
                      child: Container(
                        height: buttonHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: isLocked
                              ? const LinearGradient(colors: [Colors.grey, Colors.grey])
                              : const LinearGradient(
                            colors: [Color(0xFFFF0050), Color(0xFFFE2C55)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(cardRadius)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center, // 确保纵向居中
                          children: [
                            if (isLocked)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                    Icons.lock,
                                    size: 11, // 稍微调大一点点，匹配 12 号字体的视觉重心
                                    color: Colors.white.withOpacity(0.9)
                                ),
                              ),
                            Text(
                              isLocked ? "未解锁" : "赠送",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                height: -0.13, // 重要：设置行高可以压低文字基线，使其与图标中心对齐
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}