import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/live_models.dart';
import '../gift_banner/animate_gift_item.dart';

// 🚀 导入唯一单例信号站
import 'user_entrance_effect_layer.dart';

class GiftTrayEffectLayer extends StatefulWidget {
  final Function(GiftEvent event)? onEffectTrigger;
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
  final double _leftOrigin = 16.0;
  final double _slotHeight = 40.0;
  final double _slotSpacing = -1.0; // 连击时的间距稍微留一点

  final Queue<GiftEvent> _waitingQueue = Queue();
  final List<GiftEvent?> _activeSlots = [null, null];
  final List<GlobalKey<_GiftTraySlotItemState>?> _slotKeys = [null, null];

  void addTrayGift(GiftEvent newGift) {
    for (int i = 0; i < _activeSlots.length; i++) {
      final currentGift = _activeSlots[i];
      if (currentGift != null &&
          currentGift.senderName == newGift.senderName &&
          currentGift.giftName == newGift.giftName) {
        _activeSlots[i] = newGift;
        _slotKeys[i]?.currentState?.triggerCombo(newGift);
        return;
      }
    }

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
    // =========================================================
    // 🚀🚀🚀 终极适配修复：完美复刻 real_live_page 进场条的坐标体系！
    // =========================================================
    double paddingTop = MediaQuery.of(context).padding.top;
    double screenWidth = MediaQuery.of(context).size.width;
    double pkVideoHeight = screenWidth * 0.87;

    // 💡 这里的 162.0 来自于你主页的代码：TopBar(50) + gap(68) + MaxTopOffset(40) + margin(4)
    double entranceTop = paddingTop + pkVideoHeight + 162.0;

    // 让礼物图层的整体基准高度，死死咬住进场条的 Top！
    // 无论换多长多短的手机，它们的间距绝对是一模一样的！
    double baseTopOrigin = entranceTop - 15.0; // -15 只是为了微调 MP4 特效的中心点
    double topPos = baseTopOrigin + (index * (_slotHeight + _slotSpacing));

    return Positioned(
      // 🚀 核心：废弃 bottom 定位，彻底改为 top 定位！
      top: topPos,
      left: _leftOrigin,
      child: SizedBox(
        width: 350,
        height: _slotHeight,
        child: _GiftTraySlotItem(
          key: _slotKeys[index],
          initialGiftEvent: gift,
          onEffectTrigger: widget.onEffectTrigger,
          onAllFinished: () => _onSlotFinished(index),
          enableEffectDelay: widget.enableEffectDelay,
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
  final int _videoDurationMs = 3000;
  final int _earlyShowMs = 100;

  final double _scale = 0.8;
  static const double _baseWidth = 300.0;
  static const double _baseHeight = 630.0;
  static const double _baseTop = -220.0;
  static const double _baseLeft = -25.0;

  final double _bannerLeft = -5.0;

  // 🚀 Banner 避让核心配置 (保持简单的固定值，因为现在父组件已经完美对齐了)
  final double _baseBannerTop = 12.0;
  final double _bannerShiftAmount = 25.0; // 进场条出现时 +20 丝滑下移

  double get _videoWidth => _baseWidth * _scale;
  double get _videoHeight => _baseHeight * _scale;
  double get _videoTop => _baseTop * _scale + (60 * (1 - _scale)) / 2;
  double get _videoLeft => _baseLeft * _scale;

  bool _showVideo = false;
  bool _showBanner = false;
  bool _isEntranceActive = false;

  bool _isReadyForComboEffect = false;
  int _bufferedComboCount = 0;
  bool _bannerAnimationFinished = false;
  bool _effectTriggerLogicDone = false;

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

    EntranceSignal.active.addListener(_onEntranceChanged);
    _isEntranceActive = EntranceSignal.active.value;

    _startSequence();
  }

  void _onEntranceChanged() {
    if (mounted) {
      setState(() {
        _isEntranceActive = EntranceSignal.active.value;
      });
    }
  }

  void _tryToFinish() {
    if (_bannerAnimationFinished && _effectTriggerLogicDone) {
      widget.onAllFinished();
    }
  }

  void triggerCombo(GiftEvent newGift) {
    if (!mounted) return;
    setState(() {
      int newTotalCount = _currentGiftEvent.count + newGift.count;
      _currentGiftEvent = _currentGiftEvent.copyWith(count: newTotalCount);
    });

    if (_isReadyForComboEffect) {
      widget.onEffectTrigger?.call(newGift);
    } else {
      _bufferedComboCount++;
    }
  }

  void _startSequence() async {
    int giftPrice = widget.initialGiftEvent.giftPrice ?? 0;

    if (giftPrice < 1000) {
      if (mounted) {
        setState(() {
          _showVideo = false;
          _showBanner = true;
          _isReadyForComboEffect = true;
          _effectTriggerLogicDone = true;
        });
      }
      widget.onEffectTrigger?.call(_currentGiftEvent);
      return;
    }

    String? effectUrl =
        "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/banner_tray/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E7%A4%BC%E7%89%A9%E6%89%98%E7%9B%982.mp4";

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

        if (widget.enableEffectDelay) {
          _isReadyForComboEffect = false;
          _effectTriggerLogicDone = false;
          _bufferedComboCount = 0;
        } else {
          _isReadyForComboEffect = true;
          _effectTriggerLogicDone = true;
          _bufferedComboCount = 0;
          widget.onEffectTrigger?.call(_currentGiftEvent);
        }
      });
    } else {
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

    _alphaController?.onFinish = () {
      if (mounted) {
        setState(() {
          _showVideo = false;
          if (!_showBanner) _showBanner = true;
        });
      }

      if (widget.enableEffectDelay && !_isReadyForComboEffect) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            widget.onEffectTrigger?.call(_currentGiftEvent);
            if (_bufferedComboCount > 0) {
              for (int i = 0; i < _bufferedComboCount; i++) {
                widget.onEffectTrigger?.call(_currentGiftEvent);
              }
              _bufferedComboCount = 0;
            }
            _isReadyForComboEffect = true;
            _effectTriggerLogicDone = true;
            _tryToFinish();
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
      if (mounted) setState(() => _showBanner = true);
    });
  }

  void _onBannerAnimationFinished() {
    _bannerAnimationFinished = true;
    _tryToFinish();
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
    EntranceSignal.active.removeListener(_onEntranceChanged);
    _earlyShowTimer?.cancel();
    _alphaController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 1. 底层：MP4 特效 (钉死在原地绝对不动！)
        Positioned(
          top: _videoTop,
          left: _videoLeft,
          child: SizedBox(
            width: _videoWidth,
            height: _videoHeight,
            child: _showVideo
                ? IgnorePointer(
              child: MyAlphaPlayerView(key: const ValueKey("TrayEffectPlayer"), onCreated: _onPlayerCreated),
            )
                : const SizedBox(),
          ),
        ),

        // 2. 顶层：文字 Banner
        if (_showBanner)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: _bannerLeft,
            // 🚀 因为现在外层的盒子也是用 top 定位了，内部的 Banner 直接 +30 就能完美避让了！
            top: _isEntranceActive ? (_baseBannerTop + _bannerShiftAmount) : _baseBannerTop,
            child: AnimatedGiftItem(
              key: ValueKey("Banner_$_stableBannerKeyId"),
              giftEvent: _currentGiftEvent,
              onFinished: _onBannerAnimationFinished,
            ),
          ),
      ],
    );
  }
}