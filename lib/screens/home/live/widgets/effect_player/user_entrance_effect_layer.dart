import 'dart:async';
import 'dart:collection';
import 'dart:convert'; // 🟢 引入 base64，修复 hashCode 缓存 Bug
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_alpha_player/my_alpha_player.dart';
import 'package:path_provider/path_provider.dart';

import 'entrance_banner_widget.dart'; // 🚀 引入我们刚刚完美封装的进场横幅组件

// 🚀🚀🚀 终极修复：定义一个静态单例信号站，彻底粉碎 Import 路径导致的双胞胎 Bug！
class EntranceSignal {
  static final ValueNotifier<bool> active = ValueNotifier(false);
  // 🚀 新增：专门用来标记是否有“特权进场”正在播放，用于全局打断普通进场！
  static final ValueNotifier<bool> isSpecialPlaying = ValueNotifier(false);
}

/// 用户进场数据模型
/// 用户进场数据模型
class EntranceModel {
  final String userName;
  final String avatar;
  final String? floatVideoUrl; // 🚀 新增：动态悬浮视频链接 (可为空)

  // 动态配置参数
  final Color? primaryColor;
  final double? bannerHeight;
  final double? avatarSize;

  EntranceModel({
    required this.userName,
    required this.avatar,
    this.floatVideoUrl, // 🚀
    this.primaryColor,
    this.bannerHeight,
    this.avatarSize,
  });

  factory EntranceModel.fromJson(Map<String, dynamic> json, Map<String, dynamic>? extraConfig) {
    Color? parsedColor;
    if (extraConfig?['primaryColor'] != null) {
      parsedColor = HexColor.fromHex(extraConfig!['primaryColor']);
    }

    return EntranceModel(
      userName: json['userName'] ?? '',
      avatar: json['avatar'] ?? '',
      // 🚀 优先取 resourceUrl (对应数据库表字段)，如果没有再找 floatVideoUrl
      floatVideoUrl: json['resourceUrl'] ?? json['floatVideoUrl'],
      primaryColor: parsedColor,
      bannerHeight: (extraConfig?['bannerHeight'] as num?)?.toDouble(),
      avatarSize: (extraConfig?['avatarSize'] as num?)?.toDouble(),
    );
  }
}

class UserEntranceEffectLayer extends StatefulWidget {
  const UserEntranceEffectLayer({super.key});

  @override
  State<UserEntranceEffectLayer> createState() => UserEntranceEffectLayerState();
}

class UserEntranceEffectLayerState extends State<UserEntranceEffectLayer> {
  final double _effectWidth = 400.0;
  final double _effectHeight = 640.0;
  final double _topPosition = 215.0;

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
    EntranceSignal.isSpecialPlaying.value = true; // 🚀 触发特权打断信号！
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
      EntranceSignal.isSpecialPlaying.value = false; // 🚀 解除特权打断信号！
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
              // 🚀 替换为了我们全新的单视频+横幅融合组件
              child: _SingleEntranceItem(
                key: _currentUniqueKey,
                floatVideoUrl: _currentData!.floatVideoUrl,
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

// ============================================================================
// 🎬 全新融合组件：底层 Flutter 渲染横幅 + 顶层 Alpha 渲染视频
// ============================================================================
class _SingleEntranceItem extends StatefulWidget {
  final String? floatVideoUrl; // 🚀 1. 改为可空类型 (String?)
  final EntranceModel userData;
  final VoidCallback onFinished;

  const _SingleEntranceItem({
    super.key,
    required this.floatVideoUrl,
    required this.userData,
    required this.onFinished,
  });

  @override
  State<_SingleEntranceItem> createState() => _SingleEntranceItemState();
}

class _SingleEntranceItemState extends State<_SingleEntranceItem> {
  MyAlphaPlayerController? _floatController;
  bool _fileReady = false;
  String? _floatPath;

  bool _hasTriggeredFinish = false;
  int _finishCount = 0;

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    // 🚀 2. 核心容错：如果该用户根本没有配置特效视频，直接跳过下载！
    if (widget.floatVideoUrl == null || widget.floatVideoUrl!.isEmpty) {
      if (mounted) {
        setState(() {
          _fileReady = true;
        });
      }
      // 直接触发一次结束信号（假装视频已经播完了，让横幅正常走流程）
      _checkBothFinished();
      return;
    }

    // 有链接才去走真实的下载逻辑
    final path = await _downloadFile(widget.floatVideoUrl!);
    if (!mounted) return;

    _floatPath = path;

    setState(() {
      _fileReady = true;
    });

    if (_floatPath == null) {
      _checkBothFinished();
    }
  }

  void _onFloatPlayerCreated(MyAlphaPlayerController controller) {
    _floatController = controller;

    // 视频播完后，上报一次结束
    _floatController?.onFinish = () {
      _checkBothFinished();
    };

    if (_floatPath != null) {
      try {
        _floatController?.play(_floatPath!);
      } catch (e) {
        _checkBothFinished();
      }
    }
  }

  /// 🎯 同步器：确保横幅退场了，且视频也播完了，才进行下一个
  void _checkBothFinished() {
    _finishCount++;
    // 当计数器达到 2 (视频结束1次 + 横幅结束1次) 时，呼叫父级进入下一个队列
    if (_finishCount >= 2) {
      if (!_hasTriggeredFinish) {
        _hasTriggeredFinish = true;
        widget.onFinished();
      }
    }
  }

  // 🟢 顺手修复了这里之前用 hashCode 导致的重启重复下载 Bug
  Future<String?> _downloadFile(String url) async {
    if (kIsWeb) return url;
    try {
      final dir = await getApplicationDocumentsDirectory();

      String safeName = base64Url.encode(utf8.encode(url));
      if (safeName.length > 50) safeName = safeName.substring(safeName.length - 50);

      String fileName = "entrance_$safeName.mp4";
      final savePath = "${dir.path}/$fileName";
      final file = File(savePath);

      if (await file.exists() && await file.length() > 1000) return savePath;

      await Dio().download(url, savePath);

      if (await file.exists() && await file.length() > 1000) return savePath;
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  void dispose() {
    _floatController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_fileReady) return const SizedBox();

    return Stack(
      alignment: Alignment.center,
      children: [
        // ==========================================
        // 1. 底层：我们的炫酷横幅
        // ==========================================
        Positioned.fill(
          child: EntranceBannerWidget(
            avatarUrl: widget.userData.avatar,
            userName: widget.userData.userName,
            verticalOffset: 0.0,
            // 🚀 核心接入：如果后端配了颜色和尺寸，就用后端的；如果没有，组件内部会使用默认值
            primaryColor: widget.userData.primaryColor ?? const Color(0xFFFF4D81),
            bannerHeight: widget.userData.bannerHeight ?? 28.0,
            avatarSize: widget.userData.avatarSize ?? 40.0,

            onComplete: () {
              _checkBothFinished();
            },
          ),
        ),

        // ==========================================
        // 2. 顶层：悬浮的视频特效 (加上 left 偏移对齐横幅)
        // ==========================================
        if (_floatPath != null)
          Positioned(
            left: 12.0,
            // 🚀 核心改动：往右推 12 像素，和横幅的起始点绝对对齐！
            top: 0,
            bottom: 0,
            right: 0,
            child: MyAlphaPlayerView(key: const ValueKey("EntranceAlphaPlayer_Key"), onCreated: _onFloatPlayerCreated),
          ),
      ],
    );
  }
}

// 将这端代码放在你的工具类里，或者 user_entrance_effect_layer.dart 底部
extension HexColor on Color {
  static Color fromHex(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
