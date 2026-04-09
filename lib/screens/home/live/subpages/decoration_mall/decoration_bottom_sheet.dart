import 'package:flutter/material.dart';
import 'package:flutter_live/tools/HttpUtil.dart'; // 🟢 确保 HttpUtil 的路径正确

// ============================================================================
// 🟢 1. 数据模型与枚举定义
// ============================================================================

/// 装扮类型枚举 (根据后端的 type 映射: 1-头像框, 2-进场特效, 3-等级荣耀buff, 4-主页背景)
enum DecorationType {
  all(0, '全部'),
  avatarFrame(1, '头像框'),
  entranceEffect(2, '进场特效'),
  gloryBuff(3, '荣耀Buff'),
  homeBg(4, '主页背景');

  final int value;
  final String label;
  const DecorationType(this.value, this.label);

  static DecorationType fromValue(int val) {
    return DecorationType.values.firstWhere((e) => e.value == val, orElse: () => DecorationType.avatarFrame);
  }
}

/// 装扮数据模型 (合并了 Store 表和 UserBag 表的数据)
class DecorationItem {
  final String storeId;     // 商城表 ID (CoinDecoration.id)
  String? bagId;            // 背包表 ID (CoinUserDecoration.id)，购买后才有
  final String name;
  final DecorationType type;
  final String imageUrl;    // 静态图
  final String resourceUrl; // 动效资源
  final int price;          // 价格
  final int days;           // 天数

  bool isOwned;             // 是否已拥有 (存在于背包)
  bool isEquipped;          // 是否佩戴中
  DateTime? expireDate;     // 过期时间

  DecorationItem({
    required this.storeId,
    this.bagId,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.resourceUrl,
    required this.price,
    required this.days,
    this.isOwned = false,
    this.isEquipped = false,
    this.expireDate,
  });

  // 判断是否过期
  bool get isExpired {
    if (expireDate == null) return false;
    return expireDate!.isBefore(DateTime.now());
  }
}

// ============================================================================
// 🟢 2. 核心 UI 与状态管理组件
// ============================================================================

class DecorationBottomSheet extends StatefulWidget {
  const DecorationBottomSheet({super.key});

  /// 外部一键调用方法：DecorationBottomSheet.show(context);
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (context) => const DecorationBottomSheet(),
    );
  }

  @override
  State<DecorationBottomSheet> createState() => _DecorationBottomSheetState();
}

class _DecorationBottomSheetState extends State<DecorationBottomSheet> with SingleTickerProviderStateMixin {

  int _currentMainTab = 0; // 0 - 商城，1 - 我的
  DecorationType _currentType = DecorationType.all;
  DecorationItem? _selectedItem;

  List<DecorationItem> _items = [];
  bool _isLoading = true; // 加载状态

  @override
  void initState() {
    super.initState();
    _fetchData(); // 🟢 初始化时请求接口
  }

  // ============================================================================
  // 🟢 3. API 接口请求与数据处理
  // ============================================================================

  /// 核心方法：同时拉取商城和背包数据，并在前端进行合并
  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // 1. 获取商城列表
      var storeRes = await HttpUtil().get('/api/decoration/store/list');
      // 2. 获取我的背包
      var bagRes = await HttpUtil().get('/api/decoration/my/list');

      List<DecorationItem> newItems = [];

      // 解析商城数据
      if (storeRes is List) {
        for (var s in storeRes) {
          newItems.add(DecorationItem(
            storeId: s['id'].toString(),
            name: s['name'] ?? '未命名装扮',
            type: DecorationType.fromValue(s['type'] ?? 1),
            imageUrl: s['iconUrl'] ?? '',
            resourceUrl: s['resourceUrl'] ?? '',
            price: s['price'] ?? 0,
            days: s['days'] ?? 7
          ));
        }
      }

      // 解析背包数据，并与商城数据进行合并
      if (bagRes is List) {
        for (var b in bagRes) {
          String decId = b['decorationId'].toString();
          // 在商城列表中查找对应的商品
          var matchIndex = newItems.indexWhere((e) => e.storeId == decId);

          DateTime? expTime;
          if (b['expireTime'] != null) {
            // 解析 SpringBoot 默认返回的 ISO 格式时间
            expTime = DateTime.tryParse(b['expireTime'].toString());
          }

          if (matchIndex != -1) {
            // 如果商城里有，直接更新拥有的状态
            newItems[matchIndex].isOwned = true;
            newItems[matchIndex].bagId = b['id'].toString();
            newItems[matchIndex].isEquipped = b['isEquipped'] == 1;
            newItems[matchIndex].expireDate = expTime;
          } else {
            // 如果商城下架了，但用户背包还有，也要加进列表以供在“我的装扮”中显示
            newItems.add(DecorationItem(
              storeId: decId,
              bagId: b['id'].toString(),
              name: b['decorationName'] ?? '绝版装扮', // 需确保后端 selectMyBagList 关联查询了名称和图片
              type: DecorationType.fromValue(b['type'] ?? 1),
              imageUrl: b['iconUrl'] ?? '',
              resourceUrl: b['resourceUrl'] ?? '',
              price: 0,
              days: 0,
              isOwned: true,
              isEquipped: b['isEquipped'] == 1,
              expireDate: expTime,
            ));
          }
        }
      }

