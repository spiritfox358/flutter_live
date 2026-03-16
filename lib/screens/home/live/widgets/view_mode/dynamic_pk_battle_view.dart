import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_live/screens/home/live/widgets/avatar_animation.dart'; // 确保引入了你的头像组件

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
  final bool isPunished; // 是否处于惩罚变灰状态
  final bool isSpeaking; // 是否正在说话 (用于头像动画)
  final bool isMyTeam; // 🟢 1. 新增：是否为我方阵营
  final VideoPlayerController? videoController; // 真实视频流控制器

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
    this.isMyTeam = false, // 🟢 2. 默认 false
    this.videoController,
  });
}

// ==========================================
// 🎨 2. 真实业务网格组件 (无状态，完全由外部数据驱动)
// ==========================================
class DynamicPKBattleView extends StatelessWidget {
  final List<LivePKPlayerModel> players;
  final Function(LivePKPlayerModel)? onTapPlayer;

  const DynamicPKBattleView({
    super.key,
    required this.players,
    this.onTapPlayer,
  });

  // ==========================================
  // 🛠️ 专属微调区：调整分数胶囊的位置和居中
  // ==========================================
  // 1. 胶囊外边距 (控制整个胶囊距离左上角的距离)
  final double rankBadgeTopOffset = 4.0;  // 距离格子顶部的间距
  final double rankBadgeLeftOffset = 4.0; // 距离格子左侧的间距

  // 2. 胶囊内边距 (如果感觉文字整体偏上，可以把 top 调大，或者 bottom 调小)
  final EdgeInsets rankBadgePadding = const EdgeInsets.only(left: 2, right: 6, top: 2, bottom: 2);

  // 3. 字体行高 (解决数字自带留白的核心参数！通常 1.0~1.2 之间微调，数值越小字越往上缩)
  final double scoreTextHeight = 1.1;
  // ==========================================

  // --- UI 样式配置常量 ---
  final double dividerThickness = 1.0;
  final Color dividerColor = Colors.black;
  final Color rankBadgeBgColor = const Color(0x66000000); // Colors.black.withOpacity(0.4)
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

