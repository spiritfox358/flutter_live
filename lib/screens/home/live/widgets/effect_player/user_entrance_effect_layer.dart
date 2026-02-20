import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:path_provider/path_provider.dart';

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
  // =======================================================
  // 🔧🔧🔧 参数调节区域 🔧🔧🔧
  // =======================================================

  // 1. 尺寸调整 (建议根据 MP4 原始比例调整)
  final double _effectWidth = 400.0;
  final double _effectHeight = 640.0;

  // 2. 位置调整
  final double _topPosition = 250.0;

  // 3. 视频地址
  final String _baseVideoUrl =
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/entrance/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E5%BA%95%E5%BA%A7.mp4";
  final String _floatVideoUrl =
      "https://fzxt-resources.oss-cn-beijing.aliyuncs.com/assets/mystery_shop/adornment/entrance/%E5%BE%A1%E9%BE%99%E6%B8%B8%E4%BE%A0%E6%BC%82%E6%B5%AE.mp4";

  // =======================================================

  final Queue<EntranceModel> _waitingQueue = Queue();
  EntranceModel? _currentData;
  bool _isPlaying = false;

  // 🔴 核心修复：把 Key 存在 State 里，而不是在 build 里动态生成
  // 只有当开始播放新特效时，才更新这个 Key
  Key? _currentUniqueKey;

  /// 外部调用此方法添加进场特效
  void addEntrance(EntranceModel data) {
    if (_isPlaying) {
      _waitingQueue.add(data);
    } else {
      _play(data);
    }
  }

  void _play(EntranceModel data) {
    if (!mounted) return;
    setState(() {
      _currentData = data;
      _isPlaying = true;
      // 🟢 只有在这里才更新 Key！
      _currentUniqueKey = UniqueKey();
    });
  }

  void _onFinish() {
    if (!mounted) return;

    setState(() {
      _currentData = null;
      _isPlaying = false;
      _currentUniqueKey = null; // 清理 Key
    });

    // 检查队列
    if (_waitingQueue.isNotEmpty) {
      final next = _waitingQueue.removeFirst();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _play(next);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有正在播放的内容，返回空
    if (!_isPlaying || _currentData == null) {
      return const SizedBox();
    }

    return Positioned(
      top: _topPosition,
      left: 0,
      right: 0,
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
    );
  }
}

/// 内部组件：负责同时播放两个视频
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

  // 控制整体可见性，默认为 false (透明)
  bool _isVisible = false;

  String? _basePath;
  String? _floatPath;

  // 防止多次调用结束回调
  bool _hasTriggeredFinish = false;

  // =======================================================
  // 🎨🎨🎨 进场动效参数调节 🎨🎨🎨
  // =======================================================
  final double _avatarRadius = 15.0; // 头像大小 (半径15)
  final double _barHeight = 40.0; // 昵称渐变长条的高度
  final double _barWidth = 240.0; // 整体信息条的总宽度 (含头像)
  final int _slideDurationMs = 1200; // 整体组件从右侧匀速滑入的时间 (毫秒)

  // 📝 动态文字位移参数
  final int _textMoveDelayMs = 3000; // 视频播放后多久开始位移 (毫秒，例如3000=3秒)
  final int _textMoveDurationMs = 500; // 文字滑动的动画时长 (毫秒，越短越快)
  final double _initialTextPadding = 0.0; // 文字初始的左侧边距
  final double _targetTextPadding = 53.0; // 文字最终的左侧边距

  // 内部状态，用于触发位移动画
  late double _currentTextPadding;
  // =======================================================

  @override
  void initState() {
    super.initState();
    _currentTextPadding = _initialTextPadding; // 初始化 padding
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
      debugPrint("🎬 进场特效播放结束");
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

        // 1. 整体 UI 延迟显示，消除闪烁
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isVisible = true;
            });
          }
        });

        // 2. 触发文字位移动画 (比如第3秒)
        Future.delayed(Duration(milliseconds: _textMoveDelayMs), () {
          if (mounted) {
            setState(() {
              _currentTextPadding = _targetTextPadding;
            });
          }
        });

      } catch (e) {
        debugPrint("❌ 播放异常: $e");
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
          // 1. 底座
          Positioned.fill(
            child: MyAlphaPlayerView(
                key: const ValueKey("BasePlayer"),
                onCreated: _onBasePlayerCreated),
          ),

          // 2. 用户信息
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
                      // 底层：昵称渐变长条
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
                          // 🟢 动态变化的 Padding 包裹 Text
                          child: AnimatedPadding(
                            padding: EdgeInsets.only(left: _currentTextPadding,top: 1),
                            duration: Duration(milliseconds: _textMoveDurationMs),
                            curve: Curves.easeOutCubic, // 平滑减速动画曲线
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

                      // 顶层：头像
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

          // 3. 漂浮
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