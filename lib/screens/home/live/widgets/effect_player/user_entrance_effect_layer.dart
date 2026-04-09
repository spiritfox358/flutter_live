import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:path_provider/path_provider.dart';

// 🚀🚀🚀 终极修复：定义一个静态单例信号站，彻底粉碎 Import 路径导致的双胞胎 Bug！
class EntranceSignal {
  static final ValueNotifier<bool> active = ValueNotifier(false);
}

/// 用户进场数据模型
class EntranceModel {
  final String userName;
  final String avatar;

  EntranceModel({required this.userName, required this.avatar});
}

class UserEntranceEffectLayer extends StatefulWidget {
  const UserEntranceEffectLayer({super.key});

  @override
  State<UserEntranceEffectLayer> createState() => UserEntranceEffectLayerState();
}

class UserEntranceEffectLayerState extends State<UserEntranceEffectLayer> {
  final double _effectWidth = 400.0;
  final double _effectHeight = 640.0;
  final double _topPosition = 250.0;

  final String _baseVideoUrl =
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/entrance/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E5%BA%95%E5%BA%A72.mp4";
  final String _floatVideoUrl =
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/entrance/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E6%BC%82%E6%B5%AE2.mp4";

  final Queue<EntranceModel> _waitingQueue = Queue();
  EntranceModel? _currentData;
  bool _isPlaying = false;
  Key? _currentUniqueKey;

  void addEntrance(EntranceModel data) {
    if (_isPlaying) {
      _waitingQueue.add(data);
    } else {
      _play(data);
    }
  }

  void _play(EntranceModel data) {
    if (!mounted) return;

    // 🚀🚀🚀 进场开始，点亮唯一信号灯！
    EntranceSignal.active.value = true;
    debugPrint("💡 [进场信号] 信号灯已开启: true");

    setState(() {
      _currentData = data;
      _isPlaying = true;
      _currentUniqueKey = UniqueKey();
    });
  }

  void _onFinish() {
    if (!mounted) return;

    setState(() {
      _currentData = null;
      _isPlaying = false;
      _currentUniqueKey = null;
    });

    if (_waitingQueue.isNotEmpty) {
      final next = _waitingQueue.removeFirst();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _play(next);
      });
    } else {
      // 🚀🚀🚀 进场全部结束，熄灭唯一信号灯！
      EntranceSignal.active.value = false;
      debugPrint("💡 [进场信号] 信号灯已熄灭: false");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPlaying || _currentData == null) {
      return const SizedBox();
    }

    return Positioned(
      top: _topPosition,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: RepaintBoundary(
          child: Center(
            child: SizedBox(
              width: _effectWidth,
              height: _effectHeight,
              child: _DualVideoItem(
                key: _currentUniqueKey,
                baseVideoUrl: _baseVideoUrl,
                floatVideoUrl: _floatVideoUrl,
                userData: _currentData!,
                onFinished: _onFinish,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DualVideoItem extends StatefulWidget {
  final String baseVideoUrl;
  final String floatVideoUrl;
  final EntranceModel userData;
  final VoidCallback onFinished;

  const _DualVideoItem({
    super.key,
    required this.baseVideoUrl,
    required this.floatVideoUrl,
    required this.userData,
    required this.onFinished,
  });

  @override
  State<_DualVideoItem> createState() => _DualVideoItemState();
}

class _DualVideoItemState extends State<_DualVideoItem> {
  MyAlphaPlayerController? _baseController;
  MyAlphaPlayerController? _floatController;
  bool _filesReady = false;
  bool _isVisible = false;
  String? _basePath;
  String? _floatPath;
  bool _hasTriggeredFinish = false;

  final double _avatarRadius = 15.0;
  final double _barHeight = 40.0;
  final double _barWidth = 240.0;
  final int _slideDurationMs = 1200;
  final int _textMoveDelayMs = 3000;
  final int _textMoveDurationMs = 500;
  final double _initialTextPadding = 0.0;
  final double _targetTextPadding = 63.0;

  late double _currentTextPadding;

  @override
  void initState() {
    super.initState();
    _currentTextPadding = _initialTextPadding;
    _prepareAndPlay();
  }

  Future<void> _prepareAndPlay() async {
    final results = await Future.wait([
      _downloadFile(widget.baseVideoUrl),
      _downloadFile(widget.floatVideoUrl)
    ]);

    if (!mounted) return;

    _basePath = results[0];
    _floatPath = results[1];

    if (_basePath != null && _floatPath != null) {
      setState(() {
        _filesReady = true;
      });
    } else {
      _triggerFinish();
    }
  }

  void _onBasePlayerCreated(MyAlphaPlayerController controller) {
    _baseController = controller;
    _checkAndPlay();
  }

  void _onFloatPlayerCreated(MyAlphaPlayerController controller) {
    _floatController = controller;
    _floatController?.onFinish = () {
      if (mounted) {
        setState(() => _isVisible = false);
        Future.delayed(const Duration(milliseconds: 300), () {
          _triggerFinish();
        });
      } else {
        _triggerFinish();
      }
    };
    _checkAndPlay();
  }

  void _checkAndPlay() {
    if (_baseController != null && _floatController != null && _filesReady) {
      try {
        _baseController?.play(_basePath!);
        _floatController?.play(_floatPath!);

        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _isVisible = true);
        });

        Future.delayed(Duration(milliseconds: _textMoveDelayMs), () {
          if (mounted) setState(() => _currentTextPadding = _targetTextPadding);
        });
      } catch (e) {
        _triggerFinish();
      }
    }
  }

  void _triggerFinish() {
    if (_hasTriggeredFinish) return;
    _hasTriggeredFinish = true;
    widget.onFinished();
  }

  Future<String?> _downloadFile(String url) async {
    if (kIsWeb) return url;
    try {
      final dir = await getApplicationDocumentsDirectory();
      String fileName = "entrance_${url.hashCode}.mp4";
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
    _baseController?.dispose();
    _floatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_filesReady) return const SizedBox();

    return AnimatedOpacity(
      opacity: _isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: MyAlphaPlayerView(
                key: const ValueKey("BasePlayer"),
                onCreated: _onBasePlayerCreated),
          ),
          Positioned(
            top: 6,
            bottom: 40,
            left: 8,
            right: 0,
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSlide(
                offset: _isVisible ? Offset.zero : const Offset(1.5, 0),
                duration: Duration(milliseconds: _slideDurationMs),
                curve: Curves.easeIn,
                child: SizedBox(
                  width: _barWidth,
                  height: _avatarRadius * 2,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Positioned(
                        left: _avatarRadius,
                        right: 0,
                        height: _barHeight,
                        child: Container(
                          padding: EdgeInsets.only(
                            left: _avatarRadius + 10,
                            right: 8,
                          ),
                          alignment: Alignment.centerLeft,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.transparent, Colors.transparent],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.horizontal(
                                left: Radius.circular(_barHeight / 2)),
                          ),
                          child: AnimatedPadding(
                            padding: EdgeInsets.only(left: _currentTextPadding, top: 1),
                            duration: Duration(milliseconds: _textMoveDurationMs),
                            curve: Curves.easeOutCubic,
                            child: Text(
                              widget.userData.userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        child: Container(
                          width: _avatarRadius * 2,
                          height: _avatarRadius * 2,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.amber, width: 2),
                            image: DecorationImage(
                                image: NetworkImage(widget.userData.avatar),
                                fit: BoxFit.cover),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: MyAlphaPlayerView(
                key: const ValueKey("FloatPlayer"),
                onCreated: _onFloatPlayerCreated),
          ),
        ],
      ),
    );
  }
}