    return Container(
      color: dividerColor,
      child: _buildDynamicPKGrid(),
    );
  }

  // 🧠 基于行数的万能网格分配器
  Widget _buildDynamicPKGrid() {
    int count = players.length;
    switch (count) {
      case 2: return _buildFlexGrid([2]);
      case 3: return _build3PersonLayout();
      case 4: return _buildFlexGrid([2, 2]);
      case 5: return _buildFlexGrid([2, 3]);
      case 6: return _buildFlexGrid([3, 3]);
      case 7: return _buildFlexGrid([3, 4]);
      case 8: return _buildFlexGrid([4, 4]);
      case 9: return _buildFlexGrid([3, 3, 3]);
      default: return const Center(child: Text('仅支持 2-9 人', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _vDivider() => Container(width: dividerThickness, color: dividerColor);
  Widget _hDivider() => Container(height: dividerThickness, color: dividerColor);

  Widget _build3PersonLayout() {
    return Row(
      children: [
        Expanded(flex: 1, child: _buildCell(players[0])),
        _vDivider(),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(flex: 1, child: _buildCell(players[1])),
              _hDivider(),
              Expanded(flex: 1, child: _buildCell(players[2])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlexGrid(List<int> rowConfigs) {
    List<Widget> rows = [];
    int playerIndex = 0;

    for (int i = 0; i < rowConfigs.length; i++) {
      int colsInThisRow = rowConfigs[i];
      List<Widget> rowChildren = [];

      for (int j = 0; j < colsInThisRow; j++) {
        if (playerIndex < players.length) {
          rowChildren.add(Expanded(child: _buildCell(players[playerIndex])));
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
  // 🎨 单个方块 UI 渲染 (终极极简纯净版)
  // ==========================================
  Widget _buildCell(LivePKPlayerModel player) {
    bool hasProp = player.propText != null && player.propText!.isNotEmpty;
    bool showScoreBadge = players.length > 2;

    // 🟢 1. 计算全场最高分 (用于判断是否高亮背景)
    int highestScore = 0;
    for (var p in players) {
      if (p.score > highestScore) highestScore = p.score;
    }
    // 判断当前格子的玩家是否为最高分
    // bool isHighest = player.score == highestScore && highestScore > 0;
    bool isHighest = false;

    // 核心内容装配
    Widget cellContent = Container(
      clipBehavior: Clip.hardEdge, // 强制裁剪，防止高斯模糊泄漏
      decoration: const BoxDecoration(color: Color(0xFF1B1B1B)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. 🖼️ 底层：视频 或 头像高斯模糊
          _buildMediaContent(player),

          // 2. 🌫️ 阴影层：底部弱渐变 (保护名字文字)
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: bottomGradientHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // 3. 🥇 覆盖层左上角：排名 + 分数
          if (showScoreBadge)
            Positioned(
              top: rankBadgeTopOffset, // 👈 绑定微调变量：距离顶部
              left: rankBadgeLeftOffset, // 👈 绑定微调变量：距离左侧
              child: Container(
                padding: rankBadgePadding, // 👈 绑定微调变量：上下内边距
                decoration: BoxDecoration(
                  // 🟢 最高分黄色半透明，其他按阵营红蓝半透明
                  color: isHighest
                      ? Colors.orange.withOpacity(0.8)
                      : (player.isMyTeam
                      ? const Color(0xFFFF2E56).withOpacity(0.3)
                      : const Color(0xFF2962FF).withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(rankBadgeRadius),
                  border: isHighest ? Border.all(color: Colors.amberAccent.withAlpha(100), width: 0.5) : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center, // 👈 强制组件在 Row 中绝对居中对齐
                  children: [
                    // 阵营圆圈
                    Container(
                      width: rankCircleSize, height: rankCircleSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: player.isMyTeam ? const Color(0xFFD32F2F).withAlpha(100) : const Color(0xFF1565C0).withAlpha(100),
                      ),
                      child: Center(
                        child: Text(
                            '${player.rank}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: textRankSize,
                              fontWeight: FontWeight.bold,
                              height: 1.1, // 圆圈里的数字通常也需要给个行高来绝对居中
                            )
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // 分数文本
                    Text(
                        '${player.score}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: textScoreSize,
                          fontWeight: FontWeight.w600,
                          height: scoreTextHeight, // 👈 绑定微调变量：解决字体原生偏移
                          shadows: isHighest ? [const Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))] : null,
                        )
                    ),
                  ],
                ),
              ),
            ),

          // 4. 🔇 覆盖层右上角：静音图标
          if (player.isMuted)
            Positioned(top: 6, right: 6, child: Icon(Icons.mic_off_outlined, color: muteIconColor, size: muteIconSize)),

          // 5. 🏷️ 覆盖层底部：名字与道具状态栏
          Positioned(
            bottom: 4, left: 4, right: 4,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        player.name,
                        style: TextStyle(color: Colors.white, fontSize: textNameSize, fontWeight: FontWeight.w500, height: 1.2),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasProp) ...[
                      Container(width: 1, height: 10, margin: const EdgeInsets.symmetric(horizontal: 4), color: Colors.white38),
                      Text(player.propText!, style: TextStyle(color: Colors.white, fontSize: textPropSize, fontWeight: FontWeight.w600, height: 1.2), maxLines: 1),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // ✨ 融合点击事件
    return GestureDetector(
      onTap: () {
        if (onTapPlayer != null) onTapPlayer!(player);
      },
      behavior: HitTestBehavior.opaque,
      child: cellContent,
    );
  }

  // ✨ 融合：构建视频或非视频模式底图
  Widget _buildMediaContent(LivePKPlayerModel player) {
    Widget content;

    // 优先显示视频
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
      // 视频未准备好或无视频时，使用你的高斯模糊+头像组件
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
            // 👇 核心修复：加上四周留白，并强制自动缩放！
            child: Padding(
              padding: const EdgeInsets.all(12.0), // 给四周留一点呼吸空间，防止太贴边
              child: FittedBox(
                fit: BoxFit.scaleDown, // ✨ 核心魔法：放不下时自动等比例缩小，绝不溢出边界
                child: AvatarAnimation(
                  avatarUrl: player.avatarUrl,
                  isSpeaking: player.isSpeaking,
                  isRotating: false,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // ✨ 融合：如果是惩罚期输了，加上灰显滤镜
    if (player.isPunished) {
      return RepaintBoundary(
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
          child: content,
        ),
      );
    }

    return RepaintBoundary(child: content);
  }
}