      if (mounted) {
        setState(() {
          _items = newItems;
          _isLoading = false;
          // 刷新数据后，如果当前选中的物品状态变了，更新引用
          if (_selectedItem != null) {
            _selectedItem = _items.firstWhere((e) => e.storeId == _selectedItem!.storeId, orElse: () => _selectedItem!);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showToast("数据加载失败: $e");
      }
    }
  }

  /// 购买 / 续费 请求
  Future<void> _handleBuyOrRenew(DecorationItem item) async {
    _showLoadingDialog();
    try {
      await HttpUtil().post('/api/decoration/buy', data: {
        "decorationId": int.parse(item.storeId)
      });
      _hideLoadingDialog();
      _showToast('购买/续费成功！');
      _fetchData(); // 重新拉取刷新状态
    } catch (e) {
      _hideLoadingDialog();
      _showToast(e.toString());
    }
  }

  /// 佩戴 / 卸下 请求
  Future<void> _handleEquipToggle(DecorationItem item) async {
    if (item.bagId == null) {
      _showToast("装扮异常，无法佩戴");
      return;
    }
    _showLoadingDialog();
    try {
      // 佩戴/卸下 接口需要传入背包表里的记录 id
      await HttpUtil().post('/api/decoration/equip', data: {
        "id": int.parse(item.bagId!)
      });
      _hideLoadingDialog();
      _showToast(item.isEquipped ? '已卸下' : '佩戴成功！');
      _fetchData(); // 重新拉取刷新状态
    } catch (e) {
      _hideLoadingDialog();
      _showToast(e.toString());
    }
  }

  // --- 辅助 Toast 与 Loading ---
  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D81))),
    );
  }

  void _hideLoadingDialog() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  // ============================================================================
  // 🟢 4. UI 过滤与展示逻辑
  // ============================================================================

  /// 核心过滤逻辑：决定哪些 item 可以显示在当前的 GridView 中
  List<DecorationItem> get _displayItems {
    return _items.where((item) {
      // 1. 大Tab过滤
      if (_currentMainTab == 0) {
        // 🟢 【业务规则】商城模式：不要出现已拥有且未过期的装扮
        if (item.isOwned && !item.isExpired) {
          return false;
        }
      } else {
        // 我的模式：只显示已拥有
        if (!item.isOwned) {
          return false;
        }
      }

      // 2. 小分类过滤
      if (_currentType != DecorationType.all && item.type != _currentType) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final sheetHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      height: sheetHeight,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E28),
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildMainTabs(),
          const SizedBox(height: 12),
          _buildTypeFilter(),
          const SizedBox(height: 8),
          Expanded(child: _isLoading ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF4D81))) : _buildGridContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 48),
          const Expanded(
            child: Text('装扮中心', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          SizedBox(
            width: 48,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white54, size: 22),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMainTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMainTabItem('装扮商城', 0),
        const SizedBox(width: 60),
        _buildMainTabItem('我的装扮', 1),
      ],
    );
  }

  Widget _buildMainTabItem(String title, int index) {
    bool isSelected = _currentMainTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentMainTab = index;
          _selectedItem = null; // 切换大 Tab 时清除选中状态
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.white54,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: isSelected ? 16 : 15,
            ),
          ),
          const SizedBox(height: 6),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: isSelected ? 24 : 0,
            decoration: BoxDecoration(color: const Color(0xFFFF4D81), borderRadius: BorderRadius.circular(1.5)),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilter() {
    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: DecorationType.values.length,
        itemBuilder: (context, index) {
          final type = DecorationType.values[index];
          final isSelected = _currentType == type;

          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(type.label),
              selected: isSelected,
              showCheckmark: false,
              selectedColor: const Color(0xFFFF4D81).withOpacity(0.15),
              backgroundColor: Colors.white.withOpacity(0.04),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFFF4D81) : Colors.white60,
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(color: isSelected ? const Color(0xFFFF4D81).withOpacity(0.5) : Colors.transparent),
              onSelected: (bool selected) {
                setState(() {
                  _currentType = type;
                  _selectedItem = null;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildGridContent() {
    final items = _displayItems;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.white.withOpacity(0.2)),
            const SizedBox(height: 16),
            Text('这里空空如也', style: TextStyle(color: Colors.white.withOpacity(0.4))),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.65,
      ),
      itemBuilder: (context, index) {
        return _buildItemCard(items[index]);
      },
    );
  }

  Widget _buildItemCard(DecorationItem item) {
    bool showAsExpired = _currentMainTab == 1 && item.isExpired;
    bool isSelected = _selectedItem?.storeId == item.storeId;

    // 判断是否为荣耀buff
    bool isGloryBuff = item.type == DecorationType.gloryBuff;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedItem = item;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2A36),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFFFF4D81) : Colors.transparent, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. 上半部分
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 根据类型设置不同的显示方式
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: Container(
                      color: const Color(0xFF2A2A36),
                      child: Center(
                        child: ColorFiltered(
                          colorFilter: showAsExpired
                              ? const ColorFilter.matrix(<double>[
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0.2126, 0.7152, 0.0722, 0, 0,
                            0,      0,      0,      1, 0,
                          ])
                              : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                          child: isGloryBuff
                              ? Container(
                            padding: const EdgeInsets.only(top: 30, left: 10, right: 10, bottom: 10),
                            child: Image.network(
                              item.imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (c, e, s) => const Icon(Icons.image, color: Colors.white24, size: 30),
                            ),
                          )
                              : Image.network(
                            item.imageUrl,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: double.infinity,
                            errorBuilder: (c, e, s) => const Icon(Icons.image, color: Colors.white24, size: 40),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (item.isEquipped)
                    Positioned(
                      top: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF4D81),
                          borderRadius: BorderRadius.only(topRight: Radius.circular(11), bottomLeft: Radius.circular(8)),
                        ),
                        child: const Text('佩戴中', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),

            // 2. 下半部分
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(item.name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),

                  if (_currentMainTab == 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.diamond, color: Colors.cyanAccent, size: 11),
                        const SizedBox(width: 2),
                        Text('${item.price}/${item.days}天', style: const TextStyle(color: Colors.cyanAccent, fontSize: 11)),
                      ],
                    ),
                  ] else ...[
                    Text(
                        showAsExpired ? '已过期' : _formatRemainingTime(item.expireDate),
                        style: TextStyle(color: showAsExpired ? Colors.redAccent : Colors.white54, fontSize: 11)
                    ),
                  ],

                  const SizedBox(height: 8),
                  _buildActionButton(item, showAsExpired),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建卡片底部按钮状态机
  Widget _buildActionButton(DecorationItem item, bool isExpired) {
    String btnText;
    Color btnColor;
    Color textColor = Colors.white;
    VoidCallback? onTap;

    if (_currentMainTab == 0) {
      // 商城 Tab (因为过滤过了，这里要么是未购买的，要么是已过期的)
      if (item.isOwned) {
        btnText = '续费';
        btnColor = Colors.transparent;
        textColor = const Color(0xFFFFB74D);
        onTap = () => _handleBuyOrRenew(item);
      } else {
        btnText = '购买';
        btnColor = const Color(0xFFFF4D81);
        onTap = () => _handleBuyOrRenew(item);
      }
    } else {
      // 我的 Tab
      if (isExpired) {
        btnText = '续费';
        btnColor = const Color(0xFFFFB74D);
        onTap = () => _handleBuyOrRenew(item);
      } else if (item.isEquipped) {
        btnText = '卸下';
        btnColor = Colors.white.withOpacity(0.1);
        textColor = Colors.white70;
        onTap = () => _handleEquipToggle(item);
      } else {
        btnText = '佩戴';
        btnColor = const Color(0xFF4A90E2);
        onTap = () => _handleEquipToggle(item);
      }
    }

    return SizedBox(
      width: double.infinity,
      height: 28,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: btnColor == Colors.transparent ? const BorderSide(color: Color(0xFFFFB74D)) : BorderSide.none,
          ),
        ),
        onPressed: onTap,
        child: Text(btnText, style: TextStyle(fontSize: 12, color: textColor, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _formatRemainingTime(DateTime? expireDate) {
    if (expireDate == null) return '永久有效';
    final diff = expireDate.difference(DateTime.now());
    if (diff.inDays > 0) return '剩 ${diff.inDays} 天';
    if (diff.inHours > 0) return '剩 ${diff.inHours} 小时';
    return '不足1小时';
  }
}