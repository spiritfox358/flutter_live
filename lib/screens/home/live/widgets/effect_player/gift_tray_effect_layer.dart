import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:path_provider/path_provider.dart';

// 引入您的 Model 和 Banner 组件
import '../../models/live_models.dart';
import '../gift_banner/animate_gift_item.dart';

class GiftTrayEffectLayer extends StatefulWidget {
  const GiftTrayEffectLayer({super.key});

  @override
  State<GiftTrayEffectLayer> createState() => GiftTrayEffectLayerState();
}

class GiftTrayEffectLayerState extends State<GiftTrayEffectLayer> {
  // -------------------------------------------------------
  // 🔧 槽位基础配置
  // -------------------------------------------------------
  final double _bottomOrigin = 320.0;
  final double _leftOrigin = 16.0;

  // 【修改点】：调小高度，使Banner更紧凑 (保留您的设置)
  final double _slotHeight = 50.0;
  // 【修改点】：调小间距 (保留您的设置)
  final double _slotSpacing = 0.0;
  // -------------------------------------------------------

  final Queue<GiftEvent> _waitingQueue = Queue();
  final List<GiftEvent?> _activeSlots = [null, null];

  // 【新增】：为每个槽位维护一个 GlobalKey，用于触发连击
  final List<GlobalKey<_GiftTraySlotItemState>?> _slotKeys = [null, null];

  void addTrayGift(GiftEvent newGift) {
    // ---------------------------------------------------------
    // 1. 检查连击 (Combo Check)
    // ---------------------------------------------------------
    for (int i = 0; i < _activeSlots.length; i++) {
      final currentGift = _activeSlots[i];
      // 判断条件：槽位不为空 && 是同一个用户 && 是同一种礼物
      // 注意：这里用 senderName 和 giftName 判断，如果您的 Model 有 uid 或 giftId 更好
      if (currentGift != null &&
          currentGift.senderName == newGift.senderName &&
          currentGift.giftName == newGift.giftName) {

        debugPrint("🚀 [Tray] 触发连击: Slot $i");

        // 更新 activeSlots 里的数据 (保持最新，虽然不触发重绘)
        _activeSlots[i] = newGift;

        // 【核心】：通过 Key 直接调用子组件的连击方法，不销毁组件，不重播视频
        _slotKeys[i]?.currentState?.triggerCombo(newGift);
        return; // 连击处理完毕，直接返回
      }
    }

    // ---------------------------------------------------------
    // 2. 寻找空位 (Find Free Slot)
    // ---------------------------------------------------------
    int freeSlotIndex = _activeSlots.indexOf(null);
    if (freeSlotIndex != -1) {
      _playInSlot(freeSlotIndex, newGift);
    } else {
      _waitingQueue.add(newGift);
    }
  }

  void _playInSlot(int index, GiftEvent gift) {
    setState(() {
      _activeSlots[index] = gift;
      // 【新增】：新开槽位时，创建新的 GlobalKey
      _slotKeys[index] = GlobalKey<_GiftTraySlotItemState>();
    });
  }

  void _onSlotFinished(int index) {
    setState(() {
      _activeSlots[index] = null;
      _slotKeys[index] = null; // 清理 Key
    });

    if (_waitingQueue.isNotEmpty) {
      final nextGift = _waitingQueue.removeFirst();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) {
          // 注意：这里改调 addTrayGift，这样队列里出来的礼物也能触发连击逻辑
          addTrayGift(nextGift);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (_activeSlots[0] != null) _buildPositionedSlot(0, _activeSlots[0]!),
        if (_activeSlots[1] != null) _buildPositionedSlot(1, _activeSlots[1]!),
      ],
    );
  }

  Widget _buildPositionedSlot(int index, GiftEvent gift) {
    double bottomPos = _bottomOrigin + (index * (_slotHeight + _slotSpacing));

    return Positioned(
      bottom: bottomPos,
      left: _leftOrigin,
      child: SizedBox(
        width: 350,
        height: _slotHeight,
        child: _GiftTraySlotItem(
          // 【关键】：传入 GlobalKey
          key: _slotKeys[index],
          initialGiftEvent: gift,
          onAllFinished: () => _onSlotFinished(index),
        ),
      ),
    );
  }
}

class _GiftTraySlotItem extends StatefulWidget {
  // 改名为 initialGiftEvent，表示这只是初始值
  final GiftEvent initialGiftEvent;
  final VoidCallback onAllFinished;

  const _GiftTraySlotItem({
    Key? key,
    required this.initialGiftEvent,
    required this.onAllFinished,
  }) : super(key: key);

  @override
  State<_GiftTraySlotItem> createState() => _GiftTraySlotItemState();
}

class _GiftTraySlotItemState extends State<_GiftTraySlotItem> {
  // =======================================================
  // 🔧🔧🔧 智能调节区域 (保留您的原有参数) 🔧🔧🔧
  // =======================================================
  final int _videoDurationMs = 3000;
  final int _earlyShowMs = 280;

