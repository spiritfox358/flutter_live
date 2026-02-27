import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:path_provider/path_provider.dart';

// 引入您的 Model 和 Banner 组件
// ⚠️ 请确保路径正确
import '../../models/live_models.dart';
import '../gift_banner/animate_gift_item.dart';

class GiftTrayEffectLayer extends StatefulWidget {
  // 回调函数：通知外部播放全屏特效
  final Function(GiftEvent event)? onEffectTrigger;

  // 🟢 控制开关
  // true  = 旧逻辑：等待 Tray 视频播完 + 等待 1秒，再播放特效
  // false = 新逻辑：不等 Tray 视频播完，直接播放特效 (立即触发)
  final bool enableEffectDelay;

  const GiftTrayEffectLayer({
    super.key,
    this.onEffectTrigger,
    this.enableEffectDelay = false,
  });

  @override
  State<GiftTrayEffectLayer> createState() => GiftTrayEffectLayerState();
}

class GiftTrayEffectLayerState extends State<GiftTrayEffectLayer> {
  // -------------------------------------------------------
  // 🔧 槽位基础配置
  // -------------------------------------------------------
  final double _bottomOrigin = 320.0;
  final double _leftOrigin = 16.0;

  final double _slotHeight = 50.0;
  final double _slotSpacing = 0.0;
  // -------------------------------------------------------

  final Queue<GiftEvent> _waitingQueue = Queue();
  final List<GiftEvent?> _activeSlots = [null, null];
  final List<GlobalKey<_GiftTraySlotItemState>?> _slotKeys = [null, null];

