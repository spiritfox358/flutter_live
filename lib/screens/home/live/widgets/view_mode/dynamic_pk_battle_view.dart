import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_live/screens/home/live/widgets/pk_score_bar_widgets.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart';

// ==========================================
// 📦 1. 真实业务数据模型
// ==========================================
class LivePKPlayerModel {
  final String userId;
  final String roomId;
  final String name;
  final String avatarUrl;
  final int rank;
  final int score;
  final bool isMuted;
  final String? propText;
  final bool isPunished;
  final bool isSpeaking;
  final bool isMyTeam;
  final VideoPlayerController? videoController;

  LivePKPlayerModel({
    required this.userId,
    required this.roomId,
    required this.name,
    required this.avatarUrl,
    required this.rank,
    required this.score,
    this.isMuted = false,
    this.propText,
    this.isPunished = false,
    this.isSpeaking = false,
    this.isMyTeam = false,
    this.videoController,
  });
}

// ==========================================
// 🎨 2. 真实业务网格组件 (无状态，完全由外部数据驱动)
// ==========================================
class DynamicPKBattleView extends StatelessWidget {
  final List<LivePKPlayerModel> players;
  final PKStatus pkStatus;
  final Function(LivePKPlayerModel)? onTapPlayer;
  final String currentRoomId;

  const DynamicPKBattleView({super.key, required this.players, this.onTapPlayer, this.pkStatus = PKStatus.idle, required this.currentRoomId});

  // ==========================================
  // 🛠️ 专属微调区
  // ==========================================
  final double rankBadgeTopOffset = 4.0;
  final double rankBadgeLeftOffset = 4.0;
  final EdgeInsets rankBadgePadding = const EdgeInsets.only(left: 2, right: 6, top: 2, bottom: 2);
  final double scoreTextHeight = 1.1;

  // --- UI 样式配置常量 ---
  final double dividerThickness = 1.0;
  final Color dividerColor = Colors.black;
  final Color rankBadgeBgColor = const Color(0x66000000);
  final Color rankCircleColor = const Color(0xFF8AA4FC);
  final double rankCircleSize = 14.0;
  final double rankBadgeRadius = 12.0;
  final double bottomGradientHeight = 40.0;
  final double textRankSize = 9.0;
  final double textScoreSize = 10.0;
  final double textNameSize = 11.0;
  final double textPropSize = 10.0;
  final double muteIconSize = 16.0;
  final Color muteIconColor = Colors.white70;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const SizedBox.shrink();

    final sortedPlayers = List<LivePKPlayerModel>.from(players);
    sortedPlayers.sort((a, b) {
      bool isMainAnchorA = a.roomId == currentRoomId;
      bool isMainAnchorB = b.roomId == currentRoomId;

      if (isMainAnchorA && !isMainAnchorB) return -1;
      if (!isMainAnchorA && isMainAnchorB) return 1;

      if (a.isMyTeam && !b.isMyTeam) return -1;
      if (!a.isMyTeam && b.isMyTeam) return 1;

      return b.score.compareTo(a.score);
    });

