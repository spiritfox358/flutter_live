import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';
import 'package:video_player/video_player.dart';

import '../../../../services/ai_music_service.dart';
import '../widgets/pk_widgets.dart';

class PKRealBattleView extends StatefulWidget {
  // --- 左侧配置 (我方/主播) ---
  final VideoPlayerController? leftVideoController;
  final String? leftBgImage;

  // 🟢 新增：左侧头像和名字 (用于非视频模式)
  final String leftAvatarUrl;
  final String leftName;

  // --- 右侧配置 (对手) ---
  final bool isRightVideoMode;
  final VideoPlayerController? rightVideoController;
  final String rightAvatarUrl;
  final String rightName;
  final bool isRotating;
  final String rightBgImage;

  // PK 数据
  final PKStatus pkStatus;
  final int myScore;
  final int opponentScore;

  // 状态控制
  final bool isOpponentSpeaking;
  final VoidCallback? onTapOpponent;

  const PKRealBattleView({
    super.key,
    // 左侧参数
    required this.leftVideoController,
    required this.leftBgImage,
    required this.leftAvatarUrl, // 🟢 必传
    required this.leftName, // 🟢 必传
    // 右侧参数
    this.isRightVideoMode = false,
    this.rightVideoController,
    required this.rightAvatarUrl,
    required this.rightName,
    required this.rightBgImage,
    required this.isRotating,

    // 通用参数
    required this.pkStatus,
    required this.myScore,
    required this.opponentScore,
    this.isOpponentSpeaking = true,
    this.onTapOpponent,
  });

  @override
  State<PKRealBattleView> createState() => _PKRealBattleViewState();
}

class _PKRealBattleViewState extends State<PKRealBattleView> with TickerProviderStateMixin {
  late AnimationController _rotateController;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _rotateController = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();

    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

    if (widget.pkStatus == PKStatus.playing) {
      _safePlayMusic();
    }
  }

  @override
  void didUpdateWidget(covariant PKRealBattleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pkStatus != widget.pkStatus) {
      if (widget.pkStatus == PKStatus.playing) {
        _safePlayMusic();
      } else {
        _safeStopMusic();
      }
    }
  }

  @override
  void deactivate() {
    _safeStopMusic();
    super.deactivate();
  }

  @override
  void dispose() {
    _rotateController.dispose();
    _waveController.dispose();
    _safeStopMusic();
    super.dispose();
  }

  void _safePlayMusic() {
    try {
      AIMusicService().playRandomBgm();
    } catch (e) {
      debugPrint("播放音乐失败: $e");
    }
  }

  void _safeStopMusic() {
    try {
      AIMusicService().stopMusic();
    } catch (e) {
      debugPrint("停止音乐失败: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPunishment = widget.pkStatus == PKStatus.punishment;
    final bool isLeftWin = widget.myScore >= widget.opponentScore;

    return Row(
      children: [
        // --- 左侧：我方 ---
        Expanded(
          flex: 1,
          child: Container(
            clipBehavior: Clip.hardEdge,
            decoration: const BoxDecoration(
              color: Colors.black,
              border: Border(right: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildLeftContent(isPunishment && !isLeftWin),
                Container(color: Colors.transparent),
              ],
            ),
          ),
        ),

        // 中割线
        Container(width: 2, color: Colors.black),

        // --- 右侧：对手 ---
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: widget.onTapOpponent,
            behavior: HitTestBehavior.opaque,
            child: Container(
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(left: BorderSide(color: Colors.white12, width: 1)),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.isRightVideoMode)
                    _buildRightVideoContent(isPunishment && isLeftWin)
                  else
                    _buildRightImageModeContent(isPunishment && isLeftWin),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 构建左侧内容 (视频 或 复用AvatarView)
  Widget _buildLeftContent(bool showPunishmentMask) {
    // 1. 优先显示视频
    if (widget.leftVideoController != null && widget.leftVideoController!.value.isInitialized) {
      Widget video = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: widget.leftVideoController!.value.size.width,
            height: widget.leftVideoController!.value.size.height,
            child: VideoPlayer(widget.leftVideoController!),
          ),
        ),
      );

      return RepaintBoundary(
        child: showPunishmentMask ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: video) : video,
      );
    }

    // 2. 🟢 无视频时，使用通用的头像模式 (背景 + 头像组件)
    return _buildGenericImageMode(
      bgImage: widget.leftBgImage ?? "",
      avatarUrl: widget.leftAvatarUrl,
      name: widget.leftName,
      isSpeaking: true,
      // 左侧一般默认自己在说话
      showPunishmentMask: showPunishmentMask,
      isRotating: false,
    );
  }

  // 构建右侧视频内容
  Widget _buildRightVideoContent(bool isGrayscale) {
    Widget content;
    if (widget.rightVideoController != null && widget.rightVideoController!.value.isInitialized) {
      content = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: widget.rightVideoController!.value.size.width,
            height: widget.rightVideoController!.value.size.height,
            child: VideoPlayer(widget.rightVideoController!),
          ),
        ),
      );
    } else {
      content = Image.network(
        widget.rightBgImage,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
      );
    }

    return RepaintBoundary(
      child: isGrayscale ? ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: content) : content,
    );
  }

  // 构建右侧非视频模式 (复用AvatarView)
  Widget _buildRightImageModeContent(bool showPunishmentMask) {
    return _buildGenericImageMode(
      bgImage: widget.rightBgImage,
      avatarUrl: widget.rightAvatarUrl,
      name: widget.rightName,
      isSpeaking: widget.isOpponentSpeaking,
      isRotating: widget.isRotating,
      showPunishmentMask: showPunishmentMask,
    );
  }

  // 🟢 通用的非视频模式构建器
  Widget _buildGenericImageMode({
    required String bgImage,
    required String avatarUrl,
    required String name,
    required bool isSpeaking,
    required bool isRotating,
    required bool showPunishmentMask,
  }) {
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 背景图
          if (bgImage.isNotEmpty)
            Image.network(
              bgImage,
              fit: BoxFit.cover,
              errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
            )
          else
            Container(color: Colors.black),

          // 2. 黑色遮罩 (凸显头像)
          Container(color: Colors.black.withOpacity(0.6)),

          // 3. 🟢 复用的头像组件
          Center(
            child: AvatarAnimation(
              avatarUrl: avatarUrl,
              name: name,
              isSpeaking: isSpeaking,
              isRotating: isRotating,
            ),
          ),

          // 4. 惩罚滤镜
          if (showPunishmentMask)
            BackdropFilter(
              filter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
              child: Container(color: Colors.transparent),
            ),
        ],
      ),
    );
  }
}