  void addTrayGift(GiftEvent newGift) {
    // ---------------------------------------------------------
    // 1. 检查连击 (Combo Check)
    // ---------------------------------------------------------
    for (int i = 0; i < _activeSlots.length; i++) {
      final currentGift = _activeSlots[i];
      if (currentGift != null &&
          currentGift.senderName == newGift.senderName &&
          currentGift.giftName == newGift.giftName) {

        debugPrint("🚀 [Tray] 触发连击: Slot $i");

        // 更新数据
        _activeSlots[i] = newGift;

        // 调用子组件更新连击数
        _slotKeys[i]?.currentState?.triggerCombo(newGift);
        return;
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
    if (!mounted) return;
    setState(() {
      _activeSlots[index] = gift;
      _slotKeys[index] = GlobalKey<_GiftTraySlotItemState>();
    });
  }

  void _onSlotFinished(int index) {
    if (!mounted) return;
    setState(() {
      _activeSlots[index] = null;
      _slotKeys[index] = null;
    });

    if (_waitingQueue.isNotEmpty) {
      final nextGift = _waitingQueue.removeFirst();
      Future.delayed(const Duration(milliseconds: 50), () {
        if (mounted) addTrayGift(nextGift);
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
          key: _slotKeys[index],
          initialGiftEvent: gift,
          onEffectTrigger: widget.onEffectTrigger,
          onAllFinished: () => _onSlotFinished(index),
          enableEffectDelay: widget.enableEffectDelay, // 透传开关
        ),
      ),
    );
  }
}

class _GiftTraySlotItem extends StatefulWidget {
  final GiftEvent initialGiftEvent;
  final VoidCallback onAllFinished;
  final Function(GiftEvent event)? onEffectTrigger;
  final bool enableEffectDelay;

  const _GiftTraySlotItem({
    super.key,
    required this.initialGiftEvent,
    required this.onAllFinished,
    this.onEffectTrigger,
    required this.enableEffectDelay,
  });

  @override
  State<_GiftTraySlotItem> createState() => _GiftTraySlotItemState();
}

class _GiftTraySlotItemState extends State<_GiftTraySlotItem> {
  // =======================================================
  // 🔧🔧🔧 智能调节区域 🔧🔧🔧
  // =======================================================
  final int _videoDurationMs = 3000;
  final int _earlyShowMs = 120;

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

  // 状态标志位：是否允许触发全屏特效
  bool _isReadyForComboEffect = false;

  // 缓冲计数器
  int _bufferedComboCount = 0;

  // 🛑 生命周期控制标志
  bool _bannerAnimationFinished = false; // Banner 动画是否播完
  bool _effectTriggerLogicDone = false;  // 特效触发逻辑是否已执行（包括等待时间）

  MyAlphaPlayerController? _alphaController;
  String? _effectPath;
  Timer? _earlyShowTimer;

  late String _stableBannerKeyId;
  late GiftEvent _currentGiftEvent;

  @override
  void initState() {
    super.initState();
    _currentGiftEvent = widget.initialGiftEvent;
    _stableBannerKeyId = widget.initialGiftEvent.id;
    _startSequence();
  }

  // 🟢 尝试结束整个 Slot 的生命周期
  // 只有当【Banner播完】且【特效逻辑走完】时，才真正通知父组件销毁
  void _tryToFinish() {
    if (_bannerAnimationFinished && _effectTriggerLogicDone) {
      debugPrint("✅ [Tray] 所有任务完成，销毁 Slot");
      widget.onAllFinished();
    }
  }

  // 🟢 触发连击
  void triggerCombo(GiftEvent newGift) {
    if (!mounted) return;

    setState(() {
      int newTotalCount = _currentGiftEvent.count + newGift.count;
      _currentGiftEvent = _currentGiftEvent.copyWith(count: newTotalCount);
    });

    if (_isReadyForComboEffect) {
      debugPrint("⚡️ [Tray] 连击触发，立即播放特效");
      widget.onEffectTrigger?.call(newGift);
    } else {
      _bufferedComboCount++;
      debugPrint("⏳ [Tray] 视频未结束，连击特效已缓存 (积压: $_bufferedComboCount)");
    }
  }

  void _startSequence() async {
    int giftPrice = widget.initialGiftEvent.giftPrice ?? 0;

    // 🟢 情况 1: 低价礼物 (< 1000)
    if (giftPrice < 1000) {
      if (mounted) {
        setState(() {
          _showVideo = false;
          _showBanner = true;
          _isReadyForComboEffect = true;
          _effectTriggerLogicDone = true; // 低价礼物无需等待特效逻辑
        });
      }
      widget.onEffectTrigger?.call(_currentGiftEvent);
      return;
    }

    // 🟢 情况 2: 高级礼物 (>= 1000)
    String? effectUrl = "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/banner_tray/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E7%A4%BC%E7%89%A9%E6%89%98%E7%9B%98.mp4";

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

        // 🔴 逻辑分歧点
        if (widget.enableEffectDelay) {
          // [Enable=true] -> 旧逻辑：等待
          _isReadyForComboEffect = false;
          _effectTriggerLogicDone = false; // 还没做完，需要等视频结束+1s
          _bufferedComboCount = 0;
        } else {
          // [Enable=false] -> 新逻辑：不等，立即就绪
          _isReadyForComboEffect = true;
          _effectTriggerLogicDone = true; // 立即触发算作做完
          _bufferedComboCount = 0;
          debugPrint("🚀 [Tray] 新逻辑：立即触发全屏特效");
          widget.onEffectTrigger?.call(_currentGiftEvent);
        }
      });
    } else {
      // 下载失败，直接兜底
      if (mounted) {
        setState(() {
          _showBanner = true;
          _isReadyForComboEffect = true;
          _effectTriggerLogicDone = true;
        });
        widget.onEffectTrigger?.call(_currentGiftEvent);
      }
    }
  }

  void _onPlayerCreated(MyAlphaPlayerController controller) {
    _alphaController = controller;

    // 1. 视频结束回调
    _alphaController?.onFinish = () {
      debugPrint("🎬 [Tray] 视频结束");
      if (mounted) {
        setState(() {
          _showVideo = false;
          if (!_showBanner) _showBanner = true;
        });
      }

      // 🔴 仅在 [Enable=true] (旧逻辑) 且 尚未就绪时 执行等待
      if (widget.enableEffectDelay && !_isReadyForComboEffect) {
        // ⏳ 旧逻辑：等待 1000ms
        // 这里不需要 check mounted，因为我们通过 _tryToFinish 强行续命了
        Future.delayed(const Duration(milliseconds: 1000), () {
          debugPrint("⏰ 1秒已到，开始处理特效队列");

          // 此时 mounted 应该是 true，因为 bannerFinished 还没发出去
          if (mounted) {
            // A. 触发特效
            widget.onEffectTrigger?.call(_currentGiftEvent);

            // B. 补发积压
            if (_bufferedComboCount > 0) {
              for (int i = 0; i < _bufferedComboCount; i++) {
                widget.onEffectTrigger?.call(_currentGiftEvent);
              }
              _bufferedComboCount = 0;
            }

            // C. 标记状态
            _isReadyForComboEffect = true;
            _effectTriggerLogicDone = true; // ✅ 特效逻辑终于跑完了

            // D. 尝试结束 (如果 Banner 早就播完了，这里就会触发销毁)
            _tryToFinish();
          } else {
            // 如果万一还是 unmounted 了 (异常情况)，至少尝试调一下回调
            widget.onEffectTrigger?.call(_currentGiftEvent);
          }
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

  // 🟢 Banner 动画播放完毕的回调
  void _onBannerAnimationFinished() {
    debugPrint("🚩 [Tray] Banner 动画播放完毕");
    _bannerAnimationFinished = true; // 标记 Banner 已完成
    _tryToFinish(); // 尝试结束 (如果特效还在等 1s，这里不会销毁，会等特效做完)
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
        Positioned(
          top: _videoTop,
          left: _videoLeft,
          child: SizedBox(
            width: _videoWidth,
            height: _videoHeight,
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

        if (_showBanner)
          Positioned(
            left: _bannerLeft,
            top: _bannerTop,
            child: AnimatedGiftItem(
              key: ValueKey("Banner_$_stableBannerKeyId"),
              giftEvent: _currentGiftEvent,
              // 🔴 关键修改：不要直接调 widget.onAllFinished，而是调我们的中间层
              onFinished: _onBannerAnimationFinished,
            ),
          ),
      ],
    );
  }
}