  final double _scale = 0.8;
  static const double _baseWidth = 400.0;
  static const double _baseHeight = 800.0;
  static const double _baseTop = -300.0;
  static const double _baseLeft = -25.0;

  final double _bannerLeft = -5.0;
  final double _bannerTop = 60.0;

  double get _videoWidth => _baseWidth * _scale;
  double get _videoHeight => _baseHeight * _scale;
  double get _videoTop => _baseTop * _scale + (60 * (1 - _scale)) / 2;
  double get _videoLeft => _baseLeft * _scale;
  // =======================================================

  bool _showVideo = false;
  bool _showBanner = false;

  MyAlphaPlayerController? _alphaController;
  String? _effectPath;
  Timer? _earlyShowTimer;

  late String _stableBannerKeyId;

  // 【新增】：内部维护当前显示的 GiftEvent，用于连击更新
  late GiftEvent _currentGiftEvent;

  @override
  void initState() {
    super.initState();
    // 初始化当前事件
    _currentGiftEvent = widget.initialGiftEvent;
    _stableBannerKeyId = widget.initialGiftEvent.id;
    _startSequence();
  }

  // =======================================================
  // 🚀 【新增方法】用于父组件调用，触发连击
  // =======================================================
  void triggerCombo(GiftEvent newGift) {
    if (!mounted) return;

    setState(() {
      // 计算新的数量。假设 newGift.count 是 1，我们要累加。
      // 如果后端直接传总数，就直接用 newGift.count。
      // 这里为了稳妥，我们手动累加一下：
      int newTotalCount = _currentGiftEvent.count + newGift.count;

      // 使用 copyWith 更新数量 (前提是您的 Model copyWith 已经修复)
      // 如果 copyWith 还有问题，您可以暂时用下面这种笨办法构造对象:
      _currentGiftEvent = _currentGiftEvent.copyWith(count: newTotalCount);
    });

    debugPrint("🔥 [TrayItem] 连击生效，当前数量: ${_currentGiftEvent.count}");
  }
  // =======================================================

  void _startSequence() async {
    String? effectUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/banner_tray/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E7%A4%BC%E7%89%A9%E6%89%98%E7%9B%98.mp4";

    if (effectUrl == null || effectUrl.isEmpty) {
      if (mounted) setState(() => _showBanner = true);
      return;
    }

    String? path;
    if (kIsWeb) {
      path = effectUrl;
    } else {
      path = await _downloadFile(effectUrl);
    }

    if (path != null && mounted) {
      _effectPath = path;
      setState(() {
        _showVideo = true;
        _showBanner = false;
      });
    } else {
      if (mounted) setState(() => _showBanner = true);
    }
  }

  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaController = controller;
    _alphaController?.onFinish = () {
      debugPrint("🎬 [Tray] 视频结束");
      if (mounted) {
        setState(() {
          _showVideo = false;
          // 兜底：如果计时器没触发，这里强制显示 Banner
          if (!_showBanner) _showBanner = true;
        });
      }
    };

    if (_effectPath != null) {
      _alphaController?.play(_effectPath!);
      _startBannerTimer();
    }
  }

  void _startBannerTimer() {
    int delayMs = _videoDurationMs - _earlyShowMs;
    if (delayMs < 0) delayMs = 0;

    _earlyShowTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted) {
        setState(() => _showBanner = true);
      }
    });
  }

  Future<String?> _downloadFile(String url) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      String fileName = "tray_${url.hashCode}.mp4";
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);
      if (await file.exists()) return savePath;
      await Dio().download(url, savePath);
      if (await file.exists()) return savePath;
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _earlyShowTimer?.cancel();
    _alphaController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. 视频层
        Positioned(
          top: _videoTop,
          left: _videoLeft,
          child: SizedBox(
            width: _videoWidth,
            height: _videoHeight,
            // 始终保留 MyAlphaPlayerView 的位置，不销毁
            child: _showVideo
                ? IgnorePointer(
              child: MyAlphaPlayerView(
                key: const ValueKey("TrayEffectPlayer"),
                onCreated: _onPlayerCreated,
              ),
            )
                : const SizedBox(),
          ),
        ),

        // 2. Banner 层
        if (_showBanner)
          Positioned(
            left: _bannerLeft,
            top: _bannerTop,
            child: AnimatedGiftItem(
              // 【核心修改】：使用 widget.initialGiftEvent.id 作为 Key
              // 这样即使 count 变了，Key 依然不变，Flutter 就不会销毁这个 Widget
              // 而是触发 AnimatedGiftItem 内部的 didUpdateWidget，从而播放连击动画
              key: ValueKey("Banner_$_stableBannerKeyId"),

              // 传入最新的事件数据 (包含最新的 count)
              giftEvent: _currentGiftEvent,

              onFinished: widget.onAllFinished,
            ),
          ),
      ],
    );
  }
}