    return Container(color: dividerColor, child: _buildDynamicPKGrid(sortedPlayers));
  }

  Widget _buildDynamicPKGrid(List<LivePKPlayerModel> sortedList) {
    int count = sortedList.length;
    switch (count) {
      case 2:
        return _buildFlexGrid([2], sortedList);
      case 3:
        return _build3PersonLayout(sortedList);
      case 4:
        return _buildFlexGrid([2, 2], sortedList);
      case 5:
        return _buildFlexGrid([2, 3], sortedList);
      case 6:
        return _buildFlexGrid([3, 3], sortedList);
      case 7:
        return _buildFlexGrid([3, 4], sortedList);
      case 8:
        return _buildFlexGrid([4, 4], sortedList);
      case 9:
        return _buildFlexGrid([3, 3, 3], sortedList);
      default:
        return const Center(
          child: Text('仅支持 2-9 人', style: TextStyle(color: Colors.white)),
        );
    }
  }

  Widget _vDivider() => Container(width: dividerThickness, color: dividerColor);

  Widget _hDivider() => Container(height: dividerThickness, color: dividerColor);

  Widget _build3PersonLayout(List<LivePKPlayerModel> sortedList) {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildCell(sortedList[0])),
        _vDivider(),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: _buildCell(sortedList[1])),
              _hDivider(),
              Expanded(flex: 1, child: _buildCell(sortedList[2])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlexGrid(List<int> rowConfigs, List<LivePKPlayerModel> sortedList) {
    List<Widget> rows = [];
    int playerIndex = 0;

    for (int i = 0; i < rowConfigs.length; i++) {
      int colsInThisRow = rowConfigs[i];
      List<Widget> rowChildren = [];

      for (int j = 0; j < colsInThisRow; j++) {
        if (playerIndex < sortedList.length) {
          rowChildren.add(Expanded(child: _buildCell(sortedList[playerIndex])));
          if (j < colsInThisRow - 1) rowChildren.add(_vDivider());
          playerIndex++;
        }
      }

      rows.add(Expanded(child: Row(children: rowChildren)));
      if (i < rowConfigs.length - 1) rows.add(_hDivider());
    }

    return Column(children: rows);
  }

  // ==========================================
  // 🎨 单个方块 UI 渲染
  // ==========================================
  Widget _buildCell(LivePKPlayerModel player) {
    bool hasProp = player.propText != null && player.propText!.isNotEmpty;

    bool isBattleState = pkStatus == PKStatus.playing || pkStatus == PKStatus.punishment;
    bool isCoHostState = pkStatus == PKStatus.coHost || pkStatus == PKStatus.idle || pkStatus == PKStatus.matching;

    bool showScoreBadge = isCoHostState || players.length > 2;

    int highestScore = 0;
    for (var p in players) {
      if (p.score > highestScore) highestScore = p.score;
    }
    bool isHighest = isBattleState && player.score == highestScore && highestScore > 0;

    // ✨ 核心修改 1：重构颜色获取方法，增加 isForScore 参数区分“分数牌”和“人名牌”
    Color getBadgeColor(double opacity, {bool isForScore = false}) {
      if (isCoHostState) return Colors.black.withOpacity(0.4);
      // 只有左上角的分数牌，在最高分时才会变黄
      if (isForScore && isHighest) return Colors.orange.withOpacity(0.8);
      // 其他情况（包括所有人名牌），永远显示原本的红蓝队颜色
      return player.isMyTeam ? const Color(0xFFFF2E56).withOpacity(opacity) : const Color(0xFF2962FF).withOpacity(opacity);
    }

    Widget cellContent = Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(color: Color(0xFF1B1B1B)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _buildMediaContent(player),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: bottomGradientHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          if (showScoreBadge)
            Positioned(
              top: rankBadgeTopOffset,
              left: rankBadgeLeftOffset,
              child: Container(
                padding: rankBadgePadding,
                decoration: BoxDecoration(
                  // ✨ 传参 isForScore: true，允许变黄
                  color: getBadgeColor(0.3, isForScore: true),
                  borderRadius: BorderRadius.circular(rankBadgeRadius),
                  border: isHighest ? Border.all(color: Colors.amberAccent.withAlpha(100), width: 0.5) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: rankCircleSize,
                      height: rankCircleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isBattleState
                            ? (player.isMyTeam ? const Color(0xFFD32F2F).withAlpha(100) : const Color(0xFF1565C0).withAlpha(100))
                            : Colors.white24,
                      ),
                      child: Center(
                        child: Text(
                          '${player.rank}',
                          style: TextStyle(color: Colors.white, fontSize: textRankSize, fontWeight: FontWeight.bold, height: 1.1),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${player.score}',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: textScoreSize,
                        fontWeight: FontWeight.w600,
                        height: scoreTextHeight,
                        shadows: isHighest ? [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))] : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (player.isMuted)
            Positioned(
              top: 6,
              right: 6,
              child: Icon(Icons.mic_off_outlined, color: muteIconColor, size: muteIconSize),
            ),

          Positioned(
            bottom: 2,
            left: 4,
            right: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  // ✨ 核心修改 2：传参 isForScore: false，强制保持队伍颜色
                  color: getBadgeColor(0.4, isForScore: false),
                  borderRadius: BorderRadius.circular(12),
                  // ✨ 核心修改 3：去掉了 isHighest 的黄色边框逻辑，让人名牌完全不受最高分影响
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      flex: 1,
                      fit: FlexFit.loose,
                      child: Transform.translate(
                        offset: const Offset(0, 0.4), // 向上移动 1.0 像素，数值可调整 (负数向上)
                        child: Text(
                          player.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: textNameSize,
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                            leadingDistribution: TextLeadingDistribution.even,
                          ),
                          strutStyle: StrutStyle(
                            fontSize: textNameSize,
                            height: 1.2, // 强制行高为字体大小的 1 倍
                            leading: 0, // 移除额外的行间距
                            forceStrutHeight: true, // 关键：强制使用 strut 高度
                          ),
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.clip,
                        ),
                      ),
                    ),
                    if (hasProp) ...[
                      Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white38),
                      Flexible(
                        flex: 0,
                        child: Transform.translate(
                          offset: const Offset(0, 0.4), // 向上移动 1.0 像素，数值可调整 (负数向上)
                          child: Text(
                            player.propText!,
                            style: TextStyle(
                              fontSize: textPropSize,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                              leadingDistribution: TextLeadingDistribution.even,
                            ),
                            strutStyle: StrutStyle(
                              fontSize: textNameSize,
                              height: 1.2, // 强制行高为字体大小的 1 倍
                              leading: 0, // 移除额外的行间距
                              forceStrutHeight: true, // 关键：强制使用 strut 高度
                            ),
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return GestureDetector(
      onTap: () {
        if (onTapPlayer != null) onTapPlayer!(player);
      },
      behavior: HitTestBehavior.opaque,
      child: cellContent,
    );
  }

  Widget _buildMediaContent(LivePKPlayerModel player) {
    Widget content;

    if (player.videoController != null && player.videoController!.value.isInitialized) {
      content = SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: player.videoController!.value.size.width,
            height: player.videoController!.value.size.height,
            child: VideoPlayer(player.videoController!),
          ),
        ),
      );
    } else {
      // ✨ 核心修改：根据总人数动态计算头像外边距
      // 边距越大，中间的头像就被挤得越小
      double avatarPadding = 12.0;
      if (players.length == 9) {
        avatarPadding = 18.0; // 7-9人时格子很小，边距加大，让头像明显变小
      } else if (players.length >= 7) {
        avatarPadding = 5.0; // 5-6人时适中
      }

      content = Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            player.avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, stack) => Container(color: Colors.grey[900]),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
            child: Container(color: Colors.black.withOpacity(0.5)),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.all(avatarPadding),
              child: ConstrainedBox(
                // 👇 锁死最大宽高！数值你可以自己微调，比如 80、90 或 100
                constraints: const BoxConstraints(maxWidth: 125.0, maxHeight: 125.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AvatarAnimation(avatarUrl: player.avatarUrl, isSpeaking: player.isSpeaking, isRotating: false),
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (player.isPunished) {
      return RepaintBoundary(
        child: ColorFiltered(colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation), child: content),
      );
    }

    return RepaintBoundary(child: content);
  }
}
