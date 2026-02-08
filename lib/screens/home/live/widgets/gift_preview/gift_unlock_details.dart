import 'package:flutter/material.dart';
import '../../../../../tools/HttpUtil.dart'; // 请确保路径正确
import '../../models/live_models.dart';
import '../recharge_popup.dart';
import 'gift_preview_loop_player.dart';

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
  // 基础详情数据
  String _currentBgUrl = "";
  String _currentVideoUrl = "";
  String _introTitle = "";
  String _content = "加载中...";

  List<GiftItemData> _gifts = [];
  final Map<int, dynamic> _detailsCache = {};

  // 🟢 状态管理：充值与解锁
  int _currentRecharge = 0;      // 当前周充值金额 (分)
  int _unlockThreshold = 150000; // 解锁门槛 (默认15万)
  bool _isUnlocked = false;      // 是否已解锁
  bool _isUnlocking = false;     // 是否正在请求解锁接口

  int _selectedIndex = 0;
  bool _isLoading = true;
  late ScrollController _scrollController;
  bool _isPreviewOn = false;

  @override
  void initState() {
    super.initState();
    _gifts = [widget.currentGift];
    _scrollController = ScrollController();
    _fetchInitData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePreview(bool value) {
    if (_currentVideoUrl.isEmpty && value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("该礼物暂无特效视频"), duration: Duration(seconds: 1)),
      );
      return;
    }
    setState(() {
      _isPreviewOn = value;
    });
  }

  /// 🟢 1. 获取初始化数据 (包含充值进度)
  Future<void> _fetchInitData() async {
    try {
      final res = await HttpUtil().get(
          '/api/gift-detail/init',
          params: {'giftId': widget.currentGift.id}
      );

      if (mounted && res != null) {
        setState(() {
          // 礼物列表
          final listData = res['privilegeGifts'] as List;
          _gifts = listData.map((e) => GiftItemData.fromJson(e)).toList();

          _selectedIndex = _gifts.indexWhere((g) => g.id == widget.currentGift.id);
          if (_selectedIndex == -1) _selectedIndex = 0;

          // 详情内容
          if (res['detail'] != null) {
            _detailsCache[int.parse(widget.currentGift.id)] = res['detail'];
            _updateDisplayDetail(res['detail']);
          }

          // 🟢 解析进度数据
          _currentRecharge = res['weeklyRecharge'] ?? 0;
          _unlockThreshold = res['unlockThreshold'] ?? 150000;
          _isUnlocked = res['isUnlocked'] ?? false;

          _isLoading = false;
        });

        Future.delayed(const Duration(milliseconds: 100), () => _scrollToCenter(_selectedIndex));
      }
    } catch (e) {
      debugPrint("初始化数据失败: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// 切换礼物
  Future<void> _onGiftSelected(int index) async {
    if (_selectedIndex == index) return;

    setState(() {
      _selectedIndex = index;
      _isLoading = true;
      _isPreviewOn = false; // 切换时关闭预览，避免视频错乱
    });
    _scrollToCenter(index);

    final selectedId = _gifts[index].id;

    try {
      // 切换礼物时，理论上后端也应该返回该礼物的解锁状态
      // 这里简化处理：假设切换只更新详情文案，进度逻辑如果不同礼物不同，
      // 则需要后端 '/api/gift-detail/$selectedId' 也返回 weeklyRecharge 等字段
      if (_detailsCache.containsKey(int.parse(selectedId))) {
        _updateDisplayDetail(_detailsCache[int.parse(selectedId)]);
        setState(() => _isLoading = false);
      } else {
        final detail = await HttpUtil().get('/api/gift-detail/$selectedId');
        _detailsCache[int.parse(selectedId)] = detail;
        _updateDisplayDetail(detail);
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("切换礼物详情失败: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateDisplayDetail(dynamic detail) {
    if (detail != null) {
      _currentBgUrl = detail['bgUrl'] ?? "";
      _introTitle = detail['introTitle'] ?? "";
      _content = detail['content'] ?? "";
      _currentVideoUrl = detail['videoUrl'] ?? "";
    }
  }

  void _scrollToCenter(int index) {
    if (!_scrollController.hasClients) return;
    const double itemWidth = 80.0;
    final double halfScreen = MediaQuery.of(context).size.width / 2;
    double offset = (index * itemWidth) - halfScreen + (itemWidth / 2);

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent + 50),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  /// 🟢 2. 执行解锁逻辑
  Future<void> _handleUnlock() async {
    if (_isUnlocking) return;
    setState(() => _isUnlocking = true);

    try {
      // 调用解锁接口
      await HttpUtil().post(
        '/api/gift-detail/unlock',
        data: {'giftId': _gifts[_selectedIndex].id},
      );
      // 假设 HttpUtil 封装了 code==200 的判断，否则在这里判断
      if (mounted) {
        setState(() {
          _isUnlocked = true; // 标记为已解锁
          _isUnlocking = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 恭喜！解锁成功，尊贵身份已激活"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint("解锁失败: $e");
      if (mounted) {
        setState(() => _isUnlocking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("解锁失败: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final double height = MediaQuery.of(context).size.height * 0.7;
    final double bottomPanelHeight = 120.0 + MediaQuery.of(context).padding.bottom;

    return Container(
      height: height,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // 1. 背景图
          Positioned.fill(
            child: _currentBgUrl.isNotEmpty
                ? Image.network(_currentBgUrl, fit: BoxFit.cover)
                : Container(color: const Color(0xFF0C0C0E)),
          ),

          // 2. 特效视频预览
          if (_isPreviewOn && _currentVideoUrl.isNotEmpty)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: bottomPanelHeight - 20,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.width * 16 / 9,
                        child: GiftPreviewLoopPlayer(videoUrl: _currentVideoUrl),
                      ),
                    ),
                  ),
                  // 边缘遮罩
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withOpacity(1),
                            Colors.black.withOpacity(0.8),
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                            Colors.black.withOpacity(0.9),
                          ],
                          stops: const [0.0, 0.2, 0.5, 0.6, 0.8, 1.0],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 3. 全局遮罩
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),

          // 4. 内容层
          Column(
            children: [
              const SizedBox(height: 12),
              _buildAppBar(context),
              _buildThumbnailList(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: Colors.white24, strokeWidth: 2))
                    : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: _buildDescriptionContent(),
                ),
              ),
              // 底部操作栏
              _buildBottomActionPanel(context),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          const Text(
            "神秘商店",
            style: TextStyle(color: Color(0xFFEBD3B6), fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("预览", style: TextStyle(color: _isPreviewOn ? const Color(0xFFF2D194) : Colors.white60, fontSize: 12)),
                const SizedBox(width: 6),
                Transform.scale(
                  scale: 0.7,
                  child: Switch(
                    value: _isPreviewOn,
                    activeColor: const Color(0xFFF2D194),
                    activeTrackColor: const Color(0xFF4A3418),
                    inactiveThumbColor: Colors.grey,
                    inactiveTrackColor: Colors.white12,
                    onChanged: _togglePreview,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailList() {
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _gifts.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedIndex;
          return GestureDetector(
            onTap: () => _onGiftSelected(index),
            child: Container(
              width: 80.0,
              color: Colors.transparent,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                width: isSelected ? 68.0 : 50.0,
                height: isSelected ? 68.0 : 50.0,
                padding: EdgeInsets.all(isSelected ? 8.0 : 4.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFF2D194).withAlpha(100) : Colors.transparent,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected ? const Color(0xFFF2D194).withOpacity(0.25) : Colors.transparent,
                      blurRadius: isSelected ? 12.0 : 0.0,
                      spreadRadius: isSelected ? 1.0 : 0.0,
                    )
                  ],
                ),
                child: Opacity(
                  opacity: isSelected ? 1.0 : 0.6,
                  child: Image.network(_gifts[index].iconUrl, fit: BoxFit.contain),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDescriptionContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _gifts[_selectedIndex].name,
          style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(width: 40, height: 2, color: const Color(0xFFEBD3B6)),
        const SizedBox(height: 24),
        Text(
          _introTitle,
          style: TextStyle(color: const Color(0xFFEBD3B6).withOpacity(0.9), fontSize: 16, fontStyle: FontStyle.italic),
        ),
        const SizedBox(height: 16),
        Text(
          _content,
          textAlign: TextAlign.left,
          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.7),
        ),
      ],
    );
  }

  /// 🟢 3. 底部操作栏（核心修改区域）
  Widget _buildBottomActionPanel(BuildContext context) {
    // 数据计算 (单位换算：假设金额单位是分，显示为万)
    // 实际根据你业务逻辑调整，这里假设后端返回的是整数(如150000)
    final double targetWan = _unlockThreshold / 10000;
    final double currentWan = _currentRecharge / 10000;
    final double diffWan = (_unlockThreshold - _currentRecharge) > 0
        ? (_unlockThreshold - _currentRecharge) / 10000
        : 0;

    // 是否满足解锁条件
    final bool canUnlock = _currentRecharge >= _unlockThreshold;
    // 进度条 (0.0 - 1.0)
    final double progress = (_currentRecharge / _unlockThreshold).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1F2A).withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          // 左侧：进度信息
          Expanded(
            flex: 75,
            child: GestureDetector(
              onTap: ()async {
                // 点击左侧文字也能打开充值弹窗，提升体验
                if (!_isUnlocked && !canUnlock) {
                  // 🟢 2. 等待充值结果
                  final success = await RechargePopup.show(context);
                  // 🟢 3. 如果成功，刷新数据
                  if (success == true) {
                    _fetchInitData();
                  }
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Text("周期解锁", style: TextStyle(color: Color(0xFFC7C7CC), fontSize: 13)),
                      const SizedBox(width: 6),
                      // 已解锁显示绿色勾
                      if (_isUnlocked)
                        const Icon(Icons.check_circle, color: Colors.green, size: 14),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 根据状态显示不同文案
                  _isUnlocked
                      ? const Text("已达成条件，特权已激活", style: TextStyle(fontSize: 13, color: Colors.greenAccent))
                      : RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      children: [
                        const TextSpan(text: "已充"),
                        TextSpan(
                            text: "${currentWan.toStringAsFixed(2)}万",
                            style: const TextStyle(color: Color(0xFFFFD700))),
                        const TextSpan(text: "，差"),
                        TextSpan(
                            text: "${diffWan.toStringAsFixed(2)}万",
                            style: const TextStyle(color: Color(0xFFFFD700))),
                        const TextSpan(text: "可得"),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 进度条
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: _isUnlocked ? 1.0 : progress,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          _isUnlocked ? Colors.green : const Color(0xFFFFD700)
                      ),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),

          // 右侧：操作按钮
          Expanded(
            flex: 25,
            child: InkWell(
              onTap: ()async {
                if (_isUnlocked) return;
                // 2. 正在解锁中 -> 无操作
                if (_isUnlocking) return;

                if (canUnlock) {
                  // 3. 达标 -> 执行解锁
                  _handleUnlock();
                } else {
                  // 4. 未达标 -> 去充值
                  // 🟢 5. 等待充值结果并刷新
                  final success = await RechargePopup.show(context);
                  if (success == true) {
                    _fetchInitData();
                  }
                }
              },
              borderRadius: BorderRadius.circular(12),
              splashColor: Colors.white.withOpacity(0.1),
              highlightColor: Colors.transparent,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _isUnlocked
                        ? [Colors.white24, Colors.white24] // 灰色
                        : canUnlock
                        ? [const Color(0xFF43A047), const Color(0xFF66BB6A)] // 绿色 (立即解锁)
                        : [const Color(0xFFF2D194), const Color(0xFFD6A563)], // 金色 (立即充值)
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isUnlocking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(
                  _isUnlocked
                      ? "已解锁"
                      : (canUnlock ? "立即解锁" : "立即充值"),
                  style: TextStyle(
                    color: canUnlock || _isUnlocked ? Colors.white : const Color(0xFF4A3418),
                    fontSize: 13,
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
}