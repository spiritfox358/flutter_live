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
  final double? floatEffectTop; // 🚀 新增：动态悬浮视频Top

  // 动态配置参数
  final Color? primaryColor;
  final double? bannerHeight;
  final double? avatarSize;

  EntranceModel({
    required this.userName,
    required this.avatar,
    this.floatVideoUrl, // 🚀
    this.floatEffectTop, // 🚀
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
      floatEffectTop: (extraConfig?['floatEffectTop'] as num?)?.toDouble(),
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

    // 🚀 1. 在最外层算好绝对高度，一次性把整个图层定准位置！
    final double paddingTop = MediaQuery.of(context).padding.top;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double pkVideoHeight = screenWidth * 0.87;
    final double entranceTop = paddingTop + pkVideoHeight + 150.0;

    return Positioned(
      top: entranceTop, // 外层盒子直接定位到这个安全高度
      left: 0,
      right: 0,
      // 🚨 注意：这里绝不能写 height！让它被里面的名字横幅自动撑开
      child: IgnorePointer(
        child: RepaintBoundary(
          child: _SingleEntranceItem(
            key: _currentUniqueKey,
            floatVideoUrl: _currentData!.floatVideoUrl,
            userData: _currentData!,
            onFinished: _onFinish,
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

  const _SingleEntranceItem({super.key, required this.floatVideoUrl, required this.userData, required this.onFinished});

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

    // 获取当前屏幕的宽度，用来进行等比例放大，绝对防止拉伸
    final double screenWidth = MediaQuery.of(context).size.width;

    return Stack(
      clipBehavior: Clip.none, // 允许特效溢出包围盒
      // 🚀🚀🚀 核心黑魔法：让 Stack 里的所有组件，都在垂直方向上绝对居中！
      alignment: Alignment.centerLeft,
      children: [
        // ==========================================
        // 1. 底层：炫酷横幅
        // 🚨 删掉所有的 Positioned 约束！它原本多高，Stack 就多高
        // ==========================================
        EntranceBannerWidget(
          avatarUrl: widget.userData.avatar,
          userName: widget.userData.userName,
          verticalOffset: 0.0,
          primaryColor: widget.userData.primaryColor ?? const Color(0xFFFF4D81),
          bannerHeight: widget.userData.bannerHeight ?? 28.0,
          avatarSize: widget.userData.avatarSize ?? 40.0,
          onComplete: () {
            _checkBothFinished();
          },
        ),

        // ==========================================
        // 2. 顶层：悬浮的视频特效
        // ==========================================
        if (_floatPath != null)
          Positioned(
            // 🚨 极其关键：只写 left，绝对不写 top 和 bottom！！！
            // 因为没写 top/bottom，Flutter 会根据父级的 alignment 把它自动垂直居中！
            left: 10.0,
            child: Transform.translate(
              // 现在的 floatEffectTop 是纯粹的微调。如果特效视频本身就是居中的，传 0 就完美了
              offset: Offset(0, widget.userData.floatEffectTop ?? 0.0),
              // 🚀 核心防拉伸：给视频一个明确的包围盒
              child: SizedBox(
                width: screenWidth, // 宽度铺满屏幕
                // 高度根据原始比例动态计算 (假设原始视频是 400宽 x 640高 = 1.6倍)
                // 如果你的视频是正方形，这里就直接填 screenWidth 即可！
                height: screenWidth * (640.0 / 400.0),
                child: MyAlphaPlayerView(
                    key: const ValueKey("EntranceAlphaPlayer_Key"),
                    onCreated: _onFloatPlayerCreated
                ),
              ),
            ),
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
