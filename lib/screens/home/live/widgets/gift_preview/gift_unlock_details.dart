import 'dart:ui';
import 'package:flutter/material.dart';
// ⚠️ 请确保路径正确引用你的模型文件
import '../../models/live_models.dart';

class GiftUnlockDetails extends StatefulWidget {
  final GiftItemData currentGift;

  const GiftUnlockDetails({Key? key, required this.currentGift}) : super(key: key);

  static void show(BuildContext context, GiftItemData gift) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => GiftUnlockDetails(currentGift: gift),
    );
  }

  @override
  State<GiftUnlockDetails> createState() => _GiftUnlockDetailsState();
}

class _GiftUnlockDetailsState extends State<GiftUnlockDetails> {
  static const bool useMockData = true;
  // 统一背景图
  final String bgUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/live/bg/bg_3.png";

  late List<GiftItemData> _gifts;
  late int _selectedIndex;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _gifts = [widget.currentGift];
    _selectedIndex = 0;
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _generateMockData();
    });
  }

  void _generateMockData() {
    final List<String> mockIcons = [
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/gift/1.png",
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/gift/2.png",
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/gift/3.png",
    ];

    List<GiftItemData> tempList = [];
    for (int i = 0; i < 3; i++) {
      tempList.add(_createMockItem(i, "礼物L$i", mockIcons[i % mockIcons.length]));
    }
    tempList.add(widget.currentGift);
    for (int i = 0; i < 3; i++) {
      tempList.add(_createMockItem(i + 10, "礼物R$i", mockIcons[(i + 1) % mockIcons.length]));
    }

    setState(() {
      _gifts = tempList;
      _selectedIndex = _gifts.indexOf(widget.currentGift);
    });
    _scrollToCenter(_selectedIndex);
  }

  GiftItemData _createMockItem(int idSuffix, String name, String url) {
    return GiftItemData(
      id: "mock_$idSuffix",
      name: name,
      price: 999,
      iconUrl: url,
      isLocked: true,
      tabId: "0",
    );
  }

  void _scrollToCenter(int index) {
    if (!_scrollController.hasClients) return;
    double offset = (index * 56.0) - (MediaQuery.of(context).size.width / 2) + 28.0;
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent + 100),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ 1. 页面整体高度改为 70%
    final double height = MediaQuery.of(context).size.height * 0.7;

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // 背景图保持 BoxFit.cover，比例不失调
          Positioned.fill(
            child: Image.network(
              bgUrl,
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          Column(
            children: [
              const SizedBox(height: 12),
              _buildAppBar(context),
              _buildThumbnailList(),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: _buildDescriptionContent(),
                ),
              ),

              _buildBottomActionPanel(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            "神秘商店",
            style: TextStyle(color: Color(0xFFEBD3B6), fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white70),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailList() {
    return Container(
      height: 56,
      margin: const EdgeInsets.only(top: 10, bottom: 20),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _gifts.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = index);
              _scrollToCenter(index);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected ? Border.all(color: Colors.cyanAccent, width: 2) : null,
                boxShadow: isSelected ? [BoxShadow(color: Colors.cyanAccent.withOpacity(0.5), blurRadius: 8)] : null,
              ),
              child: Opacity(
                opacity: isSelected ? 1.0 : 0.6,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Image.network(_gifts[index].iconUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ✅ 2. 标题和描述文字全部居左
  Widget _buildDescriptionContent() {
    final gift = _gifts[_selectedIndex];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start, // 整体内容靠左
      children: [
        Text(
          gift.name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black, blurRadius: 10)],
          ),
        ),
        const SizedBox(height: 12),
        // 装饰线靠左
        Container(
          width: 40,
          height: 2,
          color: const Color(0xFFEBD3B6),
        ),
        const SizedBox(height: 24),
        Text(
          "万象森罗 · 潜龙出渊",
          style: TextStyle(
            color: const Color(0xFFEBD3B6).withOpacity(0.9),
            fontSize: 16,
            fontStyle: FontStyle.italic,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "传说此物汲取天地灵气，非凡夫俗子所能窥见。唯有达成特定的缘分积累，方可解锁其神秘面纱。一旦现世，必将引动八方云雨，尽显尊贵气象。",
          textAlign: TextAlign.left, // 文字内容居左
          style: TextStyle(
            color: Colors.white.withOpacity(0.85),
            fontSize: 14,
            height: 1.7,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionPanel(BuildContext context) {
    const int current = 0;
    const int target = 15;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F2A).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // 75% 区域：左侧文字和进度条
              Expanded(
                flex: 75,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text("周期解锁", style: TextStyle(color: Color(0xFFC7C7CC), fontSize: 13)),
                        const SizedBox(width: 4),
                        Icon(Icons.help_outline, color: Colors.white.withOpacity(0.3), size: 14),
                      ],
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.white),
                        children: [
                          TextSpan(text: "已充"),
                          TextSpan(text: "${current}万钻", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                          TextSpan(text: "，差"),
                          TextSpan(text: "${target}万", style: TextStyle(color: Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                          TextSpan(text: "可得"),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: const LinearProgressIndicator(
                        value: 0.05,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation(Color(0xFFFFD700)),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // 25% 区域：立即充值按钮
              Expanded(
                flex: 25,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF2D194), Color(0xFFD6A563)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      "立即充值",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF4A3418), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}